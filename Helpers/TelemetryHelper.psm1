. (Join-Path $PSScriptRoot "..\AL-Go-Helper.ps1")

$signals = @{
    "DO0070" = "AL-Go.AddExistingApp-Action";                       
    "DO0071" = "AL-Go.CheckForUpdates-Action";                      
    "DO0072" = "AL-Go.CreateApp-Action";                            
    "DO0073" = "AL-Go.CreateDevelopmentEnvironment-Action";         
    "DO0074" = "AL-Go.CreateReleaseNotes-Action";                   
    "DO0075" = "AL-Go.Deploy-Action";                               
    "DO0076" = "AL-Go.IncrementVersionNumber-Action";               
    "DO0077" = "AL-Go.PipelineCleanup-Action";                      
    "DO0078" = "AL-Go.ReadSecrets-Action";                          
    "DO0079" = "AL-Go.ReadSettings-Action";                         
    "DO0080" = "AL-Go.RunPipeline-Action";

    "DO0090" = "AL-Go.AddExistingAppOrTestApp-Workflow";            
    "DO0091" = "AL-Go.CiCd-Workflow";                               
    "DO0092" = "AL-Go.CreateApp-Workflow";                          
    "DO0093" = "AL-Go.CreateOnlineDevelopmentEnvironment-Workflow"; 
    "DO0094" = "AL-Go.CreateRelease-Workflow";                      
    "DO0095" = "AL-Go.CreateTestApp-Workflow";                      
    "DO0096" = "AL-Go.IncrementVersionNumber-Workflow";             
    "DO0097" = "AL-Go.PublishToEnvironment-Workflow";               
    "DO0098" = "AL-Go.UpdateGitHubGoSystemFiles-Workflow";    
}


function GetTelemetrySignal {
    param (
        [string] $eventId
    )
    
    return $signals[$eventId] 
}

function GetTelemeteryConfiguration {

    Write-Host "Reading telemetry settings."
    return @{
        MicrosoftTelemetryConnectionString = "InstrumentationKey=b503f4de-5674-4d35-8b3e-df9e815e9473;IngestionEndpoint=https://westus2-2.in.applicationinsights.azure.com/";
        PartnerTelemetryConnectionString   = "InstrumentationKey=b503f4de-5674-4d35-8b3e-df9e815e9473;IngestionEndpoint=https://westus2-2.in.applicationinsights.azure.com/";
        UseExtendedTelemetry               = $false
    }
}

function CreateScope {
    param (
        [string] $eventId,
        [string] $parentCorrelationId,
        [hashtable] $parameters = @{}
    )

    $telemetryconfig = GetTelemeteryConfiguration

    $bcContainerHelperConfig.MicrosoftTelemetryConnectionString = $telemetryconfig["MicrosoftTelemetryConnectionString"] 
    $bcContainerHelperConfig.PartnerTelemetryConnectionString = $telemetryconfig["PartnerTelemetryConnectionString"] 
    $bcContainerHelperConfig.UseExtendedTelemetry = $telemetryconfig["UseExtendedTelemetry"]

    $signal = GetTelemetrySignal -eventId $eventId

    if (-not $signal) {
        throw "Invalid event id ($eventId) is enountered."
    }

    $telemetryScope = InitTelemetryScope -name $signal["name"] -eventId $eventId -parameterValues $parameters.PSBase.Values -includeParameters $parameters.PSBase.Keys 
    $telemetryScope["Emitted"] = $false
    $telemetryScope[""] = $false

    if ($parentCorrelationId) {
        $telemetryScope["ParentId"] = $parentCorrelationId
    }

    return $telemetryScope
}