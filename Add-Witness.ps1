#
# Add_Witness.ps1
#
<#
Check ClusterQuorum Model
if not exist filesharewitness
check Connection to SMB File Share
check Existence of Share
if Not exist; create share on Server and assign security to Cluster Virtual Computer Object
Check Existence of Share
Test Write to Share
If successful;
Set Cluster Quorum no witness
set Cluster Quorum fileshare witness
verify content of Share
Success
#>

<#
#Param
$SMBFileServer
$SMBFSHardDisk
$ClusterName
$ClusterAccount
#>



Function Get-QuorumWitnessStatus {

}    #End Get-QuorumWitnessStatus

Function Get-WitnessShareStatus {
	  [ValidateScript({
          If (Test-Path -Path $_ -PathType Container) {
            $true
          }
          else {
            Throw "'$_' is not a valid directory."
          }
        })]
        [string]$Path
}    #End Get-WitnessShareStatus

Function Get-WitnessShareContent {
}    #End Get-WitnessShareContent

Function Get-ValidAccountStatus {
    Param ([Parameter(Mandatory=$true)][System.String]$userName, [System.String]$domain = $null)
        
    $idrefUser = $null
    $strUsername = $userName
    If ($domain) {
        $strUsername += [String]("@" + $domain)
    }
        
    Try {
        $idrefUser = ([System.Security.Principal.NTAccount]($strUsername)).Translate([System.Security.Principal.SecurityIdentifier])
    }
    catch [System.Security.Principal.IdentityNotMappedException] {
        $idrefUser = $null
    }
           
    If ($idrefUser) {
        return $true
    }
    Else {
        return $false
    }
}    #End Get-ValidAccountStatus

Function New-FileShareWitnessShare {
[CmdletBinding()]
PARAM(
	[Parameter(Mandatory=$True, HelpMessage="Enter the name of the cluster")]$ClusterName,
	[Parameter(Mandatory=$True, HelpMessage="Enter your cluster domain account/Virtual Computer Object Account")]
	[ValidateScript({Get-ValidAccountStatus -userName $ClusterAccount.Split("\")[1] -domain $ClusterAccount.Split("\")[0]})]
	[Alias("VCO")]$ClusterAccount
	[Parameter(Mandatory=$True, HelpMessage="Enter the Server Drive Letter hosting the Share e.g. D:")]$DriveLetter
)

$FSMPath = "$($DriveLetter)\FSM_DIR_$($ClusterName)"
$FSMShare = "FSM_$ClusterName"

IF (test-path -path $FSMPath -PathType Container)
    {Write-Error "$FSMPath directory already exists"}
    ELSE
    {New-Item -path $FSMPath -ItemType directory}

IF (get-smbshare -name $FSMShare -ErrorAction SilentlyContinue)
    {write-error "$FSMShare share already exists"}
    ELSE
    {New-SmbShare -name $FSMShare -Path $FSMPath `
        -Description "File Witness Share for Cluster $ClusterName" `
        -FullAccess "Administrators",$ClusterAccount
    }

$acl = get-acl $FSMPath
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$ClusterAccount", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl $FSMPath $acl    

}    #End New-FileShareWitness

Process {}