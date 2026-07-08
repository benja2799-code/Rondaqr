Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $projectRoot 'assets\images\rondaqr_icon_minimal.png'
$outputDirectory = Split-Path -Parent $outputPath

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$size = 1024
$bitmap = [System.Drawing.Bitmap]::new(
    $size,
    $size,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

try {
    $bounds = [System.Drawing.Rectangle]::new(0, 0, $size, $size)
    $background = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $bounds,
        [System.Drawing.Color]::FromArgb(255, 6, 27, 68),
        [System.Drawing.Color]::FromArgb(255, 8, 102, 255),
        45
    )
    $graphics.FillRectangle($background, $bounds)
    $background.Dispose()

    $shield = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $shield.AddBezier(512, 132, 610, 188, 700, 220, 790, 244)
    $shield.AddBezier(790, 244, 784, 508, 762, 644, 688, 730)
    $shield.AddBezier(688, 730, 626, 802, 558, 852, 512, 876)
    $shield.AddBezier(512, 876, 466, 852, 398, 802, 336, 730)
    $shield.AddBezier(336, 730, 262, 644, 240, 508, 234, 244)
    $shield.AddBezier(234, 244, 324, 220, 414, 188, 512, 132)
    $shield.CloseFigure()

    $shieldFill = [System.Drawing.SolidBrush]::new(
        [System.Drawing.Color]::FromArgb(220, 4, 29, 72)
    )
    $shieldBorder = [System.Drawing.Pen]::new(
        [System.Drawing.Color]::White,
        34
    )
    $shieldBorder.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $graphics.FillPath($shieldFill, $shield)
    $graphics.DrawPath($shieldBorder, $shield)

    $innerBorder = [System.Drawing.Pen]::new(
        [System.Drawing.Color]::FromArgb(255, 72, 167, 255),
        13
    )
    $innerBorder.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $graphics.DrawPath($innerBorder, $shield)

    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $navy = [System.Drawing.SolidBrush]::new(
        [System.Drawing.Color]::FromArgb(255, 6, 27, 68)
    )

    function Draw-Finder {
        param(
            [System.Drawing.Graphics]$Canvas,
            [int]$X,
            [int]$Y,
            [int]$FinderSize,
            [System.Drawing.Brush]$LightBrush,
            [System.Drawing.Brush]$DarkBrush
        )

        $Canvas.FillRectangle($LightBrush, $X, $Y, $FinderSize, $FinderSize)
        $inset = [int]($FinderSize * 0.22)
        $Canvas.FillRectangle(
            $DarkBrush,
            $X + $inset,
            $Y + $inset,
            $FinderSize - (2 * $inset),
            $FinderSize - (2 * $inset)
        )
        $centerInset = [int]($FinderSize * 0.38)
        $Canvas.FillRectangle(
            $LightBrush,
            $X + $centerInset,
            $Y + $centerInset,
            $FinderSize - (2 * $centerInset),
            $FinderSize - (2 * $centerInset)
        )
    }

    Draw-Finder $graphics 342 320 142 $white $navy
    Draw-Finder $graphics 540 320 142 $white $navy
    Draw-Finder $graphics 342 518 142 $white $navy

    $module = 38
    $modules = @(
        @(540, 518), @(578, 518), @(654, 518),
        @(540, 556), @(616, 556), @(654, 556),
        @(578, 594), @(616, 594),
        @(540, 632), @(616, 632), @(654, 632),
        @(692, 594), @(692, 632), @(578, 670)
    )

    foreach ($modulePosition in $modules) {
        $graphics.FillRectangle(
            $white,
            $modulePosition[0],
            $modulePosition[1],
            $module,
            $module
        )
    }

    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $white.Dispose()
    $navy.Dispose()
    $innerBorder.Dispose()
    $shieldBorder.Dispose()
    $shieldFill.Dispose()
    $shield.Dispose()
} finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}

Write-Output $outputPath
