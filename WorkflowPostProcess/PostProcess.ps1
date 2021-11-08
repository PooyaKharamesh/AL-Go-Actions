Param(
    [Parameter(HelpMessage = "Name of workflow initiating the workflow", Mandatory = $false)]
    [string] $workflowName = $env:GITHUB_WORKFLOW,
    [Parameter(HelpMessage = "Telemetry scope generated during the workflow initialization", Mandatory = $false)]
    $telemetryScopeJson = $null
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

try {
    . (Join-Path $PSScriptRoot "..\AL-Go-Helper.ps1")
    $BcContainerHelperPath = DownloadAndImportBcContainerHelper 
    $bcContainerHelperConfig.TelemetryConnectionString = "InstrumentationKey=b503f4de-5674-4d35-8b3e-df9e815e9473;IngestionEndpoint=https://westus2-2.in.applicationinsights.azure.com/"
    $bcContainerHelperConfig.UseExtendedTelemetry = $true

    $telemetryScope = @{}
    (ConvertFrom-Json $telemetryScopeJson).psobject.properties | ForEach-Object { $telemetryScope[$_.Name] = $_.Value }
    Write-Host "here is the scope : $($telemetryScope|ConvertTo-Json) "

    if (-not $telemetryScope) {
        Write-Host "Could not find a valid telemetry scope. A telemetry scope would be created."
        $telemetryScope = InitTelemetryScope -name $workflowName -eventId "test1"  -parameterValues $PSBoundParameters -includeParameters @()
    }
}
catch {
    OutputError -message $_.Exception.Message
    TrackException -telemetryScope $telemetryScope -errorRecord $_
}
finally {
    Write-Host "Emitting the telemetry signal."
    TrackTrace -telemetryScope $telemetryScope

    # Cleanup
    try {
        Remove-Module BcContainerHelper
        Remove-Item $bcContainerHelperPath -Recurse
    }
    catch {}
}
