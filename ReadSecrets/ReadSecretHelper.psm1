$gitHubSecrets = $env:Secrets | ConvertFrom-Json
$IsAzKeyvaultSet = $gitHubSecrets.PSObject.Properties.Name -eq "AZURE_CREDENTIALS"
$AzKeyvaultConnectionExists = $false

function GetGithubSecret {
    param (
        [string] $secretName
    )
    $secretSplit = $secretName.Split('=')
    $envVar = $secretSplit[0]
    $secret = $envVar
    if ($secretSplit.Count -gt 1) {
        $secret = $secretSplit[1]
    }
    
    if ($gitHubSecrets.PSObject.Properties.Name -eq $secret) {
        $value = $githubSecrets."$secret"
        if ($value) {
            MaskValueInLog -value $value
            Add-Content -Path $env:GITHUB_ENV -Value "$envVar=$value"
            Write-Host "Secret $envVar successfully read from GitHub Secret $secret"
            return $value
        }
    }

    return $null
}
	
function Get-AzKeyVaultCredentials {
    if (-not $script:IsAzKeyvaultSet) {
        throw "AZURE_CREDENTIALS is not set in your repo."
    }   

    try {
        return $gitHuBSecrets.AZURE_CREDENTIALS | ConvertFrom-Json
    }
    catch {
        throw "AZURE_CREDENTIALS are wrongly formatted."
    }

    throw "AZURE_CREDENTIALS are missing. In order to use a Keyvault, please add an AZURE_CREDENTIALS secret like explained here: https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure"
}

function InstallKeyVaultModuleIfNeeded {
    if (-not $script:IsAzKeyvaultSet) {
        return
    }

    if (-not (Get-InstalledModule -Name 'Az.KeyVault' -erroraction 'silentlycontinue')) {
        # module is not loaded
        installModules -modules @('Az.KeyVault')
    }
}

function ConnectAzureKeyVaultIfNeeded {
    param( 
        [string] $subscriptionId,
        [string] $tenantId,
        [string] $clientId ,
        [string] $clientSecret 
    )
    try {
        if ($script:AzKeyvaultConnectionExists) {
            return
        }

        Clear-AzContext -Scope Process
        Clear-AzContext -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        $credential = New-Object PSCredential -argumentList $clientId, (ConvertTo-SecureString $clientSecret -AsPlainText -Force)
        Connect-AzAccount -ServicePrincipal -Tenant $tenantId -Credential $credential | Out-Null
        Set-AzContext -Subscription $subscriptionId -Tenant $tenantId | Out-Null
        $script:AzKeyvaultConnectionExists = $true
        Write-Host "Successfuly connected to Azure Key Vault."
    }
    catch {
        throw "Error trying to authenticate to Azure using Az. Error was $($_.Exception.Message)"
    }
}

function GetKeyVaultSecret {
    param (
        [string] $secretName
    )

    if (-not $script:IsAzKeyvaultSet) {
        return $null
    }
        
    if (-not $script:AzKeyvaultConnectionExists) {
            
        InstallKeyVaultModuleIfNeeded
            
        $credentialsJson = Get-AzKeyVaultCredentials
        $clientId = $credentialsJson.clientId
        $clientSecret = $credentialsJson.clientSecret
        $subscriptionId = $credentialsJson.subscriptionId
        $tenantId = $credentialsJson.tenantId
            
        if ($script:keyVaultName -eq "" -and ($credentialsJson.PSObject.Properties.Name -eq "KeyVaultName")) {
            $script:keyVaultName = $credentialsJson.KeyVaultName
        }

        ConnectAzureKeyVaultIfNeeded -subscriptionId $subscriptionId -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret
    }

    $keyVaultSecret = Get-AzKeyVaultSecret -VaultName $script:keyVaultName -Name $secret 
    if ($keyVaultSecret) {
        $value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(([Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyVaultSecret.SecretValue)))
        MaskValueInLog -value $value
        MaskValueInLog -value $value.Replace('&', '\u0026')
        return $value
    }

    return $null
}

function GetSecret {
    param (
        $secret
    )

    Write-Host "Try get the secret($secret) from the github environment"
    $value = GetGithubSecret -secretName $secret
    if ($value) {
        Write-Host "Secret($secret) was retrieved from the github environment."
        return $value
    }

    Write-Host "Try get the secret($secret) from Key Vault"
    $value = GetKeyVaultSecret -secretName $secret
    if ($value) {
        Write-Host "Secret($secret) was retrieved from the Key Vault."
        return $value
    }

    Write-Host  "Could not find secret $secret in Github secrets or Azure Key Vault."
    return $null
}
