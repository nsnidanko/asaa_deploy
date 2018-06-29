# Author: Naz Snidanko
# Date Created: Jun 7, 2018
# Date Modified: 
# Version: 1.0
# Description: ASAA operations for Hyalto lab env.

Param(
  [string]$platform,
  [string]$version
)

$WarningPreference = "SilentlyContinue"

#call log function
. "$PsScriptRoot/apilog.ps1"

#import-module
import-module VMware.PowerCLI
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false

Write-Log -Message "apiupdate: Started template update for $platform to $version" -Severity Information

#parse settings.ini file
Get-Content "$PsScriptRoot/settings.ini" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }

#slack settings
$strSlackURL = $h.Get_item("SlackWebhook")
$strSlackChannel = $h.Get_item("SlackChannel")
#temp directory settings
$strTempDir = $h.Get_item("TempDir")
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
				$strTemplate = "ASAA_vCloud"
				$strType = "vcloud"
				}
				elseif ($platform -eq "vcenter") {
				$strTemplate = "ASAA_vCenter"
				$strType = "vcenter"
				}
				else {
				Write-Log -Message "apideploy: Invalid option $platform suppplied for platform " -Severity Error
			    }

#build url
$strVersion = $version
$strURL = "https://s3-us-west-2.amazonaws.com/hyalto.ovas/$strType-adapter-$strVersion.ova"
echo "Download url: $strURL"

Write-Log -Message "apiupdate: Download of OVA from S3 bucket started" -Severity Information		
#download OVA
$dest = "$strTempDir/$strTemplate.ova"
$wc = New-Object net.webclient
$wc.Downloadfile($strURL, $dest)
Write-Log -Message "apiupdate: Download of OVA from S3 bucket completed" -Severity Information
		
#Connect to vcenter server  
connect-viserver -Server $strVCenter -User $strUsername -Password $strPassword
Write-Log -Message "apiupdate: connected to vCenter $strVCenter" -Severity Information	
#random host selection
$vmh = Get-Cluster $strCluster | Get-VMHost -State Connected | Get-Random
        
#Remove template
Remove-Template -Template $strTemplate -DeletePermanently -confirm:$false
Write-Log -Message "apiupdate: Removed old template" -Severity Information	
		
# Convert and Deploy OVF
$ovfConfig = Get-OvfConfiguration $dest
$ovfConfig.NetworkMapping.dvportgroup_1739.Value = $(Get-VDPortgroup -Name $vdPortGroup)
Write-Log -Message "apiupdate: Import of OVA to $vmh started" -Severity Information	 
Import-VApp $dest -OvfConfiguration $ovfConfig -VMHost $vmh -Location $strCluster -Datastore $(Get-Datastore -Name $strDatastore) -Name $strTemplate -Force
Write-Log -Message "apiupdate: Import of OVA to $vmh completed" -Severity Information	
# Convert to template
Get-VM -Name $strTemplate | Set-VM -ToTemplate -confirm:$false
Write-Log -Message "apiupdate: VM $strTemplate converted to template" -Severity Information	
#Remove temporary folders
Remove-Item -Path "$strTempDir/$strTemplate.ova" -confirm:$false
Write-Log -Message "apiupdate: temporary files removed" -Severity Information	

disconnect-viserver -confirm:$false
Write-Log -Message "apiupdate: Disconnected from vCenter" -Severity Information	

#slack integration
$payload = @{
  "channel" = "$strSlackChannel"
  "text" = "Template for $strType updated to $strVersion"
  "username"= "powerhost-bot"
}
 
Invoke-WebRequest -UseBasicParsing -Body (ConvertTo-Json -Compress -InputObject $payload) -Method Post -Uri "$strSlackURL"	