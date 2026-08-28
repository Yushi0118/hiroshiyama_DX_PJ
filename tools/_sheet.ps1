$ErrorActionPreference='Stop'; Add-Type -AssemblyName System.Drawing
$root="C:\Users\yushi.hoshiyama\Desktop\Claud連携\hiroshiyama_DX_PJ"
. "$root\tools\preview-deco.ps1"
$S="C:\Users\YUSHI~1.HOS\AppData\Local\Temp\claude\C--Users-yushi-hoshiyama-Desktop-Claud--\0069ab21-c354-4d6d-a1bc-6d68b2e2430a\scratchpad"
$f=@()
$f+=(Get-ChildItem "$root\assets\img\icons\what" -Filter illus-*.png|Sort-Object Name).FullName
$f+=(Get-ChildItem "$root\assets\img\icons\benefit" -Filter illus-*.png|Sort-Object Name).FullName
$f+=(Get-ChildItem "$root\assets\img\icons\flow" -Filter illus-*.png|Sort-Object Name).FullName
New-MultiplySheet -Files $f -Out "$S\sheet-illus.png" -Cols 6 -Cell 230
