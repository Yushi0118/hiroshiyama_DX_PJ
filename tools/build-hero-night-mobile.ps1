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
# 青が赤をこれ以上上回れば水。木立(b-r -4)と原爆ドーム(b-r -6)が
# 陸に残る範囲で、できるだけ低くする。月光の道の照り返しは暖色寄りに
# なる画素があり、10 では海の一部を陸と読んで舟が弾かれた。
$WATER_BR = 2

# 色では見分けられないものは区画で除外する（比率 x1,y1,x2,y2）
$KeepOut = @(
  @(0.00, 0.640, 0.55, 0.860),   # 左の島と岸（原爆ドーム・鳥居・広島城・木立）
  @(0.74, 0.640, 1.00, 0.782)    # 右の島としまなみの橋
)

# 夜の舟10点。数字はファイル名の (n)
$ShipFiles = 1..10 | ForEach-Object {
  Join-Path $shipDir ("ChatGPT Image 2026年9月4日 10_29_13 ({0}).png" -f $_)
}

<#
  舟の配置。x は中心、y は喫水線（船底）、w は画像幅に対する舟の幅。

  当てずっぽうで置くと片端から陸に乗る。先に「行ごとに水が続いている
  範囲」を実測してから決めた（3px刻みで走査）：

    y0.68〜0.78   x0.55〜0.74            ← 左は岬、右は島と橋で塞がれている
    y0.80         x0.55〜0.63, 0.66〜1.00
    y0.82〜0.84   x0.55〜1.00
    y0.86         x0.13〜1.00
    y0.88〜0.90   x0.42〜1.00（左は岬の縁がまだ残る）
    y0.92〜1.00   x0.00〜1.00

  上へ行くほど水が細くなるので、遠くの舟ほど中央の細い水路へ寄せる。
  舟の高さは幅の1.25倍。段の間隔はその高さぶん空けないと、下の段の
  マストが上の段の舟へ突き上げる。
