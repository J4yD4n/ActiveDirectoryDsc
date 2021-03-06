$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:localizationModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'ActiveDirectoryDsc.Common'
Import-Module -Name (Join-Path -Path $script:localizationModulePath -ChildPath 'ActiveDirectoryDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_ADObjectPermissionEntry'

<#
    .SYNOPSIS
        Get the current state of the object permission entry.

    .PARAMETER Path
        Active Directory path of the target object to add or remove the
        permission entry, specified as a Distinguished Name.

    .PARAMETER IdentityReference
        Indicates the identity of the principal for the permission entry.

    .PARAMETER AccessControlType
        Indicates whether to Allow or Deny access to the target object.

    .PARAMETER ObjectType
        The schema GUID of the object to which the access rule applies.

    .PARAMETER ActiveDirectorySecurityInheritance
        One of the 'ActiveDirectorySecurityInheritance' enumeration values that
        specifies the inheritance type of the access rule.

    .PARAMETER InheritedObjectType
        The schema GUID of the child object type that can inherit this access
        rule.

    .PARAMETER Credential
        Specifies the user account credentials to use to perform the task.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $IdentityReference,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Allow', 'Deny')]
        [System.String]
        $AccessControlType,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ObjectType,

        [Parameter(Mandatory = $true)]
        [ValidateSet('All', 'Children', 'Descendents', 'None', 'SelfAndChildren')]
        [System.String]
        $ActiveDirectorySecurityInheritance,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InheritedObjectType,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential
    )

    # Return object, by default representing an absent ace
    $returnValue = @{
        Ensure                             = 'Absent'
        Path                               = $Path
        IdentityReference                  = $IdentityReference
        ActiveDirectoryRights              = ''
        AccessControlType                  = $AccessControlType
        ObjectType                         = $ObjectType
        ActiveDirectorySecurityInheritance = $ActiveDirectorySecurityInheritance
        InheritedObjectType                = $InheritedObjectType
    }

    try
    {
        # Get the current acl
        $DirectoryEntry = Get-DirectoryEntry -Path $Path -Credential $Credential
    }
    catch [System.Management.Automation.ItemNotFoundException]
    {
        Write-Verbose -Message ($script:localizedData.ObjectPathIsAbsent -f $Path)
        $DirectoryEntry = $null
    }
    catch
    {
        throw $_
    }

    if ($null -ne $DirectoryEntry)
    {
        $FoundEntry = $DirectoryEntry.ObjectSecurity.Access | Where-Object {
            $_.IsInherited -eq $false -and
            $_.IdentityReference.Value -eq $IdentityReference -and
            $_.AccessControlType -eq $AccessControlType -and
            $_.ObjectType.Guid -eq $ObjectType -and
            $_.InheritanceType -eq $ActiveDirectorySecurityInheritance -and
            $_.InheritedObjectType.Guid -eq $InheritedObjectType
        }

        if ($null -ne $FoundEntry)
        {
            $returnValue['Ensure'] = 'Present'
            $returnValue['ActiveDirectoryRights'] = [System.String[]] $FoundEntry.ActiveDirectoryRights.ToString().Split(',').ForEach( { $_.Trim() })
        }
    }

    if ($returnValue.Ensure -eq 'Present')
    {
        Write-Verbose -Message ($script:localizedData.ObjectPermissionEntryFound -f $Path)
    }
    else
    {
        Write-Verbose -Message ($script:localizedData.ObjectPermissionEntryNotFound -f $Path)
    }

    return $returnValue
}

