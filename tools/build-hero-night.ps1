<#
  build-hero-night.ps1 ― ヒーローの絵を書き出す（昼・夜）

  依頼主からもらった絵は、どれも舟や灯りが最初から描き込まれている。
  こちらで合成するものは何もない。やることは寸法を揃えて JPEG にするだけ。

    横・昼   1672x941  → hero-scene-wide.jpg    1600x900
    横・夜   1672x941  → hero-night-wide.jpg    1600x900
    縦・夜    941x1672 → hero-night-mobile.jpg   900x1599

  縦・昼（hero-mobile.jpg）だけは、舟の描かれていない絵に舟アイコンを
  合成して作っている（tools/build-hero-mobile.ps1）。

  **昼と夜は必ず同じ寸法・同じ比率にすること。** CSS は昼夜で
  background-position を共有しているので、比率がずれると夜だけ
  切り取り位置が変わる。0.02 以上ずれたらこの script が止まる。
#>
param([switch]$Force)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$cfg = Join-Path $PSScriptRoot 'config.local.ps1'
if (-not (Test-Path $cfg)) { throw "tools/config.local.ps1 がありません。" }
. $cfg

$root = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $root 'assets\img\backgrounds'
$srcDir = Join-Path $LP_ROOT '背景画像'

$jobs = @(
  @{ src = 'ChatGPT Image 2026年8月21日 18_04_41 (3).png'; out = 'hero-scene-wide.jpg';  w = 1600; h = 900  },
  @{ src = 'ChatGPT Image 2026年8月31日 17_41_16.png';     out = 'hero-night-wide.jpg';  w = 1600; h = 900  },
  @{ src = 'ChatGPT Image 2026年8月31日 17_44_28.png';     out = 'hero-night-mobile.jpg'; w = 900; h = 1599 }
)

# JPEG の符号化器と品質
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
         Where-Object { $_.MimeType -eq 'image/jpeg' }
$prm = New-Object System.Drawing.Imaging.EncoderParameters(1)
$prm.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
  [System.Drawing.Imaging.Encoder]::Quality, [int64]82)

foreach ($j in $jobs) {
  $srcPath = Join-Path $srcDir $j.src
  if (-not (Test-Path $srcPath)) { throw "元の絵がありません: $srcPath" }

  $src = [System.Drawing.Bitmap]::FromFile($srcPath)
  Write-Host ("元 {0}  {1}x{2}" -f $j.src, $src.Width, $src.Height)

  # 比率が想定とずれていたら止める。気づかずに切り取り位置がずれるのを防ぐ。
  $arSrc = [math]::Round($src.Width / $src.Height, 3)
  $arOut = [math]::Round($j.w / $j.h, 3)
  if ([math]::Abs($arSrc - $arOut) -gt 0.02) {
    $src.Dispose()
    throw ("比率が合いません: 元 {0} / 書き出し {1}（{2}）" -f $arSrc, $arOut, $j.src)
  }

  $dst = New-Object System.Drawing.Bitmap($j.w, $j.h,
         [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($dst)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $j.w, $j.h)))
  $g.Dispose()
  $src.Dispose()

  $outPath = Join-Path $outDir $j.out
  $dst.Save($outPath, $codec, $prm)
  $dst.Dispose()

  $kb = [math]::Round((Get-Item $outPath).Length / 1KB)
  Write-Host ("  → {0}  {1}x{2}  {3}KB" -f $j.out, $j.w, $j.h, $kb)
}

Write-Host '夜の絵を書き出した。'
