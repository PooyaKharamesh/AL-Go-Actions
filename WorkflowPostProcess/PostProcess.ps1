Param(
    [Parameter(HelpMessage = "Name of workflow initiating the workflow", Mandatory = $false)]
    [string] $workflowName = $env:GITHUB_WORKFLOW,
    [Parameter(HelpMessage = "Telemetry scope generated during the workflow initialization", Mandatory = $false)]
    $telemetryScopeJson = $null
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
. (Join-Path $PSScriptRoot "..\AL-Go-Helper.ps1")
$BcContainerHelperPath = DownloadAndImportBcContainerHelper 
try {

    $bcContainerHelperConfig.MicrosoftTelemetryConnectionString = "InstrumentationKey=b503f4de-5674-4d35-8b3e-df9e815e9473;IngestionEndpoint=https://westus2-2.in.applicationinsights.azure.com/"
    $bcContainerHelperConfig.PartnerTelemetryConnectionString = "InstrumentationKey=b503f4de-5674-4d35-8b3e-df9e815e9473;IngestionEndpoint=https://westus2-2.in.applicationinsights.azure.com/"
    $bcContainerHelperConfig.UseExtendedTelemetry = $false

    $telemetryScope = $telemetryScopeJson| ConvertFrom-Json | ConvertTo-HashTable 

    $localTelemetryScope = InitTelemetryScope -eventId $workflowName 
    $localTelemetryScope.CorrelationId = $telemetryScope.CorrelationId
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
