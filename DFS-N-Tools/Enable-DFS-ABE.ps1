<#
.SYNOPSIS
    Activates AccessBasedEnumeration on a DFS-Namespace, and transfers the existing NTFS permissions when avail.
.DESCRIPTION
    It will activate ABE on the name space and on all DFS links withing the namespace by transfering the NTFS
    permissions to the DFS link permission, including "Set explicit view permissions on the DFS folder".
    By default it will exclude "Local Admin", "SYSTEM", "EVERYBODY" and "CREATOR/OWNER" when transfering NTFS ACL.
    Log file will be places on Desktop.
.PARAMETER DFSNroot
    The DFS root.
.PARAMETER Domaincontroller
    If you are in a multiforest environment you may have to set this.
    Default is trying to autodetect.
.PARAMETER AlwaysUpdateDFSACL
    Always transfer the NFTS ACL to the DFS-link ACL, even when there is already a DFS-link ACL.
    Default is $true.
.PARAMETER ExcludeSpecialAccounts
    If set if will exclude "Local Admin", "SYSTEM", "EVERYBODY" and "CREATOR/OWNER" when transfering NTFS ACL.
    Default is $true.
.EXAMPLE
    Enable-DFS-ABE.ps1 "\\domain.local\DFSroot"
    Enable-DFS-ABE.ps1 -DFSNroot "\\domain.local\DFSroot" -Domaincontroller "dc1.domain.local" -AlwaysUpdateDFSACL:$false -ExcludeSpecialAccounts:$false
.NOTES
    Author: Joachim Otahal / jou@gmx.net / https://github.com/Joachim-Otahal, https://joumxyzptlk.de
.LINK
    https://github.com/Joachim-Otahal
#>


# 0.0  2022-09-08 First version (proof of concept since it was needed for a customer with ~ 100 DFS-N root and thousands of DFS-N links)
# 0.1  2022-09-09 Option "always transfer NTFS permission", basic checks whether there are actually usable NTFS ACL.
# 0.2  2022-09-10 Getting it ready for international and for Github.
# 0.3  2022-02-22 Adding a delay before adjusting the AD-Objects (AD-Sync wait)

param (
    [Parameter(Mandatory=$true)][string] $DFSNroot,
    [Parameter(Mandatory=$true)][string] $Domaincontroller,
    [bool] $AlwaysUpdateDFSACL = $true,
    [bool] $ExcludeSpecialAccounts = $true
)

#################### Modules

$CheckModulesList=@("DFSN","ActiveDirectory")
for ($i = 0; $i -lt $CheckModulesList.Count; $i++) {
    if ((Get-Module -ListAvailable $CheckModulesList[$i]) -eq $null) {
        "Module $($CheckModulesList[$i]) not available. Is required!"
        Write-Verbose "Module $($CheckModulesList[$i]) not available. Is required!" -Verbose
        Start-Sleep 20
        break
    } else {
        Import-Module $CheckModulesList[$i]
    }
}

#################### Definitions

$TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# $DFSNroot = "\\pki-test.local\pki"

# If you are in a multiforest environment set this.
# $Domaincontroller = ""

# Always update DFS-N ACL? If set to true it will throw away existing permission and transfer it new. Else it will skip this who already have permissions.
# $AlwaysUpdateDFSACL = $True

# $ExcludeSpecialAccounts = $True

#################### Konstanten

$logfile = "$env:USERPROFILE\Desktop\Enable-DFS-ABE $TIMESTAMP.log"

# Defining special accounts via SID to be independent from the local lanugage.
$objUserLOCALADMINS       = $(New-Object System.Security.Principal.SecurityIdentifier ("S-1-5-32-544")).Translate( [System.Security.Principal.NTAccount])
$objUserLOCALSYSTEM       = $(New-Object System.Security.Principal.SecurityIdentifier ("S-1-5-18")).Translate( [System.Security.Principal.NTAccount])
$objUserEVERYBODY         = $(New-Object System.Security.Principal.SecurityIdentifier ("S-1-1-0")).Translate( [System.Security.Principal.NTAccount])
$objUserCREATOROWNERuser  = $(New-Object System.Security.Principal.SecurityIdentifier ("S-1-3-0")).Translate( [System.Security.Principal.NTAccount])
$objUserCREATOROWNERgroup = $(New-Object System.Security.Principal.SecurityIdentifier ("S-1-3-1")).Translate( [System.Security.Principal.NTAccount])

#################### Scriptbeginn

if (!$Domaincontroller) {
    $Domaincontroller = (Get-ADDomain).PDCEmulator
}

$DFSNrootObject = Get-DfsnRoot -Path "$DFSNroot"
if ($DFSNrootObject.Flags -notcontains "AccessBased Enumeration") {
    "$($DFSNrootObject.Path): Activating ABE on DFS-N root" | Tee-Object -FilePath $logfile -Append
    Set-DfsnRoot -Path $DFSNrootObject.Path -EnableAccessBasedEnumeration $True -Verbose | Tee-Object -FilePath $logfile -Append
} else {
    "$($DFSNrootObject.Path): ABE already activated, no change." | Tee-Object -FilePath $logfile -Append
}

$DFSNPaths = @(Get-DfsnFolder -Path "$($DFSNrootObject.Path)\*")

