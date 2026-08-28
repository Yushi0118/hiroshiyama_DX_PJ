# preview-fleet.ps1 ― 船の配置を背景画像の上にマーカーで重ねて確認する
# （WebP は System.Drawing で復号できないため、船影は矩形＋喫水線で代用する）
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$S = "C:\Users\YUSHI~1.HOS\AppData\Local\Temp\claude\C--Users-yushi-hoshiyama-Desktop-Claud--\0069ab21-c354-4d6d-a1bc-6d68b2e2430a\scratchpad"
$root = "C:\Users\yushi.hoshiyama\Desktop\Claud連携\hiroshiyama_DX_PJ"
$ships = Get-Content "$S\ships.json" -Raw | ConvertFrom-Json

function Draw-Fleet($src, $list, $out, $maxW) {
  $img = [System.Drawing.Bitmap]::FromFile($src)
  $bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.DrawImage($img, 0, 0, $img.Width, $img.Height)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $hull = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(215, 24, 46, 84))
  $sail = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(190, 250, 248, 240))
  $mark = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 200, 30, 30)), 2
  foreach ($s in $list) {
    $w = $s[2]/100.0 * $img.Width
    $h = $w * 1.25
    $x = $s[0]/100.0 * $img.Width
    $y = $s[1]/100.0 * $img.Height
    # 帆（上6割）と船体（下4割）で船影を模す
    $g.FillPolygon($sail, @(
      (New-Object System.Drawing.PointF(($x+$w*0.5), $y)),
      (New-Object System.Drawing.PointF(($x+$w*0.9), ($y+$h*0.62))),
      (New-Object System.Drawing.PointF(($x+$w*0.1), ($y+$h*0.62)))))
    $g.FillEllipse($hull, $x, ($y+$h*0.6), $w, ($h*0.38))
    # 喫水線の高さに赤い横線（ここが水面に乗っているべき位置）
    $g.DrawLine($mark[0], ($x-$w*0.25), ($y+$h*0.85), ($x+$w*1.25), ($y+$h*0.85))
  }
  $g.Dispose(); $img.Dispose()
  $final = $bmp
  if ($bmp.Width -gt $maxW) {
    $nh = [int]($bmp.Height * $maxW / $bmp.Width)
    $rs = New-Object System.Drawing.Bitmap($maxW, $nh)
    $g2 = [System.Drawing.Graphics]::FromImage($rs)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.DrawImage($bmp, 0, 0, $maxW, $nh); $g2.Dispose(); $final = $rs
  }
  $final.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  "$out  ($($final.Width)x$($final.Height))"
  if ($final -ne $bmp) { $final.Dispose() }
  $bmp.Dispose()
}
Draw-Fleet "$root\assets\img\backgrounds\hero-scene-wide.jpg" $ships.desktop "$S\fleet-wide.png" 1200
Draw-Fleet "$root\assets\img\backgrounds\hero-scene-tall.jpg" $ships.mobile "$S\fleet-tall.png" 700
