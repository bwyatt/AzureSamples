<#
    .SYNOPSIS
    Copy blobs from one storage account to another using AzCopy and API-issued SAS tokens

    .NOTES
    Please note that while being developed by a Microsoft employee, this script is not a Microsoft service or product. 
    This is a personal/community driven project, there are no implicit or explicit obligations related to this project, 
        it is provided 'as is' with no warranties and confer no rights.
#>
param(
    # Required parameters
    [Parameter(Mandatory=$true)]
    [string[]]$SourceAccount,
    [Parameter(Mandatory=$true)]
    [string[]]$SourceContainer,
    [Parameter(Mandatory=$true)]
    [string[]]$DestinationAccount,
    [Parameter(Mandatory=$true)]
    [string[]]$DestinationContainer,
    [Parameter(Mandatory=$true)]
    [string[]]$DestinationSasToken,

    # One of these parameters must be used, but not both
    [Parameter(Mandatory=$true, ParameterSetName="Pattern")] 
    [string[]]$Pattern,
    [Parameter(Mandatory=$true, ParameterSetName="Regex")]
    [string[]]$Regex,

    # Optional parameters
    [datetime]$BeforeDate,
    [datetime]$AfterDate,
    [ValidateSet("true", "false", "ifSourceNewer")]
    [switch]$Overwrite,
    [switch]$Dryrun
)

# Set up environment
$SourceTokenApiEndpoint = "https://api.example.com/sourceToken"
$ApiTimeout = 15 # The timeout period for the API call to retrieve source SAS Token, in seconds

#region Get SAS token for source account from an API - Customize this region for the API being used
$SourceSasToken = ""
try {
    $ApiResponse = Invoke-RestMethod -Uri $SourceTokenApiEndpoint `
                        -StatusCodeVariable "ApiStatusCode" -OperationTimeoutSeconds $ApiTimeout

    # TODO: Parse API status code and proceed based on the code
    if ($ApiStatusCode -notin 200..299) {
        Write-Host "API returned status code $ApiStatusCode"
        return 1
    }

    $SourceSasToken = $ApiResponse.token

}
catch [System.Net.WebException] {
    Write-Host "An exception occurred while requesting the SAS Token:"
    Write-Host $_

    return 2

}
catch {
    Write-Host "An unknown error occurred at $($_.ScriptStackTrace):"
    Write-Host $_

    return 3
}

#endregion

#region Build and execute Azcopy command
$CopyArgs = "'https://$($SourceAccount).blob.core.windows.net/$($SourceContainer)/?$($SourceSasToken)' "
$CopyArgs += "'https://$($DestinationAccount).blob.core.windows.net/$($DestinationContainer)/?$($DestinationSasToken)' "

if ($Pattern) {
    $CopyArgs += "--include-pattern `"$($Pattern)`" "
}
elseif ($Regex) {
    $CopyArgs += "--include-regex `"$($Regex)`" "
}


# Add optional parameters
if ($BeforeDate) {
    $CopyArgs += "--include-before `"$($BeforeDate)`" "
}

if ($AfterDate) {
    $CopyArgs += "--include-after `"$($AfterDate)`" "
}

if ($Overwrite) {
    $CopyArgs += "--overwrite `"$($Overwrite)`" "
}

if ($Dryrun) {
    $CopyArgs += "--dry-run "
}

# Execute copy
azcopy copy $CopyArgs
#endregion
