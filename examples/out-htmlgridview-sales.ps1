Import-Module (Join-Path $PSScriptRoot '..\PSHereNow.psd1') -Force

$salesPath = Join-Path $PSScriptRoot 'sample-sales.csv'
$result = Import-Csv -LiteralPath $salesPath |
    Out-HtmlGridView -Title 'Sales Grid'

$result | Format-List Url, Slug, Anonymous, ExpiresAt, ClaimUrl, ClaimFile, SourceRowCount
