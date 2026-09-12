param(
    [string]$ArtRoot = (Join-Path $PSScriptRoot '..\resource\art\TianJin'),
    [string]$PreviewPath = (Join-Path $PSScriptRoot '..\.tmp\customer_portraits_preview.png'),
    [string]$LayoutPath = (Join-Path $PSScriptRoot '..\resource\art\TianJin\Customers\portrait_layout.json')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.InteropServices
$drawingAssembly = [System.Drawing.Bitmap].Assembly.Location
$drawingPrimitivesAssembly = [System.Drawing.Rectangle].Assembly.Location
Add-Type -ReferencedAssemblies @($drawingAssembly, $drawingPrimitivesAssembly) -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class PortraitBitmapTools
{
    // The lowest skin run in the middle of an isolated expression is its neck,
    // rather than the bottom of a hat/hair bounding box.
    public static PointF NeckAnchor(Bitmap bitmap, Rectangle bounds)
    {
        int left = bounds.Left + (int)(bounds.Width * .30);
        int right = bounds.Left + (int)(bounds.Width * .72);
        for (int y = bounds.Bottom - 1; y >= bounds.Top + bounds.Height / 2; y--)
        {
            int count = 0; double sum = 0;
            for (int x = left; x < right; x++)
            {
                Color c = bitmap.GetPixel(x, y);
                if (c.A < 200 || c.R < 185 || c.G < 100 || c.G > 225
                    || c.R < c.G * 1.09 || c.G < c.B * 1.08) continue;
                count++; sum += x;
            }
            if (count >= Math.Max(4, bounds.Width / 35)) return new PointF((float)(sum / count), y);
        }
        throw new InvalidOperationException("No neck anchor found in expression.");
    }

    public static void CutOriginalHead(Bitmap body, int cutY)
    {
        // Authored collar cut replaces the union-of-expression erase, which
        // removed different parts of the shirt and left old ears/chins behind.
        var rect = new Rectangle(0, 0, body.Width, body.Height);
        BitmapData data = body.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        try
        {
            byte[] clear = new byte[data.Stride * cutY];
            Marshal.Copy(clear, 0, data.Scan0, clear.Length);
        }
        finally { body.UnlockBits(data); }
    }

    public static int FindBestVerticalCut(Bitmap bitmap, int searchLeft, int searchRight)
    {
        var rect = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
        BitmapData data = bitmap.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try
        {
            byte[] bytes = new byte[data.Stride * data.Height];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            int midpoint = (searchLeft + searchRight) / 2;
            int bestX = -1;
            int bestCount = int.MaxValue;
            int bestDistance = int.MaxValue;
            for (int x = Math.Max(0, searchLeft); x <= Math.Min(bitmap.Width - 1, searchRight); x++)
            {
                int count = 0;
                for (int y = 0; y < bitmap.Height; y++)
                {
                    if (bytes[y * data.Stride + x * 4 + 3] <= 12) continue;
                    count++;
                }
                int distance = Math.Abs(x - midpoint);
                if (count > bestCount || (count == bestCount && distance >= bestDistance)) continue;
                bestX = x;
                bestCount = count;
                bestDistance = distance;
            }
            return bestX;
        }
        finally
        {
            bitmap.UnlockBits(data);
        }
    }

    public static Rectangle KeepComponentNearest(Bitmap bitmap, int expectedCenterX, int expectedCenterY)
    {
        var rect = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
        BitmapData data = bitmap.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        try
        {
            byte[] bytes = new byte[data.Stride * data.Height];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            int seed = -1;
            long bestDistance = long.MaxValue;
            for (int y = 0; y < bitmap.Height; y++)
            {
                int row = y * data.Stride;
                for (int x = 0; x < bitmap.Width; x++)
                {
                    if (bytes[row + x * 4 + 3] <= 12) continue;
                    long dx = x - expectedCenterX, dy = y - expectedCenterY;
                    long distance = dx * dx + dy * dy;
                    if (distance >= bestDistance) continue;
                    bestDistance = distance;
                    seed = y * bitmap.Width + x;
                }
            }
            if (seed < 0) throw new InvalidOperationException("Expression cell contains no visible pixels.");

            bool[] keep = new bool[bitmap.Width * bitmap.Height];
            int[] queue = new int[bitmap.Width * bitmap.Height];
            int queueHead = 0;
            int queueTail = 0;
            keep[seed] = true;
            queue[queueTail++] = seed;
            int minX = bitmap.Width, minY = bitmap.Height, maxX = -1, maxY = -1;
            while (queueHead < queueTail)
            {
                int current = queue[queueHead++];
                int x = current % bitmap.Width;
                int y = current / bitmap.Width;
                minX = Math.Min(minX, x); minY = Math.Min(minY, y);
                maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y);
                for (int offsetY = -1; offsetY <= 1; offsetY++)
                {
                    int nextY = y + offsetY;
                    if (nextY < 0 || nextY >= bitmap.Height) continue;
                    for (int offsetX = -1; offsetX <= 1; offsetX++)
                    {
                        if (offsetX == 0 && offsetY == 0) continue;
                        int nextX = x + offsetX;
                        if (nextX < 0 || nextX >= bitmap.Width) continue;
                        int next = nextY * bitmap.Width + nextX;
                        // Keep the same visibility threshold during traversal so
                        // faint generator noise cannot bridge adjacent portraits.
                        // The padded source rectangle preserves transparent room
                        // for high-quality resampling around the retained outline.
                        if (keep[next] || bytes[nextY * data.Stride + nextX * 4 + 3] <= 12) continue;
                        keep[next] = true;
                        queue[queueTail++] = next;
                    }
                }
            }

            for (int y = 0; y < bitmap.Height; y++)
            {
                int row = y * data.Stride;
                for (int x = 0; x < bitmap.Width; x++)
                {
                    if (keep[y * bitmap.Width + x]) continue;
                    int pixel = row + x * 4;
                    bytes[pixel] = bytes[pixel + 1] = bytes[pixel + 2] = bytes[pixel + 3] = 0;
                }
            }
            Marshal.Copy(bytes, 0, data.Scan0, bytes.Length);
            const int padding = 6;
            minX = Math.Max(0, minX - padding);
            minY = Math.Max(0, minY - padding);
            maxX = Math.Min(bitmap.Width - 1, maxX + padding);
            maxY = Math.Min(bitmap.Height - 1, maxY + padding);
            return new Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
        }
        finally
        {
            bitmap.UnlockBits(data);
        }
    }

    public static Rectangle VisibleBounds(Bitmap bitmap)
    {
        var rect = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
        BitmapData data = bitmap.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try
        {
            byte[] bytes = new byte[data.Stride * data.Height];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            int minX = bitmap.Width, minY = bitmap.Height, maxX = -1, maxY = -1;
            for (int y = 0; y < bitmap.Height; y++)
            {
                int row = y * data.Stride;
                for (int x = 0; x < bitmap.Width; x++)
                {
                    if (bytes[row + x * 4 + 3] <= 12) continue;
                    minX = Math.Min(minX, x); minY = Math.Min(minY, y);
                    maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y);
                }
            }
            if (maxX < minX || maxY < minY)
                throw new InvalidOperationException("Bitmap contains no visible pixels.");
            return new Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
        }
        finally
        {
            bitmap.UnlockBits(data);
        }
    }


}
'@

