Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

Function Test-EndTest{
    $endTest = Test-Path -path "$filestore\status\endTest.txt"
    If($endTest -eq $true){exit}
    }

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

Write-Host "Test is Starting"
$list = import-csv "$filestore\status\starttest.csv"

foreach($item in $list | Where-Object {$_.server -eq $env:computername})
{ 
    Test-EndTest
    start-sleep $item.delay
    Test-EndTest
    .\\Scripts\Launcher.ps1 -SiteURL $item.storefrontURL -UserName $item.user -Password $password -ResourceName $item.desktop
    write-host $item.user
    Test-EndTest
}

new-item -Path "$filestore\status\$env:computername-END.txt"



