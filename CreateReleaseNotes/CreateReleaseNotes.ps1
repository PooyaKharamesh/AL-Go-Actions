Param(
    [string] $actor,
    [string] $token,
    [string] $workflowToken,
    [string] $tag_name)


$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

try {
    . (Join-Path $PSScriptRoot "..\AL-Go-Helper.ps1")
    Import-Module (Join-Path $PSScriptRoot '..\Github-Helper.psm1')

    $latestRelease = GetLatestRelease -token $token -api_url $ENV:GITHUB_API_URL -repository $ENV:GITHUB_REPOSITORY 
    $latestReleaseTag = $latestRelease.tag_name

    $realseNotes = GetReleaseNotes -token $token -api_url $ENV:GITHUB_API_URL -repository $ENV:GITHUB_REPOSITORY  -tag_name $tag_name -previous_tag_name $latestReleaseTag
    Write-Host $realseNotes

    Write-Host "set-output name=realseNotes::$realseNotes"
}
catch {
    OutputError -message "Couldn't create release notes. Error was $($_.Exception.Message)"
}
