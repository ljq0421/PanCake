$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$dest = Join-Path $PSScriptRoot 'upload'
$gen = 'D:\CodexHome-Clean-Test-20260814\generated_images\01a0d644-24c1-73e3-a3e4-719a7d7e29ea'
function Export-Png($source, $name, $width, $height) {
    $src = [System.Drawing.Image]::FromFile($source)
    $bmp = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $attr = [System.Drawing.Imaging.ImageAttributes]::new()
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $g.DrawImage($src, [System.Drawing.Rectangle]::new(0,0,$width,$height), 0,0,$src.Width,$src.Height,[System.Drawing.GraphicsUnit]::Pixel,$attr)
    $bmp.Save((Join-Path $dest $name),[System.Drawing.Imaging.ImageFormat]::Png)
    $attr.Dispose(); $g.Dispose(); $bmp.Dispose(); $src.Dispose()
}
Export-Png "$gen\exec-eba42dd9-700a-431e-9b23-cf79776c996c.png" 'library-capsule-schinese-600x900.png' 600 900
Export-Png "$gen\exec-572aba81-a78f-4486-bb1f-9cd145c21ad9.png" 'library-capsule-english-600x900.png' 600 900
Export-Png "$gen\exec-67038862-7682-4307-b81e-cd742a9f9b66.png" 'library-header-schinese-920x430.png' 920 430
Export-Png "$gen\exec-ef8243ff-4a30-47b4-a0d7-1c1ae2602db2.png" 'library-header-english-920x430.png' 920 430
Export-Png "$gen\exec-7564e605-2946-462c-bde0-daa33717ab93.png" 'library-hero-shared-3840x1240.png' 3840 1240
$art = Join-Path (Split-Path $PSScriptRoot) 'resource\art\Global\StartPage'
Export-Png "$art\全世界等我开饭.png" 'library-logo-schinese-1280x640.png' 1280 640
Export-Png "$art\World, Breakfast Is Served.png" 'library-logo-english-1280x640.png' 1280 640

$sheet = [System.Drawing.Bitmap]::new(1400,1200)
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::FromArgb(40,44,49))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
function Place($name,$x,$y,$w,$h) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $dest $name))
    $g.DrawImage($img,$x,$y,$w,$h)
    $img.Dispose()
}
Place 'library-capsule-schinese-600x900.png' 20 20 300 450
Place 'library-capsule-english-600x900.png' 340 20 300 450
Place 'library-header-schinese-920x430.png' 670 20 690 323
Place 'library-header-english-920x430.png' 670 360 690 323
Place 'library-logo-schinese-1280x640.png' 20 490 300 150
Place 'library-logo-english-1280x640.png' 340 490 300 150
Place 'library-hero-shared-3840x1240.png' 20 710 1344 434
# Illustrative logo placement; not an upload asset.
Place 'library-logo-schinese-1280x640.png' 70 920 360 180
$sheet.Save((Join-Path $PSScriptRoot 'review\overview.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $sheet.Dispose()

$report = foreach ($file in Get-ChildItem $dest -Filter '*.png') {
    $img = [System.Drawing.Bitmap]::new($file.FullName)
    $alpha = $img.GetPixel(0,0).A
    [PSCustomObject]@{File=$file.Name;Width=$img.Width;Height=$img.Height;CornerAlpha=$alpha;Bytes=$file.Length}
    if ($file.Name -like '*logo*' -and $alpha -ne 0) { throw "Logo lacks transparent corner: $($file.Name)" }
    $img.Dispose()
}
$report | ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot 'review\validation.json') -Encoding UTF8
$report | Format-Table -AutoSize
