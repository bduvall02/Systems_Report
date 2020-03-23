try{
  stop-transcript|out-null
}
catch [System.InvalidOperationException]{}

if (!(Test-Path "$($PSScriptRoot)\Log"))
{
    Write-Host "Creating Directory Structure for Log"
    $NULL = New-Item -Path "$($PSScriptRoot)\Log" -ItemType Directory
}
# Log Location
$logfile = "$($PSScriptRoot)\Log\report_log_$(get-date -Format MM_dd_yyyy).txt"

# One Way Transfer Location for moving the final All_Systems.XML up classifications
$onewaylocation = "C:\work\OneWay\SBU"

# One Way Transfers for LOW and MID if this script is run on HIGH network
$onewaylocation_LOW = "C:\work\oneway\SBU"
$onewaylocation_MID = "C:\work\oneway\MID"

# Classification: Use LOW, MID, HIGH
$classification = "HIGH"

Start-Transcript -Path $logfile -Append
Import-Module netappdocs

#Login information
[string]$username = "DOMAIN\ACCOUNT"
$pass = cat D:\Scripts\password.txt | ConvertTo-SecureString
$mycred = new-object -TypeName System.Management.Automation.PSCredential -ArgumentList $username,$pass
#########################################################################
#### If New Password needs to be generated - Do the following
#### $credential = get-credential <USER ACCOUNT> -Enter password when dialog box appears
#### $credential.password | ConvertFrom-SecureString | Out-File D:\scripts\password.txt
######################################################################### 



#Folder for all created files.  If today is February 3rd, 2019, the folder will be 02_03_2019.
$folder = "$($PSScriptRoot)\$(Get-Date -Format MM_dd_yyyy)"


# If the dated folder is not available, create it.

if (!(Test-Path $folder))
{
    Write-Host "Creating Directory Structure $($folder)"
    $NULL = New-Item -Path $folder -ItemType Directory
}



#Count of Total Clusters in All_Systems.txt file
$total = $(Get-Content "$($PSScriptRoot)\All_Systems.txt" | ? {$_ -ne ""}).count
$counter = 0
$time = @()
<#############################
    Requires a file called All_Systems.txt.  This file will provide the Cluster Name, IP address, Location, and Environment for each cluster on the network. 
    The format of the file requires a comma between each value.  
#############################>
foreach ($cluster in Get-Content "$($PSScriptRoot)\All_Systems.txt" | ? {$_ -ne ""}){
    $counter++
    #Split the line by commas.  This provides the following information:
    # 0 - Cluster Name
    # 1 - IP Address
    # 2 - Location
    # 3 - Environment
    # 4 - Network - This is the $Classification variable defined by user above
    $items = $cluster.split(',')
    $items += $classification
    Write-Host "Collecting data from Cluster $($counter) of $($total) [$($items[0])]"
    # Gathers Cluster Data and exports an XML file for later use.
    $measure = Measure-Command { Get-NtapClusterData -Name $items[1] -Credential $cred | Export-Clixml -Path "$($folder)\$($items[0])_raw.xml"}
    $customobject = New-Object psobject
    $customobject | Add-Member -MemberType NoteProperty -Name Cluster -Value $items[0]
    $customobject | Add-Member -MemberType NoteProperty -Name Process -Value "Collection"
    $customobject | Add-Member -MemberType NoteProperty -Name Hours -Value $measure.Hours
    $customobject | Add-Member -MemberType NoteProperty -Name Minutes -Value $measure.Minutes
    $customobject | Add-Member -MemberType NoteProperty -Name Seconds -Value $measure.Seconds
    $time += $customobject
    $customobject = New-Object psobject
    Write-Host "Creating Report for Cluster $($counter) of $($total)"
    # Imports the XML file created in previous step, then Formats the Data and Adds the Custom Location/Environment information.  Output is an Excel Spreadsheet.
    $measure = Measure-Command {Get-ChildItem $($folder) -filter "$($items[0])_raw.xml" | Format-NtapClusterData | Add-NtapDocsExtendedData -CustomScript "$($PSScriptRoot)\Add-Environment.ps1" | Out-NtapDocument -XmlFile "$($folder)\$($items[0])_formatted.xml"  -ExcelFile "$($folder)\$($items[0]).xlsx"  -CustomerName "NGA" -CustomerLocation "NCE" -ProjectName "$($items[3])" -AuthorName "Matt Tennyson" | Out-Null}
    $customobject = New-Object psobject
    $customobject | Add-Member -MemberType NoteProperty -Name Cluster -Value $items[0]
    $customobject | Add-Member -MemberType NoteProperty -Name Process -Value "Processing"
    $customobject | Add-Member -MemberType NoteProperty -Name Hours -Value $measure.Hours
    $customobject | Add-Member -MemberType NoteProperty -Name Minutes -Value $measure.Minutes
    $customobject | Add-Member -MemberType NoteProperty -Name Seconds -Value $measure.Seconds
    $time += $customobject

    #Create a report to show the differences between two reports
    $diff = Get-ChildItem -path $PSScriptRoot -Recurse -Filter "$($items[0])_formatted.xml" | Sort-Object -Property LastWriteTime -Descending | select -First 2
    Compare-NtapDocsData -XmlFile1 $diff[0].PSPath -XmlFile2 $diff[1].PSPath | Out-NtapDocument -ExcelFile "$($folder)\$($items[0])_diff.xlsx" -CustomerName "NGA" -CustomerLocation "NCE" -ProjectName "Difference Report" -AuthorName "Matt Tennyson"
}
Write-Host "Creating Complete System Report..."
# Gathers all of the Cluster Data XML files. Formats the Data and Adds the Custom Location/Environment information. Output is an Excel Spreadsheet.
$measure = Measure-Command {Get-ChildItem $($folder) -Filter *raw.xml | Format-NtapClusterData | Add-NtapDocsExtendedData -CustomScript "$($PSScriptRoot)\Add-Environment.ps1" | Out-NtapDocument -XmlFile "$($folder)\All_Systems_formatted.xml" -ExcelFile "$($folder)\All_Systems.xlsx" -CustomerName "NGA" -CustomerLocation "NCE" -ProjectName "All Clusters" -AuthorName "Matt Tennyson"}
$customobject = New-Object psobject
$customobject | Add-Member -MemberType NoteProperty -Name Cluster -Value "All Systems"
$customobject | Add-Member -MemberType NoteProperty -Name Process -Value "Processing"
$customobject | Add-Member -MemberType NoteProperty -Name Hours -Value $measure.Hours
$customobject | Add-Member -MemberType NoteProperty -Name Minutes -Value $measure.Minutes
$customobject | Add-Member -MemberType NoteProperty -Name Seconds -Value $measure.Seconds
$time += $customobject

