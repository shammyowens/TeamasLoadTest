Function publish-test{Param([string]$date,[string]$filestore,[string[]]$launchers,[string[]]$VDAs,[string]$workload,[string]$desktop,[string]$delay,[string]$storefrontURL,[string[]]$users)
    
    Get-Runspace -name "sessionInfo" | ForEach-Object {$_.dispose()} 
    update-window -Control LabelTestRunning -Property Content -Value "Test Started"
      
 Try{
     ((Get-Content -path $filestore\scripts\start.bat) -replace "FILESERVER",$Workload) | Set-Content -Path $filestore\scripts\start.bat -ErrorAction Stop
     ((Get-Content -path $filestore\scripts\WorkloadFunctions.psm1) -replace "FILESERVER",$filestore) | Set-Content -Path $filestore\scripts\WorkloadFunctions.psm1 -ErrorAction Stop
     ((Get-Content -path $Workload) -replace "FILESERVER",$filestore) | Set-Content -Path $Workload -ErrorAction Stop
     
    }
 Catch
     {[System.Windows.Forms.MessageBox]::Show("Cannot Amend workload files")
     exit}
 
     $endtest = Test-Path -path $filestore\status\endtest.txt
     If($endtest -eq $true){Remove-Item -path $filestore\status\endtest.txt}
 
 Try{
     Foreach($server in $VDAs){
     Copy-item -Path "$filestore\Scripts\start.bat" -Destination "\\$server\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
     $ctemp = Test-Path "\\$server\c$\temp"
     if($ctemp -eq $false){New-Item -name temp -Path \\$server\c$\ -ItemType Directory}
     Remove-item "\\$server\c$\temp\timing.csv"
                                     }
     }
 Catch{[System.Windows.Forms.MessageBox]::Show("Cannot Prepare VDAs")
     exit}
 
 
 $launcherdelay = 0
 $steppeddelay = 0
 foreach($user in $users){
                             
                             if($launcherdelay -ge $Launchers.count){$delay = $Launchers.count * $intdelay}
                             else{$delay = $steppeddelay}
                             $LauncherAdd = New-Object PSObject -property @{user=$user;server="";delay=$delay;desktop=$desktop;storefrontURL=$storefrontURL}
                             $LauncherAdd | export-csv "$filestore\status\templaunch.csv" -Append -NoTypeInformation
                             $steppeddelay += $intdelay
                             $launcherdelay += 1
                             }
 
                             $launch = import-csv "$filestore\status\templaunch.csv"
 
                             $a = 0
                             $serverlistcount = $Launchers.Count 
                             ForEach($line in $launch){
                             if($a -eq $serverlistcount){$a = 0}
                             
                             $line.server = $Launchers[$a]
                             $a += 1
                             $a
                             }
 
 $launch | export-csv "$filestore\status\startTest.csv" -NoTypeInformation
 #foreach($server in $script:Launchers){new-item -Path "$script:filestore\status\$server.txt"}
 
 
 }

