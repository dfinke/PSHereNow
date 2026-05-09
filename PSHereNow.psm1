Set-StrictMode -Version Latest

function Get-HereNowCredentialPath {
    [CmdletBinding()]
    param()

    Join-Path -Path $HOME -ChildPath '.herenow/credentials'
}

function Get-HereNowApiKey {
    [CmdletBinding()]
    param(
        [string] $ApiKey,
        [switch] $NoCredentialFile
    )

    if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
        return $ApiKey.Trim()
    }

    foreach ($name in @('HERENOW_API_KEY', 'HERE_NOW_API_KEY')) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
    }

    if (-not $NoCredentialFile) {
        $path = Get-HereNowCredentialPath
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $value = Get-Content -LiteralPath $path -Raw
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return $value.Trim()
            }
        }
    }

    $null
}

function Set-HereNowApiKey {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $ApiKey,

        [string] $Path = (Get-HereNowCredentialPath)
    )

    process {
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $directory = Split-Path -Path $resolvedPath -Parent

        if ($PSCmdlet.ShouldProcess($resolvedPath, 'Save here.now API key')) {
            if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }

            Set-Content -LiteralPath $resolvedPath -Value $ApiKey.Trim() -NoNewline -Encoding utf8

            [pscustomobject]@{
                Path = $resolvedPath
            }
        }
    }
}

function Get-HereNowContentType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $contentTypes = @{
        '.aac'   = 'audio/aac'
        '.avi'   = 'video/x-msvideo'
        '.avif'  = 'image/avif'
        '.bin'   = 'application/octet-stream'
        '.bmp'   = 'image/bmp'
        '.css'   = 'text/css; charset=utf-8'
        '.csv'   = 'text/csv; charset=utf-8'
        '.gif'   = 'image/gif'
        '.htm'   = 'text/html; charset=utf-8'
        '.html'  = 'text/html; charset=utf-8'
        '.ico'   = 'image/x-icon'
        '.jpeg'  = 'image/jpeg'
        '.jpg'   = 'image/jpeg'
        '.js'    = 'text/javascript; charset=utf-8'
        '.json'  = 'application/json; charset=utf-8'
        '.map'   = 'application/json; charset=utf-8'
        '.md'    = 'text/markdown; charset=utf-8'
        '.mjs'   = 'text/javascript; charset=utf-8'
        '.mp3'   = 'audio/mpeg'
        '.mp4'   = 'video/mp4'
        '.oga'   = 'audio/ogg'
        '.ogg'   = 'audio/ogg'
        '.ogv'   = 'video/ogg'
        '.pdf'   = 'application/pdf'
        '.png'   = 'image/png'
        '.svg'   = 'image/svg+xml'
        '.txt'   = 'text/plain; charset=utf-8'
        '.wasm'  = 'application/wasm'
        '.wav'   = 'audio/wav'
        '.webm'  = 'video/webm'
        '.webp'  = 'image/webp'
        '.woff'  = 'font/woff'
        '.woff2' = 'font/woff2'
        '.xml'   = 'application/xml; charset=utf-8'
    }

    if ($contentTypes.ContainsKey($extension)) {
        return $contentTypes[$extension]
    }

    'application/octet-stream'
}

function Get-HereNowSha256Hex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $hashBytes = $sha256.ComputeHash($stream)
            return ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
        }
        finally {
            $stream.Dispose()
        }
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-HereNowSha256HexFromBytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [byte[]] $Bytes
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha256.ComputeHash($Bytes)
        return ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function ConvertTo-HereNowSitePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Root
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $pathFull = [System.IO.Path]::GetFullPath($Path)

    if (-not $pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "File '$pathFull' is not under root '$rootFull'. Pass -Root to choose the site root."
    }

    $relative = $pathFull.Substring($rootFull.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $sitePath = $relative -replace '\\', '/'

    if ([string]::IsNullOrWhiteSpace($sitePath) -or $sitePath.Contains('..')) {
        throw "Invalid site path '$sitePath' for '$pathFull'."
    }

    $sitePath
}

function Get-HereNowCommonRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $FilePaths
    )

    if ($FilePaths.Count -eq 1) {
        return (Split-Path -Path $FilePaths[0] -Parent)
    }

    $directories = foreach ($filePath in $FilePaths) {
        [System.IO.Path]::GetFullPath((Split-Path -Path $filePath -Parent)).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    }

    $splitDirectories = foreach ($directory in $directories) {
        $directory -split '[\\/]'
    }

    $commonParts = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $true; $index++) {
        if (($splitDirectories | Where-Object { $_.Count -le $index }).Count -gt 0) {
            break
        }

        $candidate = $splitDirectories[0][$index]
        if (($splitDirectories | Where-Object { $_[$index] -ne $candidate }).Count -gt 0) {
            break
        }

        $commonParts.Add($candidate)
    }

    if ($commonParts.Count -eq 0) {
        return (Get-Location).ProviderPath
    }

    ($commonParts -join [System.IO.Path]::DirectorySeparatorChar)
}

function ConvertTo-HereNowHeaderTable {
    [CmdletBinding()]
    param(
        [object] $Headers
    )

    $table = @{}
    if ($null -eq $Headers) {
        return $table
    }

    foreach ($property in $Headers.PSObject.Properties) {
        $table[$property.Name] = [string] $property.Value
    }

    $table
}

function Get-HereNowPropertyValue {
    [CmdletBinding()]
    param(
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string] $Name,

        [object] $Default = $null
    )

    if ($null -eq $InputObject) {
        return $Default
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }

    $property.Value
}

