$p = @{
    Name        = "PSHereNow"
    NuGetApiKey = $NuGetApiKey
}

Publish-Module @p