Function Unpublish-test {Param([string]$date,[string]$filestore,[string[]]$launchers,[string[]]$VDAs,[string]$workload)
    $global:hidecontrols=("textVDAs","textLaunchers","textUsers","textDomain","textDesktop","textStorefrontURL","textDelay","textFileshare","textWorkload")
    new-Item -path $filestore\status\endtest.txt -ItemType File
    remove-item $filestore\status\starttest.csv
    remove-item $filestore\status\templaunch.csv
    Remove-Item $filestore\status\currentstate.txt
    foreach($server in $Launchers){remove-item -Path "$filestore\status\$server.txt"}

    Foreach($server in $VDAs){
        Remove-item "\\$server\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\start.bat"
        Copy-item -Path "\\$server\c$\temp\timing.csv" -Destination $filestore\Timings\timing$server$date.csv
        }

    $replace = $filestore -replace "\\","\\"
    $replaceWL = $workload -replace "\\","\\"
    ((Get-Content -path $filestore\scripts\start.bat) -replace $replaceWL,"FILESERVER") | Set-Content -Path $filestore\scripts\start.bat -ErrorAction Stop
    ((Get-Content -path $filestore\scripts\workloadfunctions.psm1) -replace $replace,"FILESERVER") | Set-Content -Path $filestore\scripts\workloadfunctions.psm1 -ErrorAction Stop
    ((Get-Content -path $workload) -replace $replace,"FILESERVER") | Set-Content -Path $workload -ErrorAction Stop

   
   Get-Runspace -name "progressbar" | ForEach-Object {$_.dispose()}
   Get-Runspace -name "perfmon" | ForEach-Object {$_.dispose()}   
   
   update-window -control buttonStart -property Visibility -value "Visible"
   update-window -control buttonStop -property Visibility -value "Hidden"
   update-window -Control labelTestRunning -Property Content -Value "Test Ended"
   update-window -control pbProgress -property value -value "100"
   update-window -control labelDuration -property Content -value ""
            $syncHash.Window.Dispatcher.invoke(
                [action]{
                    $syncHash.textVDAs.isEnabled = $true
                    $syncHash.textLaunchers.isEnabled = $true
                    $syncHash.textUsers.isEnabled = $true
                    $syncHash.textDesktop.isEnabled = $true
                    $syncHash.textStorefrontURL.isEnabled = $true
                    $syncHash.textDelay.isEnabled = $true
                    $syncHash.textDomain.isEnabled = $true
                    $syncHash.textFileShare.isEnabled = $true
                    $syncHash.checkPerfmon.isEnabled = $true
                    $syncHash.textWorkload.isEnabled = $true
                    $syncHash.textWorkload.isEnabled = $true
                    $syncHash.textVDAs.Opacity = "1.0"
                    $syncHash.textLaunchers.Opacity = "1.0"
                    $syncHash.textUsers.Opacity = "1.0"
                    $syncHash.textDesktop.Opacity = "1.0"
                    $syncHash.textStorefrontURL.Opacity = "1.0"
                    $syncHash.textDelay.Opacity = "1.0"
                    $syncHash.textDomain.Opacity = "1.0"
                    $syncHash.textFileShare.Opacity = "1.0"
                    $syncHash.checkPerfmon.Opacity = "1.0"
                    $syncHash.textWorkload.Opacity = "1.0"
                    $syncHash.textWorkload.Opacity = "1.0"
                                    },
                "Normal")
                Get-ChildItem $filestore\status | where {$_.name -ne "endtest.txt"} | Remove-Item -Force
}  

Function Update-Window {
    Param (
        $Control,
        $Property,
        $Value,
        [switch]$AppendContent
    )

    # This is kind of a hack, there may be a better way to do this
    If ($Property -eq "Close") {
        $syncHash.Window.Dispatcher.invoke([action]{$syncHash.Window.Close()},"Normal")
        Return
    }

    # This updates the control based on the parameters passed to the function
    $syncHash.$Control.Dispatcher.Invoke([action]{
        # This bit is only really meaningful for the TextBox control, which might be useful for logging progress steps
        If ($PSBoundParameters['AppendContent']) {
            $syncHash.$Control.AppendText($Value)
        } Else {
            $syncHash.$Control.$Property = $Value
        }
    }, "Normal")
}

 #https://github.com/jeremysprite/ps-quser/blob/master/Get-LoggedOnUsers.ps1
Function Get-LoggedOnUsers {
    param(
      [string]$server = "localhost"
    )
      
    $users = @()
    # Query using quser, 2>$null to hide "No users exists...", then skip to the next server
    $quser = quser /server:$server 2>$null
    if(!($quser)){
        Continue
    }
     
    #Remove column headers
    $quser = $quser[1..$($quser.Count)]
    foreach($user in $quser){
        $usersObj = [PSCustomObject]@{Server=$null;Username=$null;SessionName=$null;SessionId=$Null;SessionState=$null;LogonTime=$null;IdleTime=$null}
        $quserData = $user -split "\s+"
      
        #We have to splice the array if the session is disconnected (as the SESSIONNAME column quserData[2] is empty)
        if(($user | select-string "Disc") -ne $null){
            #User is disconnected
            $quserData = ($quserData[0..1],"null",$quserData[2..($quserData.Length -1)]) -split "\s+"
        }
     
        # Server
        $usersObj.Server = $server
        # Username
        $usersObj.Username = $quserData[1]
        # SessionName
        $usersObj.SessionName = $quserData[2]
        # SessionID
        $usersObj.SessionID = $quserData[3]
        # SessionState
        $usersObj.SessionState = $quserData[4]
        # IdleTime
        $quserData[5] = $quserData[5] -replace "\+",":" -replace "\.","0:0" -replace "Disc","0:0"
        if($quserData[5] -like "*:*"){
            $usersObj.IdleTime = [timespan]"$($quserData[5])"
        }elseif($quserData[5] -eq "." -or $quserData[5] -eq "none"){
            $usersObj.idleTime = [timespan]"0:0"
        }else{
            $usersObj.IdleTime = [timespan]"0:$($quserData[5])"
        }
        # LogonTime
        $usersObj.LogonTime = (Get-Date "$($quserData[6]) $($quserData[7]) $($quserData[8] )")
         
        $users += $usersObj
      
    }
      
    return $users
      
    }