function ConvertTo-HereNowHtmlEncoded {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value
    )

    [System.Net.WebUtility]::HtmlEncode([string] $Value)
}

function ConvertTo-HereNowJsonLiteral {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value
    )

    $Value | ConvertTo-Json -Depth 20 -Compress
}

function New-HereNowHtmlGridDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $CsvText,

        [string] $Title = 'PowerShell Grid View'
    )

    $csvBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($CsvText))
    $titleHtml = ConvertTo-HereNowHtmlEncoded -Value $Title
    $titleJson = ConvertTo-HereNowJsonLiteral -Value $Title
    $generatedJson = ConvertTo-HereNowJsonLiteral -Value ((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC'))

    $template = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>__TITLE_HTML__</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/tabulator/6.3.1/css/tabulator.min.css">
  <style>
    :root {
      color-scheme: light;
      --ink: #17211d;
      --muted: #61706a;
      --line: #d7e0db;
      --surface: #ffffff;
      --wash: #f1f5f2;
      --accent: #126b5d;
      --accent-strong: #0b5147;
      --blue: #245c9f;
      --amber: #a15e00;
      font-family: "Segoe UI", system-ui, sans-serif;
      background: var(--wash);
      color: var(--ink);
    }

    * {
      box-sizing: border-box;
    }

    body {
      min-height: 100vh;
      margin: 0;
      background:
        linear-gradient(180deg, rgba(255, 255, 255, 0.86), rgba(241, 245, 242, 0.98)),
        radial-gradient(circle at 12% 0%, rgba(18, 107, 93, 0.12), transparent 30%),
        var(--wash);
    }

    .shell {
      width: min(1240px, calc(100vw - 32px));
      margin: 0 auto;
      padding: 32px 0;
    }

    header {
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 22px;
      align-items: end;
      margin-bottom: 18px;
    }

    h1 {
      margin: 0;
      font-size: clamp(2rem, 5vw, 4.25rem);
      line-height: 0.95;
      letter-spacing: 0;
    }

    .meta {
      margin: 12px 0 0;
      color: var(--muted);
      font-size: 0.95rem;
      line-height: 1.45;
    }

    .actions,
    .toolbar {
      display: flex;
      gap: 10px;
      align-items: center;
      flex-wrap: wrap;
    }

    .actions {
      justify-content: flex-end;
    }

    button,
    input,
    select {
      height: 40px;
      border: 1px solid var(--line);
      border-radius: 6px;
      background: var(--surface);
      color: var(--ink);
      font: inherit;
    }

    button {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 0 14px;
      border-color: var(--accent);
      background: var(--accent);
      color: #fff;
      font-weight: 700;
      cursor: pointer;
    }

    button.secondary {
      border-color: var(--line);
      background: var(--surface);
      color: var(--ink);
    }

    button:hover {
      background: var(--accent-strong);
    }

    button.secondary:hover {
      background: #f6f9f7;
    }

    .metrics {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 12px;
      margin-bottom: 14px;
    }

    .metric {
      min-height: 86px;
      padding: 16px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.8);
    }

    .metric span {
      display: block;
      margin-bottom: 8px;
      color: var(--muted);
      font-size: 0.78rem;
      font-weight: 800;
      letter-spacing: 0;
      text-transform: uppercase;
    }

    .metric strong {
      font-size: clamp(1.45rem, 3vw, 2rem);
      line-height: 1;
    }

    .toolbar {
      display: grid;
      grid-template-columns: minmax(220px, 1fr) 190px auto auto;
      margin-bottom: 14px;
    }

    .toolbar input,
    .toolbar select {
      width: 100%;
      padding: 0 12px;
    }

    #grid {
      overflow: hidden;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--surface);
    }

    .tabulator {
      border: 0;
      background: var(--surface);
      font-size: 0.92rem;
    }

    .tabulator .tabulator-header {
      border-bottom-color: var(--line);
      background: #f6f9f7;
      color: var(--ink);
      font-weight: 800;
    }

    .tabulator .tabulator-row {
      border-bottom-color: #edf2ee;
    }

    .tabulator .tabulator-row.tabulator-row-even {
      background: #fbfcfb;
    }

    .empty {
      padding: 42px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--surface);
      color: var(--muted);
      text-align: center;
    }

    @media (max-width: 860px) {
      header {
        grid-template-columns: 1fr;
      }

      .actions {
        justify-content: flex-start;
      }

      .metrics,
      .toolbar {
        grid-template-columns: 1fr 1fr;
      }
    }

    @media (max-width: 560px) {
      .shell {
        width: min(100vw - 20px, 1240px);
        padding: 20px 0;
      }

      .metrics,
      .toolbar {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>
  <main class="shell">
    <header>
      <div>
        <h1 id="page-title">__TITLE_HTML__</h1>
        <p class="meta"><span id="row-copy">0 rows</span> · Generated <span id="generated-at"></span></p>
      </div>
      <div class="actions">
        <button type="button" id="download-csv">Download CSV</button>
        <button type="button" id="download-json" class="secondary">Download JSON</button>
      </div>
    </header>

    <section class="metrics" aria-label="Grid metrics">
      <div class="metric">
        <span>Rows</span>
        <strong id="metric-rows">0</strong>
      </div>
      <div class="metric">
        <span>Columns</span>
        <strong id="metric-columns">0</strong>
      </div>
      <div class="metric">
        <span>Numeric Fields</span>
        <strong id="metric-numeric">0</strong>
      </div>
      <div class="metric">
        <span>Filtered Rows</span>
        <strong id="metric-filtered">0</strong>
      </div>
    </section>

    <section class="toolbar" aria-label="Grid controls">
      <input id="quick-filter" type="search" placeholder="Search all columns">
      <select id="column-filter">
        <option value="">All columns</option>
      </select>
      <button type="button" id="clear-filters" class="secondary">Clear</button>
      <button type="button" id="fit-columns" class="secondary">Fit</button>
    </section>

    <div id="grid"></div>
  </main>

  <script id="grid-csv" type="text/plain" data-encoding="base64">__CSV_BASE64__</script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/tabulator/6.3.1/js/tabulator.min.js"></script>
  <script>
    const pageTitle = __TITLE_JSON__;
    const generatedAt = __GENERATED_JSON__;
    const currency = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 });
    const number = new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 });
    const percent = new Intl.NumberFormat("en-US", { style: "percent", maximumFractionDigits: 1 });

    function decodeBase64Utf8(value) {
      const binary = atob(value);
      const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
      return new TextDecoder().decode(bytes);
    }

    function parseCsv(text) {
      const rows = [];
      let row = [];
      let cell = "";
      let inQuotes = false;

      for (let index = 0; index < text.length; index += 1) {
        const char = text[index];
        const next = text[index + 1];

        if (char === '"' && inQuotes && next === '"') {
          cell += '"';
          index += 1;
        } else if (char === '"') {
          inQuotes = !inQuotes;
        } else if (char === "," && !inQuotes) {
          row.push(cell);
          cell = "";
        } else if ((char === "\n" || char === "\r") && !inQuotes) {
          if (char === "\r" && next === "\n") {
            index += 1;
          }

          row.push(cell);
          if (row.some((value) => value.trim() !== "")) {
            rows.push(row);
          }

          row = [];
          cell = "";
        } else {
          cell += char;
        }
      }

      row.push(cell);
      if (row.some((value) => value.trim() !== "")) {
        rows.push(row);
      }

      if (!rows.length) {
        return { headers: [], records: [] };
      }

      const headers = rows.shift();
      const records = rows.map((values) => Object.fromEntries(headers.map((header, index) => [header, values[index] ?? ""])));
      return { headers, records };
    }

    function isNumberColumn(records, field) {
      const values = records.map((row) => row[field]).filter((value) => String(value).trim() !== "");
      return values.length > 0 && values.every((value) => Number.isFinite(Number(String(value).replace(/[$,%]/g, ""))));
    }

    function isDateColumn(records, field) {
      const values = records.map((row) => row[field]).filter((value) => String(value).trim() !== "");
      return values.length > 0 && values.every((value) => /^\d{4}-\d{2}-\d{2}/.test(value));
    }

    function normalizeRecords(records, headers) {
      const numericFields = headers.filter((field) => isNumberColumn(records, field));
      const numericSet = new Set(numericFields);

      for (const row of records) {
        for (const field of numericSet) {
          const raw = String(row[field]).replace(/[$,%]/g, "");
          row[field] = raw === "" ? null : Number(raw);
        }
      }

      return numericFields;
    }

    function columnFor(field, records, numericFields) {
      const lower = field.toLowerCase();
      const isNumeric = numericFields.includes(field);
      const looksMoney = /(amount|cost|price|revenue|sales|spend|value|total|balance|profit|margin)/.test(lower);
      const looksPercent = /(percent|pct|rate|confidence|probability)/.test(lower);

      const column = {
        title: field,
        field,
        minWidth: Math.min(Math.max(field.length * 10 + 72, 120), 260),
        headerFilter: "input",
      };

      if (isNumeric) {
        column.hozAlign = "right";
        column.sorter = "number";
        column.bottomCalc = "sum";

        if (looksMoney) {
          column.formatter = "money";
          column.formatterParams = { symbol: "$", precision: false };
          column.bottomCalcFormatter = "money";
          column.bottomCalcFormatterParams = { symbol: "$", precision: false };
        } else if (looksPercent) {
          column.formatter = (cell) => {
            const value = cell.getValue();
            if (value === null || value === undefined || value === "") {
              return "";
            }

            return Math.abs(value) <= 1 ? percent.format(value) : `${number.format(value)}%`;
          };
          column.bottomCalc = false;
        } else {
          column.formatter = (cell) => {
            const value = cell.getValue();
            return value === null || value === undefined ? "" : number.format(value);
          };
        }
      } else if (isDateColumn(records, field)) {
        column.sorter = "date";
      }

      return column;
    }

    const csvText = decodeBase64Utf8(document.getElementById("grid-csv").textContent.trim());
    const parsed = parseCsv(csvText);
    const numericFields = normalizeRecords(parsed.records, parsed.headers);

    document.title = pageTitle;
    document.getElementById("page-title").textContent = pageTitle;
    document.getElementById("generated-at").textContent = generatedAt;
    document.getElementById("row-copy").textContent = `${parsed.records.length.toLocaleString()} rows`;

    if (!parsed.headers.length) {
      document.getElementById("grid").outerHTML = '<div class="empty">No rows were provided.</div>';
    }

    const columnFilter = document.getElementById("column-filter");
    for (const header of parsed.headers) {
      const option = document.createElement("option");
      option.value = header;
      option.textContent = header;
      columnFilter.append(option);
    }

    const table = new Tabulator("#grid", {
      data: parsed.records,
      columns: parsed.headers.map((field) => columnFor(field, parsed.records, numericFields)),
      layout: "fitDataStretch",
      height: "620px",
      pagination: true,
      paginationSize: 25,
      movableColumns: true,
      resizableColumnFit: true,
      placeholder: "No matching rows",
    });

    const quickFilter = document.getElementById("quick-filter");

    function applyFilters() {
      const term = quickFilter.value.trim().toLowerCase();
      const column = columnFilter.value;

      table.setFilter((row) => {
        if (!term) {
          return true;
        }

        const fields = column ? [column] : parsed.headers;
        return fields.some((field) => String(row[field] ?? "").toLowerCase().includes(term));
      });
    }

    function updateMetrics() {
      const filteredRows = table.getData("active").length;
      document.getElementById("metric-rows").textContent = parsed.records.length.toLocaleString();
      document.getElementById("metric-columns").textContent = parsed.headers.length.toLocaleString();
      document.getElementById("metric-numeric").textContent = numericFields.length.toLocaleString();
      document.getElementById("metric-filtered").textContent = filteredRows.toLocaleString();
    }

    quickFilter.addEventListener("input", applyFilters);
    columnFilter.addEventListener("change", applyFilters);

    document.getElementById("clear-filters").addEventListener("click", () => {
      quickFilter.value = "";
      columnFilter.value = "";
      table.clearFilter(true);
    });

    document.getElementById("fit-columns").addEventListener("click", () => {
      table.setColumns(parsed.headers.map((field) => columnFor(field, parsed.records, numericFields)));
    });

    document.getElementById("download-csv").addEventListener("click", () => {
      table.download("csv", "grid-data.csv");
    });

    document.getElementById("download-json").addEventListener("click", () => {
      table.download("json", "grid-data.json");
    });

    table.on("dataFiltered", updateMetrics);
    table.on("tableBuilt", updateMetrics);
    requestAnimationFrame(updateMetrics);
  </script>
