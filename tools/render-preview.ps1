<#
  render-preview.ps1
  ブラウザから取り出した実レイアウト座標をもとに、背景の合成結果
  （紙の下地 → 装飾部品の multiply/screen → スクリム）をオフラインで
  再現して1枚の画像に書き出す。

  ブラウザペインが表示できない環境でスクリーンショットの代わりに使う。
  カード・本文は描かない（背景の見え方の確認が目的）。

  使い方:
    $env:PV_JSON="layout-1440.json"; $env:PV_HERO="hero-scene-wide.jpg"
    $env:PV_OUT="preview-1440.png";  $env:PV_SCALE="0.34"
    powershell -File tools/render-preview.ps1
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$S = Join-Path (Split-Path $PSScriptRoot -Parent) '.preview'
if (-not (Test-Path $S)) { New-Item -ItemType Directory -Force -Path $S | Out-Null }
$root = Split-Path $PSScriptRoot -Parent
$deco = "$root\assets\img\deco"

function Get-Pixels([System.Drawing.Bitmap]$bmp) {
  $rect = New-Object System.Drawing.Rectangle(0, 0, $bmp.Width, $bmp.Height)
  $d = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $len = $d.Stride * $bmp.Height
  $buf = New-Object byte[] $len
  [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0, $buf, 0, $len)
  $bmp.UnlockBits($d)
  return @{ buf = $buf; stride = $d.Stride; w = $bmp.Width; h = $bmp.Height }
}

