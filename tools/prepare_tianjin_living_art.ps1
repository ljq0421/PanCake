param(
  [string]$GeneratedRoot = 'D:/CodexHome-Clean-Test-20260814/generated_images/01a0a30d-9af7-7152-988f-613da4fb7668',
  [switch]$RefreshGeneratedSources
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$artRoot = Join-Path $projectRoot 'resource/art/TianJin/LivingWorkbench'
$recordRoot = Join-Path $projectRoot 'docs/art-concepts/tianjin-living'
New-Item -ItemType Directory -Force -Path $artRoot,$recordRoot | Out-Null
if ($RefreshGeneratedSources) {
  Copy-Item -LiteralPath (Join-Path $GeneratedRoot 'exec-e69716fe-2222-41ac-8dee-167c7ad3c5e7.png') -Destination (Join-Path $recordRoot 'sprites-green.png') -Force
  Copy-Item -LiteralPath (Join-Path $GeneratedRoot 'exec-fdf4d68f-eea2-4773-bfc6-5f9d0a6799bc.png') -Destination (Join-Path $recordRoot 'clean-generated.png') -Force
}
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Console,System.Runtime,System.Private.Windows.GdiPlus,System.Private.Windows.Core -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
public static class TianjinLivingArt {
 public static void Build(string source, string records, string output) {
  using var green = new Bitmap(Path.Combine(records,"sprites-green.png"));
  Sprite(green,new Rectangle(180,20,440,900),Path.Combine(output,"pendant.png"));
  Sprite(green,new Rectangle(780,165,740,310),Path.Combine(output,"scraper.png"));
  Sprite(green,new Rectangle(790,575,730,245),Path.Combine(output,"spatula.png"));
  using var clean = new Bitmap(Path.Combine(records,"clean-generated.png"));
  foreach(string stem in new[]{"天津-煎饼","天津-煎饼-炸锅","天津-煎饼-炸锅-豆浆"}) {
   using var original = new Bitmap(Path.Combine(source,stem+"-v3.png"));
   using var result = new Bitmap(original);
   // Transfer only authorized removal regions. Pixels elsewhere remain identical.
   foreach(var area in new[]{new Rectangle(1213,65,141,273),new Rectangle(1115,503,371,71)})
    for(int y=area.Top;y<area.Bottom;y++) for(int x=area.Left;x<area.Right;x++) {
     int edge=Math.Min(Math.Min(x-area.Left,area.Right-1-x),Math.Min(y-area.Top,area.Bottom-1-y));
     float a=Math.Min(1,edge/4f);
     Color c=clean.GetPixel(x,y),b=original.GetPixel(x,y);
     result.SetPixel(x,y,Color.FromArgb(255,(int)(c.R*a+b.R*(1-a)),(int)(c.G*a+b.G*(1-a)),(int)(c.B*a+b.B*(1-a))));
    }
   SavePng(result,Path.Combine(output,stem+"-clean.png"));
  }
 }
 static void Sprite(Bitmap source,Rectangle region,string path) {
  using var keyed = new Bitmap(region.Width,region.Height,PixelFormat.Format32bppArgb);
  int left=region.Width,top=region.Height,right=0,bottom=0,partial=0;
  for(int y=0;y<region.Height;y++) for(int x=0;x<region.Width;x++) {
   Color c=source.GetPixel(x+region.X,y+region.Y);
   int dominance=c.G-Math.Max(c.R,c.B);
   float a=1-Math.Clamp((dominance-12)/100f,0,1);
   if(a<.02f) continue;
   // Despill partially covered edges without eroding brown ink.
   int g=dominance>12?Math.Min(c.G,Math.Max(c.R,c.B)):c.G;
   keyed.SetPixel(x,y,Color.FromArgb((int)(a*255),c.R,g,c.B));
   left=Math.Min(left,x);top=Math.Min(top,y);right=Math.Max(right,x);bottom=Math.Max(bottom,y);
   if(a<1)partial++;
  }
  Rectangle crop=Rectangle.FromLTRB(Math.Max(0,left-2),Math.Max(0,top-2),Math.Min(region.Width,right+3),Math.Min(region.Height,bottom+3));
  using var final=keyed.Clone(crop,PixelFormat.Format32bppArgb);
  SavePng(final,path);
  Console.WriteLine(Path.GetFileName(path)+": "+final.Width+"x"+final.Height+", antialiased alpha pixels="+partial);
 }
 static void SavePng(Bitmap image,string path) {
  string temporary=path+".tmp.png";
  image.Save(temporary,ImageFormat.Png);
  File.Move(temporary,path,true);
 }
}
'@
[TianjinLivingArt]::Build((Join-Path $projectRoot 'resource/art/TianJin'),$recordRoot,$artRoot)