</body>
</html>
'@

    $template.
        Replace('__TITLE_HTML__', $titleHtml).
        Replace('__TITLE_JSON__', $titleJson).
        Replace('__GENERATED_JSON__', $generatedJson).
        Replace('__CSV_BASE64__', $csvBase64)
}

function New-HereNowMarkdownDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $MarkdownText,

        [string] $Title = 'Markdown Preview'
    )

    $markdownBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($MarkdownText))
    $titleHtml = ConvertTo-HereNowHtmlEncoded -Value $Title
    $titleJson = ConvertTo-HereNowJsonLiteral -Value $Title
    $generatedJson = ConvertTo-HereNowJsonLiteral -Value ((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC'))

    $template = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>__TITLE_HTML__</title>
  <style>
    :root {
      color-scheme: light;
      --ink: #17211d;
      --muted: #60706a;
      --line: #d7e0db;
      --surface: #ffffff;
      --wash: #f1f5f2;
      --accent: #126b5d;
      font-family: "Segoe UI", system-ui, sans-serif;
      background: var(--wash);
      color: var(--ink);
    }

    * {
      box-sizing: border-box;
    }

    body {
      min-height: 100vh;
      margin: 0;
      background:
        linear-gradient(180deg, rgba(255, 255, 255, 0.9), rgba(241, 245, 242, 0.98)),
        radial-gradient(circle at 12% 0%, rgba(18, 107, 93, 0.12), transparent 30%),
        var(--wash);
    }

    .shell {
      width: min(920px, calc(100vw - 32px));
      margin: 0 auto;
      padding: 36px 0 56px;
    }

    header {
      margin-bottom: 20px;
      padding-bottom: 18px;
      border-bottom: 1px solid var(--line);
    }

    h1 {
      margin: 0;
      font-size: clamp(2rem, 5vw, 4rem);
      line-height: 0.98;
      letter-spacing: 0;
    }

    .meta {
      margin: 12px 0 0;
      color: var(--muted);
      font-size: 0.94rem;
    }

    .markdown-body {
      padding: 26px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--surface);
      font-size: 1rem;
      line-height: 1.68;
    }

    .markdown-body > :first-child {
      margin-top: 0;
    }

    .markdown-body > :last-child {
      margin-bottom: 0;
    }

    .markdown-body h1,
    .markdown-body h2,
    .markdown-body h3 {
      line-height: 1.15;
      letter-spacing: 0;
    }

    .markdown-body h1 {
      font-size: 2.15rem;
    }

    .markdown-body h2 {
      margin-top: 2rem;
      padding-bottom: 0.35rem;
      border-bottom: 1px solid var(--line);
      font-size: 1.55rem;
    }

    .markdown-body h3 {
      margin-top: 1.7rem;
      font-size: 1.25rem;
    }

    .markdown-body a {
      color: var(--accent);
      font-weight: 700;
    }

    .markdown-body code {
      padding: 0.12rem 0.3rem;
      border-radius: 5px;
      background: #eef4f0;
      font-family: "Cascadia Code", Consolas, monospace;
      font-size: 0.92em;
    }

    .markdown-body pre {
      overflow: auto;
      padding: 16px;
      border-radius: 8px;
      background: #16211d;
      color: #f4fbf7;
    }

    .markdown-body pre code {
      padding: 0;
      background: transparent;
      color: inherit;
    }

    .markdown-body blockquote {
      margin-left: 0;
      padding-left: 16px;
      border-left: 4px solid var(--accent);
      color: var(--muted);
    }

    .markdown-body img {
      max-width: 100%;
      height: auto;
      border-radius: 8px;
    }

    .markdown-body table {
      width: 100%;
      border-collapse: collapse;
      overflow: hidden;
      border-radius: 8px;
    }

    .markdown-body th,
    .markdown-body td {
      padding: 10px 12px;
      border: 1px solid var(--line);
      text-align: left;
    }

    .markdown-body th {
      background: #f6f9f7;
    }

    @media (max-width: 560px) {
      .shell {
        width: min(100vw - 20px, 920px);
        padding: 22px 0 36px;
      }

      .markdown-body {
        padding: 18px;
      }
    }
  </style>
</head>
<body>
  <main class="shell">
    <header>
      <h1 id="page-title">__TITLE_HTML__</h1>
      <p class="meta">Generated <span id="generated-at"></span></p>
    </header>
    <article id="markdown-body" class="markdown-body"></article>
  </main>

  <script id="markdown-source" type="text/plain" data-encoding="base64">__MARKDOWN_BASE64__</script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/dompurify/3.2.7/purify.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/marked/15.0.7/marked.min.js"></script>
  <script>
    const pageTitle = __TITLE_JSON__;
    const generatedAt = __GENERATED_JSON__;

    function decodeBase64Utf8(value) {
      const binary = atob(value);
      const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
      return new TextDecoder().decode(bytes);
    }

    const markdown = decodeBase64Utf8(document.getElementById("markdown-source").textContent.trim());
    const target = document.getElementById("markdown-body");

    document.title = pageTitle;
    document.getElementById("page-title").textContent = pageTitle;
    document.getElementById("generated-at").textContent = generatedAt;

    marked.setOptions({
      gfm: true,
      breaks: false,
    });

    target.innerHTML = DOMPurify.sanitize(marked.parse(markdown));
  </script>
</body>
</html>
'@

    $template.
        Replace('__TITLE_HTML__', $titleHtml).
        Replace('__TITLE_JSON__', $titleJson).
        Replace('__GENERATED_JSON__', $generatedJson).
        Replace('__MARKDOWN_BASE64__', $markdownBase64)
}

