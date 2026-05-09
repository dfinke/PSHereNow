# PSHereNow

PowerShell helpers for publishing static files and folders to [here.now](https://here.now/docs).

## Load the module

From this directory:

```powershell
Import-Module .\PSHereNow.psd1 -Force
```

Optional, for permanent authenticated sites:

```powershell
Set-HereNowApiKey 'hn_live_...'
```

`Publish-HereNowSite` also reads API keys from:

1. `-ApiKey`
2. `$env:HERENOW_API_KEY`
3. `$env:HERE_NOW_API_KEY`
4. `~/.herenow/credentials`

If no API key is found, it publishes anonymously. Anonymous sites expire after 24 hours. The module saves the one-time claim URL to `.herenow/<slug>.claim.json` by default.
This repo ignores `.herenow/` folders so claim tokens do not accidentally get committed.

## Publish

Publish a single file:

```powershell
Publish-HereNowSite .\examples\hello-site\index.html
```

Publish a directory:

```powershell
Publish-HereNowSite .\examples\hello-site
```

Publish and open the site in your default browser:

```powershell
Publish-HereNowSite .\examples\hello-site -Show
```

Use the short alias:

```powershell
Publish-HereNow .\examples\hello-site
```

Publish a single-page app build:

```powershell
Publish-HereNowSite .\dist -Spa
```

Update an existing site:

```powershell
Publish-HereNowSite .\dist -Slug bright-canvas-a7k2 -Spa
```

Update an anonymous site:

```powershell
Publish-HereNowSite .\dist -Slug bright-canvas-a7k2 -ClaimToken 'abc123...' -Spa
```

Pipe text into an `index.html` publish:

```powershell
Get-Content .\examples\hello-site\index.html -Raw | Publish-HereNowSite
```

Pipe text and choose the remote filename:

```powershell
Get-Content .\examples\hello-site\style.css -Raw | Publish-HereNowSite -FileName style.css
```

Pipe Markdown text and render it as a published Markdown page:

```powershell
Get-Content .\README.md -Raw | Publish-HereNowSite -Markdown -Title 'README'
```

`-Markdown` renders piped text into an HTML page before publishing, so it does not depend on the remote filename ending in `.md`.

Pipe files from `Get-ChildItem` and choose the site root:

```powershell
Get-ChildItem .\examples\hello-site -Recurse -File | Publish-HereNowSite -Root .\examples\hello-site
```

Publish the richer CSV grid example:

```powershell
.\examples\publish-csv-grid.ps1
```

Or publish it directly:

```powershell
Publish-HereNowSite .\examples\csv-grid-site -Title 'Pipeline Portfolio Grid' -Show
```

Publish PowerShell objects as an interactive HTML grid:

```powershell
Import-Csv .\examples\sample-sales.csv | Out-HtmlGridView -Title 'Sales Grid'
```

With the `ImportExcel` module:

```powershell
Import-Excel D:\sales.xlsx | Out-HtmlGridView -Title 'Sales Grid'
```

`Out-HtmlGridView` converts the input objects to CSV, embeds that CSV in a single HTML file, publishes it to here.now, and opens the published URL by default. Use `-NoShow` when you only want the returned publish object.

```powershell
$site = Import-Csv D:\sales.csv | Out-HtmlGridView -Title 'Sales Grid' -NoShow
$site.Url
```

Preview the manifest without publishing:

```powershell
Publish-HereNowSite .\examples\hello-site -WhatIf
```

## Output

The publish command returns an object with useful fields:

```powershell
$site = Publish-HereNowSite .\examples\hello-site
$site.Url
$site.Slug
$site.ClaimUrl
$site.ClaimFile
```

For anonymous publishes, save `$site.ClaimUrl` or the generated claim file. here.now only returns the claim token once.
