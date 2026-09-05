<#
  build-node-icons.ps1 ― 支援体制の5枚のカードに載せる絵を書き出す

  もらった水彩5点は白地の正方形（1254x1254）で、絵は中央の一部だけ。
  カードの地は紺なので、白い四角のまま置くと浮く。円に収めて金の輪を
  付ければ、既存の丸バッジと同じ見え方になる。

  やること
    1. 白でない画素の外接矩形を求める（絵の実際の範囲）
    2. その中心を保ったまま正方形に切り出す（円に収めるため）
    3. 320px に縮める。地は紙の色に倒して、紺の上でぎらつかせない

  円に切るのは CSS（border-radius:50%）。ここでは正方形のまま出す。
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$cfg = Join-Path $PSScriptRoot 'config.local.ps1'
if (-not (Test-Path $cfg)) { throw "tools/config.local.ps1 がありません。" }
. $cfg

$root   = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $root 'assets\img\icons\flow'
$OUT    = 320
$PAD    = 0.10          # 絵の周りに残す余白（正方形の辺に対する割合）
$PAPER  = [System.Drawing.Color]::FromArgb(255, 247, 244, 236)

$jobs = @(
  @{ src = 'ChatGPT Image 2026年9月5日 13_16_54 (1).png'; out = 'hub-peer.png';      name = '同じ悩みを持つ仲間' },
  @{ src = 'ChatGPT Image 2026年9月5日 13_16_55 (4).png'; out = 'hub-student.png';   name = '学生・若手人材' },
  @{ src = 'ChatGPT Image 2026年9月5日 13_16_54 (2).png'; out = 'hub-support.png';   name = '支援機関・業界団体' },
  @{ src = 'ChatGPT Image 2026年9月5日 13_16_55 (3).png'; out = 'hub-hiroshima.png'; name = '広島県' },
  @{ src = 'ChatGPT Image 2026年9月5日 13_16_55 (5).png'; out = 'hub-itdx.png';      name = 'IT・DX専門家' }
)

foreach ($j in $jobs) {
  $srcPath = Join-Path $LP_ROOT ('アイテム\' + $j.src)
  if (-not (Test-Path $srcPath)) { throw ('元の絵がありません: ' + $srcPath) }

  $src = [System.Drawing.Bitmap]::FromFile($srcPath)
  $W = $src.Width
  $H = $src.Height

  # 白でない画素の範囲を粗く走査して求める
  $minX = $W; $maxX = -1; $minY = $H; $maxY = -1
  for ($y = 0; $y -lt $H; $y = $y + 3) {
    for ($x = 0; $x -lt $W; $x = $x + 3) {
      $p = $src.GetPixel($x, $y)
      if ($p.A -lt 40) { continue }
      if ($p.R -gt 244 -and $p.G -gt 244 -and $p.B -gt 244) { continue }
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
  if ($maxX -lt 0) { $src.Dispose(); throw ('中身が空です: ' + $j.src) }

  # 中心を保ったまま正方形にする
  $cx = ($minX + $maxX) / 2
  $cy = ($minY + $maxY) / 2
  $half = [math]::Max($maxX - $minX, $maxY - $minY) / 2
  $half = $half * (1 + $PAD * 2)
  $sx = [int][math]::Round($cx - $half)
  $sy = [int][math]::Round($cy - $half)
  $sz = [int][math]::Round($half * 2)

  $dst = New-Object System.Drawing.Bitmap($OUT, $OUT, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($dst)
  $g.Clear($PAPER)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.DrawImage($src,
    (New-Object System.Drawing.Rectangle(0, 0, $OUT, $OUT)),
    (New-Object System.Drawing.Rectangle($sx, $sy, $sz, $sz)),
    [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  $src.Dispose()

  $outPath = Join-Path $outDir $j.out
  $dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $dst.Dispose()

  $kb = [math]::Round((Get-Item $outPath).Length / 1KB)
  Write-Host ('{0,-22} 絵の範囲 {1},{2}-{3},{4} → {5}  {6}x{6}  {7}KB' -f $j.name, $minX, $minY, $maxX, $maxY, $j.out, $OUT, $kb)
}
Write-Host '支援体制のアイコンを書き出した。'
