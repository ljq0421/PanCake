Add-Type -AssemblyName System.Drawing
$rackGuide = New-Object System.Drawing.Bitmap(1024,1024)
$rackGraphics = [System.Drawing.Graphics]::FromImage($rackGuide)
$rackGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$rackGraphics.ScaleTransform(2,2)
$rackGraphics.Clear([System.Drawing.Color]::Lime)
$rackOutline = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#513018'),4)
$rackOutline.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
function PointOnTray([double]$u,[double]$v) {
    [System.Drawing.PointF]::new([single](52+18.6*$v+(400-12*$v)*$u),[single](306-144*$v))
}
function FillPoly([string]$color,[System.Drawing.PointF[]]$points) {
    $rackBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($color))
    $rackGraphics.FillPolygon($rackBrush,$points)
    $rackGraphics.DrawPolygon($rackOutline,$points)
    $rackBrush.Dispose()
}
FillPoly '#E9B968' @([System.Drawing.PointF]::new(52,306),[System.Drawing.PointF]::new(452,306),[System.Drawing.PointF]::new(448,329),[System.Drawing.PointF]::new(57,329))
FillPoly '#FFF0BB' @((PointOnTray 0 0),(PointOnTray 1 0),(PointOnTray 1 1),(PointOnTray 0 1))
FillPoly '#E8A242' @((PointOnTray 0.055 0.11),(PointOnTray 0.945 0.11),(PointOnTray 0.945 0.88),(PointOnTray 0.055 0.88))
$rackDark = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#654737'),9)
$rackLight = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#DCCFC0'),5)
foreach($rackPen in @($rackDark,$rackLight)) {
    $rackPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $rackPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $rackGraphics.DrawLine($rackPen,(PointOnTray 0.09 0.15),(PointOnTray 0.09 0.85))
    $rackGraphics.DrawLine($rackPen,(PointOnTray 0.91 0.15),(PointOnTray 0.91 0.85))
    foreach($rackDepth in @(0.18,0.34,0.5,0.66,0.82)) {
        $rackGraphics.DrawLine($rackPen,(PointOnTray 0.09 $rackDepth),(PointOnTray 0.91 $rackDepth))
    }
}
$rackGuide.Save((Join-Path $PSScriptRoot 'perspective-guide.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$rackLight.Dispose()
$rackDark.Dispose()
$rackOutline.Dispose()
$rackGraphics.Dispose()
$rackGuide.Dispose()
