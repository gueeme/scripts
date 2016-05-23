# Based on Augagneur Alexandre's script; http://gallery.technet.microsoft.com/scriptcenter/WSB-Backup-network-email-9793e315
# as well as other parts and pieces from other blogs and forums
# A good artist creates, a great artist steals. :)

# Uses Windows Server Backup Feature

# Creates a Bare Metal Restoreable and Full VSS Backup

# Saves Backup to \\ServerName\ShareName\ComputerName\Current

# Allows for retaining older backups, you can set how many

# If the $MaxBackup variable is set to anything greater than 0 and the previous backup was successful,
# the script copies the current backup folder to \\ServerName\ShareName\ComputerName\Archive\<CurrentDate>
# before starting a new backup
cls
$ComputerName = $env:computername
 
#------------------------------------------------------------------ 
# User Provided Variables 
#------------------------------------------------------------------  
 
# Path to store Backup, no backslash at end.
# Example: "\\servername\ShareName\Folder"
# The Computer Name will be appended to the path
# If you used the example above, the script will create a folder like this: \\servername\ShareName\Folder\ComputerName 
$BackupRootPath = "\\servername\ShareName\Folder"

# Number of backups to retain (value of "0" equals disable rotation, keep no backups) 
$MaxBackup = 2
 
# From Email Address 
$from = "$ComputerName@email.com" 
 
# To Email Address 
$to = "someone@email.com","someoneelse@email.com" 
 
# SMTP Server 
$smtpserver = "smtp.email.com" 

# Send Email on Failure only? 1 = Send on Failure only, 0 = Send always
$SendEmail = 1

##### **********************************
##### Functions and Main Script Routine
##### **********************************

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

#------------------------------------------------------------------  
# Function to check if the Windows Backup Features are installed 
# Installs if not and loadds the Snapin 
#------------------------------------------------------------------  

function CheckForFeatures()
{
echo ""
echo "Checking to see if Windows Server Backup Features are installed"
echo ""
Import-Module ServerManager

$WSBBackupFeature = Get-WindowsFeature | Where-Object {$_.Name -eq "Windows-Server-Backup"} 
$WSBBackupFeatureTools = Get-WindowsFeature | Where-Object {$_.Name -eq "Windows-Server-Backup"}

If ($WSBBackupFeature.Installed -and $WSBBackupFeatureTools.Installed -eq "True")

    {
       echo ""
       echo "Loading Windows Server Backup"
       echo ""
       if ( (Get-PSSnapin -Name Windows.ServerBackup -ErrorAction SilentlyContinue) -eq $null ) { }
    }

else

    {
    echo ""
    echo "Installing Windows Server Backup Features"
    echo ""
    $InstallWSB = Add-WindowsFeature -Name Windows-Server-Backup -IncludeAllSubFeature
    If ($InstallWSB.Success) 
    	{
    	echo ""
    	echo "Windows Backup Features installed successfully"
    	echo ""
    	echo ""
	   	}
    	
    else {
            echo ""
            echo "Windows Backup Features not installed successfully"
            echo ""
            exit
         }
    }
}
  
#------------------------------------------------------------------  
# Function to compare the number of folders to retain with 
# $MaxBackup (Not called if $MaxBackup equals 0) 
#------------------------------------------------------------------  

function Rotation() 
	{
	echo ""
	echo "Starting Backup Rotation and Cleanup"
	echo ""
	$BackupFolderNameArchiveName = Get-Date -Format yyyy-MM-dd_hhmmss;
	$BackupFolderNameArchive = ($BackupRootPath+"\$ComputerName\Archive") 
	# Backup Archive folder creation 
	if(!(Test-Path -Path $BackupFolderNameArchive )){
		New-Item $BackupFolderNameArchive -Type Directory | Out-Null 
		}
	
	if ((Test-Path -path $FullBackupPath) -eq $True){
		Move-Item -Path $FullBackupPath $BackupFolderNameArchive | Out-Null
		Rename-Item $BackupFolderNameArchive"\Current" $BackupFolderNameArchiveName
		}        

	# List all backup folders 
	$Backups = @(Get-ChildItem -Path $BackupFolderNameArchive\*)

	#Number of backups folders
	$NbrBackups = $Backups.count
	echo ""
	echo "Number of existing backups at $BackupFolderNameArchive is $NbrBackups" 
	echo ""
		
	$i = 0
		 
	#Delete oldest backup folders
	while ($NbrBackups -gt $MaxBackup)
		{
		$Backups[$i] | Remove-Item -Force -Recurse -Confirm:$false
		$NbrBackups -= 1
		$i++
		}
	} 
  
#------------------------------------------------------------------ 
# Function to send email notification 
#------------------------------------------------------------------  

