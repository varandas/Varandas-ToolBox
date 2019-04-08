﻿#REQUIRES -Version 4.0
<#
.Synopsis
   
.DESCRIPTION
   
.EXAMPLE
  
.EXAMPLE
  
.EXAMPLE
  
#>
param( 
    [string]$Path=".\wsusscan2.cab"
)
# --------------------------------------------------------------------------------------------
#region HEADER
$SCRIPT_TITLE = "Get-MissingUpdates"
$SCRIPT_VERSION = "1.0"

$ErrorActionPreference 	= "Continue"	# SilentlyContinue / Stop / Continue

# -Script Name: Get-MissingUpdates.ps1------------------------------------------------------ 
# Based on PS Template Script Version: 1.0
# Author: Jose Varandas

#
# Owned By: Jose Varandas
# Purpose: Query machine for missing updates using external info source (Microsoft WSUSSCN2.cab). 
# 
#
#
# Dependencies: 
#                ID running script must be Local administrator
#                wsusscn2.cab must be present in the same folder or a valid path must be given via parameter
#
# Known Issues: 
#
# Arguments: 
Function How-ToScript(){
    Write-Log -sMessage "============================================================================================================================" -iTabs 1            
    Write-Log -sMessage "NAME:" -iTabs 1
        Write-Log -sMessage ".\$sScriptName " -iTabs 2     
    Write-Log -sMessage "============================================================================================================================" -iTabs 1            
    Write-Log -sMessage "ARGUMENTS:" -iTabs 1            
            Write-Log -sMessage "-Path -> Defines location for wsuscan2.cab. Default is `".\`"" -iTabs 3                        
            Write-Log -sMessage "-LogType (RemoteTxt/SQLLog/Both/None) -> Defines type of logging for missing updates." -iTabs 3        
                Write-Log -sMessage "-> None(default): Log is created locally only." -iTabs 4                        
                Write-Log -sMessage "-> RemoteTxt: Log is created locally and in a remote location. Share path will be required" -iTabs 4                        
                    Write-Log -sMessage "-> SharePath: Network Share which allows Domain Users and Domain Computers write access" -iTabs 5
                Write-Log -sMessage "-> SQLLog: Log is created locally and in a SQL Database location. SQL Server Name, SQL Instance and permissions to create/insert tables are required." -iTabs 4
                    Write-Log -sMessage "-> SQLServerName" -iTabs 5
                    Write-Log -sMessage "-> SQLInstanceName" -iTabs 5
                Write-Log -sMessage "-> Both: Log is created locally, in a remote location and in a SQL Database. Info will be required." -iTabs 4                   
                    Write-Log -sMessage "-> SharePath: Network Share which allows Domain Users and Domain Computers write access" -iTabs 5
                    Write-Log -sMessage "-> SQLServer" -iTabs 5
                    Write-Log -sMessage "-> SQLInstance" -iTabs 5
                    Write-Log -sMessage "-> SQLDB" -iTabs 5
    Write-Log -sMessage "============================================================================================================================" -iTabs 1            
    Write-Log -sMessage "EXAMPLE:" -iTabs 1
        Write-Log -sMessage ".\$sScriptName -Path `"C:\Users\Admin\Desktop\wsusscn2.cab`"" -iTabs 2     
            Write-Log -sMessage "Script will check for missing updates in WSUSScan CAB, SCCM WMI and log information locally" -iTabs 2     
        Write-Log -sMessage ".\$sScriptName -LogType Both -SQLServer SQL01 -SQLInstance MSSQLSERVER -SQLDB Any_DB ." -iTabs 2     
            Write-Log -sMessage "Script will check for missing updates in WSUSScan CAB, SCCM WMI. It will log information locally, remotely and in SQL Server" -iTabs 2  
    Write-Log -sMessage "============================================================================================================================" -iTabs 1                
#		
}
#endregion
#region EXIT_CODES
<# Exit Codes:
            0 - Script completed successfully

            3xxx - SUCCESS

            5xxx - INFORMATION            

            7xxx - WARNING

            9XXX - ERROR
            
            9999 - Unhandled Exception     

   
 Revision History: (Date, Author, Version, Changelog)
		2019/04/08 - Jose Varandas - 1.0			
           CHANGELOG:
               -> Script Created
