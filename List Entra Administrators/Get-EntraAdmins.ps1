param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId
)

$requiredModules = @(
    "Microsoft.Graph.Identity.DirectoryManagement",
    "Microsoft.Graph.Groups",
    "Microsoft.Graph.Identity.Governance"
)
Write-Host "Importing required modules..." -ForegroundColor Yellow
foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Host "Installing module: $module" -ForegroundColor Yellow
        Install-Module -Name $module -Scope CurrentUser -Force
    }
    Import-Module -Name $module -Force
}


# Helper function to resolve group members recursively
function Get-GroupMembersRecursive {
    param($groupId)
    $members = @()
    $groupMembers = Get-MgGroupMember -GroupId $groupId -All
    foreach ($member in $groupMembers) {
        if ($member.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.user') {
            $members += $member
        } elseif ($member.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.group') {
            $members += Get-GroupMembersRecursive -groupId $member.Id
        }
    }
    return $members
}


# Connect to Microsoft Graph with Directory.Read.All, RoleManagement.Read.Directory, GroupMember.Read.All
write-host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
Connect-MgGraph -TenantId $TenantId -Scopes "Directory.Read.All","RoleManagement.Read.Directory","GroupMember.Read.All" -NoWelcome

$globalAdminRole = Get-MgDirectoryRoleTemplate | Where-Object {$_.DisplayName -eq "Global Administrator"}
if (-not $globalAdminRole) {
    Write-Error "Global Administrator role template not found."
    exit 1
}
# Get the role definition ID for Global Administrator
$roleDefId = $globalAdminRole.Id

$report = @()


write-host "Getting all active and eligible assignments for Global Administrator..." -ForegroundColor Yellow
# Get all active assignments for Global Administrator
$activeAssignments = Get-MgRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '$roleDefId'" -All

# Get all eligible assignments for Global Administrator (PIM)
$eligibleAssignments = Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance -Filter "roleDefinitionId eq '$roleDefId'" -All

write-host "Found $($activeAssignments.Count) active assignments and $($eligibleAssignments.Count) eligible assignments." -ForegroundColor Green

# Process active assignments
foreach ($assignment in $activeAssignments) {
    $assignmentObject = Get-MgDirectoryObject -DirectoryObjectId $assignment.PrincipalId
    if ($assignmentObject.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.user") {
        $user = Get-MgUser -UserId $assignment.PrincipalId
        $report += [PSCustomObject]@{
            UserPrincipalName = $user.UserPrincipalName
            DisplayName       = $user.DisplayName
            AssignmentType    = "Active"
            AssignmentSource  = "Direct"
        }
    } elseif ($assignmentObject.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.group") {
        $group = Get-MgGroup -GroupId $assignment.PrincipalId
        $members = Get-GroupMembersRecursive -groupId $group.Id
        foreach ($member in $members) {
            $report += [PSCustomObject]@{
                UserPrincipalName = $member.AdditionalProperties.userPrincipalName
                DisplayName       = $member.AdditionalProperties.displayName
                AssignmentType    = "Active"
                AssignmentSource  = "Group ($($group.DisplayName))"
            }
        }
    }
}

# Process eligible assignments
foreach ($eligible in $eligibleAssignments) {
    $eligibleObject = Get-MgDirectoryObject -DirectoryObjectId $eligible.PrincipalId
    if ($eligibleObject.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.user") {
        $user = Get-MgUser -UserId $eligible.PrincipalId
        $report += [PSCustomObject]@{
            UserPrincipalName = $user.UserPrincipalName
            DisplayName       = $user.DisplayName
            AssignmentType    = "Eligible"
            AssignmentSource  = "Direct"
        }
    } elseif ($eligibleObject.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.group") {
        $group = Get-MgGroup -GroupId $eligible.PrincipalId
        $members = Get-GroupMembersRecursive -groupId $group.Id
        foreach ($member in $members) {
            $report += [PSCustomObject]@{
                UserPrincipalName = $member.AdditionalProperties.userPrincipalName
                DisplayName       = $member.AdditionalProperties.displayName
                AssignmentType    = "Eligible"
                AssignmentSource  = "Group ($($group.DisplayName))"
            }
        }
    }
}

# Remove duplicates (in case a user is listed multiple times)
$report = $report | Sort-Object UserPrincipalName, AssignmentType, AssignmentSource -Unique

# Output the report
$report | Format-Table UserPrincipalName, DisplayName, AssignmentType, AssignmentSource
