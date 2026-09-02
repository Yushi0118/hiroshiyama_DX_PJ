<#
  build-hero-wide.ps1 ― 横画面（PC）のヒーロー背景を作る

  素材は舟の描かれていない横長の背景（紙 + 瀬戸内の夕景、16:9）。
  そこへアイテムフォルダの舟7点を、夕日へ向かう船団として合成する。

  以前は舟が描き込まれた完成イメージを使っていた。絵としては成立して
  いたが、舟の並びを直せない ―― 水彩の一部なので、動かすには波の質感ごと
  描き直すことになる。舟の無い背景に後から置く形にすれば、並びも大きさも
  向きも、あとから何度でも調整できる。

  舟は絵に焼き込む。背景は cover で表示するため画面の縦横比によって
  切り取られるので、CSSの % で置くと切り取りとずれて陸に乗り上げる。
  絵の中に描いてしまえば、絵と一緒に切り取られるので必ず海の上にいる。

  検査は2つとも機械的に行う。
    喫水線の水率 … 舟の下側30%が水の上にあるか（陸に乗っていないか）
    重なり率     … 不透明な画素が、すでに置いた舟とどれだけ重なるか
  どちらも基準を割ったらその場で止める。目視では担保にならない。

  -Map を付けて実行すると、水の地図をASCIIで出力する。位置決めに使う。
#>
param([switch]$Map)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$cfg = Join-Path $PSScriptRoot 'config.local.ps1'
if (-not (Test-Path $cfg)) { throw "tools/config.local.ps1 がありません。" }
. $cfg

$root = Split-Path $PSScriptRoot -Parent
$bgPath = Join-Path $LP_ROOT '背景画像\ChatGPT Image 2026年8月26日 13_11_05.png'
$shipDir = Join-Path $LP_ROOT 'アイテム'
if (-not (Test-Path $bgPath)) { throw "背景が見つかりません: $bgPath" }

$HORIZON     = 0.360   # これより上は空と紙。舟は置かない
$MAX_OVERLAP = 9       # 先に置いた舟とこれ以上重なったら置き直す（%）
$MIN_WATER   = 97      # 喫水線がこれ未満の水率なら置き直す（%）

# 色では水と見分けられないものは区画で除外する（比率 x1,y1,x2,y2）
$KeepOut = @(
  @(0.84, 0.26, 1.00, 0.38),   # しまなみの橋
  @(0.00, 0.84, 0.40, 1.00),   # 六角アイコンの帯
  @(0.00, 0.66, 0.44, 1.00)    # 原爆ドーム・鳥居・広島城のある陸
)

# 舟の配置。x は中心、y は喫水線（船底）、w は画像幅に対する舟の幅。
# 奥から手前へ4段（遠景11・中遠景5・中景4・手前3）。段の中でも y を
# ばらけさせる。一直線に並べると「行列」に見えて船団にならない。
# 夕日は x=0.70 付近にあるので、その右の舟は反転させて光の方を向かせる。
$Fleet = @(
  @{ n=1; x=0.628; y=0.401; w=0.013; flip=$false },
  @{ n=2; x=0.653; y=0.400; w=0.012; flip=$false },
  @{ n=3; x=0.667; y=0.405; w=0.014; flip=$false },
  @{ n=4; x=0.681; y=0.389; w=0.012; flip=$false },
  @{ n=5; x=0.696; y=0.399; w=0.014; flip=$false },
  @{ n=6; x=0.709; y=0.388; w=0.013; flip=$false },
  @{ n=7; x=0.725; y=0.401; w=0.015; flip=$true  },
  @{ n=1; x=0.740; y=0.390; w=0.013; flip=$true  },
  @{ n=2; x=0.755; y=0.403; w=0.015; flip=$true  },
  @{ n=3; x=0.771; y=0.392; w=0.014; flip=$true  },
  @{ n=4; x=0.787; y=0.401; w=0.015; flip=$true  },
  @{ n=5; x=0.804; y=0.391; w=0.014; flip=$true  },
  @{ n=6; x=0.820; y=0.400; w=0.015; flip=$true  },
  @{ n=4; x=0.556; y=0.514; w=0.032; flip=$false },
  @{ n=5; x=0.605; y=0.478; w=0.024; flip=$false },
  @{ n=6; x=0.680; y=0.456; w=0.023; flip=$false },
  @{ n=7; x=0.755; y=0.480; w=0.028; flip=$true  },
  @{ n=1; x=0.830; y=0.457; w=0.026; flip=$true  },
  @{ n=2; x=0.885; y=0.478; w=0.031; flip=$true  },
  @{ n=3; x=0.642; y=0.630; w=0.046; flip=$false },
  @{ n=4; x=0.717; y=0.612; w=0.042; flip=$false },
  @{ n=5; x=0.792; y=0.648; w=0.054; flip=$true  },
  @{ n=6; x=0.855; y=0.618; w=0.048; flip=$true  },
  @{ n=7; x=0.585; y=0.800; w=0.128; flip=$false },
  @{ n=1; x=0.762; y=0.958; w=0.185; flip=$true  },
  @{ n=2; x=0.931; y=0.788; w=0.150; flip=$true  }
)

