<#
  deco-extract.ps1
  ひろしま協働DX LP ― 装飾部品の切り出しツール

  元画像のクリーム地を multiply の中性色（白）へ正規化して書き出す。

  原理:
    背景の合成結果 = 下地 x (部品/クリーム)  ... mix-blend-mode:multiply
    透過率 t_c = clamp(p_c / cream_c, 0, 1) を各チャンネルで求めて保存すると、
      ・p == cream の画素は t = 1（白）→ 下地に影響しない = 透過と同じ
      ・下地 == cream のとき合成結果は元画像そのものになる
    という2つの性質が同時に成り立つ。
    これにより「余白ごと大きめに切り出す」ことが許され、境界の
    フェザーブレンドが不要になる。
#>
Add-Type -AssemblyName System.Drawing

function Get-CreamColor {
  <# 指定した矩形（分数座標）の平均色をクリーム地として返す #>
  param([System.Drawing.Bitmap]$Bmp, [double[]]$Frac)
  $x = [int]($Frac[0] * $Bmp.Width); $y = [int]($Frac[1] * $Bmp.Height)
  $w = [int]($Frac[2] * $Bmp.Width); $h = [int]($Frac[3] * $Bmp.Height)
  $sr = 0.0; $sg = 0.0; $sb = 0.0; $n = 0
  for ($j = $y; $j -lt ($y + $h); $j += 3) {
    for ($i = $x; $i -lt ($x + $w); $i += 3) {
      $c = $Bmp.GetPixel($i, $j); $sr += $c.R; $sg += $c.G; $sb += $c.B; $n++
    }
  }
  return @([double]($sr / $n), [double]($sg / $n), [double]($sb / $n))
}

