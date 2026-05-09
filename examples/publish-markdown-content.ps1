Import-Module (Join-Path $PSScriptRoot '..\PSHereNow.psd1') -Force


$result = @'
## Test

### Hello World
- This is a test of publishing markdown content to HereNow.
- This should be rendered as markdown on the site.
- This is a bullet point.

1. This is a *numbered* list item.
1. This is `another` numbered list item.
1. This is yet **another** numbered list item.
1. This is a [link](https://www.example.com) in a numbered list item.
1. This is a numbered list item with an ***image*** ![alt text](https://www.example.com/image.jpg).

| This is a table | With some content |
|-----------------|------------------|
| Row 1           | This is row 1    |
| Row 2           | This is row 2    | 
| Row 3           | This is row 3    |

'@ | Publish-HereNowSite -Markdown -Title 'Markdown Content'

$result | Format-List Url, Slug, Anonymous, ExpiresAt, ClaimUrl, ClaimFile
