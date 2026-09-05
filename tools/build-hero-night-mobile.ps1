<#
  build-hero-night-mobile.ps1 ― 縦画面（スマホ）の夜のヒーローを作る

  依頼主からもらった夜の縦の絵には舟が描かれていない。代わりに、同じく
  もらった「夜の舟」10点（灯りの点いた水彩）を月明かりの海へ合成する。

  昼の縦（build-hero-mobile.ps1）と考え方は同じ。違うのは水の見分け方。
  夜は海が濃紺で、陸は木立と建物でほぼ黒。昼の規則（緑が青より強い＝陸、
  暗い＝陸）をそのまま使うと、夜の海がまるごと陸と判定される。
  夜は「明るいクリーム＝紙」「暖色に寄った暗い塊＝陸（灯りのある建物・
  木立）」「青に寄っていれば水」で見分ける。月光の道は白く輝くが、
  青みが残るので水のままになる。

  検査は昼と同じ2つ。どちらも基準を割ったらその場で止める。
    喫水線の水率 … 舟の下側30%が水の上にあるか
    重なり率     … 不透明な画素が、すでに置いた舟とどれだけ重なるか

  -Map を付けると水の地図をASCIIで出す。位置決めに使う。
#>
param([switch]$Map)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$cfg = Join-Path $PSScriptRoot 'config.local.ps1'
if (-not (Test-Path $cfg)) { throw "tools/config.local.ps1 がありません。" }
. $cfg

$root    = Split-Path $PSScriptRoot -Parent
$srcPath = Join-Path $LP_ROOT '背景画像\ChatGPT Image 2026年8月31日 17_44_28.png'
$shipDir = Join-Path $LP_ROOT 'アイテム'
$outPath = Join-Path $root 'assets\img\backgrounds\hero-night-mobile.jpg'
if (-not (Test-Path $srcPath)) { throw "夜の縦の絵がありません: $srcPath" }

$OUT_W = 900
$OUT_H = 1599

$HORIZON     = 0.655   # これより上は空と紙。舟は置かない
$MAX_OVERLAP = 9       # 先に置いた舟とこれ以上重なったら置き直す（%）
$MIN_WATER   = 97      # 喫水線がこれ未満の水率なら置き直す（%）

<#
  夜は色だけでは陸と海を分けられない。実測（GetPixel）した値：

    月光の道   R122 G131 B146  b-r +24     暗い海   R  5 G 50 B107  b-r +102
    水平線     R139 G150 B172  b-r +33     海(中)   R  0 G 36 B 83  b-r  +83
    木立       R 96 G102 B 92  b-r  -4     原爆ドーム R185 G184 B179  b-r  -6
    広島城     R 24 G 28 B 40  b-r +16     左の島    R 11 G 35 B 59  b-r  +48

  木立と灯りの点いた建物は暖色（b-r が負）なので色で弾ける。
  ところが島・城・橋は夜の海と同じ「暗い青」で、色では分けられない。
  そこは区画で除外するしかない。
#>
$WATER_BR = 10   # 青が赤をこれ以上上回れば水

# 色では見分けられないものは区画で除外する（比率 x1,y1,x2,y2）
$KeepOut = @(
  @(0.00, 0.640, 0.55, 0.860),   # 左の島と岸（原爆ドーム・鳥居・広島城・木立）
  @(0.74, 0.640, 1.00, 0.782)    # 右の島としまなみの橋
)

# 夜の舟10点。数字はファイル名の (n)
$ShipFiles = 1..10 | ForEach-Object {
  Join-Path $shipDir ("ChatGPT Image 2026年9月4日 10_29_13 ({0}).png" -f $_)
}

# 舟の配置。x は中心、y は喫水線（船底）、w は画像幅に対する舟の幅。
# 月光の道は x=0.62 あたりに落ちているので、そこへ向かって遠ざかる並びにする。
$Fleet = @(
  @{ n=10; x=0.470; y=0.686; w=0.052; flip=$false },
  @{ n=10; x=0.560; y=0.690; w=0.048; flip=$true  },
  @{ n=10; x=0.660; y=0.688; w=0.055; flip=$false },
  @{ n=10; x=0.755; y=0.694; w=0.050; flip=$true  },
  @{ n=8;  x=0.520; y=0.742; w=0.105; flip=$false },
  @{ n=7;  x=0.700; y=0.752; w=0.115; flip=$true  },
  @{ n=6;  x=0.845; y=0.746; w=0.100; flip=$true  },
  @{ n=5;  x=0.420; y=0.836; w=0.165; flip=$false },
  @{ n=3;  x=0.660; y=0.858; w=0.185; flip=$true  },
  @{ n=1;  x=0.300; y=0.952; w=0.250; flip=$false },
  @{ n=2;  x=0.640; y=0.985; w=0.280; flip=$true  }
)

