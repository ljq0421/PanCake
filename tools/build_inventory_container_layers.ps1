param(
    [string]$SourceDir = "assets/jianbing-stall/inventory-containers-v1/source",
    [string]$OutputDir = "assets/jianbing-stall/inventory-containers-v1"
)

Add-Type -AssemblyName System.Drawing

$CanvasSize = 512
$PixelFormat = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
$PngFormat = [System.Drawing.Imaging.ImageFormat]::Png

function Get-AlphaBounds {
    param([System.Drawing.Bitmap]$Bitmap, [System.Drawing.Rectangle]$Area)

    $left = $Area.Right
    $top = $Area.Bottom
    $right = -1
    $bottom = -1
    for ($y = $Area.Top; $y -lt $Area.Bottom; $y++) {
        for ($x = $Area.Left; $x -lt $Area.Right; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -gt 8) {
                if ($x -lt $left) { $left = $x }
                if ($x -gt $right) { $right = $x }
                if ($y -lt $top) { $top = $y }
                if ($y -gt $bottom) { $bottom = $y }
            }
        }
    }
    if ($right -lt $left) { return $null }
    return [System.Drawing.Rectangle]::FromLTRB($left, $top, $right + 1, $bottom + 1)
}

function New-Canvas {
    $canvas = New-Object System.Drawing.Bitmap($CanvasSize, $CanvasSize, $PixelFormat)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    return @{ Bitmap = $canvas; Graphics = $graphics }
}

function Save-Canvas {
    param($Canvas, [string]$Path)
    $Canvas.Graphics.Dispose()
    $Canvas.Bitmap.Save($Path, $PngFormat)
    $Canvas.Bitmap.Dispose()
}

function Write-Base {
    param([string]$InputPath, [string]$OutputPath, [int]$TargetWidth, [int]$TargetHeight, [int]$X, [int]$Y)
    $input = New-Object System.Drawing.Bitmap($InputPath)
    $bounds = Get-AlphaBounds $input ([System.Drawing.Rectangle]::FromLTRB(0, 0, $input.Width, $input.Height))
    $canvas = New-Canvas
    $canvas.Graphics.DrawImage($input, [System.Drawing.Rectangle]::new($X, $Y, $TargetWidth, $TargetHeight), $bounds, [System.Drawing.GraphicsUnit]::Pixel)
    Save-Canvas $canvas $OutputPath
    $input.Dispose()
}

function Write-ContentSet {
    param(
        [string]$InputPath,
        [string]$Prefix,
        [int]$MaxWidth,
        [int]$MaxHeight,
        [int]$AnchorX,
        [int]$AnchorBottom
    )
    $input = New-Object System.Drawing.Bitmap($InputPath)
    $cellWidth = [int]($input.Width / 4)
    $names = @("quarter", "half", "three-quarters", "full")
    $empty = New-Canvas
    Save-Canvas $empty (Join-Path $OutputDir "$Prefix-content-empty.png")

    for ($index = 0; $index -lt 4; $index++) {
        $cell = [System.Drawing.Rectangle]::new($index * $cellWidth, 0, $cellWidth, $input.Height)
        $bounds = Get-AlphaBounds $input $cell
        $scale = [Math]::Min($MaxWidth / $bounds.Width, $MaxHeight / $bounds.Height)
        $width = [int][Math]::Round($bounds.Width * $scale)
        $height = [int][Math]::Round($bounds.Height * $scale)
        $x = [int][Math]::Round($AnchorX - ($width / 2))
        $y = $AnchorBottom - $height
        $canvas = New-Canvas
        $canvas.Graphics.DrawImage($input, [System.Drawing.Rectangle]::new($x, $y, $width, $height), $bounds, [System.Drawing.GraphicsUnit]::Pixel)
        Save-Canvas $canvas (Join-Path $OutputDir "$Prefix-content-$($names[$index]).png")
    }
    $input.Dispose()
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Fixed, immutable container bottoms. Each asset is intended to render at ~128–170 px in the 1920×1080 workstation.
Write-Base (Join-Path $SourceDir "scallion-basket-base.png") (Join-Path $OutputDir "scallion-basket-base.png") 400 312 56 150
Write-Base (Join-Path $SourceDir "egg-basket-base.png") (Join-Path $OutputDir "egg-basket-base.png") 400 210 56 190
Write-Base (Join-Path $SourceDir "crisp-tray-base.png") (Join-Path $OutputDir "crisp-tray-base.png") 456 146 28 200

# Content overlays share a canvas and a fixed anchor per container, so changing inventory never moves the vessel.
Write-ContentSet (Join-Path $SourceDir "scallion-content-sheet.png") "scallion" 250 180 256 310
Write-ContentSet (Join-Path $SourceDir "egg-content-sheet.png") "egg" 250 172 256 306
Write-ContentSet (Join-Path $SourceDir "crisp-content-sheet.png") "crisp" 300 160 256 304
