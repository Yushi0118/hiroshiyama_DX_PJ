<#
  build-theme-icons.ps1 ― 募集テーマのカードに載せる業種アイコンを書き出す

  依頼主からもらった水彩3点を、カードの見出しの右の余白に収まる大きさへ
  整える。やることは2つだけ。

    1. 透明な余白を切り落とす（元は 1254x1254 の正方形で、絵は中央の
       一部だけ。そのまま縮めると絵が小さく見える）
    2. 表示は最大96pxなので、その2倍の 320px に収める

  背景は透明のまま残す。カードの地は不透明な白なので、乗算などの
  合成は要らない。
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$cfg = Join-Path $PSScriptRoot 'config.local.ps1'
if (-not (Test-Path $cfg)) { throw "tools/config.local.ps1 がありません。" }
. $cfg

$root   = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $root 'assets\img\themes'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

$MAX = 320   # 書き出しの長辺（表示96px × 2倍 + 余裕）
$ALPHA = 12  # これ未満の不透明度は「余白」とみなす

$jobs = @(
  @{ src = 'ChatGPT Image 2026年9月5日 11_42_01 (1).png'; out = 'beauty.png'     ; name = '理美容' },
  @{ src = 'ChatGPT Image 2026年9月5日 11_42_01 (2).png'; out = 'food.png'       ; name = '飲食' },
  @{ src = 'ChatGPT Image 2026年9月5日 11_42_01 (3).png'; out = 'backoffice.png' ; name = 'バックオフィス' }
)

foreach ($j in $jobs) {
  $srcPath = Join-Path $LP_ROOT "アイテム\$($j.src)"
  if (-not (Test-Path $srcPath)) { throw "元の絵がありません: $srcPath" }

  $src = [System.Drawing.Bitmap]::FromFile($srcPath)
  $W = $src.Width; $H = $src.Height

  # --- 不透明部分の外接矩形を求める ---
  $fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
  $data = $src.LockBits((New-Object System.Drawing.Rectangle(0,0,$W,$H)),
          [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
  $stride = $data.Stride
  $bytes = New-Object byte[] ($stride * $H)
  [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
  $src.UnlockBits($data)

  $minX = $W; $minY = $H; $maxX = -1; $maxY = -1
  for ($y = 0; $y -lt $H; $y++) {
    $row = $y * $stride
    for ($x = 0; $x -lt $W; $x++) {
      if ($bytes[$row + $x * 4 + 3] -lt $ALPHA) { continue }
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
  if ($maxX -lt 0) { $src.Dispose(); throw "中身が空です: $($j.src)" }

  $cw = $maxX - $minX + 1
  $ch = $maxY - $minY + 1

  # --- 長辺を MAX に収めて縮める ---
  $scale = [math]::Min(1.0, $MAX / [math]::Max($cw, $ch))
  $dw = [math]::Max(1, [int][math]::Round($cw * $scale))
  $dh = [math]::Max(1, [int][math]::Round($ch * $scale))

  $dst = New-Object System.Drawing.Bitmap($dw, $dh, $fmt)
  $g = [System.Drawing.Graphics]::FromImage($dst)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.CompositingMode   = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
  $g.DrawImage($src,
    (New-Object System.Drawing.Rectangle(0, 0, $dw, $dh)),
    (New-Object System.Drawing.Rectangle($minX, $minY, $cw, $ch)),
    [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  $src.Dispose()

  $outPath = Join-Path $outDir $j.out
  $dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $dst.Dispose()

  $kb = [math]::Round((Get-Item $outPath).Length / 1KB)
  "{0,-14} {1}x{2} → 切り抜き {3}x{4} → {5}  {6}x{7}  {8}KB" -f `
    $j.name, $W, $H, $cw, $ch, $j.out, $dw, $dh, $kb
}

Write-Host '業種アイコンを書き出した。'
