$ErrorActionPreference = 'Stop'

$sourcePath = 'D:\CodexHome-Clean-Test-20260814\generated_images\01a06b51-fca6-7051-8205-5953424b414a\exec-cdbf1a59-b870-41ad-b1cb-465dbc058ac4.png'
$outputPath = 'D:\Project\ProjectCake\project-cake\resource\art\天津早餐铺男上班族顾客-v1.png'

Add-Type -AssemblyName System.Drawing
$drawingAssembly = [System.Drawing.Bitmap].Assembly.Location
$gdiPlusAssembly = Join-Path (Split-Path $drawingAssembly) 'System.Private.Windows.GdiPlus.dll'
Add-Type -ReferencedAssemblies @($drawingAssembly, $gdiPlusAssembly) -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class SpriteExtractor
{
    public static void Extract(string sourcePath, string outputPath)
    {
        using (var src = new Bitmap(sourcePath))
        {
            int w = src.Width, h = src.Height, n = w * h;
            var candidate = new bool[n];
            for (int y = 0; y < h; y++)
            {
                for (int x = 0; x < w; x++)
                {
                    Color c = src.GetPixel(x, y);
                    int min = Math.Min(c.R, Math.Min(c.G, c.B));
                    int max = Math.Max(c.R, Math.Max(c.G, c.B));
                    candidate[y * w + x] = min < 210 || (max - min) > 20;
                }
            }

            var visited = new bool[n];
            var queue = new int[n];
            List<int> largest = null;
            int[] dx = { 1, -1, 0, 0 };
            int[] dy = { 0, 0, 1, -1 };

            for (int start = 0; start < n; start++)
            {
                if (!candidate[start] || visited[start]) continue;
                int head = 0, tail = 0;
                queue[tail++] = start;
                visited[start] = true;
                var component = new List<int>();
                while (head < tail)
                {
                    int p = queue[head++];
                    component.Add(p);
                    int px = p % w, py = p / w;
                    for (int d = 0; d < 4; d++)
                    {
                        int nx = px + dx[d], ny = py + dy[d];
                        if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
                        int np = ny * w + nx;
                        if (candidate[np] && !visited[np])
                        {
                            visited[np] = true;
                            queue[tail++] = np;
                        }
                    }
                }
                if (largest == null || component.Count > largest.Count) largest = component;
            }

            if (largest == null) throw new InvalidOperationException("No foreground component detected.");
            var foreground = new bool[n];
            foreach (int p in largest) foreground[p] = true;

            // Fill light-colored holes enclosed by the character silhouette.
            var exterior = new bool[n];
            int qh = 0, qt = 0;
            Action<int> enqueueExterior = p =>
            {
                if (!foreground[p] && !exterior[p])
                {
                    exterior[p] = true;
                    queue[qt++] = p;
                }
            };
            for (int x = 0; x < w; x++) { enqueueExterior(x); enqueueExterior((h - 1) * w + x); }
            for (int y = 0; y < h; y++) { enqueueExterior(y * w); enqueueExterior(y * w + w - 1); }
            while (qh < qt)
            {
                int p = queue[qh++];
                int px = p % w, py = p / w;
                for (int d = 0; d < 4; d++)
                {
                    int nx = px + dx[d], ny = py + dy[d];
                    if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
                    int np = ny * w + nx;
                    if (!foreground[np] && !exterior[np])
                    {
                        exterior[np] = true;
                        queue[qt++] = np;
                    }
                }
            }
            for (int p = 0; p < n; p++) foreground[p] = !exterior[p];

            using (var cutout = new Bitmap(w, h, PixelFormat.Format32bppArgb))
            {
                for (int y = 0; y < h; y++)
                {
                    for (int x = 0; x < w; x++)
                    {
                        int p = y * w + x;
                        if (foreground[p])
                        {
                            Color c = src.GetPixel(x, y);
                            cutout.SetPixel(x, y, Color.FromArgb(255, c.R, c.G, c.B));
                        }
                        else cutout.SetPixel(x, y, Color.Transparent);
                    }
                }

                using (var final = new Bitmap(768, 1024, PixelFormat.Format32bppArgb))
                using (Graphics g = Graphics.FromImage(final))
                {
                    g.CompositingMode = CompositingMode.SourceCopy;
                    g.CompositingQuality = CompositingQuality.HighQuality;
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    g.SmoothingMode = SmoothingMode.HighQuality;
                    g.Clear(Color.Transparent);
                    g.DrawImage(cutout, new Rectangle(0, 0, 768, 1024), new Rectangle(0, 0, w, h), GraphicsUnit.Pixel);
                    final.Save(outputPath, ImageFormat.Png);
                }
            }
        }
    }
}
'@

[SpriteExtractor]::Extract($sourcePath, $outputPath)
Get-Item -LiteralPath $outputPath | Select-Object FullName, Length
