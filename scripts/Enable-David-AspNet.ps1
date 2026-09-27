$ErrorActionPreference = "Stop"
$log = "C:\grok\logs\david-enable-aspnet.txt"
"START $(Get-Date -Format o)" | Out-File $log
$appcmd = "$env:windir\system32\inetsrv\appcmd.exe"
& $appcmd set apppool /apppool.name:"davidunderwood.net" /managedRuntimeVersion:v4.0 /managedPipelineMode:Integrated 2>&1 | Out-File $log -Append
& $appcmd set apppool /apppool.name:"davidunderwood.net" /enable32BitAppOnWin64:false 2>&1 | Out-File $log -Append
& $appcmd start apppool /apppool.name:"davidunderwood.net" 2>&1 | Out-File $log -Append
& $appcmd list apppool /name:"davidunderwood.net" 2>&1 | Out-File $log -Append
# Ensure App_Data exists + writable
$dest = "F:\website\davidunderwood.net\App_Data"
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
cacls "F:\website\davidunderwood.net" /t /e /g Everyone:f | Out-Null
"DONE $(Get-Date -Format o)" | Out-File $log -Append
Get-Content $log