function New-ScaledBitmap([string]$path, [int]$w, [int]$h, [bool]$flip) {
  $srcImg = [System.Drawing.Bitmap]::FromFile($path)
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($srcImg, 0, 0, $w, $h)
  $g.Dispose(); $srcImg.Dispose()
  if ($flip) { $bmp.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
  return $bmp
}

function Render-Section($sec, [double]$scale, [string]$heroImg) {
  $W = [int]($sec.w * $scale); $H = [int]($sec.h * $scale)

  $m = [regex]::Match($sec.bg, 'rgb\((\d+), (\d+), (\d+)\)')
  $bg = @([int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value)

  $canvas = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($canvas)
  $g.Clear([System.Drawing.Color]::FromArgb($bg[0], $bg[1], $bg[2]))
  $g.Dispose()
  $cv = Get-Pixels $canvas
  $canvas.Dispose()
  $out = $cv.buf; $stride = $cv.stride

  # 紙の粒（本番は style.css の SVG feTurbulence。ここでは同程度の
  # 淡いランダム粒で近似する）
  $rnd = New-Object System.Random 7
  for ($y = 0; $y -lt $H; $y++) {
    $rowO = $y * $stride
    for ($x = 0; $x -lt $W; $x++) {
      $o = $rowO + $x * 4
      $k = 0.90 + $rnd.NextDouble() * 0.10
      $out[$o]     = [byte][math]::Round($out[$o]     * $k)
      $out[$o + 1] = [byte][math]::Round($out[$o + 1] * $k)
      $out[$o + 2] = [byte][math]::Round($out[$o + 2] * $k)
    }
  }

  # ヒーローだけは海景の1枚絵（cover相当）
  if ($heroImg) {
    $probe = [System.Drawing.Bitmap]::FromFile($heroImg)
    $sr = $probe.Width / $probe.Height; $probe.Dispose()
    $vr = $W / $H
    if ($vr -gt $sr) { $dw = $W; $dh = [int]($W / $sr) } else { $dh = $H; $dw = [int]($H * $sr) }
    $scene = New-ScaledBitmap $heroImg $dw $dh $false
    $sp = Get-Pixels $scene; $scene.Dispose()
    $offX = [int](($dw - $W) / 2); $offY = [int](($dh - $H) / 2)
    for ($y = 0; $y -lt $H; $y++) {
      $sy = $y + $offY; if ($sy -lt 0 -or $sy -ge $sp.h) { continue }
      $rowO = $y * $stride; $rowS = $sy * $sp.stride
      for ($x = 0; $x -lt $W; $x++) {
        $sx = $x + $offX; if ($sx -lt 0 -or $sx -ge $sp.w) { continue }
        $o = $rowO + $x * 4; $s = $rowS + $sx * 4
        $out[$o] = $sp.buf[$s]; $out[$o + 1] = $sp.buf[$s + 1]; $out[$o + 2] = $sp.buf[$s + 2]
      }
    }
  }

  # 装飾部品
  foreach ($p in $sec.parts) {
    $pw = [int]($p.w * $scale); $ph = [int]($p.h * $scale)
    if ($pw -le 0 -or $ph -le 0) { continue }
    $bmp = New-ScaledBitmap "$deco\$($p.src)" $pw $ph ([bool]$p.flip)
    $pp = Get-Pixels $bmp; $bmp.Dispose()
    $px = [int]($p.x * $scale); $py = [int]($p.y * $scale)
    $a = [double]$p.opacity
    $isScreen = ($p.blend -eq 'screen')
    for ($j = 0; $j -lt $ph; $j++) {
      $y = $py + $j; if ($y -lt 0 -or $y -ge $H) { continue }
      $rowO = $y * $stride; $rowP = $j * $pp.stride
      for ($i = 0; $i -lt $pw; $i++) {
        $x = $px + $i; if ($x -lt 0 -or $x -ge $W) { continue }
        $o = $rowO + $x * 4; $q = $rowP + $i * 4
        if ($isScreen) {
          # CTAの filter: invert(1) grayscale(1) sepia(1) saturate(2.8) brightness(.45) を近似
          $lum = 0.299 * $pp.buf[$q + 2] + 0.587 * $pp.buf[$q + 1] + 0.114 * $pp.buf[$q]
          $inv = 255.0 - $lum
          $tone = @(($inv * 0.62), ($inv * 0.88), ($inv * 1.05))  # B,G,R の順（金寄り）
          for ($c = 0; $c -lt 3; $c++) {
            $b = [double]$out[$o + $c]
            $s = [math]::Min(255.0, $tone[$c] * 0.95)
            $blend = 255.0 - (255.0 - $b) * (255.0 - $s) / 255.0
            $out[$o + $c] = [byte][math]::Max(0, [math]::Min(255, [math]::Round($b * (1.0 - $a) + $blend * $a)))
          }
        } else {
          for ($c = 0; $c -lt 3; $c++) {
            $b = [double]$out[$o + $c]
            $blend = $b * $pp.buf[$q + $c] / 255.0
            $out[$o + $c] = [byte][math]::Max(0, [math]::Min(255, [math]::Round($b * (1.0 - $a) + $blend * $a)))
          }
        }
      }
    }
  }

  # スクリム
  $sc = if ($sec.scrimColor) { @([int]$sec.scrimColor[0], [int]$sec.scrimColor[1], [int]$sec.scrimColor[2]) } else { $bg }
  $kind = "$($sec.scrim)"
  $a0 = 0.55; $a1 = 0.78
  if ($sec.scrimA) { $a0 = [double]$sec.scrimA[0]; $a1 = [double]$sec.scrimA[1] }
  for ($y = 0; $y -lt $H; $y++) {
    $rowO = $y * $stride
    for ($x = 0; $x -lt $W; $x++) {
      $al = 0.0
      if ($kind -eq 'radial') {
        # 上下の縁だけを持ち上げる px 指定の2枚重ね（style.css と同じ式）
        $dTop = $y / $scale
        $aT = 0.0
        if     ($dTop -le 150) { $aT = 0.62 + ($dTop / 150.0) * (0.34 - 0.62) }
        elseif ($dTop -le 320) { $aT = 0.34 + (($dTop - 150) / 170.0) * (0.08 - 0.34) }
        elseif ($dTop -le 460) { $aT = 0.08 + (($dTop - 320) / 140.0) * (0.00 - 0.08) }
        $dBot = ($H - 1 - $y) / $scale
        $aB = 0.0
        if     ($dBot -le 130) { $aB = 0.50 + ($dBot / 130.0) * (0.22 - 0.50) }
        elseif ($dBot -le 280) { $aB = 0.22 + (($dBot - 130) / 150.0) * (0.04 - 0.22) }
        elseif ($dBot -le 400) { $aB = 0.04 + (($dBot - 280) / 120.0) * (0.00 - 0.04) }
        $al = $aT + $aB * (1.0 - $aT)
      } elseif ($kind -eq 'linearV2') {
        # 縦画面ヒーローのスクリム: .90 / .74(40%) / .20(66%) / .04(100%)
        $f = $y / [double]$H
        if     ($f -le 0.40) { $al = 0.90 + ($f/0.40)*(0.74-0.90) }
        elseif ($f -le 0.66) { $al = 0.74 + (($f-0.40)/0.26)*(0.20-0.74) }
        else                 { $al = 0.20 + (($f-0.66)/0.34)*(0.04-0.20) }
      } elseif ($kind -eq 'linearV') {
        $al = $a0 + ($y / [double]$H) * ($a1 - $a0)
      } else {
        $f = $x / [double]$W
        if ($f -le 0.55) { $al = 0.86 + ($f / 0.55) * (0.35 - 0.86) } else { $al = 0.35 + (($f - 0.55) / 0.45) * (0.12 - 0.35) }
      }
      if ($al -le 0) { continue }
      $o = $rowO + $x * 4
      $out[$o]     = [byte][math]::Round($out[$o]     * (1.0 - $al) + $sc[2] * $al)
      $out[$o + 1] = [byte][math]::Round($out[$o + 1] * (1.0 - $al) + $sc[1] * $al)
      $out[$o + 2] = [byte][math]::Round($out[$o + 2] * (1.0 - $al) + $sc[0] * $al)
    }
  }

  $res = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $rect = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
  $d = $res.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  [System.Runtime.InteropServices.Marshal]::Copy($out, 0, $d.Scan0, $out.Length)
  $res.UnlockBits($d)
  return $res
}

$scale  = if ($env:PV_SCALE) { [double]$env:PV_SCALE } else { 0.34 }
$layout = Get-Content "$S\$($env:PV_JSON)" -Raw | ConvertFrom-Json
$heroPath = "$root\assets\img\backgrounds\$($env:PV_HERO)"

$ids = @(); $bmps = @()
foreach ($sec in $layout.sections) {
  $hi = if ($sec.id -eq 'hero') { $heroPath } else { $null }
  $ids += $sec.id
  $bmps += (Render-Section $sec $scale $hi)
  Write-Output "  rendered: $($sec.id)"
}
# PV_ROW=1 なら横並び（縦長のモバイル用。縦積みだと細長くなりすぎて見られない）
if ($env:PV_ROW -eq "1") {
  $gap = 12; $lab = 22
  $sheetW = 0; foreach ($b in $bmps) { $sheetW += $b.Width + $gap }
  $sheetH = [int](($bmps | ForEach-Object { $_.Height } | Measure-Object -Maximum).Maximum) + $lab + $gap
  $sheet = New-Object System.Drawing.Bitmap($sheetW, $sheetH)
  $g = [System.Drawing.Graphics]::FromImage($sheet)
  $g.Clear([System.Drawing.Color]::FromArgb(58, 58, 68))
  $font = New-Object System.Drawing.Font('Consolas', 11, [System.Drawing.FontStyle]::Bold)
  $fb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
  $x = 0
  for ($i = 0; $i -lt $bmps.Count; $i++) {
    $g.DrawString($ids[$i], $font, $fb, ($x + 2), 3)
    $g.DrawImage($bmps[$i], $x, $lab)
    $x += $bmps[$i].Width + $gap
    $bmps[$i].Dispose()
  }
  $g.Dispose()
  $outPath = (Join-Path $S $env:PV_OUT)
  $sheet.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $sheet.Dispose()
  "preview: $outPath ($sheetW x $sheetH)"
  return
}

$totalH = [int](($bmps | ForEach-Object { $_.Height } | Measure-Object -Sum).Sum) + ($bmps.Count * 26)
$maxW = [int](($bmps | ForEach-Object { $_.Width } | Measure-Object -Maximum).Maximum)
$sheet = New-Object System.Drawing.Bitmap($maxW, $totalH)
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::FromArgb(58, 58, 68))
$font = New-Object System.Drawing.Font('Consolas', 12, [System.Drawing.FontStyle]::Bold)
$fb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$y = 0
for ($i = 0; $i -lt $bmps.Count; $i++) {
  $g.DrawString($ids[$i], $font, $fb, 6, ($y + 3))
  $g.DrawImage($bmps[$i], 0, ($y + 22))
  $y += $bmps[$i].Height + 26
  $bmps[$i].Dispose()
}
$g.Dispose()
$outPath = "$S\$($env:PV_OUT)"
$sheet.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
"preview: $outPath ($maxW x $totalH)"
