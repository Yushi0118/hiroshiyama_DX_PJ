<#
  build-deco.ps1 ― 装飾部品ライブラリと ヒーロー海景を生成する

  出力先: assets/img/deco/
  すべての部品は cream→white 正規化済みなので、CSS 側では
    mix-blend-mode: multiply
  で重ねることを前提とする。
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
. "$root\tools\deco-extract.ps1"
. "$root\tools\deco-repair.ps1"

$LP  = "C:\Users\yushi.hoshiyama\Desktop\ＬＴＳ\公共\広島県\広島県DX協働モデル事例創出プロジェクト実施業務\LP"
$S4  = "$LP\全体\完成イメージ\ChatGPT Image 2026年8月26日 14_01_11 (4).png"   # メリット   1491x1055
$S5  = "$LP\全体\完成イメージ\ChatGPT Image 2026年8月26日 14_01_12 (5).png"   # 募集テーマ 1491x1055
$S6  = "$LP\全体\完成イメージ\ChatGPT Image 2026年8月26日 14_01_13 (6).png"   # 進め方     1491x1055
$S7  = "$LP\全体\完成イメージ\ChatGPT Image 2026年8月26日 14_01_13 (7).png"   # 支援体制   1055x1491
$HW  = "$LP\背景画像\ChatGPT Image 2026年8月26日 13_11_05.png"                 # PCヒーロー 1672x941
$HT  = "$LP\背景画像\ChatGPT Image 2026年8月27日 15_25_51.png"                 # SPヒーロー  941x1672
$out = "$root\assets\img\deco"

# 各元画像で「純粋なクリーム紙」の矩形（ここの平均色を白に正規化する）
$c4 = @(0.05, 0.235, 0.10, 0.040)
$c6 = @(0.005, 0.005, 0.030, 0.030)
$c7 = @(0.040, 0.200, 0.060, 0.025)
$cW = @(0.200, 0.450, 0.100, 0.080)
$cT = @(0.150, 0.300, 0.120, 0.060)

Write-Output "=== 装飾部品 ==="

# --- メリット(4) 由来 ---
Export-Deco -Src $S4 -Rect @(0.55,0.00,0.45,0.31)  -CreamRect $c4 -Out "$out\deco-sea-bridge.jpg"    -MaxWidth 900
Export-Deco -Src $S4 -Rect @(0.00,0.775,1.00,0.225) -CreamRect $c4 -Out "$out\deco-band-bottom.jpg"   -MaxWidth 1400
Export-Deco -Src $S4 -Rect @(0.00,0.750,0.17,0.250) -CreamRect $c4 -Out "$out\deco-lighthouse-sm.jpg" -MaxWidth 420
Export-Deco -Src $S4 -Rect @(0.855,0.830,0.145,0.170) -CreamRect $c4 -Out "$out\deco-leaves-a.jpg"    -MaxWidth 420
Export-Deco -Src $S4 -Rect @(0.578,0.088,0.095,0.145) -CreamRect $c4 -Out "$out\deco-sailboat.jpg"    -MaxWidth 320

# --- 進め方(6) 由来 ---
Export-Deco -Src $S6 -Rect @(0.745,0.030,0.220,0.280) -CreamRect $c6 -Out "$out\deco-compass.jpg"     -MaxWidth 460
Export-Deco -Src $S6 -Rect @(0.505,0.000,0.240,0.450) -CreamRect $c6 -Out "$out\deco-wave-diag.jpg"   -MaxWidth 560
Export-Deco -Src $S6 -Rect @(0.000,0.895,1.000,0.105) -CreamRect $c6 -Out "$out\deco-band-wave.jpg"   -MaxWidth 1400

# --- 募集テーマ(5) 由来 ---
Export-Deco -Src $S5 -Rect @(0.550,0.000,0.450,0.340) -CreamRect $c4 -Out "$out\deco-wave-sweep.jpg"  -MaxWidth 900

# --- 支援体制(7) 由来 ---
Export-Deco -Src $S7 -Rect @(0.000,0.205,0.145,0.395) -CreamRect $c7 -Out "$out\deco-lighthouse-tall.jpg" -MaxWidth 340
Export-Deco -Src $S7 -Rect @(0.700,0.085,0.300,0.225) -CreamRect $c7 -Out "$out\deco-bridge-coast.jpg"    -MaxWidth 560
Export-Deco -Src $S7 -Rect @(0.898,0.755,0.062,0.170) -CreamRect $c7 -Out "$out\deco-leaves-vine.jpg"     -MaxWidth 260
Export-Deco -Src $S7 -Rect @(0.045,0.695,0.160,0.200) -CreamRect $c7 -Out "$out\deco-lighthouse-lg.jpg"   -MaxWidth 400
Export-Deco -Src $S7 -Rect @(0.120,0.195,0.190,0.058) -CreamRect $c7 -Out "$out\deco-seagulls.jpg"        -MaxWidth 320
Export-Deco -Src $S7 -Rect @(0.000,0.935,1.000,0.065) -CreamRect $c7 -Out "$out\deco-band-sea.jpg"        -MaxWidth 1200

# --- ヒーロー画像 由来 ---
Export-Deco -Src $HW -Rect @(0.000,0.000,0.120,0.320) -CreamRect $cW -Out "$out\deco-leaves-b.jpg"    -MaxWidth 340
Export-Deco -Src $HW -Rect @(0.540,0.000,0.420,0.170) -CreamRect $cW -Out "$out\deco-network.jpg"     -MaxWidth 800
Export-Deco -Src $HT -Rect @(0.020,0.690,0.500,0.130) -CreamRect $cT -Out "$out\deco-landmarks.jpg"   -MaxWidth 700

# 紙の粒は style.css の --paper-grain（SVGのfeTurbulence）で描くため、
# ラスタのタイルは生成しない（ミラータイルでは格子状の折り目が見えた）。

Write-Output ""
Write-Output "=== ヒーロー海景（焼き込みの業種ヘキサゴンを除去） ==="

# PC: ヘキサゴンは y .858 以下にしか無いため、修復せず帯ごと切り落とす。
#     ランドマーク（原爆ドーム・鳥居・広島城）は y .846 までなので残る。
Export-Deco -Src $HW -Rect @(0.000,0.000,1.000,0.858) -NoNormalize `
  -Out "$root\assets\img\backgrounds\hero-scene-wide.jpg" -MaxWidth 1600

# SP: ヘキサゴンは x .05-.52 / y .852-.915。真下の海面を上下反転して被せる
#     （水面の反射として読めるので、単純な平行コピーより継ぎ目が目立たない）
Save-Repaired -Src $HT -Out "$root\assets\img\backgrounds\hero-scene-tall.jpg" -Quality 88 -Repairs @(
  @{ Target=@(0.040,0.848,0.500,0.070); Source=@(0.040,0.918,0.500,0.070); Feather=22; MirrorY=$true }
)

Write-Output ""
Write-Output "=== 生成物一覧 ==="
Get-ChildItem $out -File | Sort-Object Name | ForEach-Object { "{0,-28} {1,7} KB" -f $_.Name, [math]::Round($_.Length/1KB) }
Get-ChildItem "$root\assets\img\backgrounds" -Filter "hero-scene-*" | ForEach-Object { "{0,-28} {1,7} KB" -f $_.Name, [math]::Round($_.Length/1KB) }
