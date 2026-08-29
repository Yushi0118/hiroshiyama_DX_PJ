<#
  build-creatures.ps1 ― 生成された生き物イラストを配置用に整える

  元画像は既に透過済みなので、切り抜きは不要。やることは2つ。
    1. 縁に写り込んだ別の生き物の断片を消す（Erase で矩形を透明にする）
    2. 表示に必要な範囲だけを切り出し、余白を詰めて縮小する

  余白を詰めるのは重要。1024四方のうち被写体が中央の半分しか無いと、
  CSS で幅を指定しても実際に見える大きさが半分になり、
  「指定したのに小さい」という食い違いが起きる。
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Build-Creature {
  param(
    [string]$Src,
    [string]$Out,
    [array]$Erase = @(),        # 透明にする矩形の配列（各要素が x,y,w,h の分数座標）
    [int]$MaxWidth = 760,
    [int]$Pad = 6               # 自動トリム後に残す余白（px）
  )
  $img = [System.Drawing.Bitmap]::FromFile($Src)
  try {
    $w = $img.Width; $h = $img.Height
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($img, 0, 0, $w, $h)
    $g.Dispose()

    $rect = New-Object System.Drawing.Rectangle(0,0,$w,$h)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $len = $data.Stride * $h
    $buf = New-Object byte[] $len
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buf, 0, $len)

    # 1) 指定矩形を透明にする
    foreach ($e in $Erase) {
      $ex = [int]($e[0]*$w); $ey = [int]($e[1]*$h)
      $ew = [int]($e[2]*$w); $eh = [int]($e[3]*$h)
      for ($y = $ey; $y -lt [math]::Min($ey+$eh, $h); $y++) {
        for ($x = $ex; $x -lt [math]::Min($ex+$ew, $w); $x++) {
          $p = $y * $data.Stride + $x * 4
          $buf[$p] = 0; $buf[$p+1] = 0; $buf[$p+2] = 0; $buf[$p+3] = 0
        }
      }
    }

    # 2) 不透明な画素の外接矩形を求める（余白を詰める）
    $minX = $w; $minY = $h; $maxX = -1; $maxY = -1
    for ($y = 0; $y -lt $h; $y++) {
      $row = $y * $data.Stride
      for ($x = 0; $x -lt $w; $x++) {
        if ($buf[$row + $x*4 + 3] -gt 12) {
          if ($x -lt $minX) { $minX = $x }
          if ($x -gt $maxX) { $maxX = $x }
          if ($y -lt $minY) { $minY = $y }
          if ($y -gt $maxY) { $maxY = $y }
        }
      }
    }
    [System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $data.Scan0, $len)
    $bmp.UnlockBits($data)

    if ($maxX -lt 0) { throw "不透明な画素がありません: $Src" }
    $minX = [math]::Max(0, $minX - $Pad); $minY = [math]::Max(0, $minY - $Pad)
    $maxX = [math]::Min($w-1, $maxX + $Pad); $maxY = [math]::Min($h-1, $maxY + $Pad)
    $cw = $maxX - $minX + 1; $ch = $maxY - $minY + 1

    $nw = [math]::Min($MaxWidth, $cw); $nh = [int][math]::Round($ch * $nw / $cw)
    $final = New-Object System.Drawing.Bitmap($nw, $nh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g2 = [System.Drawing.Graphics]::FromImage($final)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0,0,$nw,$nh)),
                        (New-Object System.Drawing.Rectangle($minX,$minY,$cw,$ch)),
                        [System.Drawing.GraphicsUnit]::Pixel)
    $g2.Dispose()

    $dir = Split-Path $Out -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $final.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
    "{0,-20} {1,4}x{2,-4} (元 {3}x{4} から余白を除去)  {5,4} KB" -f (Split-Path $Out -Leaf), $nw, $nh, $w, $h, [math]::Round((Get-Item $Out).Length/1KB)
    $final.Dispose(); $bmp.Dispose()
  } finally { $img.Dispose() }
}

$dl   = "C:\Users\yushi.hoshiyama\Downloads"
$zip  = "$dl\marine_assets_6png"
$root = Split-Path $PSScriptRoot -Parent
$out  = "$root\assets\img\creatures"

# 縁の写り込みは、元画像を目視して座標を決めた（tools/grid-overlay.ps1 で確認）
Build-Creature -Src "$dl\fish-school-1.png" -Out "$out\fish-school-1.png" -MaxWidth 760
Build-Creature -Src "$dl\fish-school-2.png" -Out "$out\fish-school-2.png" -MaxWidth 760
Build-Creature -Src "$zip\coral.png"        -Out "$out\coral.png"        -MaxWidth 700 `
  -Erase @(@(0.00,0.00,0.14,1.00), @(0.82,0.00,0.18,1.00))
Build-Creature -Src "$zip\fish-large.png"   -Out "$out\fish-large.png"   -MaxWidth 700 `
  -Erase @(,@(0.00,0.73,1.00,0.27))   # 下辺の薄い写り込み2つ
Build-Creature -Src "$zip\jelly-1.png"      -Out "$out\jelly-1.png"      -MaxWidth 520
Build-Creature -Src "$zip\jelly-2.png"      -Out "$out\jelly-2.png"      -MaxWidth 520 `
  -Erase @(@(0.69,0.00,0.31,1.00), @(0.50,0.00,0.20,0.10))   # 右の珊瑚と上の点
Build-Creature -Src "$zip\seaweed.png"      -Out "$out\seaweed.png"      -MaxWidth 460 `
  -Erase @(,@(0.28,0.50,0.115,0.50))
Build-Creature -Src "$zip\turtle.png"       -Out "$out\turtle.png"       -MaxWidth 640 `
  -Erase @(,@(0.93,0.00,0.07,1.00))