function Export-Deco {
  param(
    [string]$Src,
    [double[]]$Rect,          # x,y,w,h 分数座標（0..1）
    [double[]]$CreamRect,     # クリーム地をサンプルする矩形（分数座標）
    [string]$Out,
    [double]$Gain = 1.0,      # 濃度調整。1未満で薄く、1超で濃く
    [int]$MaxWidth = 0,       # 0 なら等倍
    [switch]$NoNormalize      # 正規化せずそのまま切り出す
  )
  $bmpSrc = [System.Drawing.Bitmap]::FromFile($Src)
  try {
    $x = [int]($Rect[0] * $bmpSrc.Width); $y = [int]($Rect[1] * $bmpSrc.Height)
    $w = [int]($Rect[2] * $bmpSrc.Width); $h = [int]($Rect[3] * $bmpSrc.Height)
    if ($x -lt 0) { $x = 0 }; if ($y -lt 0) { $y = 0 }
    if (($x + $w) -gt $bmpSrc.Width)  { $w = $bmpSrc.Width  - $x }
    if (($y + $h) -gt $bmpSrc.Height) { $h = $bmpSrc.Height - $y }

    $cream = if ($NoNormalize) { @(255.0, 255.0, 255.0) } else { Get-CreamColor -Bmp $bmpSrc -Frac $CreamRect }

    # 切り出し（32bppARGB へ複製して LockBits で走査する）
    $crop = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($crop)
    $g.DrawImage($bmpSrc, (New-Object System.Drawing.Rectangle(0,0,$w,$h)), (New-Object System.Drawing.Rectangle($x,$y,$w,$h)), [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()

    if (-not $NoNormalize) {
      $lockRect = New-Object System.Drawing.Rectangle(0,0,$w,$h)
      $data = $crop.LockBits($lockRect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
      $bytes = $data.Stride * $h
      $buf = New-Object byte[] $bytes
      [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buf, 0, $bytes)

      # ルックアップテーブル（BGRA 順）
      $lutB = New-Object byte[] 256; $lutG = New-Object byte[] 256; $lutR = New-Object byte[] 256
      for ($v = 0; $v -lt 256; $v++) {
        $tb = ($v / $cream[2]); $tg = ($v / $cream[1]); $tr = ($v / $cream[0])
        # Gain: 透過率を 1 から遠ざける/近づける（濃度調整）
        $tb = 1.0 - (1.0 - $tb) * $Gain
        $tg = 1.0 - (1.0 - $tg) * $Gain
        $tr = 1.0 - (1.0 - $tr) * $Gain
        $lutB[$v] = [byte][math]::Max(0, [math]::Min(255, [math]::Round($tb * 255)))
        $lutG[$v] = [byte][math]::Max(0, [math]::Min(255, [math]::Round($tg * 255)))
        $lutR[$v] = [byte][math]::Max(0, [math]::Min(255, [math]::Round($tr * 255)))
      }
      for ($p = 0; $p -lt $bytes; $p += 4) {
        $buf[$p]     = $lutB[$buf[$p]]
        $buf[$p + 1] = $lutG[$buf[$p + 1]]
        $buf[$p + 2] = $lutR[$buf[$p + 2]]
        $buf[$p + 3] = 255
      }
      [System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $data.Scan0, $bytes)
      $crop.UnlockBits($data)
    }

    # 必要なら縮小
    $final = $crop
    if ($MaxWidth -gt 0 -and $w -gt $MaxWidth) {
      $nh = [int][math]::Round($h * $MaxWidth / $w)
      $rs = New-Object System.Drawing.Bitmap($MaxWidth, $nh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
      $g2 = [System.Drawing.Graphics]::FromImage($rs)
      $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g2.PixelOffsetMode  = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $g2.DrawImage($crop, 0, 0, $MaxWidth, $nh)
      $g2.Dispose()
      $final = $rs
    }

    $dir = Split-Path $Out -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    if ($Out -match '\.jpe?g$') {
      $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
      $ps  = New-Object System.Drawing.Imaging.EncoderParameters(1)
      $ps.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 92L)
      $final.Save($Out, $enc, $ps)
    } else {
      $final.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
    }

    "{0,-30} {1,4}x{2,-4} cream=({3:N0},{4:N0},{5:N0})" -f (Split-Path $Out -Leaf), $final.Width, $final.Height, $cream[0], $cream[1], $cream[2]
    if ($final -ne $crop) { $final.Dispose() }
    $crop.Dispose()
  } finally { $bmpSrc.Dispose() }
}

function New-ContactSheet {
  <# 複数画像を1枚のシートに並べて目視確認しやすくする #>
  param([string[]]$Files, [string]$Out, [int]$Cols = 3, [int]$Cell = 420, [string]$BgHex = '#FAF5EA')
  $rows = [math]::Ceiling($Files.Count / $Cols)
  $pad = 10; $label = 22
  $sheet = New-Object System.Drawing.Bitmap(($Cols * ($Cell + $pad) + $pad), ($rows * ($Cell + $pad + $label) + $pad))
  $g = [System.Drawing.Graphics]::FromImage($sheet)
  $bg = [System.Drawing.ColorTranslator]::FromHtml($BgHex)
  $g.Clear($bg)
  $font = New-Object System.Drawing.Font('Consolas', 11)
  $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40,40,60))
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,150,120,60))
  for ($i = 0; $i -lt $Files.Count; $i++) {
    $c = $i % $Cols; $r = [math]::Floor($i / $Cols)
    $cx = $pad + $c * ($Cell + $pad); $cy = $pad + $r * ($Cell + $pad + $label)
    $img = [System.Drawing.Image]::FromFile($Files[$i])
    $sc = [math]::Min($Cell / $img.Width, $Cell / $img.Height)
    $dw = [int]($img.Width * $sc); $dh = [int]($img.Height * $sc)
    $g.DrawImage($img, ($cx + ($Cell - $dw)/2), ($cy + ($Cell - $dh)/2), $dw, $dh)
    $g.DrawRectangle($pen, $cx, $cy, $Cell, $Cell)
    $g.DrawString((Split-Path $Files[$i] -Leaf), $font, $brush, $cx, ($cy + $Cell + 3))
    $img.Dispose()
  }
  $g.Dispose()
  $sheet.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $sheet.Dispose()
  "sheet: $Out"
}
