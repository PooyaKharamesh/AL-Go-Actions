Param(
    [Parameter(HelpMessage = "Name of workflow initiating the workflow", Mandatory = $false)]
    [string] $workflowName = $env:GITHUB_WORKFLOW
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

try {
    . (Join-Path $PSScriptRoot "..\AL-Go-Helper.ps1")
    $BcContainerHelperPath = DownloadAndImportBcContainerHelper 
    
    $bcContainerHelperConfig.MicrosoftTelemetryConnectionString = "InstrumentationKey=b503f4de-5674-4d35-8b3e-df9e815e9473;IngestionEndpoint=https://westus2-2.in.applicationinsights.azure.com/"
    $bcContainerHelperConfig.UseExtendedTelemetry = $true
    $bcContainerHelperConfig

    $telemetryScope = InitTelemetryScope -name $workflowName -eventId "test1" -parameterValues $PSBoundParameters -includeParameters @()

    
    if (-not $telemetryScope.CorrelationId) {
        $telemetryScope["CorrelationId"] = (New-Guid).ToString()
    } 

    $telemetryScope["Emitted"] = $false
    
    Write-Host "::set-output name=telemetryScope::$telemetryScope"
    Write-Host "set-output name=telemetryScope::$($telemetryScope | ConvertTo-Json)"

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