<#
    .SYNOPSIS
        Add or remove the object permission entry.

    .PARAMETER Ensure
        Indicates if the access will be added (Present) or will be removed
        (Absent). Default is 'Present'.

    .PARAMETER Path
        Active Directory path of the target object to add or remove the
        permission entry, specified as a Distinguished Name.

    .PARAMETER IdentityReference
        Indicates the identity of the principal for the permission entry.

    .PARAMETER ActiveDirectoryRights
        A combination of one or more of the ActiveDirectoryRights enumeration
        values that specifies the rights of the access rule. Default is
        'GenericAll'.

    .PARAMETER AccessControlType
        Indicates whether to Allow or Deny access to the target object.

    .PARAMETER ObjectType
        The schema GUID of the object to which the access rule applies.

    .PARAMETER ActiveDirectorySecurityInheritance
        One of the 'ActiveDirectorySecurityInheritance' enumeration values that
        specifies the inheritance type of the access rule.

    .PARAMETER InheritedObjectType
        The schema GUID of the child object type that can inherit this access
        rule.

    .PARAMETER Credential
        Specifies the user account credentials to use to perform the task.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $IdentityReference,

        [Parameter()]
        [ValidateSet('AccessSystemSecurity', 'CreateChild', 'Delete', 'DeleteChild', 'DeleteTree', 'ExtendedRight', 'GenericAll', 'GenericExecute', 'GenericRead', 'GenericWrite', 'ListChildren', 'ListObject', 'ReadControl', 'ReadProperty', 'Self', 'Synchronize', 'WriteDacl', 'WriteOwner', 'WriteProperty')]
        [System.String[]]
        $ActiveDirectoryRights = 'GenericAll',

        [Parameter(Mandatory = $true)]
        [ValidateSet('Allow', 'Deny')]
        [System.String]
        $AccessControlType,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ObjectType,

        [Parameter(Mandatory = $true)]
        [ValidateSet('All', 'Children', 'Descendents', 'None', 'SelfAndChildren')]
        [System.String]
        $ActiveDirectorySecurityInheritance,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InheritedObjectType,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential
    )

    try
    {
        # Get the current acl
        $DirectoryEntry = Get-DirectoryEntry -Path $Path -Credential $Credential
    }
    catch [System.Management.Automation.ItemNotFoundException]
    {
        Write-Verbose -Message ($script:localizedData.ObjectPathIsAbsent -f $Path)
        $DirectoryEntry = $null
    }
    catch
    {
        throw $_
    }

    if ($Ensure -eq 'Present')
    {
        $FoundEntry = $null
        $FoundEntry = $DirectoryEntry.ObjectSecurity.Access | Where-Object {
            $_.IsInherited -eq $false -and
            $_.IdentityReference.Value -eq $IdentityReference -and
            $_.AccessControlType -eq $AccessControlType -and
            $_.ObjectType.Guid -eq $ObjectType -and
            $_.InheritanceType -eq $ActiveDirectorySecurityInheritance -and
            $_.InheritedObjectType.Guid -eq $InheritedObjectType
        }
        Write-Verbose -Message ($script:localizedData.AddingObjectPermissionEntry -f $Path)

        $ntAccount = New-Object -TypeName 'System.Security.Principal.NTAccount' -ArgumentList $IdentityReference
        $ntAccount = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
        $ace = New-Object -TypeName 'System.DirectoryServices.ActiveDirectoryAccessRule' -ArgumentList $ntAccount, $ActiveDirectoryRights, $AccessControlType, $ObjectType, $ActiveDirectorySecurityInheritance, $InheritedObjectType

        if ($null -ne $FoundEntry)
        {
            #Remove the existing record and create a new record with the updated permissions
            if ($FoundEntry.ActiveDirectoryRights -ne $ActiveDirectoryRights)
            {
                $DirectoryEntry.ObjectSecurity.RemoveAccessRule($FoundEntry)
                $DirectoryEntry.ObjectSecurity.AddAccessRule($ace)
            }
            else
            {
                #Record already exists and is correct
            }
        }
        else
        {
            $DirectoryEntry.ObjectSecurity.AddAccessRule($ace)
        }
    }
    else
    {
        <#
            Iterate through all ace entries to find the desired ace, which
            should be absent. If found, remove the ace from the acl.
        #>
        $FoundEntry = $null
        $FoundEntry = $DirectoryEntry.ObjectSecurity.Access | Where-Object {
            $_.IsInherited -eq $false -and
            $_.IdentityReference.Value -eq $IdentityReference -and
            $_.AccessControlType -eq $AccessControlType -and
            $_.ObjectType.Guid -eq $ObjectType -and
            $_.InheritanceType -eq $ActiveDirectorySecurityInheritance -and
            $_.InheritedObjectType.Guid -eq $InheritedObjectType
        }
        if ($null -ne $FoundEntry)
        {
            Write-Verbose -Message ($script:localizedData.RemovingObjectPermissionEntry -f $Path)

            $DirectoryEntry.ObjectSecurity.RemoveAccessRuleSpecific($FoundEntry)
        }
    }

    # Update the acl on the object
    $DirectoryEntry.CommitChanges()
}

