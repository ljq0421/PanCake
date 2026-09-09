param([string]$Source = "$PSScriptRoot/../resource/art/TianJin/OrderUI/Sources/sauce_amounts_green.png")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskRoot = [IO.Path]::GetFullPath("$PSScriptRoot/..")
$taskOutput = Join-Path $taskRoot 'resource/art/TianJin/OrderUI'
$taskTemp = Join-Path $taskRoot '.tmp/order-icons'
New-Item -ItemType Directory -Force -Path $taskOutput,$taskTemp | Out-Null
$taskBitmap = [Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $Source).Path)
try {
    $taskHalf = [int]($taskBitmap.Width / 2)
    for ($taskIndex = 0; $taskIndex -lt 2; $taskIndex++) {
        $taskName = @('sauce_light','sauce_extra')[$taskIndex]
        $taskCrop = $taskBitmap.Clone([Drawing.Rectangle]::new($taskIndex * $taskHalf,0,$taskHalf,$taskBitmap.Height),[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $taskPath = Join-Path $taskTemp "$taskName-green.png"
        try { $taskCrop.Save($taskPath,[Drawing.Imaging.ImageFormat]::Png) } finally { $taskCrop.Dispose() }
        & "$PSScriptRoot/prepare_tianjin_stock_ui.ps1" -Source $taskPath -Destination (Join-Path $taskOutput "$taskName.png") -Width 96
    }
} finally { $taskBitmap.Dispose() }
