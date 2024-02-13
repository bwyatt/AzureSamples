<#
    .SYNOPSIS
    Copy blobs from one storage account to another using AzCopy and API-issued SAS tokens

    .NOTES
    Please note that while being developed by a Microsoft employee, this script is not a Microsoft service or product. 
    This is a personal/community driven project, there are no implicit or explicit obligations related to this project, 
        it is provided 'as is' with no warranties and confer no rights.
#>
param(
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
    [Parameter(Mandatory=$true, ParameterSetName="Pattern")] 
    [PSDefaultValue(Value="*")]
    [string[]]$Pattern,
    [Parameter(Mandatory=$true, ParameterSetName="Regex")]
    [datetime]$BeforeDate,
    [datetime]$AfterDate,
    [string[]]$Regex,
    [switch]$OverwriteDestination,
    [switch]$Dryrun
)


# TODO: Determine required permissions for SAS tokens

# Get SAS token for source account from a web service
# As a best practice, the token should be short-lived and have only the necessary permissions to perform the copy operation


# Build AzCopy command w/ configuration and tokens
    # TODO: Implement support for --dry-run flag on AzCopy; fetch the tokens and use them just for the dry run

# Execute copy
