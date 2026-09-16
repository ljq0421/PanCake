param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Save-AlphaCrop {
    param(
        [System.Drawing.Bitmap]$Image,
        [System.Drawing.Rectangle]$SearchArea,
        [int]$TargetWidth,
        [string]$Path
    )

    $left = $SearchArea.Right; $top = $SearchArea.Bottom; $right = $SearchArea.Left; $bottom = $SearchArea.Top
    for ($y = $SearchArea.Top; $y -lt $SearchArea.Bottom; $y++) {
        for ($x = $SearchArea.Left; $x -lt $SearchArea.Right; $x++) {
            if ($Image.GetPixel($x, $y).A -le 8) { continue }
            $left = [Math]::Min($left, $x); $top = [Math]::Min($top, $y)
            $right = [Math]::Max($right, $x); $bottom = [Math]::Max($bottom, $y)
        }
    }
    if ($right -lt $left -or $bottom -lt $top) { throw "No visible artwork found in $SearchArea." }

    $padding = 4
    $crop = [System.Drawing.Rectangle]::FromLTRB(
        [Math]::Max(0, $left - $padding), [Math]::Max(0, $top - $padding),
        [Math]::Min($Image.Width, $right + $padding + 1), [Math]::Min($Image.Height, $bottom + $padding + 1))
    $targetHeight = [Math]::Round($TargetWidth * $crop.Height / $crop.Width)
    $output = [System.Drawing.Bitmap]::new($TargetWidth, $targetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($output)
        try {
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($Image, [System.Drawing.Rectangle]::new(0, 0, $TargetWidth, $targetHeight), $crop, [System.Drawing.GraphicsUnit]::Pixel)
        }
        finally { $graphics.Dispose() }
        $output.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "$Path $TargetWidth`x$targetHeight from $crop"
    }
    finally { $output.Dispose() }
}

$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$input = [System.Drawing.Bitmap]::new($sourcePath)
try {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Save-AlphaCrop $input ([System.Drawing.Rectangle]::new(0, 0, $input.Width, 480)) 768 (Join-Path $Destination 'teaching-panel-v1.png')
    Save-AlphaCrop $input ([System.Drawing.Rectangle]::new(0, 480, $input.Width, $input.Height - 480)) 272 (Join-Path $Destination 'teaching-action-v1.png')
}
finally { $input.Dispose() }
