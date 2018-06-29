# Author: Naz Snidanko
# Date Created: Jun 7, 2018
# Date Modified: 
# Version: 1.0
# Description: ASAA operations for Hyalto lab env.

function Write-Log {
     [CmdletBinding()]
     param(
         [Parameter()]
         [ValidateNotNullOrEmpty()]
         [string]$Message,
 
         [Parameter()]
         [ValidateNotNullOrEmpty()]
         [ValidateSet('Information','Warning','Error')]
         [string]$Severity = 'Information'
     )
 
     [pscustomobject]@{
         Time = (Get-Date -f g)
         Message = $Message
         Severity = $Severity
     } | Export-Csv -Path "$PsScriptRoot/LogFile.csv" -Append -NoTypeInformation
 }