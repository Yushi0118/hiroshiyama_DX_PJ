$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-MultiplySheet {
  param([string[]]$Files, [string]$Out, [int]$Cols = 4, [int]$Cell = 300, [string]$CreamHex = '#FAF5EA')
  $cream = [System.Drawing.ColorTranslator]::FromHtml($CreamHex)
  $rows  = [math]::Ceiling($Files.Count / $Cols)
  $pad = 12; $lab = 20
  $sheet = New-Object System.Drawing.Bitmap(($Cols*($Cell+$pad)+$pad), ($rows*($Cell+$pad+$lab)+$pad))
  $g = [System.Drawing.Graphics]::FromImage($sheet)
  $g.Clear($cream)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $cm = New-Object System.Drawing.Imaging.ColorMatrix
  $cm.Matrix00 = $cream.R/255.0; $cm.Matrix11 = $cream.G/255.0; $cm.Matrix22 = $cream.B/255.0; $cm.Matrix33 = 1.0; $cm.Matrix44 = 1.0
  $ia = New-Object System.Drawing.Imaging.ImageAttributes
  $ia.SetColorMatrix($cm)
  $font  = New-Object System.Drawing.Font('Consolas', 10)
  $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30,40,70))
  $pen   = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70,180,150,80))
  for ($i=0; $i -lt $Files.Count; $i++) {
    $c = $i % $Cols; $r = [math]::Floor($i / $Cols)
    $cx = $pad + $c*($Cell+$pad); $cy = $pad + $r*($Cell+$pad+$lab)
    $img = [System.Drawing.Image]::FromFile($Files[$i])
    $sc = [math]::Min($Cell/$img.Width, $Cell/$img.Height)
    $dw = [int]($img.Width*$sc); $dh = [int]($img.Height*$sc)
    $dx = [int]($cx + ($Cell-$dw)/2); $dy = [int]($cy + ($Cell-$dh)/2)
    $dest = New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)
    $g.DrawImage($img, $dest, 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g.DrawRectangle($pen, $cx, $cy, $Cell, $Cell)
    $g.DrawString((Split-Path $Files[$i] -Leaf), $font, $brush, $cx, ($cy+$Cell+2))
    $img.Dispose()
  }
  $g.Dispose()
  $sheet.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $sheet.Dispose()
  "sheet: $Out"
}

$deco = Join-Path (Split-Path $PSScriptRoot -Parent) 'assetsimgdeco'
$S = Join-Path (Split-Path $PSScriptRoot -Parent) '.preview'
if (-not (Test-Path $S)) { New-Item -ItemType Directory -Force -Path $S | Out-Null }
$files = Get-ChildItem $deco -Filter *.png | Sort-Object Name | Select-Object -ExpandProperty FullName
New-MultiplySheet -Files $files -Out "$S\sheet-deco.png" -Cols 4 -Cell 300