Function Start-Perfmon{
Param([string]$date,[string]$filestore,[string[]]$VDAs)
                
        $x+= "."
        $newRunspace =[runspacefactory]::CreateRunspace()
        $newRunspace.ApartmentState = "STA"
        $newRunspace.Name = "Perfmon"
        $newRunspace.ThreadOptions = "ReuseThread"          
        $newRunspace.Open()
        $newRunspace.SessionStateProxy.SetVariable("SyncHash",$SyncHash) 
        $newRunspace.SessionStateProxy.SetVariable("VDAs",$VDAs) 
        $newRunspace.SessionStateProxy.SetVariable("Filestore",$filestore) 
        $newRunspace.SessionStateProxy.SetVariable("Date",$date) 
        $PowerShell = [PowerShell]::Create().AddScript({
        set-location $filestore
        import-module $filestore\scripts\ControlFunctions.psm1       
        Get-counter -Counter "\Terminal Services\Total Sessions","\Processor(_Total)\% Processor Time","\Memory\% Committed Bytes In Use" -computername $VDAs -Continuous -SampleInterval 2 | export-counter "$filestore\perfmon\$date.blg" -ErrorAction stop

        })
        $PowerShell.Runspace = $newRunspace
        [void]$global:jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Runspace = $PowerShell.BeginInvoke()
            }
        ))
}

Function Start-ProgressBar{
Param([int]$intDelay,[int]$UserCount,[string]$filestore)
            $x+= "."
        $newRunspace =[runspacefactory]::CreateRunspace()
        $newRunspace.ApartmentState = "STA"
        $newRunspace.Name = "ProgressBar"
        $newRunspace.ThreadOptions = "ReuseThread"          
        $newRunspace.Open()
        $newRunspace.SessionStateProxy.SetVariable("SyncHash",$SyncHash)
        $newRunspace.SessionStateProxy.SetVariable("Delay",$intDelay) 
        $newRunspace.SessionStateProxy.SetVariable("UserCount",$UserCount) 
        $newRunspace.SessionStateProxy.SetVariable("Filestore",$Filestore) 
        $PowerShell = [PowerShell]::Create().AddScript({
        import-module $filestore\scripts\ControlFunctions.psm1       
 $totalSeconds = ($Delay + 15) * $UserCount
 $percentPerSecond = 100 / $totalseconds
 $endTime = (Get-Date).AddSeconds($totalSeconds)

 do{
    $remainingseconds = $endTime - (get-date) | ForEach-Object{$_.TotalSeconds}
    $displaysecs = [Int]$remainingseconds
    $currentPerCent = ($totalSeconds - $remainingseconds) * $percentPerSecond 
    $syncHash.Window.Dispatcher.invoke(
        [action]{
           
            $synchash.pbProgress.Value = $currentPerCent
            $synchash.labelDuration.Content = "$displaysecs seconds left"
            
        },
        "Normal"
    ) 

 Start-Sleep 1

    }
 until($displaysecs -lt 1)
        
        })
        $PowerShell.Runspace = $newRunspace
        [void]$global:jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Runspace = $PowerShell.BeginInvoke()
            }
        ))

}

Function Start-SessionInfo{
Param([string[]]$VDAs,[string]$filestore)

            $x+= "."
        $newRunspace =[runspacefactory]::CreateRunspace()
        $newRunspace.ApartmentState = "STA"
        $newRunspace.Name = "SessionInfo"
        $newRunspace.ThreadOptions = "ReuseThread"          
        $newRunspace.Open()
        $newRunspace.SessionStateProxy.SetVariable("SyncHash",$SyncHash)
        $newRunspace.SessionStateProxy.SetVariable("VDAs",$VDAs)
        $newRunspace.SessionStateProxy.SetVariable("Filestore",$filestore)  
        $PowerShell = [PowerShell]::Create().AddScript({
        import-module $filestore\scripts\ControlFunctions.psm1       
  #Wait-Debugger
 do{
     $script:sessionAdd = @()
                                #$syncHash.Window.Dispatcher.invoke([action]{$synchash.DataGridSessions.itemssource = $script:sessionAdd},"Normal")      
    foreach($server in $VDAs){
                                
                                $sessions = Get-LoggedOnUsers -server $server

                                ForEach($session in $sessions){
                                                                $username = $session.username
                                                                $logontime = $session.logontime
                                                                $server = $session.server
                                                                $script:sessionAdd += New-Object PSObject -property @{'username'="$username";'logintime'="$LogonTime";'server'="$server"}
                                                                }
                                
                                $syncHash.Window.Dispatcher.invoke([action]{$synchash.DataGridSessions.itemssource = $script:sessionAdd},"Normal")      
                                }                      
    Start-Sleep 5
    }
until($p -eq 100)
        #Wait-Debugger
})        
     
        $PowerShell.Runspace = $newRunspace
        [void]$global:jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Runspace = $PowerShell.BeginInvoke()
            }
        ))
        }