for ($i = 0;$i -lt $DFSNPaths.Count;$i++) {
    $DFSLink = @(Get-DfsnFolderTarget -Path $DFSNPaths[$i].Path).Where({$_.State -eq "Online"})[0]
    if ($DFSLink.Path) {
        $DFSNAccess = Get-DfsnAccess -Path $DFSLink.Path
        if (!($DFSNAccess) -or $AlwaysUpdateDFSACL) {
            "$($DFSLink.Path): Getting NTFS rights and transfere them." | Tee-Object -FilePath $logfile -Append
            $aclAccess = $aclAccessAllow = $aclAccessDeny = ""
            $aclAccess = (Get-Acl -LiteralPath $DFSLink.TargetPath -ErrorAction Ignore).Access
            if ($aclAccess) {
                if ($ExcludeSpecialAccounts) {
                    $aclAccessAllow = $aclAccess.Where({$_.AccessControlType -ne "Deny" -and $_.IdentityReference -ne $objUserLOCALADMINS -and $_.IdentityReference -ne $objUserLOCALSYSTEM -and $_.IdentityReference -ne $objUserEVERYBODY -and $_.IdentityReference -ne $objUserCREATOROWNERuser -and $_.IdentityReference -ne $objUserCREATOROWNERgroup})
                    $aclAccessDeny = $aclAccess.Where({$_.AccessControlType -eq "Deny" -and $_.IdentityReference -ne $objUserLOCALADMINS -and $_.IdentityReference -ne $objUserLOCALSYSTEM -and $_.IdentityReference -ne $objUserEVERYBODY -and $_.IdentityReference -ne $objUserCREATOROWNERuser -and $_.IdentityReference -ne $objUserCREATOROWNERgroup})
                } else {
                    $aclAccessAllow = $aclAccess.Where({$_.AccessControlType -ne "Deny"})
                    $aclAccessDeny = $aclAccess.Where({$_.AccessControlType -eq "Deny"})
                }
            }
            if ($aclAccessAllow -or $aclAccessDeny) {
                if ($aclAccessAllow) {
                    Grant-DfsnAccess -Path $DFSLink.Path -AccountName $aclAccessAllow.IdentityReference -Verbose | ft | Tee-Object -FilePath $logfile -Append
                }
                if ($aclAccessDeny) {
                    Revoke-DfsnAccess -Path $DFSLink.Path -AccountName $aclAccessDeny.IdentityReference -Verbose | ft | Tee-Object -FilePath $logfile -Append
                }
            } else {
                "$($DFSLink.TargetPath): SKIPPED - Cannot get NTFS ACL, or there is no usable ACL." | Tee-Object -FilePath $logfile -Append
                Write-Error "$($DFSLink.TargetPath): SKIPPED - Cannot get NTFS ACL, or there ise nt usable ACL."
            }
        } else {
            "$($DFSLink.Path): SKIPPED - there is already an ACL set. Current ACL" | Tee-Object -FilePath $logfile -Append
            $DFSNAccess | Tee-Object -FilePath $logfile -Append
        }
    }
}

Write-Verbose "Waiting for 30 Seconds to give AD-Sync a chance. If you see lots of ""SKIPPED. No DFS ACL found."" or simply nothing is shown below this line it was not enough wait time. Simply re-run this script after a few minutes." -Verbose
Start-Sleep 30

# Supposedly: The Option "Set explicit view permissions on the DFS folder" cannot be set using Powershell or DFSUTIL, only via GUI.
# Doing exactly that here right now.
# Getting DFS-links from the AD.
$ADSIPath="LDAP://CN=$($DFSNrootObject.Path.Split('\')[-1].ToLower()),CN=$($DFSNrootObject.Path.Split('\')[-1].ToLower()),CN=Dfs-Configuration,CN=System,DC=$($DFSNrootObject.Path.Split('\')[2].Split('.') -join ',DC=')"
$LinkListBase = [ADSI]$ADSIPath
# Extract the active links and their DistinguishedName
$DFSLinkList = ($LinkListBase.psbase.Children.distinguishedName).Where({$_ -like "CN=link-*" })
if ($DFSLinkList.Count -lt 1) {
    Write-Verbose "Warning: Could not get ANY DFS-N ABE config-info from the AD. AD-Sync is probably not yet finished. Re-Run this script in a few minutes." -Verbose
}
# And now we activate "Set explicit view permissions on the DFS folder", but only when there is a ACL.
foreach ($DFSLink in $DFSLinkList) {
    $FullObject = Get-ADObject -Server $Domaincontroller -Identity $DFSLink -Properties *
    $DFSLinkAccess = $FullObject.'msDFS-LinkSecurityDescriptorv2'
    if ($DFSLinkAccess.Access.Count -gt 0) {
        if ($DFSLinkAccess.AreAccessRulesProtected -ne $True) {
            "$($FullObject.'msDFS-LinkPathv2') = AD Objekt $($DFSLink): Activating ""Set explicit view permissions on the DFS folder""." | Tee-Object -FilePath $logfile -Append
            $DFSLinkAccess.SetAccessRuleProtection($True,$False)
            Set-ADObject -Server $Domaincontroller -Identity $DFSLink -Replace @{'msDFS-LinkSecurityDescriptorv2'=$DFSLinkAccess} -Verbose # -WhatIf
        }
    } else {
        "$($FullObject.'msDFS-LinkPathv2'): SKIPPED. No DFS ACL found." | Tee-Object -FilePath $logfile -Append
    }
}
