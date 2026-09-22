$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'prepare_tianjin_customer_portraits.ps1') `
    -ArtRoot (Join-Path $PSScriptRoot '../resource/art/Wuhan') `
    -LayoutPath (Join-Path $PSScriptRoot '../resource/art/Wuhan/Customers/portrait_layout.json') `
    -PreviewPath (Join-Path $PSScriptRoot '../output/wuhan-customers/portraits.png') `
    -CharacterConfigPath (Join-Path $PSScriptRoot 'wuhan_customer_sources.json') `
    -CalibrationPath (Join-Path $PSScriptRoot 'wuhan_portrait_calibration.json')
