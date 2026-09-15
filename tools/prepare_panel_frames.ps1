param([Parameter(Mandatory=$true)][string]$Source, [Parameter(Mandatory=$true)][string]$Destination,
      [int]$Width = 384, [switch]$AllowCenterTransparency)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Console,System.Runtime,System.Private.Windows.GdiPlus,System.Private.Windows.Core -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
public static class PanelFrameKey {
 public static void Run(string source, string destination, int targetWidth, bool allowCenterTransparency) {
  if(targetWidth<1) throw new ArgumentOutOfRangeException(nameof(targetWidth));
  using var input = new Bitmap(source);
  using var keyed = new Bitmap(input.Width, input.Height, PixelFormat.Format32bppArgb);
  int left=input.Width, top=input.Height, right=0, bottom=0;
  for(int y=0;y<input.Height;y++) for(int x=0;x<input.Width;x++) {
   var c=input.GetPixel(x,y);
   int excess=c.G-Math.Max(c.R,c.B);
   float a=(c.A/255f)*(1-Math.Clamp((excess-8)/100f,0,1));
   if(a<.02f) continue;
   int g=excess>8?Math.Min(c.G,Math.Max(c.R,c.B)):c.G;
   keyed.SetPixel(x,y,Color.FromArgb((int)(255*a),c.R,g,c.B));
   left=Math.Min(left,x); top=Math.Min(top,y); right=Math.Max(right,x); bottom=Math.Max(bottom,y);
  }
  if(right<=left || bottom<=top) throw new Exception("Empty foreground");
  var area=Rectangle.FromLTRB(Math.Max(0,left-4),Math.Max(0,top-4),Math.Min(input.Width,right+5),Math.Min(input.Height,bottom+5));
  int width=targetWidth, height=Math.Max(1,(int)Math.Round((double)width*area.Height/area.Width));
  using var output=new Bitmap(width,height,PixelFormat.Format32bppArgb);
  using(var g=Graphics.FromImage(output)) {
   g.CompositingMode=CompositingMode.SourceCopy;
   g.InterpolationMode=InterpolationMode.HighQualityBicubic;
   g.PixelOffsetMode=PixelOffsetMode.HighQuality;
   g.DrawImage(keyed,new Rectangle(0,0,width,height),area,GraphicsUnit.Pixel);
  }
  int transparent=0, partial=0, green=0;
  for(int y=0;y<height;y++) for(int x=0;x<width;x++) {
   var c=output.GetPixel(x,y);
   // Bicubic filtering can reintroduce a few green-dominant low-alpha pixels.
   if(c.A>0 && c.A<255 && c.G-Math.Max(c.R,c.B)>8) {
    c=Color.FromArgb(c.A,c.R,Math.Max(c.R,c.B),c.B);
    output.SetPixel(x,y,c);
   }
   if(c.A==0) transparent++; else if(c.A<255) partial++;
   if(c.A>0 && c.G-Math.Max(c.R,c.B)>8) green++;
  }
  if(transparent==0 || partial==0 || green>0 || (!allowCenterTransparency && output.GetPixel(width/2,height/2).A!=255))
   throw new Exception($"Alpha/edge validation failed: transparent={transparent}, partial={partial}, green={green}, center={output.GetPixel(width/2,height/2).A}");
  Directory.CreateDirectory(Path.GetDirectoryName(destination));
  output.Save(destination,ImageFormat.Png);
  Console.WriteLine($"{destination}: {width}x{height}; transparent={transparent}; antialiased={partial}; green spill={green}; center alpha={output.GetPixel(width/2,height/2).A}; source crop={area}");
 }
}
'@
[PanelFrameKey]::Run((Resolve-Path -LiteralPath $Source).Path, [IO.Path]::GetFullPath($Destination), $Width, $AllowCenterTransparency.IsPresent)
