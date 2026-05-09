Import-Module (Join-Path $PSScriptRoot '..\PSHereNow.psd1') -Force

$apiKey = Read-Host 'Paste your here.now API key'
Set-HereNowApiKey -ApiKey $apiKey | Format-List
