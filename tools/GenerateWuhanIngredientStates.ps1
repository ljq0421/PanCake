# Rebuild food-only Wuhan stock overlays from the pixels of the current workbench.
# This keeps their line work and palette identical to the shipped background.
param(
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent)
)

$source = Join-Path $ProjectRoot 'resource/art/Wuhan/武汉-热干面-v1.png'
$destination = Join-Path $ProjectRoot 'resource/art/Wuhan/IngredientStates'
$greenDestination = Join-Path $ProjectRoot 'artifacts/wuhan-supply-assets/source-green'
New-Item -ItemType Directory -Path $destination, $greenDestination -Force | Out-Null

$drawingFolder = Split-Path ([System.Drawing.Bitmap].Assembly.Location)
$drawingAssemblies = @(
    [System.Drawing.Bitmap].Assembly.Location,
    [System.Drawing.PointF].Assembly.Location,
    (Join-Path $drawingFolder 'System.Private.Windows.Core.dll'),
    (Join-Path $drawingFolder 'System.Private.Windows.GdiPlus.dll')
)
Add-Type -ReferencedAssemblies $drawingAssemblies -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

public static class WuhanIngredientStates
{
    private const int Width = 160;
    private const int Height = 112;

    private sealed class Spec
    {
        public string Name;
        public int X, Y;
        public RectangleF Food;
        public PointF[] Contour;
        public Spec(string name, int x, int y, RectangleF food, PointF[] contour)
        { Name=name; X=x; Y=y; Food=food; Contour=contour; }
    }

    private static PointF P(float x, float y) { return new PointF(x,y); }

    public static void Run(string sourcePath, string destination, string greenDestination)
    {
        var specs = new[] {
            new Spec("芝麻酱",420,720,RectangleF.Empty,
                new[] {P(15,52),P(20,39),P(31,29),P(47,22),P(65,18),P(87,17),P(107,21),P(123,31),P(133,44),P(134,57),P(124,70),P(106,77),P(84,81),P(59,81),P(38,76),P(23,70)}),
            new Spec("辣油",570,720,RectangleF.Empty,
                new[] {P(19,56),P(23,42),P(35,30),P(52,23),P(72,20),P(94,20),P(116,26),P(132,37),P(138,52),P(137,66),P(126,79),P(105,88),P(80,91),P(56,87),P(36,79),P(23,68)}),
            new Spec("香葱",720,720,RectangleF.Empty,
                new[] {P(17,70),P(20,54),P(29,40),P(42,29),P(59,22),P(77,17),P(98,18),P(117,27),P(131,41),P(138,57),P(137,72),P(127,81),P(109,84),P(81,86),P(54,83),P(31,78)}),
            new Spec("卤牛肉",870,720,RectangleF.Empty,
                new[] {P(17,70),P(22,53),P(35,40),P(52,29),P(72,22),P(94,20),P(115,26),P(130,38),P(137,55),P(137,71),P(125,84),P(105,91),P(76,93),P(49,89),P(30,81)}),
        };
        using (var source = new Bitmap(sourcePath))
        {
            foreach (var spec in specs)
            {
                Write(source,spec,"满",1f,1f,destination,greenDestination);
                Write(source,spec,"3-4",.88f,.82f,destination,greenDestination);
                Write(source,spec,"1-2",.72f,.64f,destination,greenDestination);
                Write(source,spec,"空",0f,0f,destination,greenDestination);
            }
        }
    }

    private static void Write(Bitmap source, Spec spec, string level, float sx, float sy,
        string destination, string greenDestination)
    {
        using (var mask = new Bitmap(Width,Height,PixelFormat.Format32bppArgb))
        using (var mg = Graphics.FromImage(mask))
        {
            mg.SmoothingMode = SmoothingMode.AntiAlias;
            if (sx > 0)
            {
                using (var path = new GraphicsPath())
                {
                    if (spec.Contour == null) path.AddEllipse(spec.Food);
                    else path.AddPolygon(spec.Contour);
                    using (var matrix = new Matrix())
                    {
                        // Keep the rear of the food lower as its volume decreases.
                        matrix.Translate(-80,-100);
                        matrix.Scale(sx,sy,MatrixOrder.Append);
                        matrix.Translate(80,100,MatrixOrder.Append);
                        path.Transform(matrix);
                    }
                    mg.FillPath(Brushes.White,path);
                }
            }

            using (var green = new Bitmap(Width,Height,PixelFormat.Format32bppArgb))
            using (var final = new Bitmap(Width,Height,PixelFormat.Format32bppArgb))
            {
                for (int y=0;y<Height;y++) for (int x=0;x<Width;x++)
                {
                    int alpha = mask.GetPixel(x,y).A;
                    // Paint food into the spoon's baked-in footprint from nearby food.
                    // A separate spoon can later sit above these food-only layers.
                    bool spoon = x >= 80 && y <= 90;
                    int sampleX = spoon ? 160-x : x;
                    bool liquid = spec.Name == "芝麻酱" || spec.Name == "辣油";
                    if (liquid && x >= 60 && x <= 110 && y <= 85)
                    {
                        int from = y < 35 ? 58 : y < 70 ? 35 : 43;
                        sampleX = from+(int)((70f-from)*(x-60)/50f);
                    }
                    int sampleY = y;
                    var sourceColor = source.GetPixel(spec.X+sampleX,spec.Y+sampleY);
                    bool lightRim = spec.Name == "芝麻酱" && y >= 69
                        && sourceColor.R > 205 && sourceColor.G > 160 && sourceColor.B > 120;
                    lightRim |= spec.Name == "香葱" && y >= 75
                        && sourceColor.R > 165 && sourceColor.G > 165 && sourceColor.B > 145;
                    if (lightRim)
                        sourceColor = source.GetPixel(spec.X+sampleX,spec.Y+Math.Max(20,y-12));
                    // First make the opaque green-backed art. The same mask then keys it
                    // back to clean alpha without a chroma fringe at the ink edge.
                    green.SetPixel(x,y,Color.FromArgb(255,
                        (sourceColor.R*alpha + 0*(255-alpha))/255,
                        (sourceColor.G*alpha + 255*(255-alpha))/255,
                        (sourceColor.B*alpha + 0*(255-alpha))/255));
                    final.SetPixel(x,y,Color.FromArgb(alpha,sourceColor.R,sourceColor.G,sourceColor.B));
                }
                if (sx > 0)
                    green.Save(Path.Combine(greenDestination,spec.Name+"-"+level+"-绿底.png"),ImageFormat.Png);
                final.Save(Path.Combine(destination,spec.Name+"-"+level+".png"),ImageFormat.Png);
            }
        }
    }

}
'@

[WuhanIngredientStates]::Run($source, $destination, $greenDestination)
