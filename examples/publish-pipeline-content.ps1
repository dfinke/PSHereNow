Import-Module (Join-Path $PSScriptRoot '..\PSHereNow.psd1') -Force

$indexPath = Join-Path $PSScriptRoot 'hello-site\index.html'
$result = Get-Content -LiteralPath $indexPath -Raw | Publish-HereNowSite

$result | Format-List Url, Slug, Anonymous, ExpiresAt, ClaimUrl, ClaimFile
