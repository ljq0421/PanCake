param(
    [string]$Source = "$PSScriptRoot/../resource/art/Wuhan/蛋液勺.png",
    [string]$Output = "$PSScriptRoot/../resource/art/Wuhan/蛋液勺-透明-v1.png"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Private.Windows.GdiPlus,System.Private.Windows.Core,System.Collections -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
public static class EggLadleMatte {
    public static void Extract(string source, string output) {
        using var original = new Bitmap(source);
        using var image = new Bitmap(original.Width, original.Height, PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(image)) graphics.DrawImageUnscaled(original, 0, 0);
        int w = image.Width, h = image.Height;
        var visited = new bool[w*h];
        var queue = new Queue<int>();
        void Enqueue(int x, int y) {
            if (x < 0 || y < 0 || x >= w || y >= h || visited[y*w+x]) return;
            var c = image.GetPixel(x,y);
            if (Math.Min(c.R, Math.Min(c.G,c.B)) < 205 || Math.Max(c.R,Math.Max(c.G,c.B))-Math.Min(c.R,Math.Min(c.G,c.B)) > 24) return;
            visited[y*w+x] = true; queue.Enqueue(y*w+x);
        }
        for(int x=0;x<w;x++){Enqueue(x,0);Enqueue(x,h-1);}
        for(int y=0;y<h;y++){Enqueue(0,y);Enqueue(w-1,y);}
        while(queue.Count>0){int i=queue.Dequeue(),x=i%w,y=i/w;Enqueue(x-1,y);Enqueue(x+1,y);Enqueue(x,y-1);Enqueue(x,y+1);}
        // Only edge-connected white matte is removed; metal and liquid highlights survive.
        for(int y=0;y<h;y++)for(int x=0;x<w;x++) if(visited[y*w+x])image.SetPixel(x,y,Color.Transparent);
        image.Save(output,ImageFormat.Png);
    }
}
'@
[EggLadleMatte]::Extract([IO.Path]::GetFullPath($Source), [IO.Path]::GetFullPath($Output))
