<#
    .SYNOPSIS
    Copy blobs from one storage account to another using AzCopy and an API-issued SAS token

    .DESCRIPTION
    Copy blobs from one Azure storage account container to another, using SAS tokens for authentication. The Source account SAS token is retrieved via an API. The Destination account SAS token is provided as an argument.

    When calling this script, you must provide either a blob name Pattern or Regular Expression via parameters. The script will not execute if these options are omitted, and only one may be provided.

    The API call demonstrated in this script is an example only and isn't targeting a specific existing API. That section should be customized to conform to the API to be used. The remainder of the script expects the Source storage account SAS token to be held in a string variable named $SourceSasToken. 

    .PARAMETER SourceAccount
    The name of the source storage account. Note that this is the account name only, not the URL.

    .PARAMETER SourceContainer
    The name of the blob container to be copied from

    .PARAMETER DestinationAccount
    The name of the destination storage account. Note that this is the account name only, not the URL.

    .PARAMETER DestinationContainer
    The name of the blob container to be copied to

    .PARAMETER DestinationSasToken
    The SAS token to be used to authenticate to the destination storage accountl

    .PARAMETER Pattern
    The blob name pattern to pass to AzCopy's --include-pattern argument. Use * as a wildcard. Blobs with names which match the pattern will be copied.

    .PARAMETER Regex
    An alternative to -Pattern, a regular expression to pass to AzCopy's --include-regex argument. Blobs with names which match the expression will be copied.

    .PARAMETER BeforeDate
    Optional. If provided, the copy operation will include only blobs created before this date.

    .PARAMETER AfterDate
    Optional. If provided, the copy operation will include only blobs created after this date.

    .PARAMETER Overwrite
    Optional. Passed to AzCopy's --overwrite argument. Possible values are 'true', 'false', and 'ifSourceNewer'. 'Prompt' is supported by AzCopy but is not supported in this script, which is intended to run unattended.

    .PARAMETER Dryrun
    Optional. If included, AzCopy will run with the --dry-run argument. This allows you to preview what would be copied without performing the copy. When this flag is included, the -Overwrite parameter has no effect. 

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
    # For help crafting the API request, refer to the documentation for Invoke-RestMethod here: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-restmethod
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
