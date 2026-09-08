param(
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Destination,
    [int]$Width = 0
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
public static class TianjinGreenKey {
    public static void Export(string source, string destination, int width) {
        using (var input = new Bitmap(source))
        using (var bitmap = new Bitmap(input.Width, input.Height, PixelFormat.Format32bppArgb)) {
            using (var g = Graphics.FromImage(bitmap)) g.DrawImageUnscaled(input, 0, 0);
            var data = bitmap.LockBits(new Rectangle(0, 0, bitmap.Width, bitmap.Height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            var bytes = new byte[data.Stride * data.Height];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            int minX = bitmap.Width, minY = bitmap.Height, maxX = -1, maxY = -1, removed = 0;
            for (int y = 0; y < bitmap.Height; y++) for (int x = 0; x < bitmap.Width; x++) {
                int offset = y * data.Stride + x * 4;
                int max = Math.Max(bytes[offset], bytes[offset + 2]);
                int excess = bytes[offset + 1] - max;
                if (excess > 4) {
                    double alpha = Math.Max(0, 1 - (excess - 4) / 56.0);
                    bytes[offset + 3] = (byte)(bytes[offset + 3] * alpha);
                    bytes[offset + 1] = (byte)max;
                    if (alpha == 0) removed++;
                }
                if (bytes[offset + 3] > 12) {
                    minX = Math.Min(minX, x); minY = Math.Min(minY, y);
                    maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y);
                }
            }
            Marshal.Copy(bytes, 0, data.Scan0, bytes.Length);
            bitmap.UnlockBits(data);
            if (maxX < minX) throw new InvalidOperationException("Key removed entire image");
            minX = Math.Max(0, minX - 2); minY = Math.Max(0, minY - 2);
            maxX = Math.Min(bitmap.Width - 1, maxX + 2); maxY = Math.Min(bitmap.Height - 1, maxY + 2);
            var crop = new Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
            int outputWidth = width > 0 ? width : crop.Width;
            int outputHeight = (int)Math.Round((double)crop.Height * outputWidth / crop.Width);
            using (var output = new Bitmap(outputWidth, outputHeight, PixelFormat.Format32bppArgb)) {
                using (var g = Graphics.FromImage(output)) {
                    g.CompositingMode = CompositingMode.SourceCopy;
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    g.DrawImage(bitmap, new Rectangle(0,0,outputWidth,outputHeight), crop, GraphicsUnit.Pixel);
                }
                output.Save(destination, ImageFormat.Png);
            }
            Console.WriteLine("{0}: {1}x{2}; removed green pixels: {3}", destination, outputWidth, outputHeight, removed);
        }
    }
}
'@
$targetDirectory = Split-Path -Parent $Destination
New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
[TianjinGreenKey]::Export((Resolve-Path -LiteralPath $Source).Path, [IO.Path]::GetFullPath($Destination), $Width)