$src = [System.Drawing.Bitmap]::FromFile($bgPath)
$W = $src.Width; $H = $src.Height
Write-Host ("背景 {0}x{1}" -f $W, $H)

$fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
$canvas = New-Object System.Drawing.Bitmap($W, $H, $fmt)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.DrawImage($src, 0, 0, $W, $H)
$src.Dispose()

# --- 水の地図 ---
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
    $lum = (($r * 77) + ($gg * 151) + ($b * 28)) -shr 8
    # 緑が青を上回る＝島の緑。暗い＝木立や建物。どちらも陸。
    # 夕日の光路は白く輝いて緑寄りに出るので、明るい画素は陸から除く。
    # 暗いだけで陸と決めてはいけない。手前の波の谷は濃い青で暗く、
    # そのままだと海の一部が陸として弾かれる（実際に弾かれた）。
    # 暗くても青が赤を上回っていれば水。木立や建物は青が立たない。
    $isLand = (($gg -gt $b + 10) -and ($lum -lt 195)) -or (($lum -lt 95) -and ($b -le $r + 8))
    $water[$wrow + $x] = -not $isLand
  }
}
# 紙は明るいクリームで、色の規則では「陸ではない＝水」と読まれてしまう。
# 破れた縁は曲線なので矩形でも切れない。実測した数点を通る折れ線で、
# その左側をまとめて除外する（値は絵を見て読み取った、紙の内側に安全に
# 収まる線）。
$PaperEdge = @( @(0.360,0.525), @(0.450,0.482), @(0.550,0.452), @(0.660,0.438), @(1.000,0.438) )
for ($y = $yTop; $y -lt $H; $y++) {
  $t2 = $y / $H
  $fx = $PaperEdge[-1][1]
  for ($k2 = 1; $k2 -lt $PaperEdge.Count; $k2++) {
    if ($t2 -le $PaperEdge[$k2][0]) {
      $p0 = $PaperEdge[$k2-1]; $p1 = $PaperEdge[$k2]
      $u = ($t2 - $p0[0]) / ($p1[0] - $p0[0])
      if ($u -lt 0) { $u = 0 }
      $fx = $p0[1] + ($p1[1] - $p0[1]) * $u
      break
    }
  }
  $edge = [int]($fx * $W)
  $wrow = $y * $W
  for ($x = 0; $x -lt [math]::Min($edge, $W); $x++) { $water[$wrow + $x] = $false }
}

foreach ($k in $KeepOut) {
  $x1 = [int]($k[0]*$W); $y1 = [int]($k[1]*$H); $x2 = [int]($k[2]*$W); $y2 = [int]($k[3]*$H)
  for ($y = [math]::Max($y1,0); $y -lt [math]::Min($y2,$H); $y++) {
    $wrow = $y * $W
    for ($x = [math]::Max($x1,0); $x -lt [math]::Min($x2,$W); $x++) { $water[$wrow + $x] = $false }
  }
}

if ($Map) {
  Write-Host "`n水の地図（#=水 .=陸や除外区画 空白=水平線より上）"
  Write-Host ("      " + (0..5 | ForEach-Object { "{0,-12}" -f ("x=" + ($_ * 12 / 76.0).ToString("0.00")) }) -join '')
  for ($ry = 0; $ry -lt 46; $ry++) {
    $y = [int]($ry / 46.0 * $H)
    $line = ""
    for ($rx = 0; $rx -lt 76; $rx++) {
      $x = [int]($rx / 76.0 * $W)
      if ($y -lt $yTop) { $line += " " }
      elseif ($water[$y * $W + $x]) { $line += "#" } else { $line += "." }
    }
    "{0,5:N2} {1}" -f ($ry / 46.0), $line
  }
  $g.Dispose(); $canvas.Dispose()
  return
}

