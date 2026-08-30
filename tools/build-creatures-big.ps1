<#
  build-creatures-big.ps1 ― 大きめの海の意匠を素材にする

  クジラ・熱水噴出孔・海底火山・カニ2種。小魚やクラゲと違って「点景」では
  なく「見せ場」なので、少し大きく置く前提で書き出す。

  やることは2つだけ。

  1. 不透明部分の外接矩形へ切り詰める
     生成画像は正方形や 3:2 の枠に描かれていて、周りが大きく余っている。
     そのまま使うと、CSSで指定した幅の半分近くが透明な余白になり、
     位置合わせの計算が実物と合わなくなる。

  2. 表示する大きさの2倍程度まで縮める
     元は 1254〜1536px・1〜2.4MB ある。画面で 300px 前後にしか出ないので、
     そのまま置くと通信量が10倍以上になる。

  元ファイルは Downloads に置かれた生成物を、生成時刻で指定している。
  差し替えるときは $Items のパスを書き換える。
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$dl = Join-Path $env:USERPROFILE 'Downloads'
$out = Join-Path $root 'assets\img\creatures'

# 出力名 / 元ファイル / 書き出す最大の幅
$Items = @(
  @{ name = 'whale.png';     src = 'ChatGPT Image 2026年8月30日 21_31_17.png'; w = 640 },
  @{ name = 'volcano.png';   src = 'ChatGPT Image 2026年8月30日 21_35_53.png'; w = 460 },
  @{ name = 'vent.png';      src = 'ChatGPT Image 2026年8月30日 21_36_33.png'; w = 680 },
  @{ name = 'crab-blue.png'; src = 'ChatGPT Image 2026年8月30日 21_40_55.png'; w = 460 },
  @{ name = 'crab-red.png';  src = 'ChatGPT Image 2026年8月30日 21_43_33.png'; w = 460 }
)

$fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb

foreach ($it in $Items) {
  $path = Join-Path $dl $it.src
  if (-not (Test-Path $path)) { Write-Host ("見つからない: {0}" -f $it.src); continue }

  $src = [System.Drawing.Bitmap]::FromFile($path)
  $flat = New-Object System.Drawing.Bitmap($src.Width, $src.Height, $fmt)
  $g = [System.Drawing.Graphics]::FromImage($flat)
  $g.DrawImage($src, 0, 0, $src.Width, $src.Height)
  $g.Dispose(); $src.Dispose()

  $rect = New-Object System.Drawing.Rectangle(0, 0, $flat.Width, $flat.Height)
  $d = $flat.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
  $st = $d.Stride
  $px = New-Object byte[] ($st * $flat.Height)
  [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0, $px, 0, $px.Length)
  $flat.UnlockBits($d)

  # 不透明部分の外接矩形。にじみの端まで拾いたいので閾値は低めにする。
  $x0 = $flat.Width; $y0 = $flat.Height; $x1 = -1; $y1 = -1
  for ($y = 0; $y -lt $flat.Height; $y++) {
    $r = $y * $st
    for ($x = 0; $x -lt $flat.Width; $x++) {
      if ($px[$r + $x * 4 + 3] -gt 12) {
        if ($x -lt $x0) { $x0 = $x }; if ($x -gt $x1) { $x1 = $x }
        if ($y -lt $y0) { $y0 = $y }; if ($y -gt $y1) { $y1 = $y }
      }
    }
  }
  $cw = $x1 - $x0 + 1; $ch = $y1 - $y0 + 1

  $nw = [math]::Min($it.w, $cw)
  $nh = [int][math]::Round($ch * $nw / $cw)
  $dst = New-Object System.Drawing.Bitmap($nw, $nh, $fmt)
  $g2 = [System.Drawing.Graphics]::FromImage($dst)
  $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g2.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g2.DrawImage($flat, (New-Object System.Drawing.Rectangle(0, 0, $nw, $nh)),
                       (New-Object System.Drawing.Rectangle($x0, $y0, $cw, $ch)),
                       [System.Drawing.GraphicsUnit]::Pixel)
  $g2.Dispose()

  $target = Join-Path $out $it.name
  $dst.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
  "{0,-15} {1}x{2} → {3}x{4}  {5} KB" -f $it.name, $flat.Width, $flat.Height, $nw, $nh, [math]::Round((Get-Item $target).Length / 1KB)
  $dst.Dispose(); $flat.Dispose()
}
Write-Host "完了"
