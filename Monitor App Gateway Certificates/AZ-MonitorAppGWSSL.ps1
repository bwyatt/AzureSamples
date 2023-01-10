<#
    .SYNOPSIS
    Get-Function displays the name and syntax of all functions in the session.

    .NOTES
    Please note that while being developed by a Microsoft employee, this script is not a Microsoft service or product. 
    This is a personal/community driven project, there are no implicit or explicit obligations related to this project, 
        it is provided 'as is' with no warranties and confer no rights.
#>
Import-Module Az.Accounts, Az.Network

$expirationWindow = 30 # Number of days to use for expiration date comparison
Connect-AzAccount -Identity -ErrorAction Stop
$subs = Get-AzSubscription
$expirationSoonDate = (get-date).AddDays($expirationWindow)

foreach ($sub in $subs) {
    Write-Verbose "Checking subscription $($sub.Name)"
    Set-AzContext -Subscription $sub.Id
    $gateways = Get-AzApplicationGateway

    foreach ($gw in $gateways) {
        Write-Verbose "Checking gateway $($gw.Name) in resource group $($gw.ResourceGroupName)"
        # Get all SSL certs for the gateway, discarding any that are linked to a KeyVault
        $certs = Get-AzApplicationGatewaySslCertificate -ApplicationGateway $gw | Where-Object {$null -eq $_.KeyVaultSecretId}
        
        Write-Verbose "$($certs.Length) non-Key Vault certificates found"

        foreach ($cert in $certs) {
            $certInfo = [System.Security.Cryptography.X509Certificates.X509Certificate2]([System.Convert]::FromBase64String($cert.publicCertData.Substring(60, $cert.publicCertData.Length - 60)))

            if (($certInfo.NotBefore -lt (get-date)) -and ($certinfo.NotAfter -lt $expirationSoonDate)) {
                Write-Warning "Certificate '$($cert.Name)' on gateway '$($gw.Name)' in resource group '$($gw.ResourceGroupName)' in subscription '$($sub.Name)' will expire $($certinfo.NotAfter)"
            }
        }   
    }
}