#Create a report to show the differences between the two All Systems reports
Write-Host "Creating Diff Report for All Systems..."
$diff = Get-ChildItem -path $PSScriptRoot -Recurse -Filter "All_Systems_formatted.xml" | Sort-Object -Property LastWriteTime -Descending | select -First 2
Compare-NtapDocsData -XmlFile1 $diff[0].PSPath -XmlFile2 $diff[1].PSPath | Out-NtapDocument -ExcelFile "$($folder)\All_Systems_diff.xlsx" -CustomerName "NGA" -CustomerLocation "NCE" -ProjectName "Difference Report" -AuthorName "Matt Tennyson"

Write-Host "Creating Complete Sanitized System Report..."
# Gathers all of the Cluster Data XML files. Formats the Data, Santizes All Applicable Fields, then adds the Custom Location/Environment information.  Output is an Excel spreadsheet.
Get-ChildItem $($folder) -Filter *raw.xml | Format-NtapClusterData -SanitizeLevel 65535 -SanitizeMappingsXmlFile "$($folder)\reference.xml"| Add-NtapDocsExtendedData -CustomScript "$($PSScriptRoot)\Add-Environment.ps1" | Out-NtapDocument -XmlFile "$($folder)\All_Systems_sanitized.xml" -ExcelFile "$($folder)\All_Systems_SANITIZED.xlsx" -CustomerName "NGA" -CustomerLocation "NCE" -ProjectName "All Clusters" -AuthorName "Matt Tennyson"
$customobject = New-Object psobject
$customobject | Add-Member -MemberType NoteProperty -Name Cluster -Value "All Systems - Sanitized"
$customobject | Add-Member -MemberType NoteProperty -Name Process -Value "Processing"
$customobject | Add-Member -MemberType NoteProperty -Name Hours -Value $measure.Hours
$customobject | Add-Member -MemberType NoteProperty -Name Minutes -Value $measure.Minutes
$customobject | Add-Member -MemberType NoteProperty -Name Seconds -Value $measure.Seconds
$time += $customobject

$time | Format-Table -AutoSize

if ($classification -ne 'HIGH'){
    # Copies the All Systems XML Data into the One Way Transfer Folder.
    Get-ChildItem -Path $folder -filter "All_Systems_formatted.xml" -File | Copy-Item -Destination {$onewaylocation + "\" + $classification + "_" + $_.Name}
    Get-ChildItem -Path $folder -filter "All_Systems_sanitized.xml" -File | Copy-Item -Destination {$onewaylocation + "\" + $classification + "_" + $_.Name}
}else{
    Move-Item -path $($onewaylocation_LOW + "\LOW_All_Systems_formatted.xml") -Destination $folder
    Move-Item -path $($onewaylocation_LOW + "\LOW_All_Systems_sanitized.xml") -Destination $folder
    Move-Item -path $($onewaylocation_MID + "\MID_All_Systems_formatted.xml") -Destination $folder
    Move-Item -path $($onewaylocation_MID + "\MID_All_Systems_sanitized.xml") -Destination $folder
    Get-ChildItem $($folder) -Filter *All_Systems_formatted.xml | Out-NtapDocument -ExcelFile "$($folder)\All_Networks_Systems.xlsx" -CustomerName "NGA" -CustomerLocation "NCE" -ProjectName "All Clusters, All Networks" -AuthorName "Matt Tennyson"
    Get-ChildItem $($folder) -Filter *All_Systems_sanitized.xml | Out-NtapDocument -ExcelFile "$($folder)\All_Networks_Systems_SANITIZED.xlsx" -CustomerName "NGA" -CustomerLocation "NCE" -ProjectName "All Clusters, All Networks" -AuthorName "Matt Tennyson"

}

#Creates folders and moves the files to the appropriate folders
if (!(Test-Path $($folder + "\Diff_Reports")))
{
    Write-Host "Creating Directory Structure $($folder + "\Diff_Reports")"
    $NULL = New-Item -Path $($folder + "\Diff_Reports") -ItemType Directory
}
if (!(Test-Path $($folder + "\XML Data")))
{
    Write-Host "Creating Directory Structure $($folder + "\XML Data")"
    $NULL = New-Item -Path $($folder + "\XML Data") -ItemType Directory
}
Write-Host "Moving files into proper folders..."
Get-ChildItem -Path $folder -Filter "*diff.xlsx" | Move-Item -Destination $($folder + "\Diff_Reports")
Get-ChildItem -Path $folder -Filter "*xml" | Move-Item -Destination $($folder + "\XML Data")




Stop-Transcript