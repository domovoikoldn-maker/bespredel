# Скачивает и раскладывает ядра для Windows в папку $Out (рядом с .exe приложения):
#   bp-xray.exe                — Xray-core
#   zapret\bin\winws.exe       — zapret из Flowseal/zapret-discord-youtube (+ WinDivert, cygwin1.dll, *.bin)
#   zapret\lists\*.txt         — хостлисты Flowseal + наши дополнительные домены
#   zapret\strategies.json     — все стратегии Flowseal (general, ALT..ALT13, FAKE TLS, SIMPLE FAKE)
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

Write-Host '== zapret (Flowseal) =='
git clone --depth 1 https://github.com/Flowseal/zapret-discord-youtube "$tmp\fs"
$z = Join-Path $Out 'zapret'
if (Test-Path $z) { Remove-Item $z -Recurse -Force }
New-Item -ItemType Directory -Force "$z\bin", "$z\lists" | Out-Null
Copy-Item "$tmp\fs\bin\*" "$z\bin\" -Recurse -Force
Copy-Item "$tmp\fs\lists\*.txt" "$z\lists\" -Force
foreach ($f in 'list-general-user.txt', 'list-exclude-user.txt', 'ipset-exclude-user.txt') {
  $p = Join-Path "$z\lists" $f
  if (-not (Test-Path $p)) { New-Item -ItemType File $p | Out-Null }
}
# Наши дополнительные домены (Instagram, X и т.д.) — в пользовательский список
$extra = Join-Path $PSScriptRoot '..\cores\zapret-lists\list-general.txt'
if (Test-Path $extra) {
  Get-Content $extra | Add-Content (Join-Path "$z\lists" 'list-general-user.txt')
}
python "$PSScriptRoot\zapret_strategies.py" "$tmp\fs" "$z\strategies.json"
if ($LASTEXITCODE -ne 0) { throw 'не удалось сконвертировать стратегии' }
if (-not (Test-Path "$z\bin\winws.exe")) { throw 'winws.exe не найден' }

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem $Out -Recurse | Select-Object -First 60 | Format-Table FullName, Length
