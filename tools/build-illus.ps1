<#
  build-illus.ps1 ― 完成イメージから各カードの挿絵を切り出す

  すべて cream→white 正規化済み。クリーム地のカードの上に
  mix-blend-mode:multiply で重ねると、完成イメージと同じ見えになる。
  余白は白＝multiply の中性色なので、多少大きめに切り出しても害がない。
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
. "$root\tools\deco-extract.ps1"

$LP = "C:\Users\yushi.hoshiyama\Desktop\ＬＴＳ\公共\広島県\広島県DX協働モデル事例創出プロジェクト実施業務\LP\全体\完成イメージ"
$WHAT    = "$LP\ChatGPT Image 2026年8月26日 14_01_10 (3).png"   # 本プロジェクトでできること
$BENEFIT = "$LP\ChatGPT Image 2026年8月26日 14_01_11 (4).png"   # 参加事業者にとってのメリット
$FLOW    = "$LP\ChatGPT Image 2026年8月26日 14_01_13 (6).png"   # 進め方

$cWhat    = @(0.060, 0.360, 0.080, 0.030)
$cBenefit = @(0.050, 0.235, 0.100, 0.040)
$cFlow    = @(0.005, 0.005, 0.030, 0.030)

$o = "$root\assets\img\icons"

Write-Output "=== できること（STEP挿絵） ==="
Export-Deco -Src $WHAT -Rect @(0.248,0.452,0.088,0.190) -CreamRect $cWhat -Out "$o\what\illus-1.png" -MaxWidth 420
Export-Deco -Src $WHAT -Rect @(0.546,0.440,0.098,0.225) -CreamRect $cWhat -Out "$o\what\illus-2.png" -MaxWidth 420
Export-Deco -Src $WHAT -Rect @(0.822,0.548,0.124,0.155) -CreamRect $cWhat -Out "$o\what\illus-3.png" -MaxWidth 460

Write-Output ""
Write-Output "=== メリット（5枚） ==="
Export-Deco -Src $BENEFIT -Rect @(0.056,0.478,0.150,0.148) -CreamRect $cBenefit -Out "$o\benefit\illus-1.png" -MaxWidth 400
Export-Deco -Src $BENEFIT -Rect @(0.246,0.478,0.150,0.148) -CreamRect $cBenefit -Out "$o\benefit\illus-2.png" -MaxWidth 400
Export-Deco -Src $BENEFIT -Rect @(0.436,0.478,0.150,0.148) -CreamRect $cBenefit -Out "$o\benefit\illus-3.png" -MaxWidth 400
Export-Deco -Src $BENEFIT -Rect @(0.626,0.478,0.150,0.148) -CreamRect $cBenefit -Out "$o\benefit\illus-4.png" -MaxWidth 400
Export-Deco -Src $BENEFIT -Rect @(0.816,0.478,0.150,0.148) -CreamRect $cBenefit -Out "$o\benefit\illus-5.png" -MaxWidth 400

Write-Output ""
Write-Output "=== 進め方（3ステップ） ==="
Export-Deco -Src $FLOW -Rect @(0.075,0.568,0.170,0.190) -CreamRect $cFlow -Out "$o\flow\illus-1.png" -MaxWidth 420
Export-Deco -Src $FLOW -Rect @(0.400,0.565,0.200,0.195) -CreamRect $cFlow -Out "$o\flow\illus-2.png" -MaxWidth 460
Export-Deco -Src $FLOW -Rect @(0.700,0.565,0.190,0.195) -CreamRect $cFlow -Out "$o\flow\illus-3.png" -MaxWidth 460

Write-Output ""
Get-ChildItem "$o\what","$o\benefit","$o\flow" -Filter illus-*.png | ForEach-Object { "{0,-14} {1,-14} {2,6} KB" -f $_.Directory.Name, $_.Name, [math]::Round($_.Length/1KB) }
