@{
    RootModule           = 'PSHereNow.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '4f1dc753-c0cd-4265-a63f-29bd85fcbe30'
    Author               = 'Doug Finke'
    CompanyName          = 'Doug Finke'
    Copyright            = '(c) 2026 Doug Finke. All rights reserved.'
    Description          = 'PowerShell helpers for publishing static sites to here.now.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Publish-HereNowSite', 'Set-HereNowApiKey', 'Out-HtmlGridView')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @('Publish-HereNow')
    PrivateData          = @{
        PSData = @{
            Tags       = @('here-now', 'publishing', 'static-site', 'powershell')
            ProjectUri = 'https://github.com/dfinke/PSHereNow'
            LicenseUri = 'https://github.com/dfinke/PSHereNow/blob/main/LICENSE'
        }
    }
}
