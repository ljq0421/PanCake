param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Only the green connected to the outside of the canvas is background.
# Isolated green pixels in the food (scallions) deliberately remain opaque.
if (-not ('WuhanDoupiPieceMatte' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Private.Windows.GdiPlus,System.Private.Windows.Core,System.Console -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class WuhanDoupiPieceMatte
{
    private const int Padding = 8;
    private const int VisibleAlpha = 8;

    private static bool IsBackgroundCandidate(byte[] pixels, int index)
    {
        int p = index * 4;
        if (pixels[p + 3] == 0) return true;
        int b = pixels[p], g = pixels[p + 1], r = pixels[p + 2];
        return g >= 190 && r <= 85 && b <= 100 && g - Math.Max(r, b) >= 120;
    }

    private static void Visit(byte[] pixels, bool[] background, int[] queue, ref int tail, int index)
    {
        if (background[index] || !IsBackgroundCandidate(pixels, index)) return;
        background[index] = true;
        queue[tail++] = index;
    }

    private static byte ClampByte(double value)
    {
        return (byte)Math.Max(0, Math.Min(255, Math.Round(value)));
    }

    private static Bitmap FromPixels(byte[] pixels, int width, int height)
    {
        var bitmap = new Bitmap(width, height, PixelFormat.Format32bppArgb);
        var data = bitmap.LockBits(new Rectangle(0, 0, width, height), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        try
        {
            for (int y = 0; y < height; y++)
                Marshal.Copy(pixels, y * width * 4, IntPtr.Add(data.Scan0, y * data.Stride), width * 4);
        }
        finally { bitmap.UnlockBits(data); }
        return bitmap;
    }

    public static void Extract(string source, string outputDirectory)
    {
        using var input = new Bitmap(source);
        int width = input.Width, height = input.Height;
        if (width < 16 || height < 16)
            throw new InvalidDataException("The 2 x 2 source canvas must be at least 16 x 16 pixels.");

        // Normalize formats such as indexed PNG before locking the pixel buffer.
        using var normalized = new Bitmap(width, height, PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(normalized))
        {
            graphics.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
            graphics.DrawImageUnscaled(input, 0, 0);
        }
        byte[] pixels = new byte[checked(width * height * 4)];
        var data = normalized.LockBits(new Rectangle(0, 0, width, height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try
        {
            for (int y = 0; y < height; y++)
                Marshal.Copy(IntPtr.Add(data.Scan0, y * data.Stride), pixels, y * width * 4, width * 4);
        }
        finally { normalized.UnlockBits(data); }

        bool[] background = new bool[width * height];
        int[] queue = new int[background.Length];
        int head = 0, tail = 0;
        for (int x = 0; x < width; x++)
        {
            Visit(pixels, background, queue, ref tail, x);
            Visit(pixels, background, queue, ref tail, (height - 1) * width + x);
        }
        for (int y = 1; y < height - 1; y++)
        {
            Visit(pixels, background, queue, ref tail, y * width);
            Visit(pixels, background, queue, ref tail, y * width + width - 1);
        }
        while (head < tail)
        {
            int index = queue[head++], x = index % width, y = index / width;
            if (x > 0) Visit(pixels, background, queue, ref tail, index - 1);
            if (x + 1 < width) Visit(pixels, background, queue, ref tail, index + 1);
            if (y > 0) Visit(pixels, background, queue, ref tail, index - width);
            if (y + 1 < height) Visit(pixels, background, queue, ref tail, index + width);
        }
        if (tail == 0)
            throw new InvalidDataException("No exterior green background was found. Check that the source uses a plain #00FF00 background.");

        int despilled = 0;
        for (int y = 0; y < height; y++)
        for (int x = 0; x < width; x++)
        {
            int index = y * width + x, p = index * 4;
            if (background[index])
            {
                pixels[p] = pixels[p + 1] = pixels[p + 2] = pixels[p + 3] = 0;
                continue;
            }

            // Restrict decontamination to one pixel around the exterior mask.
            // Never apply a global green key: the filling contains green food.
            bool exteriorEdge = false;
            for (int dy = -1; dy <= 1 && !exteriorEdge; dy++)
            for (int dx = -1; dx <= 1; dx++)
            {
                int nx = x + dx, ny = y + dy;
                if (nx >= 0 && nx < width && ny >= 0 && ny < height && background[ny * width + nx])
                {
                    exteriorEdge = true;
                    break;
                }
            }
            int b = pixels[p], g = pixels[p + 1], r = pixels[p + 2];
            int excessGreen = g - Math.Max(r, b);
            if (!exteriorEdge || excessGreen <= 12) continue;

            // Remove the fraction of the green screen mixed into an antialiased
            // boundary pixel; keep its fractional coverage for clean compositing.
            double coverage = 1.0 - excessGreen / 255.0;
            if (coverage <= 0.01)
            {
                pixels[p] = pixels[p + 1] = pixels[p + 2] = pixels[p + 3] = 0;
            }
            else
            {
                pixels[p] = ClampByte(b / coverage);
                pixels[p + 1] = ClampByte((g - (1.0 - coverage) * 255.0) / coverage);
                pixels[p + 2] = ClampByte(r / coverage);
                pixels[p + 3] = ClampByte(pixels[p + 3] * coverage);
            }
            despilled++;
        }

        // Validate all four cells before creating any output files.
        Rectangle[] bounds = new Rectangle[4];
        for (int row = 0; row < 2; row++)
        for (int col = 0; col < 2; col++)
        {
            int piece = row * 2 + col;
            int left = col * width / 2, right = (col + 1) * width / 2;
            int top = row * height / 2, bottom = (row + 1) * height / 2;
            int minX = right, minY = bottom, maxX = -1, maxY = -1, visible = 0;
            for (int y = top; y < bottom; y++)
            for (int x = left; x < right; x++)
            {
                if (pixels[(y * width + x) * 4 + 3] <= VisibleAlpha) continue;
                visible++;
                minX = Math.Min(minX, x); maxX = Math.Max(maxX, x);
                minY = Math.Min(minY, y); maxY = Math.Max(maxY, y);
            }
            if (visible < 16 || maxX - minX < 3 || maxY - minY < 3)
                throw new InvalidDataException($"Cell {piece + 1} does not contain a usable subject.");
            if (minX <= left || maxX >= right - 1 || minY <= top || maxY >= bottom - 1)
                throw new InvalidDataException($"Cell {piece + 1} contains visible pixels touching its edge; its subject may be clipped or the background may need review.");
            bounds[piece] = Rectangle.FromLTRB(minX, minY, maxX + 1, maxY + 1);
        }

        Directory.CreateDirectory(outputDirectory);
        using var sheet = FromPixels(pixels, width, height);
        string sheetPath = Path.Combine(outputDirectory, "sheet-transparent.png");
        sheet.Save(sheetPath, ImageFormat.Png);
        Console.WriteLine($"Sheet: {sheetPath} ({width} x {height}); exterior pixels removed: {tail}; boundary pixels decontaminated: {despilled}.");

        for (int piece = 0; piece < bounds.Length; piece++)
        {
            Rectangle box = bounds[piece];
            int pieceWidth = box.Width + Padding * 2, pieceHeight = box.Height + Padding * 2;
            byte[] cropped = new byte[checked(pieceWidth * pieceHeight * 4)];
            for (int y = 0; y < box.Height; y++)
                Buffer.BlockCopy(pixels, ((box.Y + y) * width + box.X) * 4,
                    cropped, ((y + Padding) * pieceWidth + Padding) * 4, box.Width * 4);
            using var sprite = FromPixels(cropped, pieceWidth, pieceHeight);
            string piecePath = Path.Combine(outputDirectory, $"piece-{piece + 1:00}.png");
            sprite.Save(piecePath, ImageFormat.Png);
            Console.WriteLine($"Piece {piece + 1:00}: {piecePath} ({pieceWidth} x {pieceHeight}); source bounds {box}; {Padding}px transparent padding.");
        }
    }
}
'@
}

[WuhanDoupiPieceMatte]::Extract(
    [IO.Path]::GetFullPath($Source),
    [IO.Path]::GetFullPath($OutputDirectory)
)