$canvasWidth = 1086
$canvasHeight = 1448
$expressions = @('happy', 'normal', 'impatient', 'angry')

# The source sheets came from two image-generation aspect ratios. These values
# deliberately describe the checked-in sources instead of assuming a uniform grid.
$squareCells = @(@(0, 0, 314, 1254), @(314, 0, 313, 1254), @(627, 0, 314, 1254), @(941, 0, 313, 1254))
$wideCells = @(@(0, 0, 543, 724), @(543, 0, 543, 724), @(1086, 0, 543, 724), @(1629, 0, 543, 724))
$characters = @(
    @{
        Id = 'male_office'
        Portrait = '普通男上班族.png'
        Sheet = '普通男上班族-表情.png'
        ExpectedSheetSize = @(1254, 1254)
        Cells = @(@(0, 0, 318, 1254), @(318, 0, 309, 1254), @(627, 0, 311, 1254), @(938, 0, 316, 1254))
    },
    @{
        Id = 'female_office'
        Portrait = '普通女上班族.png'
        Sheet = '普通女上班族-表情.png'
        ExpectedSheetSize = @(2172, 724)
        Cells = $wideCells
    },
    @{
        Id = 'elder_regular'
        Portrait = '老大爷熟客.png'
        Sheet = '老大爷熟客-表情.png'
        ExpectedSheetSize = @(2172, 724)
        Cells = $wideCells
    },
    @{
        Id = 'young_woman'
        Portrait = '年轻女性.png'
        Sheet = '年轻女性-表情.png'
        ExpectedSheetSize = @(2172, 724)
        Cells = $wideCells
    },
    @{ Id = 'xiangsheng_performer'; Portrait = '相声演员男.png'; Sheet = '相声演员男-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'tianjin_aunt'; Portrait = '天津本地阿姨.png'; Sheet = '天津本地阿姨-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'morning_elder'; Portrait = '晨练大爷.png'; Sheet = '晨练大爷-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'morning_aunt'; Portrait = '晨练阿姨.png'; Sheet = '晨练阿姨-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'student'; Portrait = '学生顾客.png'; Sheet = '学生顾客-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'delivery_rider'; Portrait = '外卖骑手.png'; Sheet = '外卖骑手-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'taxi_driver'; Portrait = '出租车司机.png'; Sheet = '出租车司机-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'tourist'; Portrait = '外地游客.png'; Sheet = '外地游客-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'kuaiban_performer'; Portrait = '快板演员男.png'; Sheet = '快板演员男-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'yangliuqing_painter'; Portrait = '杨柳青年画年轻画师.png'; Sheet = '杨柳青年画年轻画师-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'clay_figurine_artisan'; Portrait = '泥人张手艺人.png'; Sheet = '泥人张手艺人-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'culture_street_shopkeeper'; Portrait = '古文化街老店掌柜.png'; Sheet = '古文化街老店掌柜-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'haihe_cruise_worker'; Portrait = '海河游船工作人员.png'; Sheet = '海河游船工作人员-表情.png'; ExpectedSheetSize = @(2172, 724); Cells = $wideCells },
    @{ Id = 'wudadao_clerk'; Portrait = '五大道文艺店员.png'; Sheet = '五大道文艺店员-表情.png'; ExpectedSheetSize = @(2172, 724); Cells = $wideCells },
    @{ Id = 'breakfast_shop_peer'; Portrait = '天津老字号早点铺同行大叔.png'; Sheet = '天津老字号早点铺同行大叔-表情.png'; ExpectedSheetSize = @(2172, 724); Cells = $wideCells },
    @{ Id = 'culture_street_owner'; Portrait = '古文化街文创店年轻女店主.png'; Sheet = '古文化街文创店年轻女店主-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'haihe_runner'; Portrait = '海河晨跑青年.png'; Sheet = '海河晨跑青年-表情.png'; ExpectedSheetSize = @(2172, 724); Cells = $wideCells },
    @{ Id = 'tianjin_port_worker'; Portrait = '天津港码头工作者.png'; Sheet = '天津港码头工作者-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'folk_art_performer'; Portrait = '鼓曲从业者女.png'; Sheet = '鼓曲从业者女-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells },
    @{ Id = 'kite_artisan'; Portrait = '风筝手艺人.png'; Sheet = '风筝手艺人-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells }
)

function New-TransparentBitmap {
    param([int]$Width, [int]$Height)
    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bitmap.SetResolution(96, 96)
    return $bitmap
}

function Save-Png {
    param([System.Drawing.Bitmap]$Bitmap, [string]$Path)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}


$processed = @()
$calibrations = Get-Content (Join-Path $PSScriptRoot 'tianjin_portrait_calibration.json') -Raw | ConvertFrom-Json -AsHashtable
foreach ($character in $characters) {
    $calibration = $calibrations[$character.Id]
    $portraitPath = Join-Path $ArtRoot $character.Portrait
    $sheetPath = Join-Path $ArtRoot $character.Sheet
    if (-not (Test-Path -LiteralPath $portraitPath)) { throw "Missing source portrait: $portraitPath" }
    if (-not (Test-Path -LiteralPath $sheetPath)) { throw "Missing expression sheet: $sheetPath" }

    $portrait = [System.Drawing.Bitmap]::FromFile((Resolve-Path $portraitPath))
    $sheet = [System.Drawing.Bitmap]::FromFile((Resolve-Path $sheetPath))
    try {
        if ($portrait.Width -ne $canvasWidth -or $portrait.Height -ne $canvasHeight) {
            throw "$($character.Portrait) must be ${canvasWidth}x${canvasHeight}; found $($portrait.Width)x$($portrait.Height)."
        }
        if ($sheet.Width -ne $character.ExpectedSheetSize[0] -or $sheet.Height -ne $character.ExpectedSheetSize[1]) {
            throw "$($character.Sheet) has an unexpected size: $($sheet.Width)x$($sheet.Height)."
        }

        $expectedCenters = @($character.Cells | ForEach-Object {
            ,@([int][Math]::Round($_[0] + ($_[2] / 2.0)), [int][Math]::Round($_[1] + ($_[3] / 2.0)))
        })
        $isolatedHeads = @()
        $bounds = @()
        for ($index = 0; $index -lt $character.Cells.Count; $index++) {
            # First try a full-sheet flood fill: disconnected heads can overlap
            # in X while still remaining distinct components.
            $isolated = $sheet.Clone(
                [System.Drawing.Rectangle]::new(0, 0, $sheet.Width, $sheet.Height),
                [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $expectedCenterX = $expectedCenters[$index][0]
            $expectedCenterY = $expectedCenters[$index][1]
            $bounds += [PortraitBitmapTools]::KeepComponentNearest($isolated, $expectedCenterX, $expectedCenterY)
            $isolatedHeads += $isolated
        }
        $componentCenters = @($bounds | ForEach-Object { $_.Left + ($_.Width / 2.0) })
        $needsAdaptiveSplit = $false
        for ($index = 1; $index -lt $componentCenters.Count; $index++) {
            if ($componentCenters[$index] -le $componentCenters[$index - 1]) { $needsAdaptiveSplit = $true }
        }
        if ($needsAdaptiveSplit) {
            foreach ($isolated in $isolatedHeads) { $isolated.Dispose() }
            $isolatedHeads = @()
            $bounds = @()
            $cuts = @()
            for ($index = 0; $index -lt $expectedCenters.Count - 1; $index++) {
                $cuts += [PortraitBitmapTools]::FindBestVerticalCut(
                    $sheet,
                    $expectedCenters[$index][0],
                    $expectedCenters[$index + 1][0])
            }
            for ($index = 0; $index -lt $character.Cells.Count; $index++) {
                # Touching source silhouettes are separated at the lowest-alpha
                # vertical seam between their authored centers, never at a fixed
                # equal-width grid line.
                $left = if ($index -eq 0) { 0 } else { $cuts[$index - 1] + 1 }
                $right = if ($index -eq $character.Cells.Count - 1) { $sheet.Width - 1 } else { $cuts[$index] - 1 }
                $width = $right - $left + 1
                $isolated = $sheet.Clone(
                    [System.Drawing.Rectangle]::new($left, 0, $width, $sheet.Height),
                    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
                $bounds += [PortraitBitmapTools]::KeepComponentNearest(
                    $isolated,
                    $expectedCenters[$index][0] - $left,
                    $expectedCenters[$index][1])
                $isolatedHeads += $isolated
            }
        }
        $sourceVisibleBounds = @($isolatedHeads | ForEach-Object { [PortraitBitmapTools]::VisibleBounds($_) })
        $normalSourceArea = [double]($sourceVisibleBounds[1].Width * $sourceVisibleBounds[1].Height)
        $placementScale = $calibration.headWidth / $sourceVisibleBounds[1].Width

        $heads = @()
        for ($index = 0; $index -lt $expressions.Count; $index++) {
            $head = New-TransparentBitmap -Width $canvasWidth -Height $canvasHeight
            $graphics = [System.Drawing.Graphics]::FromImage($head)
            try {
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $source = $bounds[$index]
                $sourceArea = [double]($sourceVisibleBounds[$index].Width * $sourceVisibleBounds[$index].Height)
                $expressionScale = $placementScale * [Math]::Sqrt($normalSourceArea / $sourceArea)
                $width = [int][Math]::Round($source.Width * $expressionScale)
                $height = [int][Math]::Round($source.Height * $expressionScale)
                $neck = [PortraitBitmapTools]::NeckAnchor($isolatedHeads[$index], $sourceVisibleBounds[$index])
                $left = [int][Math]::Round($calibration.neck[0] - ($neck.X - $source.Left) * $expressionScale)
                $top = [int][Math]::Round($calibration.neck[1] - ($neck.Y - $source.Top) * $expressionScale)
                $destination = [System.Drawing.Rectangle]::new($left, $top, $width, $height)
                $graphics.DrawImage($isolatedHeads[$index], $destination, $source, [System.Drawing.GraphicsUnit]::Pixel)
            }
            finally {
                $graphics.Dispose()
            }
            $heads += $head
        }
        $headAreas = @($heads | ForEach-Object {
            $visible = [PortraitBitmapTools]::VisibleBounds($_)
            [double]($visible.Width * $visible.Height)
        })
        $normalHeadArea = $headAreas[1]
        foreach ($area in $headAreas) {
            if ($area -lt $normalHeadArea * 0.98 -or $area -gt $normalHeadArea * 1.02) {
                throw "$($character.Sheet) expression area normalization exceeded 2%."
            }
        }

        $body = $portrait.Clone([System.Drawing.Rectangle]::new(0, 0, $canvasWidth, $canvasHeight), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        [PortraitBitmapTools]::CutOriginalHead($body, $calibration.cutY)

        $outputDirectory = Join-Path $ArtRoot (Join-Path 'Customers' $character.Id)
        Save-Png -Bitmap $body -Path (Join-Path $outputDirectory 'body.png')
        for ($index = 0; $index -lt $expressions.Count; $index++) {
            Save-Png -Bitmap $heads[$index] -Path (Join-Path $outputDirectory "head_$($expressions[$index]).png")
        }

        $processed += @{
            Id = $character.Id
            Body = $body
            Heads = $heads
            NormalBounds = [PortraitBitmapTools]::VisibleBounds($heads[1])
            WaistY = $calibration.waistY
        }
        foreach ($isolated in $isolatedHeads) { $isolated.Dispose() }
    }
    finally {
        $portrait.Dispose()
        $sheet.Dispose()
    }
}

$normalAreas = @($processed | ForEach-Object { [double]($_.NormalBounds.Width * $_.NormalBounds.Height) } | Sort-Object)
$middle = [int]($normalAreas.Count / 2)
$referenceArea = ($normalAreas[$middle - 1] + $normalAreas[$middle]) / 2.0
$layoutAppearances = [ordered]@{}
foreach ($character in $processed) {
    $bounds = $character.NormalBounds
    $area = [double]($bounds.Width * $bounds.Height)
    $scale = [Math]::Sqrt($referenceArea / $area)
    if ([double]::IsNaN($scale) -or [double]::IsInfinity($scale) -or $scale -le 0) {
        throw "Invalid portrait normalization scale for $($character.Id)."
    }
    $layoutAppearances[$character.Id] = [ordered]@{
        scale = [Math]::Round($scale, 8)
        headAnchor = @(
            [Math]::Round(($bounds.Left + ($bounds.Width / 2.0)) / $canvasWidth, 8),
            [Math]::Round(($bounds.Top + ($bounds.Height / 2.0)) / $canvasHeight, 8)
        )
        normalVisibleBounds = @($bounds.Left, $bounds.Top, $bounds.Width, $bounds.Height)
        counterWaist = @([int]($bounds.Left + $bounds.Width / 2), [int]$character.WaistY)
        counterHeight = [int]($character.WaistY - $bounds.Top)
    }
}
$layout = [ordered]@{
    canvasWidth = $canvasWidth
    canvasHeight = $canvasHeight
    referenceVisibleArea = [Math]::Round($referenceArea, 4)
    appearances = $layoutAppearances
}
$layoutParent = Split-Path -Parent $LayoutPath
if (-not (Test-Path -LiteralPath $layoutParent)) {
    New-Item -ItemType Directory -Path $layoutParent | Out-Null
}
$layout | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $LayoutPath -Encoding utf8

try {
    $previewPages = [Math]::Ceiling($processed.Count / 4.0)
    $previewDirectory = Split-Path -Parent $PreviewPath
    $previewName = [System.IO.Path]::GetFileNameWithoutExtension($PreviewPath)
    for ($page = 0; $page -lt $previewPages; $page++) {
        $preview = New-TransparentBitmap -Width 1600 -Height 1000
        $graphics = [System.Drawing.Graphics]::FromImage($preview)
        try {
            $graphics.Clear([System.Drawing.Color]::FromArgb(255, 255, 244, 213))
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $cellWidth = 400
            $cellHeight = 250
            for ($row = 0; $row -lt 4; $row++) {
                $characterIndex = ($page * 4) + $row
                if ($characterIndex -ge $processed.Count) { break }
                for ($column = 0; $column -lt $expressions.Count; $column++) {
                    $destination = [System.Drawing.Rectangle]::new(($column * $cellWidth) + 100, ($row * $cellHeight) + 8, 187, 234)
                    $graphics.DrawImage($processed[$characterIndex].Body, $destination)
                    $graphics.DrawImage($processed[$characterIndex].Heads[$column], $destination)
                }
            }
        }
        finally {
            $graphics.Dispose()
        }
        $pagePath = Join-Path $previewDirectory "$previewName`_$('{0:D2}' -f ($page + 1)).png"
        Save-Png -Bitmap $preview -Path $pagePath
        $preview.Dispose()
    }
}
finally {
    foreach ($character in $processed) {
        $character.Body.Dispose()
        foreach ($head in $character.Heads) { $head.Dispose() }
    }
}

Write-Output "Prepared $($processed.Count * 5) runtime customer assets."
Write-Output "Portrait layout: $LayoutPath"
Write-Output "Preview pages: $previewPages in $previewDirectory"
