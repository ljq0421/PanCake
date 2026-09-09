param([Parameter(Mandatory=$true)][string]$Source, [Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 6) {
    & powershell.exe -NoProfile -File $PSCommandPath -Source $Source -Destination $Destination
    if ($LASTEXITCODE -ne 0) { throw 'Tray keying failed in Windows PowerShell.' }
    return
}
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class WuhanTrayKey {
    public static void Export(string source, string destination) {
        using (var original = new Bitmap(source))
        using (var bmp = new Bitmap(original.Width, original.Height, PixelFormat.Format32bppArgb)) {
            using (var g = Graphics.FromImage(bmp)) g.DrawImageUnscaled(original, 0, 0);
            int w = bmp.Width, h = bmp.Height;
            var bits = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            var data = new byte[bits.Stride * h];
            Marshal.Copy(bits.Scan0, data, 0, data.Length);
            var background = new bool[w * h];
            var queue = new System.Collections.Generic.Queue<int>();
            for (int x = 0; x < w; x++) { queue.Enqueue(x); queue.Enqueue((h - 1) * w + x); }
            for (int y = 0; y < h; y++) { queue.Enqueue(y * w); queue.Enqueue(y * w + w - 1); }
            while (queue.Count > 0) {
                int p = queue.Dequeue(); if (background[p]) continue;
                int x = p % w, y = p / w, i = y * bits.Stride + x * 4;
                if (data[i + 1] < 140 || data[i + 1] - Math.Max(data[i], data[i + 2]) < 80) continue;
                background[p] = true;
                if (x > 0) queue.Enqueue(p - 1); if (x + 1 < w) queue.Enqueue(p + 1);
                if (y > 0) queue.Enqueue(p - w); if (y + 1 < h) queue.Enqueue(p + w);
            }
            int left = w, top = h, right = -1, bottom = -1;
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
                int i = y * bits.Stride + x * 4;
                if (background[y * w + x]) { data[i] = data[i + 1] = data[i + 2] = data[i + 3] = 0; continue; }
                bool edge = false;
                for (int yy = Math.Max(0, y - 2); yy <= Math.Min(h - 1, y + 2); yy++)
                    for (int xx = Math.Max(0, x - 2); xx <= Math.Min(w - 1, x + 2); xx++) edge |= background[yy * w + xx];
                // Only decontaminate silhouette edges, preserving the authored teal stripe.
                int max = Math.Max(data[i], data[i + 2]), excess = data[i + 1] - max;
                if (edge && excess > 0) { data[i + 3] = (byte)(255 - excess); data[i + 1] = (byte)max; }
                if (data[i + 3] >= 32) { left = Math.Min(left, x); top = Math.Min(top, y); right = Math.Max(right, x); bottom = Math.Max(bottom, y); }
            }
            Marshal.Copy(data, 0, bits.Scan0, data.Length); bmp.UnlockBits(bits);
            if (right < left) throw new Exception("No tray silhouette after keying");
            var crop = new Rectangle(left, top, right - left + 1, bottom - top + 1);
            using (var output = bmp.Clone(crop, PixelFormat.Format32bppArgb)) output.Save(destination, ImageFormat.Png);
            Console.WriteLine("{0}: {1}x{2}", destination, crop.Width, crop.Height);
        }
    }
}
'@
New-Item -ItemType Directory -Force (Split-Path -Parent $Destination) | Out-Null
[WuhanTrayKey]::Export((Resolve-Path -LiteralPath $Source).Path, [IO.Path]::GetFullPath($Destination))
