<#
  deco-repair.ps1
  ・Repair-Region     : 焼き込み要素を、近傍のクリーンな領域からフェザー付きで上書きして消す
  ・New-SeamlessTile  : 4方向ミラーで完全にシームレスなタイルを作る
#>
Add-Type -AssemblyName System.Drawing

function New-FeatheredPatch {
  <# 元画像の矩形を取り出し、四辺に幅 $Feather のアルファ傾斜を付けたビットマップを返す #>
  param([System.Drawing.Bitmap]$Src, [int]$Sx, [int]$Sy, [int]$W, [int]$H,
        [int]$Feather = 24, [switch]$MirrorX, [switch]$MirrorY)
  $p = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($p)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $dst = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
  $srcR = New-Object System.Drawing.Rectangle($Sx, $Sy, $W, $H)
  $g.DrawImage($Src, $dst, $srcR, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  if ($MirrorX) { $p.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
  if ($MirrorY) { $p.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipY) }

  $data = $p.LockBits($dst, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $len = $data.Stride * $H
  $buf = New-Object byte[] $len
  [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buf, 0, $len)
  for ($y = 0; $y -lt $H; $y++) {
    $dy = [math]::Min($y, $H - 1 - $y)
    for ($x = 0; $x -lt $W; $x++) {
      $dx = [math]::Min($x, $W - 1 - $x)
      $d = [math]::Min($dx, $dy)
      $a = if ($Feather -le 0 -or $d -ge $Feather) { 255 } else { [int][math]::Round(255 * $d / $Feather) }
      $buf[$y * $data.Stride + $x * 4 + 3] = [byte]$a
    }
  }
  [System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $data.Scan0, $len)
  $p.UnlockBits($data)
  return $p
}

function Repair-Region {
  <#
    $Target / $Source は分数座標 x,y,w,h。$Source の内容を $Target 上へ
    フェザー付きで重ねる。$Tile を指定すると横方向にミラー交互で敷き詰める。
  #>
  param([System.Drawing.Bitmap]$Bmp, [double[]]$Target, [double[]]$Source,
        [int]$Feather = 28, [switch]$MirrorX, [switch]$MirrorY, [switch]$Tile)
  $W = $Bmp.Width; $H = $Bmp.Height
  $tx = [int]($Target[0]*$W); $ty = [int]($Target[1]*$H); $tw = [int]($Target[2]*$W); $th = [int]($Target[3]*$H)
  $sx = [int]($Source[0]*$W); $sy = [int]($Source[1]*$H); $sw = [int]($Source[2]*$W); $sh = [int]($Source[3]*$H)
  $g = [System.Drawing.Graphics]::FromImage($Bmp)
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

  if ($Tile) {
    $x = $tx; $i = 0
    # 継ぎ目を隠すため、フェザー幅の分だけ重ねながら敷き詰める
    $step = $sw - $Feather
    while ($x -lt ($tx + $tw)) {
      $mx = if ($i % 2 -eq 1) { $true } else { [bool]$MirrorX }
      $patch = New-FeatheredPatch -Src $Bmp -Sx $sx -Sy $sy -W $sw -H $sh -Feather $Feather -MirrorX:$mx -MirrorY:$MirrorY
      $g.DrawImage($patch, $x, $ty, $sw, $th)
      $patch.Dispose()
      $x += $step; $i++
    }
  } else {
    $patch = New-FeatheredPatch -Src $Bmp -Sx $sx -Sy $sy -W $sw -H $sh -Feather $Feather -MirrorX:$MirrorX -MirrorY:$MirrorY
    $g.DrawImage($patch, $tx, $ty, $tw, $th)
    $patch.Dispose()
  }
  $g.Dispose()
}

function New-SeamlessTile {
  <# 矩形を切り出し、4方向ミラーで継ぎ目のないタイルにする #>
  param([string]$Src, [double[]]$Rect, [string]$Out, [int]$Size = 320)
  $img = [System.Drawing.Bitmap]::FromFile($Src)
  try {
    $x = [int]($Rect[0]*$img.Width); $y = [int]($Rect[1]*$img.Height)
    $w = [int]($Rect[2]*$img.Width); $h = [int]($Rect[3]*$img.Height)
    $q = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($q)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0,0,$Size,$Size)), (New-Object System.Drawing.Rectangle($x,$y,$w,$h)), [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()

    $full = New-Object System.Drawing.Bitmap(($Size*2), ($Size*2), [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g2 = [System.Drawing.Graphics]::FromImage($full)
    $a = $q.Clone()
    $b = $q.Clone(); $b.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX)
    $c = $q.Clone(); $c.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipY)
    $d = $q.Clone(); $d.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipXY)
    $g2.DrawImage($a, 0, 0, $Size, $Size)
    $g2.DrawImage($b, $Size, 0, $Size, $Size)
    $g2.DrawImage($c, 0, $Size, $Size, $Size)
    $g2.DrawImage($d, $Size, $Size, $Size, $Size)
    $g2.Dispose(); $a.Dispose(); $b.Dispose(); $c.Dispose(); $d.Dispose()

    $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ps = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $ps.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 90L)
    $full.Save($Out, $enc, $ps)
    "{0,-30} {1}x{2} (seamless mirror tile)" -f (Split-Path $Out -Leaf), $full.Width, $full.Height
    $full.Dispose(); $q.Dispose()
  } finally { $img.Dispose() }
}

function Save-Repaired {
  <# 元画像を読み、Repair 指示を順に適用して保存する #>
  param([string]$Src, [string]$Out, [array]$Repairs, [int]$MaxWidth = 0, [int]$Quality = 86)
  $img = [System.Drawing.Bitmap]::FromFile($Src)
  try {
    $bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.DrawImage($img, 0, 0, $img.Width, $img.Height); $g.Dispose()
    foreach ($r in $Repairs) {
      Repair-Region -Bmp $bmp -Target $r.Target -Source $r.Source -Feather $r.Feather `
        -MirrorX:([bool]$r.MirrorX) -MirrorY:([bool]$r.MirrorY) -Tile:([bool]$r.Tile)
    }
    $final = $bmp
    if ($MaxWidth -gt 0 -and $bmp.Width -gt $MaxWidth) {
      $nh = [int][math]::Round($bmp.Height * $MaxWidth / $bmp.Width)
      $rs = New-Object System.Drawing.Bitmap($MaxWidth, $nh, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
      $g3 = [System.Drawing.Graphics]::FromImage($rs)
      $g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g3.DrawImage($bmp, 0, 0, $MaxWidth, $nh); $g3.Dispose()
      $final = $rs
    }
    $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ps = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $ps.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
    $dir = Split-Path $Out -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $final.Save($Out, $enc, $ps)
    "{0,-30} {1}x{2}  ({3} KB)" -f (Split-Path $Out -Leaf), $final.Width, $final.Height, [math]::Round((Get-Item $Out).Length/1KB)
    if ($final -ne $bmp) { $final.Dispose() }
    $bmp.Dispose()
  } finally { $img.Dispose() }
}
