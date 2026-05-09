Import-Module (Join-Path $PSScriptRoot '..\PSHereNow.psd1') -Force

$sitePath = Join-Path $PSScriptRoot 'hello-site'
$result = Publish-HereNowSite -Path $sitePath -Title 'Hello from here.now'

$result | Format-List Url, Slug, Anonymous, ExpiresAt, ClaimUrl, ClaimFile, FileCount