#>							
# -------------------------------------------------------------------------------------------- 
#endregion
# --------------------------------------------------------------------------------------------
#region Standard FUNCTIONS
Function Start-Log(){	
# --------------------------------------------------------------------------------------------
# Function StartLog

# Purpose: Checks to see if a log file exists and if not, created it
#          Also checks log file size
# Parameters:
# Returns: None
# --------------------------------------------------------------------------------------------
    #Check to see if the log folder exists. If not, create it.
    If (!(Test-Path $sOutFilePath )) {
        New-Item -type directory -path $sOutFilePath | Out-Null
    }
    #Check to see if the log file exists. If not, create it
    If (!(Test-Path $sLogFile )) {
        New-Item $sOutFilePath -name $sOutFileName -type file | Out-Null
    }
	Else
	{
        #File exists, check file size
		$sLogFile = Get-Item $sLogFile
        
        # Check to see if the file is > 1 MB and purge if possible
        If ($sLogFile.Length -gt $iLogFileSize) {
            $sHeader = "`nMax file size reached. Log file deleted at $global:dtNow."
            Remove-Item $sLogFile  #Remove the existing log file
            New-Item $sOutFilePath -name $sOutFileName -type file  #Create the new log file
        }
    }
    $global:original = Get-Location
    Write-Log $sHeader -iTabs 0  
	Write-Log -sMessage "############################################################" -iTabs 0 
    Write-Log -sMessage "" -iTabs 0 
    Write-Log -sMessage "============================================================" -iTabs 0 	
    Write-Log -sMessage "$SCRIPT_TITLE ($sScriptName) $SCRIPT_VERSION - Start" -iTabs 0 -bEventLog $true -iEventID 5003 -sSource $sEventSource
	Write-Log -sMessage "============================================================" -iTabs 0 
	Write-Log -sMessage "Script Started at $(Get-Date)" -iTabs 0 
	Write-Log -sMessage "" -iTabs 0     
	Write-Log -sMessage "Variables:" -iTabs 0 
	Write-Log -sMessage "Script Title.....:$SCRIPT_TITLE" -iTabs 1 
	Write-Log -sMessage "Script Name......:$sScriptName" -iTabs 1 
	Write-Log -sMessage "Script Version...:$SCRIPT_VERSION" -iTabs 1 
	Write-Log -sMessage "Script Path......:$sScriptPath" -iTabs 1
	Write-Log -sMessage "User Name........:$sUserDomain\$sUserName" -iTabs 1
	Write-Log -sMessage "Machine Name.....:$sMachineName" -iTabs 1
	Write-Log -sMessage "Log File.........:$sLogFile" -iTabs 1
	Write-Log -sMessage "Command Line.....:$sCMDArgs" -iTabs 1  
	Write-Log -sMessage "============================================================" -iTabs 0    
}           ##End of Start-Log function
Function Write-Log(){
# --------------------------------------------------------------------------------------------
# Function Write-Log

# Purpose: Writes specified text to the log file
# Parameters: 
#    sMessage - Message to write to the log file
#    iTabs - Number of tabs to indent text
#    sFileName - name of the log file (optional. If not provied will default to the $sLogFile in the script
# Returns: None
# --------------------------------------------------------------------------------------------
    param( 
        [string]$sMessage="", 
        [int]$iTabs=0, 
        [string]$sFileName=$sLogFile,
        [boolean]$bTxtLog=$true,
        [boolean]$bConsole=$true,
        [string]$sColor="white",         
        [boolean]$bEventLog=$false,        
        [int]$iEventID=0,
        [ValidateSet("Error","Information","Warning")][string]$sEventLogType="Information",
        [string]$sSource=$sEventIDSource        
    )
    
    #Loop through tabs provided to see if text should be indented within file
    $sTabs = ""
    For ($a = 1; $a -le $iTabs; $a++) {
        $sTabs = $sTabs + "    "
    }

    #Populated content with timeanddate, tabs and message
    $sContent = "||"+$(Get-Date -UFormat %Y-%m-%d_%H:%M:%S)+"|"+$sTabs + "|"+$sMessage

    #Write content to the file
    if ($bTxtLog){
        Add-Content $sFileName -value  $sContent -ErrorAction SilentlyContinue
    }    
    #write content to Event Viewer
    if($bEventLog){
        try{
            New-EventLog -LogName Application -Source $sSource -ErrorAction SilentlyContinue
            if ($iEventID -gt 9000){
                $sEventLogType = "Error"
            }
            elseif ($iEventID -gt 7000){
                $sEventLogType = "Warning"
            }
            else{
                $sEventLogType = "Information"
            }
            Write-EventLog -LogName Application -Source $sSource -EntryType $sEventLogType -EventId $iEventID -Message $sMessage -ErrorAction SilentlyContinue
        }
        catch{
            
        }
    }
    # Write Content to Console
    if($bConsole){        
            Write-Host $sContent -ForegroundColor $scolor        
    }
	
}           ##End of Write-Log function
Function Finish-Log(){
# --------------------------------------------------------------------------------------------
# Function EndLog
# Purpose: Writes the last log information to the log file
# Parameters: None
# Returns: None
# --------------------------------------------------------------------------------------------
    #Loop through tabs provided to see if text should be indented within file
	Write-Log -sMessage "" -iTabs 0 
    Write-Log -sMessage "$SCRIPT_TITLE ($sScriptName) $SCRIPT_VERSION Completed at $(Get-date) with Exit Code $global:iExitCode - Finish" -iTabs 0  -bEventLog $true -sSource $sEventSource -iEventID $global:iExitCode    
    Write-Log -sMessage "============================================================" -iTabs 0     
    Write-Log -sMessage "" -iTabs 0     
    Write-Log -sMessage "" -iTabs 0 
    Write-Log -sMessage "" -iTabs 0 
    Write-Log -sMessage "" -iTabs 0 
    Set-Location $global:original
}             ##End of End-Log function
function ConvertTo-Array{
    begin{
        $output = @(); 
    }
    process{
        $output += $_;   
    }
    end{
        return ,$output;   
    }
}
#endregion
# --------------------------------------------------------------------------------------------
#region Specific FUNCTIONS
function Scan-WSUSOffline{
    param(
        $Path=".\wsusscn2.cab"
    )
    #Using WUA to Scan for Updates Offline with PowerShell 
    #VBS version: https://docs.microsoft.com/en-us/previous-versions/windows/desktop/aa387290(v=vs.85)  
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session 
    $UpdateServiceManager  = New-Object -ComObject Microsoft.Update.ServiceManager 
    $UpdateService = $UpdateServiceManager.AddScanPackageService("Offline Sync Service", $Path, 1) 
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()   
    $UpdateSearcher.ServerSelection = 3 #ssOthers 
    $UpdateSearcher.ServiceID = [string]$UpdateService.ServiceID  
    $SearchResult = $UpdateSearcher.Search("IsInstalled=0") # or "IsInstalled=0 and IsInstalled=1" to also list the installed updates as MBSA did  
    $Updates = $SearchResult.Updates 
    $OfflineUpdateArray =@()
    foreach ($Update in $Updates){       
       $UpdateObj=[pscustomobject]@{"DateTime"="";"ComputerName"="";"Source"="";"Article"="";"Title"="";"UpdateID"="";"UpdateClassification"="";"Categories"=""}       
       $UpdateObj.DateTime = $(Get-Date -UFormat %Y%m%d_%H%M%S)
       $UpdateObj.ComputerName = $env:COMPUTERNAME
       $UpdateObj.Source = "WSUSCAB"
       $UpdateObj.Article = $Update.Title | Select-String -Pattern 'KB\d*' -AllMatches | % { $_.Matches } | % {$_.value}           
       $UpdateObj.Title = $Update.Title                   
       $UpdateObj.UpdateID = $entry.UpdateID
       $UpdateObj.UpdateClassification = ""     
       foreach ($entry in $Update.Categories){
            $UpdateCat= "$($entry.Type):$($entry.Name);"            
       }      
       $UpdateObj.Categories = $UpdateCat
       $OfflineUpdateArray += $UpdateObj
    }#end foreach    
    return $OfflineUpdateArray
}
#endregion
# --------------------------------------------------------------------------------------------
#region VARIABLES
# Standard Variables
    # *****  Change Logging Path and File Name Here  *****    
    $sOutFileName	= "Get-MissingUpdates.log" # Log File Name    
    $sEventSource   = "ToolBox" # Event Source Name
    # ****************************************************
    $sScriptName 	= $MyInvocation.MyCommand
    $sScriptPath 	= Split-Path -Parent $MyInvocation.MyCommand.Path
    $sLogRoot		= "C:\Logs\System\SCCM"
    $sOutFilePath   = $sLogRoot
    $sLogFile		= Join-Path -Path $SLogRoot -ChildPath $sOutFileName
    $global:iExitCode = 0
    $sUserName		= $env:username
    $sUserDomain	= $env:userdomain
    $sMachineName	= $env:computername
    $sCMDArgs		= $MyInvocation.Line    
    $iLogFileSize 	= 1048576
    # ****************************************************
