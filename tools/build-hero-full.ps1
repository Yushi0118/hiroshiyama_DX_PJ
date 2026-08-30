<#
  build-hero-full.ps1 ― ヒーローの全面背景を作る

  完成イメージ(1) は「破れた紙 + 瀬戸内の船団」で1枚の絵になっている。
  以前は右半分（船団）だけを切り出して使っていた。すると紙の側がただの
  クリーム色の矩形になり、絵との境に縦の継ぎ目が見えてしまう。

  そこで絵は1枚のまま全面に使い、**焼き込まれた文字だけを消す**。
  文字はHTMLで置き直す（画像内文字を禁じるルールを守るため）。

  消し方 ―― 文字の画素を色で拾う方式は捨てた。
    紺の濃い所は消えても、アンチエイリアスで薄くなった縁と、金色の
    「DX」が残る。閾値をどう動かしても、残すべき葉や建物との間に
    安全な境目が無かった（2回試して2回ともゴーストが出た）。

    代わりに **文字がある帯を丸ごと紙で塗り直す**。塗る材料は同じ絵の
    中の紙そのもの（粗いグリッドで平均し、文字の無い所から拡散させて
    埋める）なので、色も濃淡のムラも周囲と地続きになる。

  帯の左右は決め打ちにできない。左には葉と原爆ドーム、右には破れた縁の
  向こうの海があり、どちらも塗り潰してはいけない。そこで
    左端 = その行で葉（緑）が終わる位置
    右端 = その行で紙が終わる位置
  を1行ずつ実測し、行方向にならしてから使う。
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$cfg = Join-Path $PSScriptRoot 'config.local.ps1'
if (-not (Test-Path $cfg)) { throw "tools/config.local.ps1 がありません。" }
. $cfg

$root = Split-Path $PSScriptRoot -Parent
$srcPath = Join-Path $LP_ROOT '全体\完成イメージ\ChatGPT Image 2026年8月26日 14_01_09 (1).png'
if (-not (Test-Path $srcPath)) { throw "元画像が見つかりません: $srcPath" }

# 文字のある帯（元画像に対する比率）。x は「ここまでは塗ってよい」上限で、
# 実際の左右は葉と紙の縁の実測値で内側へ寄る。
$Bands = @(
  @(0.118, 0.400, 0.075, 0.525),   # 見出し3行
  @(0.400, 0.535, 0.052, 0.505),   # ロゴ + ブランド名 + 罫線 + サブタイトル
  @(0.535, 0.700, 0.120, 0.470)    # リード文4行
)

$DOME_FROM  = 0.630   # この行から下は左に原爆ドームが入る
$LEAF_UNTIL = 0.340   # 葉があるのはここまで。以降で緑を拾うのはロゴ自身なので無視する
$DOME_RIGHT = 0.137   # ドームの右端は約0.131。文字の左端が0.140なので、その間を取る
$CELL       = 12      # 紙の下地を作る粗グリッドの1辺（px）
$FEATHER    = 14      # 帯の境をぼかす半径（px）

$bmpSrc = [System.Drawing.Bitmap]::FromFile($srcPath)
$W = $bmpSrc.Width; $H = $bmpSrc.Height
Write-Host ("元画像 {0}x{1}" -f $W, $H)

