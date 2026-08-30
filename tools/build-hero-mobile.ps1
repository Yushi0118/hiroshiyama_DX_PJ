<#
  build-hero-mobile.ps1 ― 縦画面（スマホ・タブレット縦置き）のヒーロー背景を作る

  素材は縦長の完成イメージ（紙 + 瀬戸内の夕景）。船が描かれていないので、
  アイテムフォルダの船7点を海の上に合成し、夕日へ向かう船団にする。

  船はCSSで重ねるのではなく、絵に焼き込む。
  背景は cover で表示するため、画面の縦横比によって左右が切り取られる。
  CSSの % で船を置くと画面の座標系に従うので、絵の切り取りとずれて
  「陸に乗り上げた船」になりかねない。絵の中に描いてしまえば、絵と一緒に
  切り取られるので、どんな画面でも船は必ず同じ海面の上にいる。

  陸に掛からないことは目視ではなく実測で担保する。
    1. 水平線より下について、画素の色から「水かどうか」の地図を作る
       （緑が青より強い＝島の緑、暗い＝建物や木立、それ以外＝水）
    2. 六角アイコンと橋は色だけでは水と区別できないので、明示的に除外区画を置く
    3. 各船の喫水線（外接矩形の下側30%）が水の上にあるかを数える
    4. ひとつでも基準を割ったら、その場で止めて位置を報告する

  合成前に -Map を付けて実行すると、水の地図をASCIIで出力する。
  位置を決めるときはこれを見る。
#>
param([switch]$Map)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$cfg = Join-Path $PSScriptRoot 'config.local.ps1'
if (-not (Test-Path $cfg)) { throw "tools/config.local.ps1 がありません。" }
. $cfg

$root = Split-Path $PSScriptRoot -Parent
$bgPath = Join-Path $LP_ROOT '全体\完成イメージ\ChatGPT Image 2026年8月27日 15_25_51.png'
$shipDir = Join-Path $LP_ROOT 'アイテム'
if (-not (Test-Path $bgPath)) { throw "縦長の背景が見つかりません: $bgPath" }

$HORIZON = 0.655   # これより上は空と紙。船は置かない

# 色では水と見分けられないものは、区画で除外する（比率 x1,y1,x2,y2）
$KeepOut = @(
  @(0.74, 0.630, 1.00, 0.690),   # しまなみの橋
  @(0.03, 0.845, 0.53, 0.935)    # 六角アイコンの帯
)

# 船の配置。x は中心、y は喫水線（船底）、w は画像幅に対する船の幅。
# flip=$true で左右反転。夕日は x=0.63 あたりにあるので、その右の船は
# 反転させて、全員が光の方を向くようにする。
$Fleet = @(
  @{ n=3; x=0.580; y=0.735; w=0.052; flip=$false },
  @{ n=5; x=0.700; y=0.745; w=0.060; flip=$true  },
  @{ n=2; x=0.505; y=0.764; w=0.076; flip=$false },
  @{ n=7; x=0.762; y=0.788; w=0.096; flip=$true  },
  @{ n=1; x=0.600; y=0.824; w=0.126; flip=$false },
  @{ n=6; x=0.790; y=0.868; w=0.156; flip=$true  },
  @{ n=4; x=0.655; y=0.918; w=0.200; flip=$false },
  @{ n=2; x=0.730; y=0.985; w=0.262; flip=$true  }
)

# --- 背景を読み込み、32bppARGB の作業面へ ---
$src = [System.Drawing.Bitmap]::FromFile($bgPath)
$W = $src.Width; $H = $src.Height
Write-Host ("背景 {0}x{1}" -f $W, $H)
$canvas = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.DrawImage($src, 0, 0, $W, $H)
$src.Dispose()

