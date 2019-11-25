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

Do{ 
    write-host "Checking for Start Test"
    $startTest = Test-Path -path "$filestore\status\startTest.csv"
    $launcherPresent = Test-Path -path "$filestore\status\$env:computername.txt"

    Start-Sleep 5
}
Until($startTest -eq $true -and $launcherPresent -eq $true)


cls
Write-Host "Test is Starting"
$list = import-csv "$filestore\status\starttest.csv"
foreach($item in $list | Where-Object {$_.server -eq $env:computername})
{ 
$endTest = Test-Path -path "$filestore\status\endTest.txt"
If($endTest -eq $true){exit}
    start-sleep $item.delay
    .\\Scripts\Launcher.ps1 -SiteURL $item.storefrontURL -UserName $item.user -Password $password -ResourceName $item.desktop
    write-host $item.user
$endTest = Test-Path -path "$filestore\status\endTest.txt"
If($endTest -eq $true){exit}
}

sleep $item.delay
add-content -Path "$filestore\status\currentstate.txt" -Value "$env:computername finished"
