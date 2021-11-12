Param(
    [Parameter(HelpMessage = "The GitHub actor running the action", Mandatory = $false)]
    [string] $actor,
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $token,
    [Parameter(HelpMessage = "Specifies the parent telemetry scope for the Telemetry signal", Mandatory = $false)]
    [string] $parentTelemetryScope, 
    [Parameter(HelpMessage = "Specifies the event Id in the telemetry", Mandatory = $false)]
    [string] $telemetryEventId,    
    [Parameter(HelpMessage = "Project folder", Mandatory = $false)]
    [string] $project = ".",
    [Parameter(HelpMessage = "Indicates whether this is called from a release pipeline", Mandatory = $false)]
    [string] $release = "N",
    [Parameter(HelpMessage = "Specifies which properties to get from the settings file, default is all", Mandatory = $false)]
    [string] $get = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0    

. (Join-Path $PSScriptRoot "..\Helpers\AL-Go-Helper.ps1")
$BcContainerHelperPath = DownloadAndImportBcContainerHelper 
import-module (Join-Path -path $PSScriptRoot -ChildPath "..\Helpers\TelemetryHelper.psm1" -Resolve)

$telemetryScope = CreateScope -eventId $telemetryEventId -parentCorrelationId $parentTelemetryScope 

try {
    if ($project  -eq ".") { $project = "" }
    $baseFolder = Join-Path $ENV:GITHUB_WORKSPACE $project
   
    $settings = ReadSettings -baseFolder $baseFolder -workflowName $env:GITHUB_WORKFLOW
    if ($get) {
        $getSettings = $get.Split(',').Trim()
    }
    else {
        $getSettings = @($settings.Keys)
    }

    if ($getSettings -contains 'appBuild' -or $getSettings -contains 'appRevision') {
        switch ($settings.versioningStrategy -band 15) {
            0 { # Use RUNID
                $settings.appBuild = $settings.runNumberOffset + [Int32]($ENV:GITHUB_RUN_NUMBER)
                $settings.appRevision = 0
            }
            1 { # USE DATETIME
                $settings.appBuild = [Int32]([DateTime]::Now.ToString('yyyyMMdd'))
                $settings.appRevision = [Int32]([DateTime]::Now.ToString('hhmmss'))
            }
            default {
                OutputError -message "Unknown version strategy $versionStrategy"
                exit
            }
        }
    }

    $outSettings = @{}
    $getSettings | ForEach-Object {
        $setting = $_.Trim()
        $outSettings += @{ "$setting" = $settings."$setting" }
        Add-Content -Path $env:GITHUB_ENV -Value "$setting=$($settings."$setting")"
    }
    $outSettingsJson = $outSettings | ConvertTo-Json -Compress
    Write-Host "::set-output name=SettingsJson::$outSettingsJson"
    Write-Host "set-output name=SettingsJson::$outSettingsJson"
    Add-Content -Path $env:GITHUB_ENV -Value "Settings=$OutSettingsJson"

    TrackTrace -telemetryScope $telemetryScope
}
catch {
    OutputError -message $_.Exception.Message
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    exit
}
finally {
    # Cleanup
    try {
        Remove-Module BcContainerHelper
        Remove-Item $bcContainerHelperPath -Recurse
    }
    catch {}
}