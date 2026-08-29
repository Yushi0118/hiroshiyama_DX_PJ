<#
  build-hero.ps1 ― ヒーローの船団画像を切り出す

  完成イメージ(1) の右側には船団が描かれており、文字は左側にしか無い。
  そこで右側だけを切り出せば「文字の入っていない船団の絵」が得られる。
  左端はマスクで消して、紙の余白へ溶け込ませる前提。
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$cfg = Join-Path $PSScriptRoot 'config.local.ps1'
if (-not (Test-Path $cfg)) { throw "tools/config.local.ps1 がありません。" }
. $cfg

$root = Split-Path $PSScriptRoot -Parent
$src  = Join-Path $LP_ROOT '全体\完成イメージ\ChatGPT Image 2026年8月26日 14_01_09 (1).png'
if (-not (Test-Path $src)) { throw "元画像が見つかりません: $src" }

function Save-Crop {
  param([string]$Src, [double[]]$Rect, [string]$Out, [int]$MaxWidth)
  $img = [System.Drawing.Bitmap]::FromFile($Src)
  try {
    $x = [int]($Rect[0]*$img.Width); $y = [int]($Rect[1]*$img.Height)
    $w = [int]($Rect[2]*$img.Width); $h = [int]($Rect[3]*$img.Height)
    $nw = [math]::Min($MaxWidth, $w); $nh = [int][math]::Round($h * $nw / $w)
    $bmp = New-Object System.Drawing.Bitmap($nw, $nh, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0,0,$nw,$nh)),
                       (New-Object System.Drawing.Rectangle($x,$y,$w,$h)),
                       [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ps = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $ps.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 88L)
    $bmp.Save($Out, $enc, $ps)
    "{0,-24} {1}x{2}  {3} KB" -f (Split-Path $Out -Leaf), $nw, $nh, [math]::Round((Get-Item $Out).Length/1KB)
    $bmp.Dispose()
  } finally { $img.Dispose() }
}

# 横長：右側の船団。見出しは x=0.513 まで伸びているので 0.525 から取る
Save-Crop -Src $src -Rect @(0.525,0.00,0.475,1.00) -Out "$root\assets\img\backgrounds\hero-fleet-wide.jpg" -MaxWidth 900
# 縦長：手前の大きな船を中心に、縦構図で切る
Save-Crop -Src $src -Rect @(0.560,0.16,0.440,0.84) -Out "$root\assets\img\backgrounds\hero-fleet-tall.jpg" -MaxWidth 760
