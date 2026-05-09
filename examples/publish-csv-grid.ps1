Import-Module (Join-Path $PSScriptRoot '..\PSHereNow.psd1') -Force

$sitePath = Join-Path $PSScriptRoot 'csv-grid-site'
$result = Publish-HereNowSite -Path $sitePath -Title 'Pipeline Portfolio Grid' -Show

$result | Format-List Url, Slug, Anonymous, ExpiresAt, ClaimUrl, ClaimFile, FileCount