#>
$Fleet = @(
  # 遠景：月光の道の細い水路へ
  @{ n=10; x=0.600; y=0.715; w=0.038; flip=$false },
  @{ n=10; x=0.702; y=0.723; w=0.036; flip=$true  },
  @{ n=10; x=0.595; y=0.770; w=0.046; flip=$false },
  @{ n=10; x=0.706; y=0.762; w=0.043; flip=$true  },
  # 中景：水が右へ開けてくる高さ
  @{ n=8;  x=0.610; y=0.836; w=0.070; flip=$false },
  @{ n=7;  x=0.760; y=0.836; w=0.075; flip=$true  },
  @{ n=6;  x=0.905; y=0.836; w=0.072; flip=$true  },
  # 中近景
  @{ n=5;  x=0.580; y=0.925; w=0.105; flip=$false },
  @{ n=4;  x=0.880; y=0.915; w=0.100; flip=$true  },
  # 手前：全幅が水になる高さ
  @{ n=1;  x=0.250; y=0.985; w=0.200; flip=$false },
  @{ n=2;  x=0.735; y=0.998; w=0.205; flip=$true  }
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
<#
  地図をならす。

  1画素ずつ色で見ると、夜の波の陰影を拾って水の中に陸の点が散る。
  実際に舟の喫水線の下を出力させたところ、陸判定は塊ではなく
  ごま塩状に散っていて、それだけで水率が 73〜90% まで落ちていた。
  陸は必ず大きな塊なので、周りが水なら水に倒してよい。

  9x9 の窓で「周りの55%以上が水なら水」とする。総和表（積分画像）を
  使って窓の合計を一度に出す。素直に81画素ずつ数えると4千万回になる。
#>
$R = 4
$SW1 = $W + 1
$sum = New-Object int[] ($SW1 * ($H + 1))
for ($y = 0; $y -lt $H; $y++) {
  $rowUp = $y * $SW1
  $rowDn = ($y + 1) * $SW1
  $run = 0
  $wrow = $y * $W
  for ($x = 0; $x -lt $W; $x++) {
    if ($water[$wrow + $x]) { $run++ }
    $sum[$rowDn + $x + 1] = $sum[$rowUp + $x + 1] + $run
  }
}
$smooth = New-Object bool[] ($W * $H)
for ($y = $yTop; $y -lt $H; $y++) {
  $y1 = [math]::Max(0, $y - $R); $y2 = [math]::Min($H - 1, $y + $R)
  $wrow = $y * $W
  $rUp = $y1 * $SW1; $rDn = ($y2 + 1) * $SW1
  for ($x = 0; $x -lt $W; $x++) {
    $x1 = [math]::Max(0, $x - $R); $x2 = [math]::Min($W - 1, $x + $R)
    $tot = ($y2 - $y1 + 1) * ($x2 - $x1 + 1)
    $cnt = $sum[$rDn + $x2 + 1] - $sum[$rUp + $x2 + 1] - $sum[$rDn + $x1] + $sum[$rUp + $x1]
    $smooth[$wrow + $x] = ($cnt * 100) -ge ($tot * 55)
  }
}
$water = $smooth

# 区画での除外（ならしたあとに掛ける。区画は境界をぼかしたくない）
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
<#
  読み込むときに透明な余白を切り落とす。

  絵によって余白がまるで違う。実測すると、舟10 は絵が中央の一部
  （横 0.364〜0.690、縦 0.240〜0.745）しかなく、下に 25.5% も余白がある。
  切らずに置くと、指定した喫水線より遥か上に浮き、幅も見た目より
  ずっと小さくなる。切っておけば y は本当に船底、w は本当に舟の幅になる。
#>
function Trim-Ship([string]$path) {
  $src = [System.Drawing.Bitmap]::FromFile($path)
  $sw = $src.Width; $sh = $src.Height
  $f32 = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
  $d = $src.LockBits((New-Object System.Drawing.Rectangle(0,0,$sw,$sh)),
       [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $f32)
  $st = $d.Stride
  $px = New-Object byte[] ($st * $sh)
  [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0, $px, 0, $px.Length)
  $src.UnlockBits($d)

  $x1 = $sw; $x2 = -1; $y1 = $sh; $y2 = -1
  for ($y = 0; $y -lt $sh; $y++) {
    $row = $y * $st
    for ($x = 0; $x -lt $sw; $x++) {
      if ($px[$row + $x * 4 + 3] -lt 60) { continue }
      if ($x -lt $x1) { $x1 = $x }
      if ($x -gt $x2) { $x2 = $x }
      if ($y -lt $y1) { $y1 = $y }
      if ($y -gt $y2) { $y2 = $y }
    }
  }
  if ($x2 -lt 0) { $src.Dispose(); throw "中身が空です: $path" }

  $cw = $x2 - $x1 + 1; $ch = $y2 - $y1 + 1
  $dst = New-Object System.Drawing.Bitmap($cw, $ch, $f32)
  $gg = [System.Drawing.Graphics]::FromImage($dst)
  $gg.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
  $gg.DrawImage($src,
    (New-Object System.Drawing.Rectangle(0, 0, $cw, $ch)),
    (New-Object System.Drawing.Rectangle($x1, $y1, $cw, $ch)),
    [System.Drawing.GraphicsUnit]::Pixel)
  $gg.Dispose()
  $src.Dispose()
  return $dst
}

$ships = @{}
foreach ($n in ($Fleet | ForEach-Object { $_.n } | Sort-Object -Unique)) {
  $p = $ShipFiles[$n - 1]
  if (-not (Test-Path $p)) { throw "舟の絵がありません: $p" }
  $ships[$n] = Trim-Ship $p
  "  舟{0,2} 切り抜き {1}x{2}" -f $n, $ships[$n].Width, $ships[$n].Height
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
  if ($ngW) {
    $bad += "舟{0} (x{1}, y{2}) 水率{3}%" -f $f.n, $f.x, $f.y, $wpct
    # 落ちたときは、喫水線の下がどうなっているかを見せる。
    # 「#=水」「.=陸」「空白=舟の絵が無い」。原因の切り分けはこれが要る。
    "     喫水線の下（#水 .陸 空白=絵なし）"
    for ($sy = [int]($dh * 0.70); $sy -lt $dh; $sy += [math]::Max(1, [int](($dh * 0.30) / 8))) {
      $py = $dy + $sy
      if ($py -lt 0 -or $py -ge $H) { continue }
      $srow = $sy * $sst
      $line = ''
      for ($sx = 0; $sx -lt $dw; $sx += [math]::Max(1, [int]($dw / 40))) {
        $px2 = $dx + $sx
        if ($px2 -lt 0 -or $px2 -ge $W) { $line += '?'; continue }
        if ($spx[$srow + $sx * 4 + 3] -lt 60) { $line += ' ' }
        elseif ($water[$py * $W + $px2]) { $line += '#' }
        else { $line += '.' }
      }
      "     {0,5} {1}" -f $py, $line
    }
  }
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
