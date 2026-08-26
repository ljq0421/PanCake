param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies ([System.Drawing.Bitmap].Assembly.Location) -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

public static class CheckerboardAlphaExtractor
{
    public static void Run(string inputPath, string outputPath)
    {
        using (var sourceFile = new Bitmap(inputPath))
        using (var source = new Bitmap(sourceFile.Width, sourceFile.Height, PixelFormat.Format32bppArgb))
        using (var graphics = Graphics.FromImage(source))
        {
            graphics.DrawImageUnscaled(sourceFile, 0, 0);
            int width = source.Width;
            int height = source.Height;
            var rect = new Rectangle(0, 0, width, height);
            var data = source.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            byte[] pixels = new byte[Math.Abs(data.Stride) * height];
            System.Runtime.InteropServices.Marshal.Copy(data.Scan0, pixels, 0, pixels.Length);
            source.UnlockBits(data);

            bool[] background = new bool[width * height];
            int[] queue = new int[width * height];
            int head = 0, tail = 0;

            Action<int, int> enqueue = (x, y) => {
                int p = y * width + x;
                if (background[p] || !LooksLikeCheckerboard(pixels, data.Stride, x, y)) return;
                background[p] = true;
                queue[tail++] = p;
            };

            for (int x = 0; x < width; x++) { enqueue(x, 0); enqueue(x, height - 1); }
            for (int y = 1; y < height - 1; y++) { enqueue(0, y); enqueue(width - 1, y); }

            while (head < tail)
            {
                int p = queue[head++];
                int x = p % width;
                int y = p / width;
                if (x > 0) enqueue(x - 1, y);
                if (x + 1 < width) enqueue(x + 1, y);
                if (y > 0) enqueue(x, y - 1);
                if (y + 1 < height) enqueue(x, y + 1);
            }

            using (var output = new Bitmap(width, height, PixelFormat.Format32bppArgb))
            {
                var outData = output.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                byte[] result = new byte[Math.Abs(outData.Stride) * height];
                for (int y = 0; y < height; y++)
                {
                    for (int x = 0; x < width; x++)
                    {
                        int p = y * width + x;
                        int src = y * data.Stride + x * 4;
                        int dst = y * outData.Stride + x * 4;
                        result[dst] = pixels[src];
                        result[dst + 1] = pixels[src + 1];
                        result[dst + 2] = pixels[src + 2];
                        result[dst + 3] = background[p] ? (byte)0 : (byte)255;
                    }
                }
                System.Runtime.InteropServices.Marshal.Copy(result, 0, outData.Scan0, result.Length);
                output.UnlockBits(outData);
                output.Save(outputPath, ImageFormat.Png);
            }
        }
    }

    private static bool LooksLikeCheckerboard(byte[] pixels, int stride, int x, int y)
    {
        int i = y * stride + x * 4;
        int b = pixels[i], g = pixels[i + 1], r = pixels[i + 2];
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        int average = (r + g + b) / 3;
        return average >= 80 && max - min <= 14;
    }
}
'@

[CheckerboardAlphaExtractor]::Run($InputPath, $OutputPath)