function Invoke-HereNowJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string] $Method,

        [Parameter(Mandatory)]
        [string] $Uri,

        [object] $Body,

        [string] $ApiKey,

        [string] $Client,

        [int] $TimeoutSec = 100
    )

    $headers = @{}
    if (-not [string]::IsNullOrWhiteSpace($Client)) {
        $headers['X-HereNow-Client'] = $Client
    }

    if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
        $headers['Authorization'] = "Bearer $ApiKey"
    }

    $parameters = @{
        Method     = $Method
        Uri        = $Uri
        Headers    = $headers
        TimeoutSec = $TimeoutSec
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $parameters['ContentType'] = 'application/json'
        $parameters['Body'] = ($Body | ConvertTo-Json -Depth 20)
    }

    try {
        Invoke-RestMethod @parameters
    }
    catch {
        throw (New-HereNowHttpError -ErrorRecord $_)
    }
}

function New-HereNowHttpError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $message = $ErrorRecord.Exception.Message
    $response = $ErrorRecord.Exception.Response

    if ($null -ne $response) {
        try {
            $statusCode = [int] $response.StatusCode
            $statusDescription = $response.StatusDescription
            $bodyText = $null

            if ($response.GetResponseStream) {
                $reader = [System.IO.StreamReader]::new($response.GetResponseStream())
                try {
                    $bodyText = $reader.ReadToEnd()
                }
                finally {
                    $reader.Dispose()
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($bodyText)) {
                try {
                    $bodyJson = $bodyText | ConvertFrom-Json
                    if ($bodyJson.message) {
                        $message = $bodyJson.message
                    }
                    elseif ($bodyJson.error) {
                        $message = $bodyJson.error
                    }
                    else {
                        $message = $bodyText
                    }

                    if ($bodyJson.code) {
                        $message = "$message ($($bodyJson.code))"
                    }
                }
                catch {
                    $message = $bodyText
                }
            }
            elseif ($statusCode -gt 0) {
                $message = "HTTP $statusCode $statusDescription"
            }
        }
        catch {
            $message = $ErrorRecord.Exception.Message
        }
    }

    [System.Exception]::new($message, $ErrorRecord.Exception)
}

