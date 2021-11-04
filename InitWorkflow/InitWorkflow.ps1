Param(
    [Parameter(HelpMessage = "Name of workflow initiating the workflow", Mandatory = $false)]
    [string] $workflowName = $env:GITHUB_WORKFLOW
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

try {
    . (Join-Path $PSScriptRoot "..\AL-Go-Helper.ps1")
    $BcContainerHelperPath = DownloadAndImportBcContainerHelper 

    $telemetryScope = InitTelemetryScope -name $workflowName -eventId "test1" -parameterValues $PSBoundParameters -includeParameters @()
    Write-Host "::set-output name=telemetryScope::$telemetryScope"
    Write-Host "set-output name=telemetryScope::$telemetryScope"
    if (-not $telemetryScope.CorrelationId) {
        $telemetryScope.CorrelationId = (New-Guid).ToString()
    }
     
    $correlationId = ($telemetryScope.CorrelationId).ToString()
    Write-Host "::set-output name=correlationId::$correlationId"
    Write-Host "set-output name=correlationId::$correlationId"
}
catch {
    OutputError -message $_.Exception.Message
    TrackException -telemetryScope $telemetryScope -errorRecord $_
}
finally {
    # Cleanup
    try {
        Remove-Module BcContainerHelper
        Remove-Item $bcContainerHelperPath -Recurse
    }
    catch {}
}
