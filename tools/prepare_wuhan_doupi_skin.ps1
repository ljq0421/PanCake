param(
    [Parameter(Mandatory=$true)][string]$Source,
    [string]$Output = "$PSScriptRoot/../resource/art/Wuhan/豆皮基础层-透明-v1.png"
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Private.Windows.GdiPlus,System.Private.Windows.Core -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
public static class DoupiGreenMatte {
    public static void Extract(string source, string output) {
        using var input = new Bitmap(source);
        using var result = new Bitmap(input.Width, input.Height, PixelFormat.Format32bppArgb);
        for (int y=0;y<input.Height;y++) for (int x=0;x<input.Width;x++) {
            var c=input.GetPixel(x,y);
            float a=1-Math.Clamp((c.G-Math.Max(c.R,c.B))/32f,0,1);
            if(a<.04f) { result.SetPixel(x,y,Color.Transparent); continue; }
            int Channel(float value) => (int)Math.Clamp(Math.Round(value/a),0,255);
            result.SetPixel(x,y,Color.FromArgb((int)(a*c.A),Channel(c.R),Channel(c.G-(1-a)*255),Channel(c.B)));
        }
        result.Save(output,ImageFormat.Png);
    }
}
'@
[DoupiGreenMatte]::Extract([IO.Path]::GetFullPath($Source),[IO.Path]::GetFullPath($Output))
