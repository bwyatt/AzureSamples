# Problem Summary

Azure App Gateway provides two mechanisms to apply SSL certificates to listeners: (1) Certificates directly uploaded and applied to the listener, and (2) Certificates uploaded to Azure Key Vault. Option 2 is considered best practice and should be used whenever possible, especially when a certificate may be used by multiple gateways.

Gateways configured via option 1 don't have a built-in mechanism for monitoring certificate expiration. This is especially problematic for organizations which have deployed a large number of gateways with this configuration.

Long-term, these organizations should move to option 2. If operational challenges exist, or if the migration will take a significant amount of time, this solution provides a workable method for monitoring directly-applied certificates for expiration.

# Requirements

* A Log Analytics workspace
* A [User-Defined Managed Identity](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-manage-user-assigned-managed-identities) - I recommend a dedicated identity for this solution
* An Azure Automation Account
* An [Azure Automation Runbook (PowerShell)](https://learn.microsoft.com/en-us/azure/automation/automation-runbook-types?tabs=lps51%2Cpy27#powershell-runbooks) - Note that this is different from a _PowerShell Workflow_ runbook
* `AZ-MonitorAppGWSSL.ps1` from this folder

# How it Works

The PowerShell script authenticates as the Managed Identity, iterates over all the Application Gateways it has access to read, and inspects the SSL configuration of every listener on the Application Gateway. It ignores listeners which use Azure Key Vault certificates, because Key Vault has its own built-in monitoring functionality that should be used instead for those listeners.

When it identifies an SSL certificate that will expire within a configurable window, it raises a Warning. This gets logged into Log Analytics, which can then be used to raise an Alert from Azure Monitor.

To change the length of the expiration window, update the value of the `$expirationWindow` variable.

# Configuration

* Assign the User-Defined Managed Identity to the Automation Account which hosts the Runbook
* Configure the Diagnostic Settings on the Automation Account to send to the Log Analytics Workspace
* Add the contents of `AZ-MonitorAppGWSSL.ps1` to the Runbook
* [Create an Azure Monitor Alert Rule](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-create-new-alert-rule?tabs=metric) that is triggered by Warnings in Log Analytics
