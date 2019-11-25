#SET VARIABLES
$date = (Get-Date -format filedatetime)
$serverlist = ("Server01 Server02")
$userlist = ("user01","user02")
$password = "Password"
$desktop = "desktop"
$storefrontURL = "https://storefront.contoso.com/Citrix/StoreWeb/"
$filestore = "\\fileserver\LoadTest"
$delay = 30
$date = (Get-Date -format filedatetime)

Set-Location $filestore


#PREPARE VDAS
Foreach($server in $serverlist){
                                    $endtest = Test-Path -path $filestore\endtest.txt
                                    If($endtest -eq $true){Remove-Item -path $filestore\endtest.txt}
                                    $counter = {
                                    $filestore = "\\fileserver\LoadTest"
                                    $date = (Get-Date -format filedatetime)
                                    Get-counter -Counter "\Terminal Services\Total Sessions","\Processor(_Total)\% Processor Time","\Memory\% Committed Bytes In Use" -computername $args[0] -Continuous -SampleInterval 2 | export-counter "$filestore\perfmon\$date.blg" -ErrorAction stop}
                                    Start-Job -ScriptBlock $counter -ArgumentList $server
                                    Copy-item -Path "$filestore\Scripts\startDEMO.bat" -Destination "\\$server\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
                                    $timing = Test-Path -path \\$server\c$\temp\timing.csv
                                    If($timing -eq $true){Remove-Item -path \\$server\c$\temp\timing.csv}
                                    
                                }
#LAUNCH SESSIONS
foreach($user in $userlist){    
                                #https://github.com/santiagocardenas/storefront-launcher                           
                                & $filestore\Scripts\Launcher.ps1 -SiteURL $storefrontURL -UserName $user -Password $password -ResourceName $desktop
                                Start-Sleep $delay
                            }

#REVERT VDAS
Foreach($server in $serverlist){
                                    new-Item -path $filestore\endtest.txt -ItemType File 
                                    Remove-item "\\$server\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\startDEMO.bat"
                                    Copy-item -Path "\\$server\c$\temp\timing.csv" -Destination "$filestore\Timings\timing$server$date.csv"
                                }

                                Get-Job | Stop-Job