# ---------- 背景を書き出しの大きさで用意する ----------
$src = [System.Drawing.Bitmap]::FromFile($srcPath)
Write-Host ("元 {0}x{1}" -f $src.Width, $src.Height)
$fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
$canvas = New-Object System.Drawing.Bitmap($OUT_W, $OUT_H, $fmt)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $OUT_W, $OUT_H)))
$src.Dispose()

$W = $OUT_W; $H = $OUT_H

# ---------- 水の地図 ----------
$rect = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
$data = $canvas.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
$stride = $data.Stride
$bytes = New-Object byte[] ($stride * $H)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$canvas.UnlockBits($data)

$water = New-Object bool[] ($W * $H)
$yTop = [int]($HORIZON * $H)
for ($y = $yTop; $y -lt $H; $y++) {
  $row = $y * $stride
  $wrow = $y * $W
  for ($x = 0; $x -lt $W; $x++) {
    $i = $row + $x * 4
    $b = $bytes[$i]; $gg = $bytes[$i+1]; $r = $bytes[$i+2]
    # 夜の海は青が赤を大きく上回る。紙・木立・灯りの点いた建物は暖色。
    # ただし波頭の白と月光の道は無彩色に近く、色だけだと陸に見える。
    # 水平線より下で明るいものは波か月光なので、水として数える
    # （紙と原爆ドームも明るいが、どちらも区画のほうで除いてある）。
    $water[$wrow + $x] = (($b - $r) -ge $WATER_BR) -or ($lum -ge 120)
  }
}
# 区画での除外
foreach ($k in $KeepOut) {
  $x1 = [int]($k[0] * $W); $y1 = [int]($k[1] * $H)
  $x2 = [int]($k[2] * $W); $y2 = [int]($k[3] * $H)
  for ($y = $y1; $y -lt $y2; $y++) {
    if ($y -lt 0 -or $y -ge $H) { continue }
    $wrow = $y * $W
    for ($x = $x1; $x -lt $x2; $x++) {
      if ($x -lt 0 -or $x -ge $W) { continue }
      $water[$wrow + $x] = $false
    }
  }
}

if ($Map) {
  Write-Host ''
  Write-Host '水の地図（# = 水、. = 陸か紙か空）'
  $cols = 60
  for ($ry = 0; $ry -lt 46; $ry++) {
    $line = ''
    $yy = [int]($H * $ry / 46)
    for ($rx = 0; $rx -lt $cols; $rx++) {
      $xx = [int]($W * $rx / $cols)
      if ($yy -lt $yTop) { $line += ' ' }
      elseif ($water[$yy * $W + $xx]) { $line += '#' } else { $line += '.' }
    }
    Write-Host ("{0,5:N2} {1}" -f ($ry / 46), $line)
  }
  Write-Host ''
}

# ---------- 舟を置く ----------
Write-Host ("舟 {0}点を読み込み" -f $ShipFiles.Count)
$ships = @{}
foreach ($n in ($Fleet | ForEach-Object { $_.n } | Sort-Object -Unique)) {
  $p = $ShipFiles[$n - 1]
  if (-not (Test-Path $p)) { throw "舟の絵がありません: $p" }
  $ships[$n] = [System.Drawing.Bitmap]::FromFile($p)
}

$occupied = New-Object bool[] ($W * $H)
$bad = @()

