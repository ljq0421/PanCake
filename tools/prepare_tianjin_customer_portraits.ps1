param(
    [string]$ArtRoot = (Join-Path $PSScriptRoot '..\resource\art\TianJin'),
    [string]$PreviewPath = (Join-Path $PSScriptRoot '..\.tmp\customer_portraits_preview.png')
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
    public static Rectangle KeepCenterComponent(Bitmap bitmap)
    {
        var rect = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
        BitmapData data = bitmap.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        try
        {
            byte[] bytes = new byte[data.Stride * data.Height];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            int seed = -1;
            long bestDistance = long.MaxValue;
            int centerX = bitmap.Width / 2;
            int centerY = bitmap.Height / 2;
            for (int y = 0; y < bitmap.Height; y++)
            {
                int row = y * data.Stride;
                for (int x = 0; x < bitmap.Width; x++)
                {
                    if (bytes[row + x * 4 + 3] <= 12) continue;
                    long dx = x - centerX, dy = y - centerY;
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
            return new Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
        }
        finally
        {
            bitmap.UnlockBits(data);
        }
    }

    public static void EraseCoveredPixels(Bitmap body, Bitmap[] heads, int dilation)
    {
        var rect = new Rectangle(0, 0, body.Width, body.Height);
        BitmapData bodyData = body.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        var headData = new BitmapData[heads.Length];
        try
        {
            byte[] bodyBytes = new byte[bodyData.Stride * bodyData.Height];
            Marshal.Copy(bodyData.Scan0, bodyBytes, 0, bodyBytes.Length);
            bool[] mask = new bool[body.Width * body.Height];
            for (int index = 0; index < heads.Length; index++)
            {
                headData[index] = heads[index].LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                byte[] bytes = new byte[headData[index].Stride * headData[index].Height];
                Marshal.Copy(headData[index].Scan0, bytes, 0, bytes.Length);
                for (int y = 0; y < body.Height; y++)
                    for (int x = 0; x < body.Width; x++)
                        if (bytes[y * headData[index].Stride + x * 4 + 3] > 0)
                            mask[y * body.Width + x] = true;
            }

            bool[] dilated = new bool[mask.Length];
            for (int y = 0; y < body.Height; y++)
            {
                for (int x = 0; x < body.Width; x++)
                {
                    if (!mask[y * body.Width + x]) continue;
                    for (int offsetY = -dilation; offsetY <= dilation; offsetY++)
                    {
                        int targetY = y + offsetY;
                        if (targetY < 0 || targetY >= body.Height) continue;
                        for (int offsetX = -dilation; offsetX <= dilation; offsetX++)
                        {
                            int targetX = x + offsetX;
                            if (targetX >= 0 && targetX < body.Width)
                                dilated[targetY * body.Width + targetX] = true;
                        }
                    }
                }
            }

            for (int y = 0; y < body.Height; y++)
            {
                int row = y * bodyData.Stride;
                for (int x = 0; x < body.Width; x++)
                {
                    if (!dilated[y * body.Width + x]) continue;
                    int pixel = row + x * 4;
                    bodyBytes[pixel] = bodyBytes[pixel + 1] = bodyBytes[pixel + 2] = bodyBytes[pixel + 3] = 0;
                }
            }
            Marshal.Copy(bodyBytes, 0, bodyData.Scan0, bodyBytes.Length);
        }
        finally
        {
            for (int index = 0; index < heads.Length; index++)
                if (headData[index] != null) heads[index].UnlockBits(headData[index]);
            body.UnlockBits(bodyData);
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
        Target = @(264, 48, 558, 558)
    },
    @{
        Id = 'female_office'
        Portrait = '普通女上班族.png'
        Sheet = '普通女上班族-表情.png'
        ExpectedSheetSize = @(2172, 724)
        Cells = $wideCells
        Target = @(272, 24, 550, 580)
    },
    @{
        Id = 'elder_regular'
        Portrait = '老大爷熟客.png'
        Sheet = '老大爷熟客-表情.png'
        ExpectedSheetSize = @(2172, 724)
        Cells = $wideCells
        Target = @(207, 92, 620, 530)
    },
    @{
        Id = 'young_woman'
        Portrait = '年轻女性.png'
        Sheet = '年轻女性-表情.png'
        ExpectedSheetSize = @(2172, 724)
        Cells = $wideCells
        Target = @(180, 42, 680, 620)
    },
    @{ Id = 'xiangsheng_performer'; Portrait = '相声演员男.png'; Sheet = '相声演员男-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(240, 30, 606, 600) },
    @{ Id = 'tianjin_aunt'; Portrait = '天津本地阿姨.png'; Sheet = '天津本地阿姨-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(235, 20, 616, 610) },
    @{ Id = 'morning_elder'; Portrait = '晨练大爷.png'; Sheet = '晨练大爷-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(235, 25, 616, 600) },
    @{ Id = 'morning_aunt'; Portrait = '晨练阿姨.png'; Sheet = '晨练阿姨-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(230, 20, 626, 620) },
    @{ Id = 'student'; Portrait = '学生顾客.png'; Sheet = '学生顾客-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(235, 30, 616, 590) },
    @{ Id = 'delivery_rider'; Portrait = '外卖骑手.png'; Sheet = '外卖骑手-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(220, 20, 650, 630) },
    @{ Id = 'taxi_driver'; Portrait = '出租车司机.png'; Sheet = '出租车司机-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(240, 45, 610, 590) },
    @{ Id = 'tourist'; Portrait = '外地游客.png'; Sheet = '外地游客-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(210, 15, 665, 650) },
    @{ Id = 'kuaiban_performer'; Portrait = '快板演员男.png'; Sheet = '快板演员男-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(235, 45, 620, 600) },
    @{ Id = 'yangliuqing_painter'; Portrait = '杨柳青年画年轻画师.png'; Sheet = '杨柳青年画年轻画师-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(225, 15, 640, 625) },
    @{ Id = 'clay_figurine_artisan'; Portrait = '泥人张手艺人.png'; Sheet = '泥人张手艺人-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(230, 25, 625, 600) },
    @{ Id = 'culture_street_shopkeeper'; Portrait = '古文化街老店掌柜.png'; Sheet = '古文化街老店掌柜-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(235, 40, 615, 580) },
    @{ Id = 'haihe_cruise_worker'; Portrait = '海河游船工作人员.png'; Sheet = '海河游船工作人员-表情.png'; ExpectedSheetSize = @(2172, 724); Cells = $wideCells; Target = @(235, 30, 620, 600) },
    @{ Id = 'wudadao_clerk'; Portrait = '五大道文艺店员.png'; Sheet = '五大道文艺店员-表情.png'; ExpectedSheetSize = @(2172, 724); Cells = $wideCells; Target = @(230, 25, 625, 620) },
    @{ Id = 'breakfast_shop_peer'; Portrait = '天津老字号早点铺同行大叔.png'; Sheet = '天津老字号早点铺同行大叔-表情.png'; ExpectedSheetSize = @(2172, 724); Cells = $wideCells; Target = @(230, 40, 625, 600) },
    @{ Id = 'culture_street_owner'; Portrait = '古文化街文创店年轻女店主.png'; Sheet = '古文化街文创店年轻女店主-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(225, 20, 640, 620) },
    @{ Id = 'haihe_runner'; Portrait = '海河晨跑青年.png'; Sheet = '海河晨跑青年-表情.png'; ExpectedSheetSize = @(2172, 724); Cells = $wideCells; Target = @(235, 25, 620, 600) },
    @{ Id = 'tianjin_port_worker'; Portrait = '天津港码头工作者.png'; Sheet = '天津港码头工作者-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(235, 25, 620, 610) },
    @{ Id = 'folk_art_performer'; Portrait = '鼓曲从业者女.png'; Sheet = '鼓曲从业者女-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(220, 10, 650, 650) },
    @{ Id = 'kite_artisan'; Portrait = '风筝手艺人.png'; Sheet = '风筝手艺人-表情.png'; ExpectedSheetSize = @(1254, 1254); Cells = $squareCells; Target = @(230, 25, 630, 610) }
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

function Remove-HeadPixels {
    param(
        [System.Drawing.Bitmap]$Body,
        [System.Drawing.Bitmap[]]$Heads
    )

    [PortraitBitmapTools]::EraseCoveredPixels($Body, $Heads, 2)
}

$processed = @()
foreach ($character in $characters) {
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

        $isolatedCells = @()
        $bounds = @()
        foreach ($cell in $character.Cells) {
            $isolated = New-TransparentBitmap -Width $cell[2] -Height $cell[3]
            $graphics = [System.Drawing.Graphics]::FromImage($isolated)
            try {
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.DrawImage(
                    $sheet,
                    [System.Drawing.Rectangle]::new(0, 0, $cell[2], $cell[3]),
                    [System.Drawing.Rectangle]::new($cell[0], $cell[1], $cell[2], $cell[3]),
                    [System.Drawing.GraphicsUnit]::Pixel)
            }
            finally {
                $graphics.Dispose()
            }
            $bounds += [PortraitBitmapTools]::KeepCenterComponent($isolated)
            $isolatedCells += $isolated
        }
        $maxWidth = ($bounds | Measure-Object -Property Width -Maximum).Maximum
        $maxHeight = ($bounds | Measure-Object -Property Height -Maximum).Maximum
        $target = $character.Target
        $scale = [Math]::Min($target[2] / $maxWidth, $target[3] / $maxHeight)
        $centerX = $target[0] + ($target[2] / 2.0)
        $centerY = $target[1] + ($target[3] / 2.0)

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
                $width = [int][Math]::Round($source.Width * $scale)
                $height = [int][Math]::Round($source.Height * $scale)
                $left = [int][Math]::Round($centerX - ($width / 2.0))
                $top = [int][Math]::Round($centerY - ($height / 2.0))
                $destination = [System.Drawing.Rectangle]::new($left, $top, $width, $height)
                $graphics.DrawImage($isolatedCells[$index], $destination, $source, [System.Drawing.GraphicsUnit]::Pixel)
            }
            finally {
                $graphics.Dispose()
            }
            $heads += $head
        }

        $body = $portrait.Clone([System.Drawing.Rectangle]::new(0, 0, $canvasWidth, $canvasHeight), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        Remove-HeadPixels -Body $body -Heads $heads

        $outputDirectory = Join-Path $ArtRoot (Join-Path 'Customers' $character.Id)
        Save-Png -Bitmap $body -Path (Join-Path $outputDirectory 'body.png')
        for ($index = 0; $index -lt $expressions.Count; $index++) {
            Save-Png -Bitmap $heads[$index] -Path (Join-Path $outputDirectory "head_$($expressions[$index]).png")
        }

        $processed += @{
            Id = $character.Id
            Body = $body
            Heads = $heads
        }
        foreach ($isolated in $isolatedCells) { $isolated.Dispose() }
    }
    finally {
        $portrait.Dispose()
        $sheet.Dispose()
    }
}

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
Write-Output "Preview pages: $previewPages in $previewDirectory"