Function Inspect-Inputs{
Param([string]$date,[string]$filestore,[string[]]$launchers,[string[]]$VDAs,[string]$workload,[string]$desktop,[string]$delay,[string]$storefrontURL,[string[]]$users)
$global:hidecontrols=("textVDAs","textLaunchers","textUsers","textDomain","textDesktop","textStorefrontURL","textDelay","textFileshare","textWorkload")
 

                                 $syncHash.Window.Dispatcher.invoke(
                [action]{
                    $syncHash.textVDAs.isEnabled = $false
                    $syncHash.textLaunchers.isEnabled = $false
                    $syncHash.textUsers.isEnabled = $false
                    $syncHash.textDesktop.isEnabled = $false
                    $syncHash.textStorefrontURL.isEnabled = $false
                    $syncHash.textDelay.isEnabled = $false
                    $syncHash.textDomain.isEnabled = $false
                    $syncHash.textFileShare.isEnabled = $false
                    $syncHash.checkPerfmon.isEnabled = $false
                    $syncHash.textWorkload.isEnabled = $false
                    $syncHash.textWorkload.isEnabled = $false
                    $syncHash.textVDAs.Opacity = "0.3"
                    $syncHash.textLaunchers.Opacity = "0.3"
                    $syncHash.textUsers.Opacity = "0.3"
                    $syncHash.textDesktop.Opacity = "0.3"
                    $syncHash.textStorefrontURL.Opacity = "0.3"
                    $syncHash.textDelay.Opacity = "0.3"
                    $syncHash.textDomain.Opacity = "0.3"
                    $syncHash.textFileShare.Opacity = "0.3"
                    $syncHash.checkPerfmon.Opacity = "0.3"
                    $syncHash.textWorkload.Opacity = "0.3"
                    $syncHash.textWorkload.Opacity = "0.3"

                                    },
                "Normal")
}

Function Watch-LauncherStatus{
Param([string]$filestore,[string[]]$launchers,[string]$launchersCount)


update-window -Control labelTestRunning -Property Content -Value "Checking Launchers"
update-window -control buttonStart -property Visibility -value "Hidden"
update-window -control buttonStop -property Visibility -value "visible"

   $script:LauncherAdd = @()
   Foreach ($launcher in $launchers)
            {
            $launcherEnd = Test-Path -path $filestore\status\$server-end.txt
            If($launcher -eq $true){Remove-Item -path $filestore\status\$server-end.txt}
                
                $script:LauncherAdd += New-Object PSObject -property @{Launcher=$launcher;Status="checking"}
                $syncHash.Window.Dispatcher.invoke([action]{$synchash.DataGridLaunchers.itemssource = $script:LauncherAdd},"Normal") 
                
            }  
            Foreach ($launcher in $launchers){
                                                    Do{ 
                                                        if(($launcherReady = (test-path $fileStore\status\$launcher.txt)) -eq $True)
                                                        {
                                                            $update = $script:LauncherAdd | where {$_.Launcher -eq "$launcher"}
                                                            $update.Status = "ready"
                                                            $syncHash.Window.Dispatcher.invoke([action]{$synchash.DataGridLaunchers.items.refresh()},"Normal") 
                                                        }
                                                        Start-Sleep 1
                                                       }
                                                    Until($launcherReady -eq $True)
                                                    }
            }    

Function Watch-TestStatus{
Param([string]$filestore,[string]$launcher,[string]$delay)

            Foreach ($launcher in $launchers){
                                                    Do{$earlyFinish = test-path "$filestore\status\endtest.txt"
                                                        if(($launcherFinished = (test-path $fileStore\status\$launcher-END.txt)) -eq $True)
                                                        {
                                                            $update = $script:LauncherAdd | where {$_.Launcher -eq "$launcher"}
                                                            $update.Status = "Finished"
                                                            $syncHash.Window.Dispatcher.invoke([action]{$synchash.DataGridLaunchers.items.refresh()},"Normal") 
                                                        }
                                                        Start-Sleep 5
                                                       }
                                                    Until($launcherFinished -eq $True -or $earlyfinish -eq $True) 
                                                    }
                                                    #Wait-Debugger
                                                    if($earlyFinish -eq $False){start-sleep $delay}
}