foreach ($f in $Fleet) {
  $ship = $ships[$f.n]
  $dw = [int]($f.w * $W)
  $dh = [int]($dw * $ship.Height / $ship.Width)
  $dx = [int]($f.x * $W) - [int]($dw / 2)
  $dy = [int]($f.y * $H) - $dh

  $img = $ship
  if ($f.flip) {
    $img = New-Object System.Drawing.Bitmap($ship)
    $img.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX)
  }

  # 置く大きさに縮めた不透明部分を取り出す
  $stamp = New-Object System.Drawing.Bitmap($dw, $dh, $fmt)
  $gs = [System.Drawing.Graphics]::FromImage($stamp)
  $gs.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $gs.DrawImage($img, (New-Object System.Drawing.Rectangle(0, 0, $dw, $dh)))
  $gs.Dispose()
  $sd = $stamp.LockBits((New-Object System.Drawing.Rectangle(0,0,$dw,$dh)),
        [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
  $sst = $sd.Stride
  $spx = New-Object byte[] ($sst * $dh)
  [System.Runtime.InteropServices.Marshal]::Copy($sd.Scan0, $spx, 0, $spx.Length)
  $stamp.UnlockBits($sd)

  # 喫水線（不透明部分の下側30%）の水率
  $wet = 0; $wetTot = 0
  $yStart = $dy + [int]($dh * 0.70)
  for ($sy = [int]($dh * 0.70); $sy -lt $dh; $sy++) {
    $py = $dy + $sy
    if ($py -lt 0 -or $py -ge $H) { continue }
    $srow = $sy * $sst
    for ($sx = 0; $sx -lt $dw; $sx++) {
      if ($spx[$srow + $sx * 4 + 3] -lt 60) { continue }
      $px2 = $dx + $sx
      if ($px2 -lt 0 -or $px2 -ge $W) { continue }
      $wetTot++
      if ($water[$py * $W + $px2]) { $wet++ }
    }
  }
  $wpct = if ($wetTot) { [math]::Round($wet / $wetTot * 100, 1) } else { 0 }

  # すでに置いた舟との重なり
  $own = 0; $hit = 0
  for ($sy = 0; $sy -lt $dh; $sy++) {
    $py = $dy + $sy
    if ($py -lt 0 -or $py -ge $H) { continue }
    $srow = $sy * $sst; $orow = $py * $W
    for ($sx = 0; $sx -lt $dw; $sx++) {
      if ($spx[$srow + $sx * 4 + 3] -lt 60) { continue }
      $px2 = $dx + $sx
      if ($px2 -lt 0 -or $px2 -ge $W) { continue }
      $own++
      if ($occupied[$orow + $px2]) { $hit++ }
    }
  }
  $ovl = if ($own) { [math]::Round($hit / $own * 100, 1) } else { 0 }

  $ngW = $wpct -lt $MIN_WATER
  $ngO = $ovl -gt $MAX_OVERLAP
  "{0}   舟{1,2}  x{2:N3} y{3:N3}  幅{4,4}px   水率{5,6:N1}%   重なり{6,5:N1}%" -f `
    $(if ($ngW -or $ngO) { 'NG' } else { 'OK' }), $f.n, $f.x, $f.y, $dw, $wpct, $ovl
  if ($ngW) { $bad += "舟{0} (x{1}, y{2}) 水率{3}%" -f $f.n, $f.x, $f.y, $wpct }
  if ($ngO) { $bad += "舟{0} (x{1}, y{2}) 重なり{3}%" -f $f.n, $f.x, $f.y, $ovl }

  # 占有マップへ足してから描く
  for ($sy = 0; $sy -lt $dh; $sy++) {
    $py = $dy + $sy
    if ($py -lt 0 -or $py -ge $H) { continue }
    $srow = $sy * $sst; $orow = $py * $W
    for ($sx = 0; $sx -lt $dw; $sx++) {
      if ($spx[$srow + $sx * 4 + 3] -lt 60) { continue }
      $px2 = $dx + $sx
      if ($px2 -lt 0 -or $px2 -ge $W) { continue }
      $occupied[$orow + $px2] = $true
    }
  }
  $stamp.Dispose()

  $g.DrawImage($img, (New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)))
  if ($f.flip) { $img.Dispose() }
}

foreach ($s in $ships.Values) { $s.Dispose() }
$g.Dispose()

if ($bad.Count -gt 0 -and -not $Map) {
  $canvas.Dispose()
  throw "舟の置き方に問題があります:`n  " + ($bad -join "`n  ")
}

# ---------- 書き出し ----------
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
         Where-Object { $_.MimeType -eq 'image/jpeg' }
$prm = New-Object System.Drawing.Imaging.EncoderParameters(1)
$prm.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
  [System.Drawing.Imaging.Encoder]::Quality, [int64]82)
$flat = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$gf = [System.Drawing.Graphics]::FromImage($flat)
$gf.DrawImage($canvas, 0, 0, $W, $H)
$gf.Dispose()
$flat.Save($outPath, $codec, $prm)
$flat.Dispose()
$canvas.Dispose()

$kb = [math]::Round((Get-Item $outPath).Length / 1KB)
Write-Host ("→ hero-night-mobile.jpg  {0}x{1}  {2}KB" -f $W, $H, $kb)