# --- 舟を読み込み、不透明部分だけに切り詰める ---
function Get-Trimmed {
  param([string]$Path)
  $b = [System.Drawing.Bitmap]::FromFile($Path)
  $d = $b.LockBits((New-Object System.Drawing.Rectangle(0,0,$b.Width,$b.Height)),
        [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $st = $d.Stride
  $px = New-Object byte[] ($st * $b.Height)
  [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0, $px, 0, $px.Length)
  $b.UnlockBits($d)
  $x0 = $b.Width; $y0 = $b.Height; $x1 = -1; $y1 = -1
  for ($y = 0; $y -lt $b.Height; $y++) {
    $r = $y * $st
    for ($x = 0; $x -lt $b.Width; $x++) {
      if ($px[$r + $x*4 + 3] -gt 24) {
        if ($x -lt $x0){$x0=$x}; if ($x -gt $x1){$x1=$x}
        if ($y -lt $y0){$y0=$y}; if ($y -gt $y1){$y1=$y}
      }
    }
  }
  $out = New-Object System.Drawing.Bitmap(($x1-$x0+1), ($y1-$y0+1),
         [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gg = [System.Drawing.Graphics]::FromImage($out)
  $gg.DrawImage($b, (New-Object System.Drawing.Rectangle(0,0,$out.Width,$out.Height)),
                    (New-Object System.Drawing.Rectangle($x0,$y0,$out.Width,$out.Height)),
                    [System.Drawing.GraphicsUnit]::Pixel)
  $gg.Dispose(); $b.Dispose()
  return $out
}

$ships = @{}
$files = Get-ChildItem "$shipDir\*.png" | Sort-Object Name
for ($i = 0; $i -lt $files.Count; $i++) { $ships[$i+1] = Get-Trimmed -Path $files[$i].FullName }
Write-Host ("舟 {0}点を読み込み" -f $ships.Count)

$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

# 舟どうしが重なった面積を測るための占有マップ。
# 矩形では判定にならない ―― 帆の上は透明な余白が広く、外接矩形が重なって
# いても絵は重なっていないことが多い。不透明な画素そのものを数える。
$occupied = New-Object bool[] ($W * $H)
$bad = @()

foreach ($f in $Fleet) {
  $ship = $ships[$f.n]
  $dw = [int]($f.w * $W)
  $dh = [int]([math]::Round($ship.Height * $dw / $ship.Width))
  $dx = [int]($f.x * $W - $dw / 2)
  $dy = [int]($f.y * $H - $dh)

  # 喫水線＝外接矩形の下30%。帆が遠くの島に重なるのは許す（手前の舟として
  # 自然に見える）。判定しているのは船底だけ。
  $hullTop = $dy + [int]($dh * 0.70)
  $tot = 0; $wet = 0
  for ($y = $hullTop; $y -lt $dy + $dh; $y++) {
    if ($y -lt 0 -or $y -ge $H) { continue }
    for ($x = $dx; $x -lt $dx + $dw; $x++) {
      if ($x -lt 0 -or $x -ge $W) { continue }
      $tot++
      if ($water[$y * $W + $x]) { $wet++ }
    }
  }
  $pct = if ($tot) { [math]::Round($wet / $tot * 100, 1) } else { 0 }

  $img = $ship
  if ($f.flip) {
    $img = New-Object System.Drawing.Bitmap($ship)
    $img.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX)
  }

  # 置く大きさに縮めた不透明部分を取り出し、すでに置いた舟との重なりを数える
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

  $ok = ($pct -ge $MIN_WATER) -and ($ovl -le $MAX_OVERLAP)
  "{0} 舟{1}  x{2:N3} y{3:N3} 幅{4,4}px   水率 {5,5:N1}%   重なり {6,5:N1}%" -f `
    $(if($ok){"OK  "}else{"NG  "}), $f.n, $f.x, $f.y, $dw, $pct, $ovl
  if (-not $ok) {
    $bad += "舟{0} (x{1}, y{2}) 水率{3}% 重なり{4}%" -f $f.n, $f.x, $f.y, $pct, $ovl
    $stamp.Dispose(); if ($f.flip) { $img.Dispose() }
    continue
  }

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
$g.Dispose()

if ($bad.Count) {
  $canvas.Dispose()
  throw "舟の置き方に問題があります:`n  " + ($bad -join "`n  ")
}

$outPath = "$root\assets\img\backgrounds\hero-scene-wide.jpg"
$MAXW = 1600
$nw = [math]::Min($MAXW, $W); $nh = [int][math]::Round($H * $nw / $W)
$dst = New-Object System.Drawing.Bitmap($nw, $nh, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g2 = [System.Drawing.Graphics]::FromImage($dst)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.DrawImage($canvas, (New-Object System.Drawing.Rectangle(0,0,$nw,$nh)))
$g2.Dispose()
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ps = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ps.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]84)
$dst.Save($outPath, $enc, $ps)
"{0,-24} {1}x{2}  {3} KB" -f (Split-Path $outPath -Leaf), $nw, $nh, [math]::Round((Get-Item $outPath).Length/1KB)
$dst.Dispose(); $canvas.Dispose()
$ships.Values | ForEach-Object { $_.Dispose() }
Write-Host "完了"
