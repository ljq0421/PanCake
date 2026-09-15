# Rebuild the two-channel data mask from the unchanged 1672x941 master.
# Requires Windows System.Drawing; no image-generation or third-party packages.
param([string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent), [switch]$WithNote)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$drawingReferences = if ($PSVersionTable.PSEdition -eq 'Core') { @('System.Drawing.Common', 'System.Drawing.Primitives', 'System.Private.Windows.GdiPlus', 'System.Private.Windows.Core') } else { @('System.Drawing') }
Add-Type -ReferencedAssemblies $drawingReferences -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
public static class JourneyBookMask {
    static double Smooth(double lo, double hi, double value) {
        double t = Math.Max(0, Math.Min(1, (value - lo) / (hi - lo)));
        return t * t * (3 - 2 * t);
    }
    public static void Build(string source, string output, bool withNote) {
        using (var image = new Bitmap(source))
        using (var mask = new Bitmap(image.Width, image.Height, PixelFormat.Format24bppRgb)) {
            if (image.Width != 1672 || image.Height != 941)
                throw new InvalidOperationException("Master dimensions changed; recalibrate mask landmarks.");
            for (int y = 0; y < image.Height; y++) for (int x = 0; x < image.Width; x++) {
                Color c = image.GetPixel(x, y);
                double cover = 0, ornament = 0;
                if (c.A > 0) {
                    // These envelopes select regions only; source pigment supplies their edges.
                    bool outer = x < 105 || x > 1580 || y < 96 || y > 820;
                    if (outer) cover = (1 - Smooth(180, 225, c.R)) * (1 - Smooth(150, 200, c.G));
                    if (x >= 832 && x <= 840 && y >= 89 && y <= 852)
                        cover = Math.Max(cover, 1 - Smooth(205, 236, c.G));
                    bool corner = (x >= 100 && x <= 390 && y >= 73 && y <= 326)
                        || (x >= 70 && x <= 227 && y >= 674 && y <= 813) // globe
                        || (x >= 80 && x <= 145 && y >= 610 && y <= 665)
                        || (x >= 202 && x <= 255 && y >= 651 && y <= 716)
                        || (x >= 237 && x <= 303 && y >= 710 && y <= 809)
                        || (x >= 1510 && x <= 1576 && y >= 73 && y <= 125)
                        || (x >= 1410 && x <= 1475 && y >= 165 && y <= 235)
                        || (x >= 1455 && x <= 1595 && y >= 105 && y <= 340) // tag
                        || (x >= 1540 && x <= 1578 && y >= 350 && y <= 388)
                        || (x >= 1490 && x <= 1594 && y >= 535 && y <= 645) // route/star
                        || (x >= 1450 && x <= 1560 && y >= 645 && y <= 722)
                        || (x >= 1360 && x <= 1480 && y >= 700 && y <= 799)
                        || (x >= 1410 && x <= 1607 && y >= 698 && y <= 817 && x < 1634 - (y - 698) * .40); // coffee/bread
                    if (corner) {
                        // Cream paper stays unmasked; colored ink is darker and/or more chromatic.
                        double chroma = Math.Max(c.R, Math.Max(c.G, c.B)) - Math.Min(c.R, Math.Min(c.G, c.B));
                        ornament = Math.Max(1 - Smooth(221, 239, c.G), Smooth(32, 58, chroma));
                        ornament *= 1 - cover;
                    }
                }
                // Keep the baked paper, pin, tag and printed rules in their original colors.
                if (withNote && x >= 855 && x <= 1530 && y >= 130 && y <= 790 - .075 * x) {
                    cover = 0; ornament = 0;
                }
                mask.SetPixel(x, y, Color.FromArgb((int)Math.Round(cover * 255), (int)Math.Round(ornament * 255), 0));
            }
            mask.Save(output, ImageFormat.Png);
        }
    }
}
'@
$artRoot = Join-Path $ProjectRoot 'resource/art/Global/StartPage'
$sourceName = if ($WithNote) { "旅行手账双页母版-带便签.png" } else { "旅行手账双页母版.png" }
$maskName = if ($WithNote) { "旅行手账双页分区遮罩-带便签.png" } else { "旅行手账双页分区遮罩.png" }
[JourneyBookMask]::Build((Join-Path $artRoot $sourceName), (Join-Path $artRoot $maskName), [bool]$WithNote)
Write-Output 'Rebuilt journey book mask (R: cover/spine, G: ornaments).'
