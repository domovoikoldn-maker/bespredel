# Скачивает и раскладывает ядра для Windows в папку $Out (рядом с .exe приложения):
#   bp-xray.exe          — Xray-core
#   zapret\winws.exe     — zapret (из bol-van/zapret-win-bundle) + WinDivert
#   zapret\files\*.bin   — фейковые пакеты для стратегий
#   zapret\lists\*.txt   — хостлисты
# bp-ciadpi.exe (ByeDPI) собирается отдельным шагом в MSYS2.
param([Parameter(Mandatory = $true)][string]$Out)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('bp-cores-' + [guid]::NewGuid())
New-Item -ItemType Directory -Force $tmp, $Out | Out-Null

Write-Host '== Xray-core =='
Invoke-WebRequest 'https://github.com/XTLS/Xray-core/releases/latest/download/Xray-windows-64.zip' -OutFile "$tmp\xray.zip"
Expand-Archive "$tmp\xray.zip" "$tmp\xray" -Force
Copy-Item "$tmp\xray\xray.exe" (Join-Path $Out 'bp-xray.exe') -Force

Write-Host '== zapret (winws) =='
git clone --depth 1 https://github.com/bol-van/zapret-win-bundle "$tmp\zwb"
$z = Join-Path $Out 'zapret'
New-Item -ItemType Directory -Force $z, "$z\files", "$z\lists" | Out-Null
Copy-Item "$tmp\zwb\zapret-winws\*" $z -Recurse -Force
Get-ChildItem "$tmp\zwb" -Recurse -Filter *.bin | ForEach-Object {
  $dst = Join-Path "$z\files" $_.Name
  if (-not (Test-Path $dst)) { Copy-Item $_.FullName $dst }
}
Copy-Item (Join-Path $PSScriptRoot '..\cores\zapret-lists\*') "$z\lists\" -Force
if (-not (Test-Path "$z\winws.exe")) { throw 'winws.exe не найден в zapret-win-bundle' }

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem $Out -Recurse | Select-Object -First 40 | Format-Table FullName, Length
