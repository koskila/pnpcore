param (
    [Parameter(Mandatory = $true)]
    [string]
    $SiteUrl,
    [Parameter(Mandatory = $true)]
    [string]
    $TenantId,
    [Parameter(Mandatory = $true)]
    [ValidateSet('Read', 'Write', 'FullControl')]
    [string]$Permissions,

    [Parameter(Mandatory = $true)]
    [string]
    $CertificatePwd,
    [string]$AzureADAppName = "Demo-AzFunction-ManagedIdentity",
    [string]$CertificateOutDir = ".\Certificates"
)

Import-Module "./ConfigureHelper.ps1"

## if no connection to SPO, connect

if ($null -eq (Get-PnPConnection)){
    Connect-PnPOnline -Url $SiteUrl -Interactive
}
## if no connection to AzureAD, connect
try {
    $connection = Get-AzureADTenantDetail
}
catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] {
    Connect-AzureAD -TenantId  $TenantId
}

# Grant API Permissions to the System Managed Identity
Write-Host "Grant API Permissions to the System-Managed Identity for app $AzureADAppName"
Set-ApiPermissionsMSI -SiteUrl $SiteUrl -TenantId $TenantId `
                     -AzureADAppName $AzureADAppName `
                     -Permissions FullControl

# Add App Registration and grant API permissions
$app=Add-AppRegistration -SiteUrl $SiteUrl -TenantId $TenantId `
                     -AzureADAppName $AzureADAppName `
                     -Permissions FullControl `
                     -CertificatePwd $CertificatePwd  -CertificateOutDir $CertificateOutDir

Write-Host "Saving app settings to local.settings.json"

$localSettings = Get-Content "./../local.settings.json" | ConvertFrom-JSON

$localSettings.Values.SiteName = ([uri](Get-PnPConnection).Url).Segments[2]
$localSettings.Values.TenantName = (Get-AzureADTenantDetail).DisplayName
$localSettings.Values.TenantId = $TenantId
$localSettings.Values.ClientId = $app.'AzureAppId/ClientId'
$localSettings.Values.CertificateThumbPrint = $app.'Certificate Thumbprint'
$localSettings.Values.WEBSITE_LOAD_CERTIFICATES = $app.'Certificate Thumbprint'

($localSettings | ConvertTo-JSON) | Out-File "./../local.settings.json"  -Encoding utf8