function New-HereNowFileEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $LocalPath,

        [Parameter(Mandatory)]
        [string] $SitePath
    )

    $fileInfo = Get-Item -LiteralPath $LocalPath

    [pscustomobject]@{
        LocalPath    = $fileInfo.FullName
        Path         = $SitePath
        Size         = $fileInfo.Length
        ContentType  = Get-HereNowContentType -Path $SitePath
        Hash         = Get-HereNowSha256Hex -Path $fileInfo.FullName
        Bytes        = $null
        IsInMemory   = $false
    }
}

function Publish-HereNowSite {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'LiteralPath')]
        [object[]] $Path,

        [string] $Root,

        [string] $FileName = 'index.html',

        [switch] $Markdown,

        [string] $Slug,

        [string] $ClaimToken,

        [string] $ApiKey,

        [switch] $NoCredentialFile,

        [string] $ApiBase = 'https://here.now',

        [string] $Client = 'powershell/here-now',

        [switch] $Spa,

        [Nullable[int]] $TtlSeconds,

        [string] $Title,

        [string] $Description,

        [string] $OgImagePath,

        [switch] $Forkable,

        [string] $ClaimOutputPath,

        [switch] $NoClaimFile,

        [switch] $Show,

        [int] $TimeoutSec = 100
    )

    begin {
        $pathInputs = New-Object System.Collections.Generic.List[object]
        $pipelineStrings = New-Object System.Collections.Generic.List[string]
        $receivedPipelineInput = $false
        $fileEntries = $null
        $fileNameWasBound = $PSBoundParameters.ContainsKey('FileName')
    }

    process {
        if ($PSBoundParameters.ContainsKey('Path')) {
            foreach ($inputItem in $Path) {
                $receivedPipelineInput = $receivedPipelineInput -or $MyInvocation.ExpectingInput

                if ($null -eq $inputItem) {
                    continue
                }

                if ($inputItem -is [System.IO.FileSystemInfo]) {
                    $pathInputs.Add($inputItem.FullName)
                    continue
                }

                if ($inputItem -is [string]) {
                    if ($MyInvocation.ExpectingInput) {
                        $pipelineStrings.Add($inputItem)
                    }
                    else {
                        $pathInputs.Add($inputItem)
                    }
                    continue
                }

                if ($inputItem.PSObject.Properties['FullName']) {
                    $pathInputs.Add([string] $inputItem.FullName)
                    continue
                }

                throw "Unsupported input type '$($inputItem.GetType().FullName)'. Pass a file path, directory path, FileInfo, DirectoryInfo, or text content."
            }
        }
    }

    end {
        if ($pipelineStrings.Count -gt 0) {
            $allStringsArePaths = $true
            foreach ($line in $pipelineStrings) {
                if ([string]::IsNullOrWhiteSpace($line) -or -not (Test-Path -LiteralPath $line)) {
                    $allStringsArePaths = $false
                    break
                }
            }

            if ($allStringsArePaths) {
                foreach ($line in $pipelineStrings) {
                    $pathInputs.Add($line)
                }
            }
            elseif ($pathInputs.Count -eq 0) {
                $text = $pipelineStrings -join [Environment]::NewLine
                $sitePath = ($FileName -replace '\\', '/').TrimStart('/')
                $contentType = Get-HereNowContentType -Path $sitePath

                if ($Markdown) {
                    $extension = [System.IO.Path]::GetExtension($sitePath).ToLowerInvariant()
                    if ($fileNameWasBound -and $extension -notin @('.html', '.htm')) {
                        throw 'When using -Markdown with piped text, omit -FileName or use an .html/.htm filename. The Markdown is rendered into an HTML page.'
                    }

                    if (-not $fileNameWasBound) {
                        $sitePath = 'index.html'
                    }

                    $markdownTitle = if ([string]::IsNullOrWhiteSpace($Title)) { 'Markdown Preview' } else { $Title }
                    $text = New-HereNowMarkdownDocument -MarkdownText $text -Title $markdownTitle
                    $contentType = 'text/html; charset=utf-8'
                }

                $encoding = [System.Text.UTF8Encoding]::new($false)
                $bytes = $encoding.GetBytes($text)

                if ([string]::IsNullOrWhiteSpace($sitePath) -or $sitePath.Contains('..')) {
                    throw "Invalid -FileName '$FileName'."
                }

                $fileEntries = @(
                    [pscustomobject]@{
                        LocalPath    = $null
                        Path         = $sitePath
                        Size         = $bytes.Length
                        ContentType  = $contentType
                        Hash         = Get-HereNowSha256HexFromBytes -Bytes $bytes
                        Bytes        = $bytes
                        IsInMemory   = $true
                    }
                )
            }
            else {
                throw 'Pipeline input mixed text content with file path input. Use either paths or content for one publish.'
            }
        }

        if ($null -eq $fileEntries) {
            if ($pathInputs.Count -eq 0) {
                throw 'Pass a file or directory path, pipe FileInfo objects, or pipe text content.'
            }

            $resolvedFiles = New-Object System.Collections.Generic.List[string]
            $directoryRoots = New-Object System.Collections.Generic.List[string]

            foreach ($inputPath in $pathInputs) {
                $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath([string] $inputPath)

                if (-not (Test-Path -LiteralPath $resolvedPath)) {
                    throw "Path not found: $inputPath"
                }

                $item = Get-Item -LiteralPath $resolvedPath -Force
                if ($item -is [System.IO.DirectoryInfo]) {
                    $directoryRoots.Add($item.FullName)
                    Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Force |
                        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
                        ForEach-Object { $resolvedFiles.Add($_.FullName) }
                }
                elseif ($item -is [System.IO.FileInfo]) {
                    $resolvedFiles.Add($item.FullName)
                }
                else {
                    throw "Unsupported filesystem item: $resolvedPath"
                }
            }

            if ($resolvedFiles.Count -eq 0) {
                throw 'No files found to publish.'
            }

            if ($resolvedFiles.Count -gt 1000) {
                throw "here.now accepts up to 1000 files per publish. This publish found $($resolvedFiles.Count) files."
            }

            if (-not [string]::IsNullOrWhiteSpace($Root)) {
                $siteRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
            }
            elseif ($directoryRoots.Count -eq 1 -and $pathInputs.Count -eq 1) {
                $siteRoot = $directoryRoots[0]
            }
            else {
                $siteRoot = Get-HereNowCommonRoot -FilePaths ([string[]] $resolvedFiles.ToArray())
            }

            $entries = New-Object System.Collections.Generic.List[object]
            foreach ($filePath in $resolvedFiles) {
                if ($resolvedFiles.Count -eq 1 -and $fileNameWasBound) {
                    $sitePath = ($FileName -replace '\\', '/').TrimStart('/')
                }
                else {
                    $sitePath = ConvertTo-HereNowSitePath -Path $filePath -Root $siteRoot
                }

                $entries.Add((New-HereNowFileEntry -LocalPath $filePath -SitePath $sitePath))
            }

            $duplicatePaths = $entries | Group-Object -Property Path | Where-Object Count -gt 1
            if ($duplicatePaths) {
                $duplicates = ($duplicatePaths | ForEach-Object Name) -join ', '
                throw "Multiple local files map to the same site path: $duplicates"
            }

            $fileEntries = @($entries.ToArray())
        }

        $manifest = foreach ($entry in $fileEntries) {
            @{
                path        = $entry.Path
                size        = [int64] $entry.Size
                contentType = $entry.ContentType
                hash        = $entry.Hash
            }
        }

        $body = @{
            files = @($manifest)
        }

        if ($null -ne $TtlSeconds) {
            $body.ttlSeconds = [int] $TtlSeconds
        }

        if ($Spa) {
            $body.spaMode = $true
        }

        if ($Forkable) {
            $body.forkable = $true
        }

        if (-not [string]::IsNullOrWhiteSpace($ClaimToken)) {
            if ([string]::IsNullOrWhiteSpace($Slug)) {
                throw '-ClaimToken is only valid when updating an existing anonymous site with -Slug.'
            }

            $body.claimToken = $ClaimToken
        }

        $viewer = @{}
        if (-not [string]::IsNullOrWhiteSpace($Title)) {
            $viewer.title = $Title
        }
        if (-not [string]::IsNullOrWhiteSpace($Description)) {
            $viewer.description = $Description
        }
        if (-not [string]::IsNullOrWhiteSpace($OgImagePath)) {
            $viewer.ogImagePath = $OgImagePath
        }
        if ($viewer.Count -gt 0) {
            $body.viewer = $viewer
        }

        $resolvedApiKey = Get-HereNowApiKey -ApiKey $ApiKey -NoCredentialFile:$NoCredentialFile
        $apiRoot = $ApiBase.TrimEnd('/')

        if ([string]::IsNullOrWhiteSpace($Slug)) {
            $publishUri = "$apiRoot/api/v1/publish"
            $httpMethod = 'POST'
            $targetDescription = 'new here.now site'
        }
        else {
            $publishUri = "$apiRoot/api/v1/publish/$Slug"
            $httpMethod = 'PUT'
            $targetDescription = "here.now site '$Slug'"
        }

        if (-not $PSCmdlet.ShouldProcess($targetDescription, "Publish $($fileEntries.Count) file(s)")) {
            return [pscustomobject]@{
                WhatIf      = $true
                ApiBase     = $apiRoot
                Slug        = $Slug
                FileCount   = $fileEntries.Count
                Files       = @($manifest)
                Anonymous   = [string]::IsNullOrWhiteSpace($resolvedApiKey)
                SpaMode     = [bool] $Spa
                Markdown    = [bool] $Markdown
                Forkable    = [bool] $Forkable
            }
        }

        $createResponse = Invoke-HereNowJson -Method $httpMethod -Uri $publishUri -Body $body -ApiKey $resolvedApiKey -Client $Client -TimeoutSec $TimeoutSec
        $uploadResponse = Get-HereNowPropertyValue -InputObject $createResponse -Name 'upload'
        $uploads = @(Get-HereNowPropertyValue -InputObject $uploadResponse -Name 'uploads' -Default @())
        $skippedFiles = @(Get-HereNowPropertyValue -InputObject $uploadResponse -Name 'skipped' -Default @())
        $versionId = Get-HereNowPropertyValue -InputObject $uploadResponse -Name 'versionId'
        $finalizeUrl = Get-HereNowPropertyValue -InputObject $uploadResponse -Name 'finalizeUrl'

        if ([string]::IsNullOrWhiteSpace($versionId) -or [string]::IsNullOrWhiteSpace($finalizeUrl)) {
            throw 'here.now publish response did not include upload.versionId or upload.finalizeUrl.'
        }

        $uploadByPath = @{}
        if ($uploads.Count -gt 0) {
            foreach ($upload in $uploads) {
                $uploadPath = Get-HereNowPropertyValue -InputObject $upload -Name 'path'
                if (-not [string]::IsNullOrWhiteSpace($uploadPath)) {
                    $uploadByPath[[string] $uploadPath] = $upload
                }
            }
        }

        foreach ($entry in $fileEntries) {
            if (-not $uploadByPath.ContainsKey($entry.Path)) {
                continue
            }

            $upload = $uploadByPath[$entry.Path]
            $uploadHeaders = ConvertTo-HereNowHeaderTable -Headers (Get-HereNowPropertyValue -InputObject $upload -Name 'headers')
            $contentType = $entry.ContentType

            if ($uploadHeaders.ContainsKey('Content-Type')) {
                $contentType = $uploadHeaders['Content-Type']
                $uploadHeaders.Remove('Content-Type')
            }

            $uploadParameters = @{
                Method      = ([string] (Get-HereNowPropertyValue -InputObject $upload -Name 'method' -Default 'PUT'))
                Uri         = ([string] (Get-HereNowPropertyValue -InputObject $upload -Name 'url'))
                Headers     = $uploadHeaders
                ContentType = $contentType
                TimeoutSec  = $TimeoutSec
            }

            try {
                if ($entry.IsInMemory) {
                    $uploadParameters['Body'] = $entry.Bytes
                }
                else {
                    $uploadParameters['InFile'] = $entry.LocalPath
                }

                Invoke-WebRequest @uploadParameters | Out-Null
            }
            catch {
                throw (New-HereNowHttpError -ErrorRecord $_)
            }
        }

        $finalizeBody = @{
            versionId = $versionId
        }

        $finalizeResponse = Invoke-HereNowJson -Method POST -Uri $finalizeUrl -Body $finalizeBody -ApiKey $resolvedApiKey -Client $Client -TimeoutSec $TimeoutSec

        $claimFile = $null
        $createSlug = Get-HereNowPropertyValue -InputObject $createResponse -Name 'slug'
        $createSiteUrl = Get-HereNowPropertyValue -InputObject $createResponse -Name 'siteUrl'
        $claimUrl = Get-HereNowPropertyValue -InputObject $createResponse -Name 'claimUrl'
        $claimToken = Get-HereNowPropertyValue -InputObject $createResponse -Name 'claimToken'
        $expiresAt = Get-HereNowPropertyValue -InputObject $createResponse -Name 'expiresAt'
        $anonymous = [bool] (Get-HereNowPropertyValue -InputObject $createResponse -Name 'anonymous' -Default $false)

        if ($claimUrl -and -not $NoClaimFile) {
            if ([string]::IsNullOrWhiteSpace($ClaimOutputPath)) {
                $claimDirectory = Join-Path -Path (Get-Location).ProviderPath -ChildPath '.herenow'
                $ClaimOutputPath = Join-Path -Path $claimDirectory -ChildPath "$createSlug.claim.json"
            }

            $claimFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ClaimOutputPath)
            $claimFileDirectory = Split-Path -Path $claimFile -Parent

            if (-not (Test-Path -LiteralPath $claimFileDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $claimFileDirectory -Force | Out-Null
            }

            [pscustomobject]@{
                slug       = $createSlug
                siteUrl    = $createSiteUrl
                claimUrl   = $claimUrl
                claimToken = $claimToken
                expiresAt  = $expiresAt
                savedAt    = (Get-Date).ToUniversalTime().ToString('o')
            } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $claimFile -Encoding utf8

            Write-Warning "Anonymous site claim URL saved to '$claimFile'. Save this URL; here.now only returns it once."
        }

        $finalSlug = Get-HereNowPropertyValue -InputObject $finalizeResponse -Name 'slug' -Default $createSlug
        $finalSiteUrl = Get-HereNowPropertyValue -InputObject $finalizeResponse -Name 'siteUrl' -Default $createSiteUrl
        $previousVersionId = Get-HereNowPropertyValue -InputObject $finalizeResponse -Name 'previousVersionId'
        $currentVersionId = Get-HereNowPropertyValue -InputObject $finalizeResponse -Name 'currentVersionId' -Default $versionId

        $result = [pscustomobject]@{
            Slug              = $finalSlug
            Url               = $finalSiteUrl
            SiteUrl           = $finalSiteUrl
            Anonymous         = $anonymous
            ExpiresAt         = $expiresAt
            ClaimUrl          = $claimUrl
            ClaimToken        = $claimToken
            ClaimFile         = $claimFile
            PreviousVersionId = $previousVersionId
            CurrentVersionId  = $currentVersionId
            UploadedFiles     = @($uploadByPath.Keys)
            SkippedFiles      = $skippedFiles
            FileCount         = $fileEntries.Count
            Files             = @($manifest)
        }

        if ($Show -and -not [string]::IsNullOrWhiteSpace($result.SiteUrl)) {
            try {
                Start-Process -FilePath $result.SiteUrl
            }
            catch {
                Write-Warning "Published successfully, but could not open '$($result.SiteUrl)': $($_.Exception.Message)"
            }
        }

        $result
    }
}

