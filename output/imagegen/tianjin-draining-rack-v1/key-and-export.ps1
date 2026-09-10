param(
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Destination,
    [switch]$Replace
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies @([System.Drawing.Bitmap].Assembly.Location, [System.Drawing.Color].Assembly.Location) -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
public static class RackSpriteExport {
    public static string Export(string source, string destination) {
        using (var input = new Bitmap(source))
        using (var cutout = new Bitmap(input.Width, input.Height, PixelFormat.Format32bppArgb)) {
            for (int y = 0; y < input.Height; y++) {
                for (int x = 0; x < input.Width; x++) {
                    Color c = input.GetPixel(x, y);
                    double excess = c.G - Math.Max(c.R, c.B);
                    double coverage = 1.0 - Math.Max(0.0, Math.Min(1.0, (excess - 8.0) / 70.0));
                    int alpha = (int)Math.Round(255.0 * coverage);
                    if (alpha == 0) cutout.SetPixel(x, y, Color.Transparent);
                    else {
                        int green = alpha < 255 ? Math.Min(c.G, Math.Max(c.R, c.B)) : c.G;
                        cutout.SetPixel(x, y, Color.FromArgb(alpha, c.R, green, c.B));
                    }
                }
            }
            using (var output = new Bitmap(512, 512, PixelFormat.Format32bppArgb)) {
                using (var graphics = Graphics.FromImage(output)) {
                    graphics.Clear(Color.Transparent);
                    graphics.CompositingMode = CompositingMode.SourceCopy;
                    graphics.CompositingQuality = CompositingQuality.HighQuality;
                    graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    graphics.DrawImage(cutout, new Rectangle(0, 0, 512, 512), 0, 0, input.Width, input.Height, GraphicsUnit.Pixel);
                }
                int transparent = 0, opaque = 0, partial = 0, greenSpill = 0;
                int minX = 512, minY = 512, maxX = -1, maxY = -1;
                for (int y = 0; y < 512; y++) {
                    for (int x = 0; x < 512; x++) {
                        Color c = output.GetPixel(x, y);
                        if (c.A > 0 && c.G > Math.Max(c.R, c.B) + 8) {
                            c = Color.FromArgb(c.A, c.R, Math.Max(c.R, c.B), c.B);
                            output.SetPixel(x, y, c);
                        }
                        if (c.A == 0) transparent++;
                        else {
                            if (c.A == 255) opaque++; else partial++;
                            if (c.G - Math.Max(c.R, c.B) > 15) greenSpill++;
                            minX = Math.Min(minX, x); minY = Math.Min(minY, y);
                            maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y);
                        }
                    }
                }
                if (transparent == 0 || opaque == 0) throw new Exception("Expected transparent background and opaque subject.");
                if (minX <= 0 || minY <= 0 || maxX >= 511 || maxY >= 511) throw new Exception("Subject touches canvas boundary.");
                output.Save(destination, ImageFormat.Png);
                return String.Format("512x512 RGBA PNG; transparent={0}, opaque={1}, antialiased={2}, greenSpill={3}, subjectBounds=({4},{5})-({6},{7})", transparent, opaque, partial, greenSpill, minX, minY, maxX, maxY);
            }
        }
    }
}
'@
if ((Test-Path -LiteralPath $Destination) -and -not $Replace) { throw "Refusing to overwrite existing asset: $Destination" }
[RackSpriteExport]::Export($Source, $Destination)
