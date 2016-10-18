#
# SCVMM_Storage_Scripts.ps1
#
Function out-clipboard {
    #############################################################################
    ##
    ## Set-Clipboard
    ##
    ## From Windows PowerShell Cookbook (O'Reilly)
    ## by Lee Holmes (http://www.leeholmes.com/guide)
    ##
    ##############################################################################

    <#
    .SYNOPSIS

    Sends the given input to the Windows clipboard.

    .EXAMPLE

    dir | Set-Clipboard
    This example sends the view of a directory listing to the clipboard

    .EXAMPLE

    Set-Clipboard "Hello World"
    This example sets the clipboard to the string, "Hello World".

    #>

    param(
        ## The input to send to the clipboard
        [Parameter(ValueFromPipeline = $true)]
        [object[]] $InputObject
    )

    begin
    {
        Set-StrictMode -Version Latest
        $objectsToProcess = @()
    }

    process
    {
        ## Collect everything sent to the script either through
        ## pipeline input, or direct input.
        $objectsToProcess += $inputObject
    }

    end
    {
        ## Launch a new instance of PowerShell in STA mode.
        ## This lets us interact with the Windows clipboard.
        $objectsToProcess | PowerShell -NoProfile -STA -Command {
            Add-Type -Assembly PresentationCore

            ## Convert the input objects to a string representation
            $clipText = ($input | Out-String -Stream) -join "`r`n"

            ## And finally set the clipboard text
            [Windows.Clipboard]::SetText($clipText)
        }
    }
}

Function Get-SCVMMSharedVolumeLUNCapacity {
	Param (
		[parameter(Mandatory=$true,
		ValueFromPipeline=$true)]
		[string[]]
		$SCVMMHost
		)

	$PrimaryClusterNodes = $SCVMMHost | % {Get-VMHost -VMMServer $_ | Select Name, VMHostGroup, HostCluster | Select HostCluster -Unique | % {(get-cluster $_.HostCluster | get-clusternode)[0].Name}}

	$CurrentDate = $(Get-Date).ToShortDateString()

	Invoke-Command `
		-ComputerName $PrimaryClusterNodes `
		-ScriptBlock {
			Get-ClusterSharedVolume | Select `
				Name, `
				@{n='Path';e={($_.SharedVolumeInfo.FriendlyVolumeName)}}, `
				@{n='Size(MB)';e={($_.SharedVolumeInfo.Partition).Size/1mb}}, `
				@{n='FreeSpace(MB)';e={($_.SharedVolumeInfo.Partition).FreeSpace/1mb}}, `
				@{n='Clustername';e={(get-cluster).Name}} `
				} | `
			Sort Clustername, PSComputerName, Name | `
			Select Clustername, PSComputerName, Name, Path, 'Size(MB)', 'Freespace(MB)'
}