function Out-HtmlGridView {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [object[]] $InputObject,

        [string] $Title = 'PowerShell Grid View',

        [string] $Slug,

        [string] $ClaimToken,

        [string] $ApiKey,

        [switch] $NoCredentialFile,

        [string] $ApiBase = 'https://here.now',

        [string] $Client = 'powershell/here-now',

        [Nullable[int]] $TtlSeconds,

        [string] $ClaimOutputPath,

        [switch] $NoClaimFile,

        [switch] $NoShow,

        [int] $TimeoutSec = 100
    )

    begin {
        $rows = New-Object System.Collections.Generic.List[object]
    }

    process {
        if (-not $PSBoundParameters.ContainsKey('InputObject')) {
            return
        }

        foreach ($item in $InputObject) {
            if ($null -ne $item) {
                $rows.Add($item)
            }
        }
    }

    end {
        if ($rows.Count -eq 0) {
            throw 'Out-HtmlGridView needs at least one input object.'
        }

        $csvText = (($rows.ToArray() | ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine)
        $html = New-HereNowHtmlGridDocument -CsvText $csvText -Title $Title

        $publishParams = @{
            FileName         = 'index.html'
            Title            = $Title
            ApiBase          = $ApiBase
            Client           = $Client
            TimeoutSec       = $TimeoutSec
            Show             = (-not $NoShow)
            NoCredentialFile = [bool] $NoCredentialFile
            NoClaimFile      = [bool] $NoClaimFile
            WhatIf           = [bool] $WhatIfPreference
        }

        if (-not [string]::IsNullOrWhiteSpace($Slug)) {
            $publishParams['Slug'] = $Slug
        }

        if (-not [string]::IsNullOrWhiteSpace($ClaimToken)) {
            $publishParams['ClaimToken'] = $ClaimToken
        }

        if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
            $publishParams['ApiKey'] = $ApiKey
        }

        if ($null -ne $TtlSeconds) {
            $publishParams['TtlSeconds'] = [int] $TtlSeconds
        }

        if (-not [string]::IsNullOrWhiteSpace($ClaimOutputPath)) {
            $publishParams['ClaimOutputPath'] = $ClaimOutputPath
        }

        $publishResult = $html | Publish-HereNowSite @publishParams
        foreach ($result in @($publishResult)) {
            $result | Add-Member -NotePropertyName SourceRowCount -NotePropertyValue $rows.Count -Force
            $result | Add-Member -NotePropertyName GridTitle -NotePropertyValue $Title -Force
            $result
        }
    }
}

Set-Alias -Name Publish-HereNow -Value Publish-HereNowSite

Export-ModuleMember -Function Publish-HereNowSite, Set-HereNowApiKey, Out-HtmlGridView -Alias Publish-HereNow