$fmt = [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
$flat = New-Object System.Drawing.Bitmap($W, $H, $fmt)
$g = [System.Drawing.Graphics]::FromImage($flat)
$g.DrawImage($bmpSrc, 0, 0, $W, $H)
$g.Dispose(); $bmpSrc.Dispose()

$rect = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
$data = $flat.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
$stride = $data.Stride
$bytes = New-Object byte[] ($stride * $H)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$flat.UnlockBits($data); $flat.Dispose()

function Get-Lum { param([int]$R, [int]$G, [int]$B) return ((($R * 77) + ($G * 151) + ($B * 28)) -shr 8) }

# --- 0a. 行ごとの「葉の右端」 ---
#   葉は緑〜オリーブなので赤が青より強い。紺の文字はその逆なので混ざらない。
#   6px 続いた所だけを葉と見なす（紙の上の細かい斑点を拾わないため）。
$leafRight = New-Object int[] $H
$LEAF_TO = [int]($W * 0.24)
for ($y = 0; $y -lt $H; $y++) {
  $row = $y * $stride
  $last = 0; $run = 0
  for ($x = 0; $x -lt $LEAF_TO; $x++) {
    $i = $row + $x * 3
    $b = $bytes[$i]; $gg = $bytes[$i+1]; $rr = $bytes[$i+2]
    if (($rr - $b) -gt 16 -and (Get-Lum $rr $gg $b) -lt 220) {
      $run++
      if ($run -ge 6) { $last = $x }
    } else { $run = 0 }
  }
  $leafRight[$y] = $last
}

# --- 0b. 紙の右端 ---
#   自動検出は諦めた。左から歩いて「紙でない画素が続いたら海」という
#   判定は、リード文のような小さな字の並びでも成立してしまう（字の縁の
#   淡い色が字間を埋めて、40px 続く）。閾値を上げると今度は金色の「DX」で
#   止まる。破れた縁は滑らかな曲線なので、実測した数点を通る折れ線で
#   持つほうが確実で、目で検算もできる。
#
#   値は出力画像を見て読み取った、紙の内側に安全に収まる線。
#   （実際の縁より 2〜3% 内側にしてある）
$EdgeCurve = @(
  @(0.10, 0.390), @(0.20, 0.455), @(0.28, 0.500), @(0.36, 0.530),
  @(0.44, 0.545), @(0.52, 0.545), @(0.60, 0.505), @(0.72, 0.470)
)
$pr = New-Object int[] $H
for ($y = 0; $y -lt $H; $y++) {
  $t = $y / $H
  $fx = $EdgeCurve[0][1]
  if ($t -ge $EdgeCurve[-1][0]) { $fx = $EdgeCurve[-1][1] }
  else {
    for ($k = 1; $k -lt $EdgeCurve.Count; $k++) {
      if ($t -le $EdgeCurve[$k][0]) {
        $p0 = $EdgeCurve[$k-1]; $p1 = $EdgeCurve[$k]
        $u = ($t - $p0[0]) / ($p1[0] - $p0[0])
        if ($u -lt 0) { $u = 0 }
        $fx = $p0[1] + ($p1[1] - $p0[1]) * $u
        break
      }
    }
  }
  $pr[$y] = [int]($fx * $W)
}

# --- 0c. 葉の右端を行方向にならす（残す側＝大きいほうへ寄せる） ---
$SMOOTH = 30
$lr = New-Object int[] $H
for ($y = 0; $y -lt $H; $y++) {
  $a = [math]::Max(0, $y - $SMOOTH); $b2 = [math]::Min($H - 1, $y + $SMOOTH)
  $mx = 0
  for ($k = $a; $k -le $b2; $k++) { if ($leafRight[$k] -gt $mx) { $mx = $leafRight[$k] } }
  $lr[$y] = $mx
}
foreach ($fy in 0.13, 0.20, 0.30, 0.39, 0.45, 0.53, 0.60, 0.69) {
  $yy = [int]($fy * $H)
  Write-Host ("  y={0:N2}  葉 {1,4}px ({2:P1})   紙 {3,4}px ({4:P1})" -f `
    $fy, $lr[$yy], ($lr[$yy]/$W), $pr[$yy], ($pr[$yy]/$W))
}

# --- 1. 塗り直す帯のマスク ---
$mask = New-Object byte[] ($W * $H)
$hits = 0
foreach ($bd0 in $Bands) {
  $y0 = [int]($bd0[0] * $H); $y1 = [int]($bd0[1] * $H)
  $bx0 = [int]($bd0[2] * $W); $bx1 = [int]($bd0[3] * $W)
  for ($y = $y0; $y -lt $y1; $y++) {
    $x0 = $bx0
    if ($y -lt [int]($LEAF_UNTIL * $H)) { $x0 = [math]::Max($x0, $lr[$y] + 10) }
    if ($y -ge [int]($DOME_FROM * $H)) { $x0 = [math]::Max($x0, [int]($DOME_RIGHT * $W)) }
    $x1 = [math]::Min($bx1, $pr[$y] - 14)
    $mrow = $y * $W
    for ($x = $x0; $x -lt $x1; $x++) { $mask[$mrow + $x] = 255; $hits++ }
  }
}
Write-Host ("塗り直す画素 {0} ({1:P2})" -f $hits, ($hits / ($W * $H)))

# --- 2. 粗グリッドで紙の下地を作る ---
#   材料は帯の外の、十分明るい画素だけ。帯の中は空セルにして、
#   隣から拡散させて埋める。こうすると帯の中でも周囲の濃淡が続く。
$cw = [int][math]::Ceiling($W / $CELL)
$ch = [int][math]::Ceiling($H / $CELL)
$n = $cw * $ch
$sumB = New-Object double[] $n; $sumG = New-Object double[] $n
$sumR = New-Object double[] $n; $cnt = New-Object int[] $n

for ($y = 0; $y -lt $H; $y++) {
  $row = $y * $stride
  $cy = [int][math]::Floor($y / $CELL)
  $mrow = $y * $W
  for ($x = 0; $x -lt $W; $x++) {
    if ($mask[$mrow + $x] -ne 0) { continue }
    $i = $row + $x * 3
    $b = $bytes[$i]; $gg = $bytes[$i+1]; $rr = $bytes[$i+2]
    if ((Get-Lum $rr $gg $b) -lt 205) { continue }
    $ci = $cy * $cw + [int][math]::Floor($x / $CELL)
    $sumB[$ci] += $b; $sumG[$ci] += $gg; $sumR[$ci] += $rr; $cnt[$ci]++
  }
}

$cB = New-Object double[] $n; $cG = New-Object double[] $n; $cR = New-Object double[] $n
$has = New-Object bool[] $n
for ($i = 0; $i -lt $n; $i++) {
  if ($cnt[$i] -gt 3) {
    $cB[$i] = $sumB[$i] / $cnt[$i]; $cG[$i] = $sumG[$i] / $cnt[$i]; $cR[$i] = $sumR[$i] / $cnt[$i]
    $has[$i] = $true
  }
}
$seed = $has.Clone()
for ($pass = 0; $pass -lt 120; $pass++) {
  $filled = 0
  $nB = $cB.Clone(); $nG = $cG.Clone(); $nR = $cR.Clone(); $nH = $has.Clone()
  for ($cy = 0; $cy -lt $ch; $cy++) {
    for ($cx = 0; $cx -lt $cw; $cx++) {
      $ci = $cy * $cw + $cx
      if ($has[$ci]) { continue }
      $sb = 0.0; $sg = 0.0; $sr = 0.0; $k = 0
      for ($dy = -1; $dy -le 1; $dy++) {
        for ($dx = -1; $dx -le 1; $dx++) {
          $ny = $cy + $dy; $nx = $cx + $dx
          if ($ny -lt 0 -or $ny -ge $ch -or $nx -lt 0 -or $nx -ge $cw) { continue }
          $nj = $ny * $cw + $nx
          if (-not $has[$nj]) { continue }
          $sb += $cB[$nj]; $sg += $cG[$nj]; $sr += $cR[$nj]; $k++
        }
      }
      if ($k -gt 0) { $nB[$ci] = $sb/$k; $nG[$ci] = $sg/$k; $nR[$ci] = $sr/$k; $nH[$ci] = $true; $filled++ }
    }
  }
  $cB = $nB; $cG = $nG; $cR = $nR; $has = $nH
  if ($filled -eq 0) { break }
}


# 拡散だけで埋めると、四隅から進んだ波面がぶつかった所に稜線ができ、
# 紙の上にうっすらX字の折り目が見える（実際に見えた）。
# 埋めたセルだけを何度もならして、その稜線を消す。元からあったセルは
# 動かさないので、周囲の濃淡はそのまま保たれる。
for ($pass = 0; $pass -lt 60; $pass++) {
  $rB = $cB.Clone(); $rG = $cG.Clone(); $rR = $cR.Clone()
  for ($cy = 0; $cy -lt $ch; $cy++) {
    for ($cx = 0; $cx -lt $cw; $cx++) {
      $ci = $cy * $cw + $cx
      if ($seed[$ci]) { continue }
      $sb = 0.0; $sg = 0.0; $sr = 0.0; $k = 0
      for ($dy = -1; $dy -le 1; $dy++) {
        for ($dx = -1; $dx -le 1; $dx++) {
          if ($dy -eq 0 -and $dx -eq 0) { continue }
          $ny = $cy + $dy; $nx = $cx + $dx
          if ($ny -lt 0 -or $ny -ge $ch -or $nx -lt 0 -or $nx -ge $cw) { continue }
          $nj = $ny * $cw + $nx
          $sb += $cB[$nj]; $sg += $cG[$nj]; $sr += $cR[$nj]; $k++
        }
      }
      if ($k -gt 0) { $rB[$ci] = $sb/$k; $rG[$ci] = $sg/$k; $rR[$ci] = $sr/$k }
    }
  }
  $cB = $rB; $cG = $rG; $cR = $rR
}
$paper = New-Object System.Drawing.Bitmap($cw, $ch, $fmt)
$pd = $paper.LockBits((New-Object System.Drawing.Rectangle(0,0,$cw,$ch)),
        [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $fmt)
$pstride = $pd.Stride
$pbytes = New-Object byte[] ($pstride * $ch)
for ($cy = 0; $cy -lt $ch; $cy++) {
  for ($cx = 0; $cx -lt $cw; $cx++) {
    $ci = $cy * $cw + $cx
    $j = $cy * $pstride + $cx * 3
    if ($has[$ci]) {
      $pbytes[$j]   = [byte][math]::Min(255, [math]::Round($cB[$ci]))
      $pbytes[$j+1] = [byte][math]::Min(255, [math]::Round($cG[$ci]))
      $pbytes[$j+2] = [byte][math]::Min(255, [math]::Round($cR[$ci]))
    } else { $pbytes[$j] = 236; $pbytes[$j+1] = 241; $pbytes[$j+2] = 246 }
  }
}
[System.Runtime.InteropServices.Marshal]::Copy($pbytes, 0, $pd.Scan0, $pbytes.Length)
$paper.UnlockBits($pd)

$paperBig = New-Object System.Drawing.Bitmap($W, $H, $fmt)
$g2 = [System.Drawing.Graphics]::FromImage($paperBig)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g2.DrawImage($paper, (New-Object System.Drawing.RectangleF(0,0,$W,$H)),
              (New-Object System.Drawing.RectangleF(-0.5,-0.5,$cw,$ch)),
              [System.Drawing.GraphicsUnit]::Pixel)
$g2.Dispose(); $paper.Dispose()

$bd = $paperBig.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
$bigStride = $bd.Stride
$pbig = New-Object byte[] ($bigStride * $H)
[System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $pbig, 0, $pbig.Length)
$paperBig.UnlockBits($bd); $paperBig.Dispose()

# --- 3. 帯の境をぼかす ---
function Invoke-BoxBlur {
  param([byte[]]$Src, [int]$Width, [int]$Height, [int]$Radius)
  $tmp = New-Object double[] ($Width * $Height)
  $out = New-Object byte[] ($Width * $Height)
  $d = 2 * $Radius + 1
  for ($y = 0; $y -lt $Height; $y++) {
    $o = $y * $Width; $acc = 0.0
    for ($x = -$Radius; $x -le $Radius; $x++) {
      $acc += $Src[$o + [math]::Max(0, [math]::Min($Width - 1, $x))]
    }
    for ($x = 0; $x -lt $Width; $x++) {
      $tmp[$o + $x] = $acc / $d
      $acc += $Src[$o + [math]::Max(0, [math]::Min($Width-1, $x + $Radius + 1))] -
              $Src[$o + [math]::Max(0, [math]::Min($Width-1, $x - $Radius))]
    }
  }
  for ($x = 0; $x -lt $Width; $x++) {
    $acc = 0.0
    for ($y = -$Radius; $y -le $Radius; $y++) {
      $acc += $tmp[[math]::Max(0, [math]::Min($Height-1, $y)) * $Width + $x]
    }
    for ($y = 0; $y -lt $Height; $y++) {
      $out[$y * $Width + $x] = [byte][math]::Min(255.0, ($acc / $d))
      $acc += $tmp[[math]::Max(0, [math]::Min($Height-1, $y + $Radius + 1)) * $Width + $x] -
              $tmp[[math]::Max(0, [math]::Min($Height-1, $y - $Radius)) * $Width + $x]
    }
  }
  return $out
}
$soft = Invoke-BoxBlur -Src $mask -Width $W -Height $H -Radius $FEATHER

# --- 4. 合成 ---
for ($y = 0; $y -lt $H; $y++) {
  $row = $y * $stride; $brow = $y * $bigStride; $mrow = $y * $W
  for ($x = 0; $x -lt $W; $x++) {
    $a = $soft[$mrow + $x]
    if ($a -eq 0) { continue }
    $i = $row + $x * 3; $j = $brow + $x * 3
    $bytes[$i]   = [byte]((($pbig[$j]   * $a) + ($bytes[$i]   * (255 - $a))) / 255)
    $bytes[$i+1] = [byte]((($pbig[$j+1] * $a) + ($bytes[$i+1] * (255 - $a))) / 255)
    $bytes[$i+2] = [byte]((($pbig[$j+2] * $a) + ($bytes[$i+2] * (255 - $a))) / 255)
  }
}

$out = New-Object System.Drawing.Bitmap($W, $H, $fmt)
$od = $out.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $fmt)
[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $od.Scan0, $bytes.Length)
$out.UnlockBits($od)

function Save-Jpeg {
  param([System.Drawing.Bitmap]$Bmp, [double[]]$Rect, [string]$Out, [int]$MaxWidth, [int]$Quality)
  $x = [int]($Rect[0] * $Bmp.Width); $y = [int]($Rect[1] * $Bmp.Height)
  $w = [int]($Rect[2] * $Bmp.Width); $h = [int]($Rect[3] * $Bmp.Height)
  $nw = [math]::Min($MaxWidth, $w); $nh = [int][math]::Round($h * $nw / $w)
  $dst = New-Object System.Drawing.Bitmap($nw, $nh, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $gg = [System.Drawing.Graphics]::FromImage($dst)
  $gg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $gg.DrawImage($Bmp, (New-Object System.Drawing.Rectangle(0,0,$nw,$nh)),
                      (New-Object System.Drawing.Rectangle($x,$y,$w,$h)),
                      [System.Drawing.GraphicsUnit]::Pixel)
  $gg.Dispose()
  $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $ps = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $ps.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
  $dst.Save($Out, $enc, $ps)
  "{0,-26} {1}x{2}  {3} KB" -f (Split-Path $Out -Leaf), $nw, $nh, [math]::Round((Get-Item $Out).Length/1KB)
  $dst.Dispose()
}

# 横長：絵の全体をそのまま全面に使う
Save-Jpeg -Bmp $out -Rect @(0.0, 0.0, 1.0, 1.0) `
  -Out "$root\assets\img\backgrounds\hero-scene-wide.jpg" -MaxWidth 1600 -Quality 82

# 縦長：紙の側には本文が乗るので、船団を中心に縦構図で切る
Save-Jpeg -Bmp $out -Rect @(0.480, 0.130, 0.520, 0.870) `
  -Out "$root\assets\img\backgrounds\hero-scene-tall.jpg" -MaxWidth 820 -Quality 82

$out.Dispose()
Write-Host "完了"
