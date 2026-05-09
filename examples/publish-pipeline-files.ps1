Import-Module (Join-Path $PSScriptRoot '..\PSHereNow.psd1') -Force

$sitePath = Join-Path $PSScriptRoot 'hello-site'
$result = Get-ChildItem -LiteralPath $sitePath -Recurse -File |
    Publish-HereNowSite -Root $sitePath -Title 'Hello from here.now'

$result | Format-List Url, Slug, Anonymous, ExpiresAt, ClaimUrl, ClaimFile, FileCount
