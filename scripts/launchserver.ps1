Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

if((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -eq $false){
    [System.Windows.Forms.MessageBox]::Show("This machine is not joined to a domain")
exit
}

if(!(get-process -name wfcrun32)){
[System.Windows.Forms.MessageBox]::Show("Is Citrix Receiver/Workspace installed and running?")
exit
}

$loc = get-location

$filestore =(get-item $loc).parent.FullName


$password = Read-Host -Prompt "what is the password"
Set-Location $filestore
new-item -Path "$filestore\status\$env:computername.txt"

Do{ 
    write-host "Checking for Start Test"
    $startTest = Test-Path -path "$filestore\status\startTest.csv"
    Start-Sleep 1
}
Until($startTest -eq $true)


cls
#Wait-Debugger

Write-Host "Test is Starting"
$list = import-csv "$filestore\status\starttest.csv"

foreach($item in $list | Where-Object {$_.server -eq $env:computername})
{ 
$endTest = Test-Path -path "$filestore\status\endTest.txt"
If($endTest -eq $true){exit}
    start-sleep $item.delay
$endTest = Test-Path -path "$filestore\status\endTest.txt"
If($endTest -eq $true){exit}
    .\\Scripts\Launcher.ps1 -SiteURL $item.storefrontURL -UserName $item.user -Password $password -ResourceName $item.desktop
    write-host $item.user
$endTest = Test-Path -path "$filestore\status\endTest.txt"
If($endTest -eq $true){exit}
}

new-item -Path "$filestore\status\$env:computername-END.txt"
#sleep $item.delay
#add-content -Path "$filestore\status\currentstate.txt" -Value "$env:computername finished"