Function Get-SCVMMAllVMHosts {
	Param (
		[parameter(Mandatory=$true,
		ValueFromPipeline=$true)]
		[string[]]
		$SCVMMHost
	)

	$SCVMMHost | % {
		Get-VMHost -VMMServer $_ | Select `
			VMHostGroup, `
			HostCluster, `
			FQDN, `
			OperatingSystem, `
			PhysicalCPUCount, `
			CoresPerCPU, `
			LogicalCPUCount, `
			CPUSpeed, `
			CPUArchitecture, `
			CPUFamily, `
			VirtualServerStateString, `
			VirtualServerVersion, `
			RunAsAccount, `
			OverallState, `
			TotalMemory, `
			RemoteStorageTotalCapacity, `
			RemoteStorageAvailableCapacity, `
			LocalStorageTotalCapacity, `
			LocalStorageAvailableCapacity, `
			TotalStorageCapacity, `
			AvailableStorageCapacity, `
			UsedStorageCapacity, `
			ID
	}
}

Function Get-VMList {
   	Param (
		[parameter(Mandatory=$true,
		ValueFromPipeline=$true)]
		[string[]]
		$SCVMMHost
	)
	$SCVMMHost | % {
		Get-VM -vmmserver $_ | Select `
			"Name", `
			"ComputerName", `
			"Description", `
			"VirtualMachineState", `
			"VMHost", `
			"VMCPath", `
			"VMId", `
			"HostId", `
			"ID", `
			"HostGroupPath", `
			"Location", `
			"TotalSize", `
			"MemoryAssignedMB", `
			"MemoryAvailablePercentage", `
			"DynamicMemoryDemandMB", `
			"DynamicMemoryStatus", `
			"StatusString", `
			"StartAction", `
			"StopAction", `
			"PerfCPUUtilization", `
			"PerfMemory", `
			"PerfDiskBytesRead", `
			"PerfDiskBytesWrite", `
			"PerfNetworkBytesRead", `
			"PerfNetworkBytesWrite", `
			"TimeSynchronizationEnabled", `
			"FailedJobID", `
			"CheckpointLocation", `
			"IsPrimaryVM", `
			"IsTestReplicaVM", `
			"ReplicationState", `
			"ReplicationHealth", `
			"ReplicationMode", `
			"LastReplicationTime", `
			"MostRecentTaskID", `
			"MostRecentTaskUIState", `
			"MostRecentTask", `
			"CreationTime", `
			"OperatingSystem", `
			"HasVMAdditions", `
			"VMAddition", `
			"CPUCount",	`
			"Memory", `
			"DynamicMemoryEnabled", `
			"DynamicMemoryMaximumMB", `
			"DynamicMemoryBufferPercentage", `
			"DynamicMemoryMinimumMB", `
			"Generation", `
			"AddedTime", `
			"ModifiedTime"
	} 
}

Function Get-AllVHD {
	Param (
		[parameter(Mandatory=$true,
		ValueFromPipeline=$true)]
		[string[]]
		$SCVMMHost
		)

	$PrimaryClusterNodes = $SCVMMHost | % {Get-VMHost -VMMServer $_ | Select Name, VMHostGroup, HostCluster | Select HostCluster -Unique | % {(get-cluster $_.HostCluster | get-clusternode)[0].Name}}

	Invoke-Command `
		-ComputerName $PrimaryClusterNodes `
		-ScriptBlock {
			$ClusterName = (get-cluster).Name
			gci c:\clusterstorage\*.vhdx -recurse | Select DirectoryName, Name, FullName, @{n='FileSize(MB)';e={($_).Length/1mb}}, LastWriteTime, @{n='Clustername';e={$ClusterName}}
			} | `
			Sort PSComputerName, Directory, Name
}

Function Get-ActiveVHDXFiles {
	Invoke-Command `
		-ComputerName $AllVMHosts.FQDN `
		-ScriptBlock {
			$vms = Get-VM
			    Foreach ($VM in $VMs)
					{
						$HardDrives = $VM.HardDrives
						Foreach ($HardDrive in $HardDrives)
							{
								$HardDrive.path | Get-VHD
							} 
					} 
		} | Select PSComputerName, Path, @{n='FileSize(MB)';e={($_).FileSize/1MB}}, @{n='Size(MB)';e={($_).Size/1MB}}, @{n='MinimumSize(MB)';e={($_).MinimumSize/1MB}}, FragmentationPercentage, Attached
}

Function Get-ISOsOnCSV {
	Param (
		[parameter(Mandatory=$true,
		ValueFromPipeline=$true)]
		[string[]]
		$SCVMMHost
		)

	$PrimaryClusterNodes = $SCVMMHost | % {Get-VMHost -VMMServer $_ | Select Name, VMHostGroup, HostCluster | Select HostCluster -Unique | % {(get-cluster $_.HostCluster | get-clusternode)[0].Name}}

	Invoke-Command `
		-ComputerName $PrimaryClusterNodes `
		-ScriptBlock {
			$ClusterName = (get-cluster).Name
			gci c:\clusterstorage\*.iso -recurse | Select DirectoryName, Name, FullName, @{n='FileSize(MB)';e={($_).Length/1mb}}, LastWriteTime, @{n='Clustername';e={$ClusterName}}
			} | `
			Sort PSComputerName, Directory, Name
}

Function Get-HBAWin {
	Param (
		[String[]]$ComputerName = $ENV:ComputerName
	)  

	$ComputerName | ForEach-Object {  
		$Computer = $_  
		$Namespace = "root\WMI"   
		Get-WmiObject -class MSFC_FCAdapterHBAAttributes -computername $Computer -namespace $namespace |  
		ForEach-Object {  
			$hash=@{  
				ComputerName     = $_.__SERVER  
				NodeWWN          = (($_.NodeWWN) | ForEach-Object {"{0:x}" -f $_}) -join ":"  
				Active           = $_.Active  
				DriverName       = $_.DriverName  
				DriverVersion    = $_.DriverVersion  
				FirmwareVersion  = $_.FirmwareVersion  
				Model            = $_.Model  
				ModelDescription = $_.ModelDescription  
			}  
			New-Object psobject -Property $hash  
		}#Foreach-Object(Adapter) 
	}#Foreach-Object(Computer)
}

Function Get-SCVMMHostHBAList {
	$AllVMHosts.FQDN | % {Get-HBAWin -ComputerName $_}
}

Import-Module Hyper-V
Import-Module VirtualMachineManager

Function Get-MountedISOs {
	Param (
		[parameter(Mandatory=$true,
		ValueFromPipeline=$true)]
		[string[]]
		$SCVMMHost
		)

	$vms = Get-VM -vmmserver $SCVMMHost[0]
	$MountedISO = foreach ($vm in $vms) {foreach ($drive in $vm.virtualdvdDrives) {If ($drive.Connection -like "ISOImage") {$drive | Select Name, ISO}}}
	$vms = get-vm -VMMServer $SCVMMHost[1]
	$MountedISO += foreach ($vm in $vms) {foreach ($drive in $vm.virtualdvdDrives) {If ($drive.Connection -like "ISOImage") {$drive | Select Name, ISO}}}
	$MountedISO
}

Function Get-VMHostPhysicalDisk {
	Invoke-command -ComputerName $AllVMHosts.FQDN -ScriptBlock {Get-WmiObject Win32_DiskDrive}
}

#RUN
[array]$SCVMMHosts = (Read-Host "SCVMMHosts? (Separate with Comma)").Split(",") | %{$_.Trim() }

$LunCapacityReport = Get-SCVMMSharedVolumeLUNCapacity -SCVMMHost $SCVMMHosts
$AllVMHosts = Get-SCVMMAllVMHosts -SCVMMHost $SCVMMHosts
$AllVMs = Get-VMList -SCVMMHost $SCVMMHosts
$AllVHDs = Get-AllVHD -SCVMMHost $SCVMMHosts
$AllActiveVHDs = Get-ActiveVHDXFiles
$ISOsonCSV = Get-ISOsOnCSV -SCVMMHost $SCVMMHosts
$SCVMMHostHBAList = Get-SCVMMHostHBAList
$MountedISOs = Get-MountedISOs -SCVMMHost $SCVMMHosts
$VMHostPhysicalDisk = Get-VMHostPhysicalDisk


<#Copy to Management Workstation
$LunCapacityReport | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation | Out-Clipboard

$AllVMHosts | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation | Out-Clipboard

$AllVMs | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation | Out-Clipboard

$AllVHDs | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation | Out-Clipboard

$AllActiveVHDs | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation | Out-Clipboard

$ISOsonCSV | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation | Out-Clipboard

$SCVMMHostHBAList | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation | Out-Clipboard

$MountedISOs | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation | Out-Clipboard

$VMHostPhysicalDisk | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation | Out-Clipboard
#>