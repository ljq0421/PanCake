param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$IntermediatePath,

    [Parameter(Mandatory = $true)]
    [string]$FinalPath
)

Add-Type -AssemblyName System.Drawing

function Export-ScaledPng {
    param(
        [System.Drawing.Bitmap]$Source,
        [System.Drawing.Rectangle]$Crop,
        [int]$Width,
        [int]$Height,
        [string]$Path
    )

    $output = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $output.SetResolution(96, 96)
    $graphics = [System.Drawing.Graphics]::FromImage($output)

    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $destination = New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)
        $graphics.DrawImage($Source, $destination, $Crop, [System.Drawing.GraphicsUnit]::Pixel)
        $output.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $output.Dispose()
    }
}

$source = [System.Drawing.Bitmap]::FromFile($SourcePath)

try {
    # The generator returned 1672x941. The largest exact 16:9 crop is 1664x936,
    # removing only 4 px per side, 2 px at the top, and 3 px at the bottom.
    $cropWidth = [Math]::Floor($source.Width / 16) * 16
    $cropHeight = [Math]::Floor([Math]::Min($source.Height, $cropWidth * 9 / 16) / 9) * 9
    $cropWidth = $cropHeight * 16 / 9
    $cropX = [Math]::Floor(($source.Width - $cropWidth) / 2)
    $cropY = [Math]::Floor(($source.Height - $cropHeight) / 2)
    $crop = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropWidth, $cropHeight)

    Export-ScaledPng -Source $source -Crop $crop -Width 2048 -Height 1152 -Path $IntermediatePath

    $intermediate = [System.Drawing.Bitmap]::FromFile($IntermediatePath)
    try {
        $fullFrame = New-Object System.Drawing.Rectangle(0, 0, 2048, 1152)
        Export-ScaledPng -Source $intermediate -Crop $fullFrame -Width 1920 -Height 1080 -Path $FinalPath
    }
    finally {
        $intermediate.Dispose()
    }
}
finally {
    $source.Dispose()
}