# Specific Variables
    
    # ****************************************************  
#endregion 
# --------------------------------------------------------------------------------------------
#region MAIN_SUB

Function MainSub{
# ===============================================================================================================================================================================
#region 1_PRE-CHECKS            
    Write-Log -iTabs 1 "Starting 1 - Pre-Checks."-scolor Cyan
    #Checking if Machine's WMI is reacheable
    Get-WmiObject -Namespace ROOT\ccm\SoftwareUpdates\UpdatesStore -Class CCM_UpdateStatus
    #Checking if WSUSSCN2.CAB is found
    #Checking if LogType set is functional       
    Write-Log -iTabs 1 "Completed 1 - Pre-Checks."-sColor Cyan    
    Write-Log -iTabs 0 -bConsole $true
#endregion
# ===============================================================================================================================================================================

# ===============================================================================================================================================================================
#region 2_EXECUTION
    Write-Log -iTabs 1 "Starting 2 - Execution." -sColor cyan    
    #Get-MissingUpdates from SCCM
    #Get-MissingUpdates from WSUSSCN2.CAB 
    #Build upload array for output
    #Write Output Locally
    #write Output remotely, if chosen
    #write output to sql, if chosen
    Write-Log -iTabs 1 "Completed 2 - Execution." -sColor cyan
    Write-Log -iTabs 0 -bConsole $true
#endregion
# ===============================================================================================================================================================================
        
# ===============================================================================================================================================================================
#region 3_POST-CHECKS
# ===============================================================================================================================================================================
    Write-Log -iTabs 1 "Starting 3 - Post-Checks."-sColor cyan
    #Check if local log was created
    #check if remote log was updates
    #check if SQL was updated
    Write-Log -iTabs 1 "Completed 3 - Post-Checks."-sColor cyan
    Write-Log -iTabs 0 "" -bConsole $true
#endregion
# ===============================================================================================================================================================================

} #End of MainSub

#endregion
# --------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------
#region MAIN_PROCESSING

# Starting log
Start-Log

Try {
	MainSub    
}
Catch {
	# Log a general exception error
	Write-Log -sMessage "Error running script" -iTabs 0        
    if ($global:iExitCode -eq 0){
	    $global:iExitCode = 9999
    }                
}
# Stopping the log
Finish-Log

# Quiting with exit code
Exit $global:iExitCode
#endregion