function EmailNotification() 
    { 
    echo ""
    echo "Starting Email Function"
    echo ""
    $BackupResult = (Get-WBSummary).LastBackupResultHR
    $CurrentVersion = (Get-WBJob -Previous 1)
    $head = "<style> body { background-color:white; font-family:Tahoma; font-size:12pt; } td, th { border:1px solid black; border-collapse:collapse; } th { color:black; background-color:white; } table, tr, td, th { padding: 2px; margin: 0px } table { margin-left:50px; width:90%} </style>"
    $b =  Get-WBSummary | Select-Object LastBackupTime,LastBackupResultHR,LastSuccessfulBackupTime | ConvertTo-Html -Fragment -PreContent "<h2>Backup Summary:</h2>" |  Out-String
    $b += Get-WBBackupSet | Select-Object VersionID,BackupTarget,RecoverableItems,@{Name="Volume";Expression={$_.Volume}},VssBackupOption | where {$_.VersionId -eq $CurrentVersion.VersionId} | ConvertTo-Html -as list -Fragment -PreContent "<h2>Backup Set info:</h2>" |  Out-String
    $b += Get-WBJob -Previous 1 | Select-Object StartTime,EndTime,JobState,HResult,DetailedHResult,ErrorDescription,@{Name="JobItems";Expression={$_.JobItems}} | ConvertTo-Html -as list -Fragment -PreContent "<h2>Job Properties:</h2>" |  Out-String
 
    if ($BackupResult -eq 0) {
    	$message = "<h2>Backup Succesful for $ComputerName</h2>"
        $body = $head,$message,$b  | Out-String
        $Subject = "Backup Report for "+$env:computername
        $attachments = $LogFile
        } 
    else
        {
        $errordesc = (Get-WBJob -Previous 1).ErrorDescription
        $message = "<h2>There was a Backup error on $ComputerName</h2> Error Description: $errordesc"
        $body = $head,$message,$b  | Out-String
        $Subject = "Backup Failed on "+$env:computername
        $attachments = $LogFile
        }
   
    # Send the email 
       
    if ($SendEmail -eq 0) {
    	echo ""
    	echo "Sending email"
    	echo ""
    	Send-MailMessage -to $to -from $from  -subject $Subject -body $Body -smtpserver $smtpserver -BodyAsHtml -attachments $attachments
    	}
    if ($SendEmail -eq 1 -and $BackupResult -ne 0) {
    	echo ""
    	echo "Backup Failed, sending email"
    	echo ""
    	Send-MailMessage -to $to -from $from  -subject $Subject -body $Body -smtpserver $smtpserver -BodyAsHtml -attachments $attachments
    	}
    if ($SendEmail -eq 1 -and $BackupResult -eq 0) {
        echo ""
        echo "Backup successful, Script is set to send email only on Failure"
        echo ""
        }
    } 
 
#------------------------------------------------------------------ 
# Main Backup Routine
#------------------------------------------------------------------  

$LogFile = $scriptPath+"\FullBackup.log"

Start-Transcript -path $LogFile

# Check to see if Windows Server Backup Features are installed
CheckForFeatures

# Volumes to backup, defaults to All Volumes
# Reference: http://technet.microsoft.com/en-us/library/ee706679.aspx
# If you only want Critical Volumes, such as the System Reserved and C:, you could use Get-WBVolume -CriticalVolumes
$Volumes = Get-WBVolume -AllVolumes

# Example, to backup just Critical Volumes
# $Volumes = Get-WBVolume -CriticalVolumes

# Backup folder 
$FullBackupPath = ($BackupRootPath+"\$ComputerName\Current") 

# Execute rotation if enabled 
if ($MaxBackup -ne 0) 
	{ 
    	# If last backup was successful, execute the rotation function
		$jobs = Get-WBJob -Previous 1
		if ($jobs.HResult -eq 0)
			{
			Rotation
			}
	} 

# Backup folder creation 
if(!(Test-Path -Path $FullBackupPath )){
    New-Item $FullBackupPath -Type Directory | Out-Null 
}

$WBPolicy = New-WBPolicy 

Add-WBVolume -Policy $WBPolicy -Volume $Volumes

Add-WBSystemState -Policy $WBPolicy | Out-Null 
  
# Enable BareMetal functionnality (system state included)
# Reference: http://technet.microsoft.com/en-us/library/ee706681.aspx
Add-WBBareMetalRecovery -Policy $WBPolicy | Out-Null 
  
# Add Network Backup target 
$BackupLocation = New-WBBackupTarget -network ($FullBackupPath)
echo ""
echo "Backup Location is $BackupLocation"
echo ""
Add-WBBackupTarget -Policy $WBPolicy -Target $BackupLocation -force -WarningAction:SilentlyContinue | Out-Null 
  
# Make this a full VSS backup as opposed to a copy backup. 
# Reference: http://blogs.technet.com/b/filecab/archive/2008/05/21/what-is-the-difference-between-vss-full-backup-and-vss-copy-backup-in-windows-server-2008.aspx
Set-WBVssBackupOptions -policy $WBPolicy -vssfullbackup | Out-null

# Pause before continuing
echo ""
echo "Sleeping for 30 seconds, CTRL+C to abort"
echo ""
Start-Sleep 30

# Start capturing output
# Determine where the Script is being ran from for the log (start-transcript) file


# Backup folder creation 
if (!(Test-Path -path $BackupLocation))
	{
		New-Item $BackupLocation -type directory | Out-Null
	}

# Displays the backup settings prior to running the job.
echo ""
echo "Starting Backup Job with the following properties:"
$WBPolicy
echo ""

# Runs the backup task.
echo ""
echo "Starting Backup"
echo ""
Start-WBBackup -Policy $WBPolicy

# Stop capturing output
Stop-Transcript

# Call email notification function 
EmailNotification
