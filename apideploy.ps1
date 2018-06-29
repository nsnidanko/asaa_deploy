# Author: Naz Snidanko
# Date Created: Jun 7, 2018
# Date Modified: 
# Version: 1.0
# Description: ASAA operations for Hyalto lab env.

Param(
  [string]$platform,
  [string]$name
)

$WarningPreference = "SilentlyContinue"

#call log function
. "$PsScriptRoot/apilog.ps1"

#import-module
import-module VMware.PowerCLI
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false

Write-Log -Message "apideploy: Started $name for $platform" -Severity Information

#parse settings.ini file
Get-Content "$PsScriptRoot/settings.ini" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }

#slack settings
$strSlackURL = $h.Get_item("SlackWebhook")
$strSlackChannel = $h.Get_item("SlackChannel")
#vCenter settings
$strVCenter = $h.Get_item("vCenterServer")
$strUsername =  $h.Get_item("vCenterUsername")
$strPassword = $h.Get_item("vCenterPassword")
#Cluster settings
$strCluster = $h.Get_item("vCenterCluster") 
#Datastore settings
$strDatastore = $h.Get_item("vCenterDatastore")
#Portgroup settings
$vdPortGroup = $h.Get_item("vCenterPortGroup") 

                #logic for platform
				if ($platform -eq "vcloud") {
				$strCSVFile = "$PsScriptRoot/ASAADeployvCloud.csv"
				$strTemplate = "ASAA_vCloud"
				}
				elseif ($platform -eq "vcenter") {
				$strCSVFile = "$PsScriptRoot/ASAADeployvCenter.csv"
				$strTemplate = "ASAA_vCenter"
				}
				else {
				Write-Log -Message "apideploy: Invalid option $platform suppplied for platform " -Severity Error
				break
				}
				
# mainlogic
$strInputVM = $name
			
#main logic start
$strNewVMName = @()
$strMAC = @()
Import-Csv $strCSVFile |  
 foreach {  
	      $strNewVMName += $_.name
	      $strMAC += $_.mac		  
		 }
Write-Log -Message "apideploy: Database $strCSVFile imported" -Severity Information
if ($strNewVMName -contains $strInputVM) {
    $Where = [array]::IndexOf($strNewVMName, $strInputVM)
    #Connect to vcenter server  
    connect-viserver -Server $strVCenter -User $strUsername -Password $strPassword
	Write-Log -Message "apideploy: connected to vCenter $strVCenter" -Severity Information		
	#stop and delete VM
	Stop-VM -vm $strInputVM -Confirm:$false
	while ($checkPowerVM -eq 'PoweredOn'){
		$checkPowerVM = Get-VM -name $strInputVM | Select PowerState
		Sleep 5
	}
	
	        Remove-VM $strInputVM -deletepermanently -confirm:$false			
			Write-Log -Message "apideploy: deleted old VM $strInputVM" -Severity Information
			#random host selection
            $vmh = Get-Cluster $strCluster | Get-VMHost -State Connected | Get-Random
            # Make new VM
	        Write-Log -Message "apideploy: Build started VMName=$strInputVM Datastore=$strDatastore Host=$vmh" -Severity Information
	        New-VM -Name $strNewVMName[$Where] -Template $(get-template $strTemplate) -Datastore $strDatastore -VMHost $vmh -RunAsync
	        $checkVM = $null
	        while ($checkVM -eq $null){
	           $checkVM = get-vm $strNewVMName[$Where] -erroraction silentlycontinue | get-networkadapter
			   sleep 15
	        }
			Write-Log -Message "apideploy: vCenter VM build completed $strInputVM" -Severity Information			
	        $oldAdapter = Get-VM $strNewVMName[$Where] |  Get-NetworkAdapter
	        Set-NetworkAdapter -NetworkAdapter $oldAdapter -MacAddress $strMAC[$Where] -WakeOnLan:$true -StartConnected:$true -NetworkName $vdPortGroup -RunAsync -Confirm:$false
            Write-Log -Message "apideploy: network reconfig completed" -Severity Information
			#start VM
	        sleep 15 #delay to finish adapter reconfig
            Start-VM -vm $strNewVMName[$Where] -RunAsync
			Write-Log -Message "apideploy: VM powered on" -Severity Information
			disconnect-viserver -confirm:$false
            Write-Log -Message "apideploy: vCenter disconnected" -Severity Information
			}
else {
Write-Log -Message "apideploy: Invalid option supplied" -Severity Error
}
Write-Log -Message "apideploy: $strInputVM deployed" -Severity Information

#slack integration
$payload = @{
  "channel" = "$strSlackChannel"
  "text" = "$strInputVM updated"
  "username"= "powerhost-bot"
}
 
Invoke-WebRequest -UseBasicParsing -Body (ConvertTo-Json -Compress -InputObject $payload) -Method Post -Uri "$strSlackURL"	