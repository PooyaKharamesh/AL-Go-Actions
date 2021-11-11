. (Join-Path $PSScriptRoot "..\Helpers\AL-Go-Helper.ps1")

$signals = @{
    "DO0070" = "AL-Go .AddExistingApp-Action";                       
    "DO0071" = "AL-Go .CheckForUpdates-Action";                      
    "DO0072" = "AL-Go .CreateApp-Action";                            
    "DO0073" = "AL-Go .CreateDevelopmentEnvironment-Action";         
    "DO0074" = "AL-Go .CreateReleaseNotes-Action";                   
    "DO0075" = "AL-Go .Deploy-Action";                               
    "DO0076" = "AL-Go .IncrementVersionNumber-Action";               
    "DO0077" = "AL-Go .PipelineCleanup-Action";                      
    "DO0078" = "AL-Go .ReadSecrets-Action";                          
    "DO0079" = "AL-Go .ReadSettings-Action";                         
    "DO0080" = "AL-Go .RunPipeline-Action";

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

function SetTelemeteryConfiguration {
    
    $userName = ""
    if ($env:USERNAME) {
        $userName = $env:USERNAME
    }

    $baseFolder = Join-Path $PSScriptRoot ".." -Resolve
    $settings = ReadSettings -baseFolder $baseFolder -userName $userName
    
    $bcContainerHelperConfig.MicrosoftTelemetryConnectionString = $settings["MicrosoftTelemetryConnectionString"] 
    $bcContainerHelperConfig.TelemetryConnectionString = $settings["TelemetryConnectionString"] 
    $bcContainerHelperConfig.UseExtendedTelemetry = $settings["UseExtendedTelemetry"]
}

function CreateScope {
    param (
        [string] $eventId,
        [string] $parentCorrelationId,
        [hashtable] $parameters = @{}
    )

    SetTelemeteryConfiguration
    $signalName = $signals[$eventId] 

    if (-not $signalName) {
        throw "Invalid event id ($eventId) is enountered."
    }

    $telemetryScope = InitTelemetryScope -name $signalName -eventId $eventId  -parameterValues @()  -includeParameters @()
   
   # todo it should be set it in the nav container helper
    $telemetryScope["Emitted"] = $false

    if ($parentCorrelationId) {
        $telemetryScope["ParentId"] = $parentCorrelationId
    }

    return $telemetryScope
}