# --- 水の地図（合成前の背景から作る） ---
$fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
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
    # 緑が青を上回る＝島の緑。暗い＝建物・木立・岩。どちらも陸。
    # ただし夕日の光路は白く輝いていて緑寄りに出る。明るい画素を
    # 陸から除かないと、海の真ん中が陸と判定されてしまう。
    $isLand = (($gg -gt $b + 10) -and ($lum -lt 195)) -or ($lum -lt 95)
    $water[$wrow + $x] = -not $isLand
  }
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
  Write-Host ("      " + (0..5 | ForEach-Object { "{0,-10}" -f ("x=" + ($_ * 10 / 62.0).ToString("0.00")) }) -join '')
  for ($ry = 0; $ry -lt 84; $ry++) {
    $y = [int]($ry / 84.0 * $H)
    $line = ""
    for ($rx = 0; $rx -lt 62; $rx++) {
      $x = [int]($rx / 62.0 * $W)
      if ($y -lt $yTop) { $line += " " }
      elseif ($water[$y * $W + $x]) { $line += "#" } else { $line += "." }
    }
    "{0,5:N2} {1}" -f ($ry / 84.0), $line
  }
  $g.Dispose(); $canvas.Dispose()
  return
}

# --- 船を読み込み、不透明部分だけに切り詰める ---
function Get-Trimmed {
  param([string]$Path)
  $b = [System.Drawing.Bitmap]::FromFile($Path)
  $d = $b.LockBits((New-Object System.Drawing.Rectangle(0,0,$b.Width,$b.Height)),
        [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
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
  $out = New-Object System.Drawing.Bitmap(($x1-$x0+1), ($y1-$y0+1), $fmt)
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
Write-Host ("船 {0}点を読み込み" -f $ships.Count)

# --- 置き場所の検査 → 合成 ---
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

$bad = @()
foreach ($f in $Fleet) {
  $ship = $ships[$f.n]
  $dw = [int]($f.w * $W)
  $dh = [int]([math]::Round($ship.Height * $dw / $ship.Width))
  $dx = [int]($f.x * $W - $dw / 2)
  $dy = [int]($f.y * $H - $dh)

  # 喫水線＝外接矩形の下30%。ここが水の上にあるかを数える。
  # 帆は遠くの島に重なってもよい（手前の船として自然に見える）。
  $hullTop = $dy + [int]($dh * 0.70)
  $tot = 0; $wet = 0
  for ($y = $hullTop; $y -lt $dy + $dh; $y += 2) {
    if ($y -lt 0 -or $y -ge $H) { continue }
    for ($x = $dx; $x -lt $dx + $dw; $x += 2) {
      if ($x -lt 0 -or $x -ge $W) { continue }
      $tot++
      if ($water[$y * $W + $x]) { $wet++ }
    }
  }
  $pct = if ($tot) { [math]::Round($wet / $tot * 100, 1) } else { 0 }
  $ok = ($pct -ge 97)
  "{0} 船{1}  x{2:N3} y{3:N3} 幅{4,4}px  喫水線の水率 {5,5:N1}%" -f $(if($ok){"OK  "}else{"NG  "}), $f.n, $f.x, $f.y, $dw, $pct
  if (-not $ok) { $bad += "船{0} (x{1}, y{2}) 水率{3}%" -f $f.n, $f.x, $f.y, $pct; continue }

  $img = $ship
  if ($f.flip) {
    $img = New-Object System.Drawing.Bitmap($ship)
    $img.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX)
  }
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)))
  if ($f.flip) { $img.Dispose() }
}
$g.Dispose()

if ($bad.Count) {
  $canvas.Dispose()
  throw "陸に掛かる船があります:`n  " + ($bad -join "`n  ")
}

# --- 書き出し ---
$outPath = "$root\assets\img\backgrounds\hero-mobile.jpg"
$MAXW = 900
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
"{0,-22} {1}x{2}  {3} KB" -f (Split-Path $outPath -Leaf), $nw, $nh, [math]::Round((Get-Item $outPath).Length/1KB)
$dst.Dispose(); $canvas.Dispose()
$ships.Values | ForEach-Object { $_.Dispose() }
Write-Host "完了"
