param (
    [string] $FullPath
)

# $FullPath = 'C:\Program Files\WindowsPowerShell\Modules\PSHereNow'
if (-not $FullPath) {
    $moduleRoot = $env:PSModulePath -split ":(?!\\)|;|," |
        Where-Object { $_ -notlike ([System.Environment]::GetFolderPath("UserProfile") + "*") -and $_ -notlike "$PSHOME*" } |
        Select-Object -First 1

    $FullPath = Join-Path $moduleRoot -ChildPath "PSHereNow"
}

Push-Location $PSScriptRoot
try {
    Robocopy . $FullPath /mir /XD .git .github .herenow /XF .gitattributes .gitignore InstallModule.ps1 PublishToGallery.ps1
}
finally {
    Pop-Location
}
