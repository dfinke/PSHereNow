Import-Module (Join-Path $PSScriptRoot '..\PSHereNow.psd1') -Force

$result = Publish-HereNowSite -Path (Join-Path $PSScriptRoot 'hello-site\index.html')

$result | Format-List Url, Slug, Anonymous, ExpiresAt, ClaimUrl, ClaimFile
