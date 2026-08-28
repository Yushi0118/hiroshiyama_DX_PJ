# grid-overlay.ps1 ― 元画像に 10% 刻みのグリッドと座標ラベルを重ねて保存する
Add-Type -AssemblyName System.Drawing
function New-GridOverlay {
  param([string]$Src, [string]$Out, [int]$MaxWidth = 1100)
  $img = [System.Drawing.Bitmap]::FromFile($Src)
  try {
    $w = $img.Width; $h = $img.Height
    $sc = if ($w -gt $MaxWidth) { $MaxWidth / $w } else { 1.0 }
    $nw = [int]($w * $sc); $nh = [int]($h * $sc)
    $bmp = New-Object System.Drawing.Bitmap($nw, $nh)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, 0, 0, $nw, $nh)
    $penMinor = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(90, 220, 40, 40)), 1
    $penMajor = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 220, 20, 20)), 2
    $font = New-Object System.Drawing.Font('Consolas', 13, [System.Drawing.FontStyle]::Bold)
    $back = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210, 255, 255, 255))
    $fore = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 200, 0, 0))
    for ($i = 1; $i -lt 20; $i++) {
      $f = $i / 20.0
      $p = if ($i % 2 -eq 0) { $penMajor[0] } else { $penMinor[0] }
      $g.DrawLine($p, [int]($f * $nw), 0, [int]($f * $nw), $nh)
      $g.DrawLine($p, 0, [int]($f * $nh), $nw, [int]($f * $nh))
    }
    for ($i = 1; $i -lt 10; $i++) {
      $f = $i / 10.0
      $tx = "$([int]($f*100))"
      $g.FillRectangle($back, [int]($f * $nw) - 15, 2, 30, 19)
      $g.DrawString($tx, $font, $fore, [int]($f * $nw) - 15, 2)
      $g.FillRectangle($back, 2, [int]($f * $nh) - 10, 30, 19)
      $g.DrawString($tx, $font, $fore, 2, [int]($f * $nh) - 10)
    }
    $g.Dispose()
    $dir = Split-Path $Out -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    "grid: $Out ($nw x $nh, source $w x $h)"
  } finally { $img.Dispose() }
}