<#
    .SYNOPSIS
        Test the object permission entry.

    .PARAMETER Ensure
        Indicates if the access will be added (Present) or will be removed
        (Absent). Default is 'Present'.

    .PARAMETER Path
        Active Directory path of the target object to add or remove the
        permission entry, specified as a Distinguished Name.

    .PARAMETER IdentityReference
        Indicates the identity of the principal for the permission entry.

    .PARAMETER ActiveDirectoryRights
        A combination of one or more of the ActiveDirectoryRights enumeration
        values that specifies the rights of the access rule. Default is
        'GenericAll'.

    .PARAMETER AccessControlType
        Indicates whether to Allow or Deny access to the target object.

    .PARAMETER ObjectType
        The schema GUID of the object to which the access rule applies.

    .PARAMETER ActiveDirectorySecurityInheritance
        One of the 'ActiveDirectorySecurityInheritance' enumeration values that
        specifies the inheritance type of the access rule.

    .PARAMETER InheritedObjectType
        The schema GUID of the child object type that can inherit this access
        rule.

    .PARAMETER Credential
        Specifies the user account credentials to use to perform the task.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $IdentityReference,

        [Parameter()]
        [ValidateSet('AccessSystemSecurity', 'CreateChild', 'Delete', 'DeleteChild', 'DeleteTree', 'ExtendedRight', 'GenericAll', 'GenericExecute', 'GenericRead', 'GenericWrite', 'ListChildren', 'ListObject', 'ReadControl', 'ReadProperty', 'Self', 'Synchronize', 'WriteDacl', 'WriteOwner', 'WriteProperty')]
        [System.String[]]
        $ActiveDirectoryRights = 'GenericAll',

        [Parameter(Mandatory = $true)]
        [ValidateSet('Allow', 'Deny')]
        [System.String]
        $AccessControlType,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ObjectType,

        [Parameter(Mandatory = $true)]
        [ValidateSet('All', 'Children', 'Descendents', 'None', 'SelfAndChildren')]
        [System.String]
        $ActiveDirectorySecurityInheritance,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InheritedObjectType,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential
    )

    # Get the current state
    $getTargetResourceSplat = @{
        Path                               = $Path
        IdentityReference                  = $IdentityReference
        AccessControlType                  = $AccessControlType
        ObjectType                         = $ObjectType
        ActiveDirectorySecurityInheritance = $ActiveDirectorySecurityInheritance
        InheritedObjectType                = $InheritedObjectType
        Credential                         = $Credential
    }
    $currentState = Get-TargetResource @getTargetResourceSplat

    # Always check, if the ensure state is desired
    $returnValue = $currentState.Ensure -eq $Ensure

    # Only check the Active Directory rights, if ensure is set to present
    if ($Ensure -eq 'Present')
    {
        # Convert to array to a string for easy compare
        [System.String] $currentActiveDirectoryRights = ($currentState.ActiveDirectoryRights |
                Sort-Object) -join ', '

        [System.String] $desiredActiveDirectoryRights = ($ActiveDirectoryRights |
                Sort-Object) -join ', '

        $returnValue = $returnValue -and $currentActiveDirectoryRights -eq $desiredActiveDirectoryRights
    }

    if ($returnValue)
    {
        Write-Verbose -Message ($script:localizedData.ObjectPermissionEntryInDesiredState -f $Path)
    }
    else
    {
        Write-Verbose -Message ($script:localizedData.ObjectPermissionEntryNotInDesiredState -f $Path)
    }

    return $returnValue
}
