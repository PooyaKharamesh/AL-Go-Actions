Param(
    [Parameter(HelpMessage = "The GitHub actor running the action", Mandatory = $false)]
    [string] $actor,
    [Parameter(HelpMessage = "The GitHub token running the action", Mandatory = $false)]
    [string] $token,
    [Parameter(HelpMessage = "Specifies the parent correlation Id for the Telemetry signal", Mandatory = $false)]
    [string] $parentCorrelationId,
    [Parameter(HelpMessage = "Specifies the event Id in the telemetry", Mandatory = $false)]
    [bool] $telemetryEventId,
    [Parameter(HelpMessage = "Projects to deploy (default is all)", Mandatory = $false)]
    [string] $projects = "*",
    [Parameter(HelpMessage = "Name of environment to deploy to", Mandatory = $true)]
    [string] $environmentName,
    [Parameter(HelpMessage = "Artifacts to deploy", Mandatory = $true)]
    [string] $artifacts,
    [Parameter(HelpMessage = "Type of deployment (CD or Publish)", Mandatory = $false)]
    [ValidateSet('CD','Publish')]
    [string] $type = "CD"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

. (Join-Path $PSScriptRoot "..\Helpers\AL-Go-Helper.ps1")
$BcContainerHelperPath = DownloadAndImportBcContainerHelper 
import-module (Join-Path -path $PSScriptRoot -ChildPath "..\Helpers\TelemetryHelper.psm1" -Resolve)

$telemetryScope = CreateScope -eventId $telemetryEventId -parentCorrelationId $parentCorrelationId 

try {
    if ($projects -eq '') { $projects = "*" }

    $apps = @()
    $baseFolder = Join-Path $ENV:GITHUB_WORKSPACE "artifacts"

    if ($artifacts -like "$($baseFolder)*") {
        $apps
        if (Test-Path $artifacts -PathType Container) {
            $apps = @((Get-ChildItem -Path $artifacts -Filter "*-Apps-*") | ForEach-Object { $_.FullName })
            if (!($apps)) {
                OutputError -message "No artifacts present in $artifacts"
                exit
            }
        }
        elseif (Test-Path $artifacts) {
            $apps = $artifacts
        }
        else {
            OutputError -message "Unable to use artifact $artifacts"
            exit
        }
    }
    elseif ($artifacts -eq "current" -or $artifacts -eq "prerelease" -or $artifacts -eq "draft") {
        # latest released version
        $releases = GetReleases -token $token -api_url $ENV:GITHUB_API_URL -repository $ENV:GITHUB_REPOSITORY
        if ($artifacts -eq "current") {
            $release = $releases | Where-Object { -not ($_.prerelease -or $_.draft) } | Select-Object -First 1
        }
        elseif ($artifacts -eq "prerelease") {
            $release = $releases | Where-Object { -not ($_.draft) } | Select-Object -First 1
        }
        elseif ($artifacts -eq "draft") {
            $release = $releases | Select-Object -First 1
        }
        if (!($release)) {
            OutputError -message "Unable to locate $artifacts release"
            exit
        }
        New-Item $baseFolder -ItemType Directory | Out-Null
        DownloadRelease -token $token -projects $projects -api_url $ENV:GITHUB_API_URL -repository $ENV:GITHUB_REPOSITORY -release $release -path $baseFolder
        $apps = @((Get-ChildItem -Path $baseFolder) | ForEach-Object { $_.FullName })
        if (!$apps) {
            OutputError -message "Unable to download $artifacts release"
            exit
        }
    }
    else {
        New-Item $baseFolder -ItemType Directory | Out-Null
        $allArtifacts = GetArtifacts -token $token -api_url $ENV:GITHUB_API_URL -repository $ENV:GITHUB_REPOSITORY
        $artifactsVersion = $artifacts
        if ($artifacts -eq "latest") {
            $artifact = $allArtifacts | Where-Object { $_.name -like "*-Apps-*" } | Select-Object -First 1
            $artifactsVersion = $artifact.name.SubString($artifact.name.IndexOf('-Apps-')+6)
        }
        $projects.Split(',') | ForEach-Object {
            $project = $_
            $allArtifacts | Where-Object { $_.name -like "$project-Apps-$artifactsVersion" } | ForEach-Object {
                DownloadArtifact -token $token -artifact $_ -path $baseFolder
            }
        }
        $apps = @((Get-ChildItem -Path $baseFolder) | ForEach-Object { $_.FullName })
        if (!($apps)) {
            OutputError -message "Unable to download artifact $project-Apps-$artifacts"
            exit
        }
    }

    Set-Location $baseFolder
    if (-not ($ENV:AUTHCONTEXT)) {
        OutputError -message "You need to create an environment secret called AUTHCONTEXT containing authentication information for the environment $environmentName"
        exit
    }

    try {
        $authContextParams = $ENV:AUTHCONTEXT | ConvertFrom-Json | ConvertTo-HashTable
        $bcAuthContext = New-BcAuthContext @authContextParams
    } catch {
        OutputError -message "Error trying to authenticate. Error was $($_.exception.message)"
        exit
    }

    $envName = $environmentName.Split(' ')[0]
    $environment = Get-BcEnvironments -bcAuthContext $bcAuthContext | Where-Object { $_.Name -eq $envName }
    if (-not ($environment)) {
        OutputError -message "Environment with name $envName does not exist in the current authorization context."
        exit
    }

    $apps | ForEach-Object {
        try {
            if ($environment.type -eq "Sandbox") {
                Write-Host "Publishing apps using development endpoint"
                Publish-BcContainerApp -bcAuthContext $bcAuthContext -environment $envName -appFile $_ -useDevEndpoint
            }
            else {
                if ($type -eq 'CD') {
                    Write-Host "Ignoring environment $environmentName, which is a production environment"
                }
                else {

                    # Check for AppSource App - cannot be deployed

                    Write-Host "Publishing apps using automation API"
                    Publish-PerTenantExtensionApps -bcAuthContext $bcAuthContext -environment $envName -appFiles $_
                }
            }
        }
        catch {
            OutputError -message "Error deploying to $environmentName. Error was $($_.Exception.Message)"
            exit
        }
    }

    TrackTrace -telemetryScope $telemetryScope

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
