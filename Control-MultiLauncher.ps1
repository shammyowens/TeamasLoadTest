#File is partly based on https://github.com/1RedOne/BlogPosts/blob/master/GUI%20Part%20V/PowerShell_GUI_Template.ps1

Add-Type -AssemblyName PresentationCore, PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

if((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -eq $false){
    [System.Windows.Forms.MessageBox]::Show("This machine is not joined to a domain")
exit
}

$Global:syncHash = [hashtable]::Synchronized(@{})
$newRunspace =[runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("syncHash",$syncHash)

$psCmd = [PowerShell]::Create().AddScript({
    
    [xml]$xaml = Get-Content xaml\multilauncher.xaml
    $AttributesToRemove = @(
        'x:Class',
        'mc:Ignorable'
    )

    foreach ($Attrib in $AttributesToRemove) {
        if ( $xaml.Window.GetAttribute($Attrib) ) {
             $xaml.Window.RemoveAttribute($Attrib)
        }
    }
    
    $reader=(New-Object System.Xml.XmlNodeReader $xaml)
    
    $syncHash.Window=[Windows.Markup.XamlReader]::Load( $reader )

    [xml]$XAML = $xaml
        $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object{
        #Find all of the form types and add them as members to the synchash
        $syncHash.Add($_.Name,$syncHash.Window.FindName($_.Name) )

    }

    $Script:JobCleanup = [hashtable]::Synchronized(@{})
    $Script:Jobs = [system.collections.arraylist]::Synchronized((New-Object System.Collections.ArrayList))

    #region Background runspace to clean up jobs
    $jobCleanup.Flag = $True
    $newRunspace =[runspacefactory]::CreateRunspace()
    $newRunspace.ApartmentState = "STA"
    $newRunspace.ThreadOptions = "ReuseThread"          
    $newRunspace.Open()        
    $newRunspace.SessionStateProxy.SetVariable("jobCleanup",$jobCleanup)     
    $newRunspace.SessionStateProxy.SetVariable("jobs",$jobs) 
    $jobCleanup.PowerShell = [PowerShell]::Create().AddScript({
        #Routine to handle completed runspaces
        Do {    
            Foreach($runspace in $jobs) {            
                If ($runspace.Runspace.isCompleted) {
                    [void]$runspace.powershell.EndInvoke($runspace.Runspace)
                    $runspace.powershell.dispose()
                    $runspace.Runspace = $null
                    $runspace.powershell = $null               
                } 
            }
            #Clean out unused runspace jobs
            $temphash = $jobs.clone()
            $temphash | Where-Object {
                $_.runspace -eq $Null
            } | ForEach-Object {
                $jobs.remove($_)
            }        
            Start-Sleep -Seconds 1     
        } while ($jobCleanup.Flag)
    })
    $jobCleanup.PowerShell.Runspace = $newRunspace
    $jobCleanup.Thread = $jobCleanup.PowerShell.BeginInvoke()  
    #endregion Background runspace to clean up jobs

    $syncHash.textDomain.Text = $env:USERDOMAIN
    $syncHash.textFileShare.Text = (Get-Location) | ForEach-Object{$_.ProviderPath}
    $syncHash.buttonWorkload.Add_Click({
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    InitialDirectory = (Get-Location) | ForEach-Object{$_.ProviderPath}
    Multiselect = $false
    Filter = 'Poweshell (*.PS1)|*.PS1'
    }
    $null = $FileBrowser.ShowDialog()

            $syncHash.Window.Dispatcher.invoke(
                [action]{
                    $syncHash.textWorkload.Text = $FileBrowser.FileName
                "Normal"
            })
    })

    $syncHash.buttonStart.Add_Click({
            $x+= "."
        $newRunspace =[runspacefactory]::CreateRunspace()
        $newRunspace.ApartmentState = "STA"
        $newRunspace.ThreadOptions = "ReuseThread"  
        $newRunspace.Name = "StartTest"        
        $newRunspace.Open()
        $newRunspace.SessionStateProxy.SetVariable("SyncHash",$SyncHash) 
        $PowerShell = [PowerShell]::Create().AddScript({

            $syncHash.Window.Dispatcher.invoke(
                [action]{
                    $script:VDAs = $syncHash.textVDAs.Text.split()
                    $script:Launchers = $syncHash.textLaunchers.Text.split()
                    $script:Users = $syncHash.textUsers.Text.split()
                    $script:Desktop = $syncHash.textDesktop.Text
                    $script:StorefrontURL = $syncHash.textStorefrontURL.text
                    $script:Delay = $syncHash.textDelay.text
                    $script:Domain = $syncHash.textDomain.Text
                    $script:FileStore = $syncHash.textFileShare.Text
                    $script:Perfmon = $syncHash.checkPerfmon.isChecked
                    $script:Workload = $syncHash.textWorkload.Text
                    $script:enabled = $syncHash.textWorkload.isEnabled
                    $syncHash.listViewSessions.items.Clear()
                                    },
                "Normal"
            )

            $intDelay = [int]$script:Delay
            $script:date = (Get-Date -format filedatetime)
Function publish-test{

   update-window -control buttonStart -property Visibility -value "Hidden"
   update-window -control buttonStop -property Visibility -value "visible"
   update-window -Control LabelTestRunning -Property Content -Value "Test Started"
   
Try{
    ((Get-Content -path $filestore\scripts\start.bat) -replace "FILESERVER",$script:Workload) | Set-Content -Path $filestore\scripts\start.bat -ErrorAction Stop
    ((Get-Content -path $filestore\scripts\WorkloadFunctions.psm1) -replace "FILESERVER",$filestore) | Set-Content -Path $filestore\scripts\WorkloadFunctions.psm1 -ErrorAction Stop
    ((Get-Content -path $script:Workload) -replace "FILESERVER",$filestore) | Set-Content -Path $script:Workload -ErrorAction Stop
    
   }
Catch
    {[System.Windows.Forms.MessageBox]::Show("Cannot Amend workload files")
    exit}

    $endtest = Test-Path -path $filestore\status\endtest.txt
    If($endtest -eq $true){Remove-Item -path $filestore\status\endtest.txt}

Try{
    Foreach($server in $script:VDAs){
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
foreach($user in $script:users){
                            
                            if($launcherdelay -ge $script:Launchers.count){$delay = $script:launchers.count * $intdelay}
                            else{$delay = $steppeddelay}
                            $LauncherAdd = New-Object PSObject -property @{user=$user;server="";delay=$delay;desktop=$script:desktop;storefrontURL=$script:storefrontURL}
                            $LauncherAdd | export-csv "$filestore\status\templaunch.csv" -Append -NoTypeInformation
                            $steppeddelay += $intdelay
                            $launcherdelay += 1
                            }

                            $launch = import-csv "$filestore\status\templaunch.csv"

                            $a = 0
                            $serverlistcount = $script:Launchers.Count 
                            ForEach($line in $launch){
                            if($a -eq $serverlistcount){$a = 0}
                            
                            $line.server = $script:Launchers[$a]
                            $a += 1
                            $a
                            }

$launch | export-csv "$script:filestore\status\startTest.csv" -NoTypeInformation
#foreach($server in $script:Launchers){new-item -Path "$script:filestore\status\$server.txt"}


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
Function unpublish-test {Param([string]$date)
    $script:date = (Get-Date -format filedatetime)
    new-Item -path $filestore\status\endtest.txt -ItemType File
    remove-item $script:filestore\status\starttest.csv
    remove-item $script:filestore\status\templaunch.csv
    foreach($server in $script:Launchers){remove-item -Path "$script:filestore\status\$server.txt"}

    sleep $script:delay
    Foreach($server in $script:VDAs){
        Remove-item "\\$server\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\start.bat"
        #Wait-Debugger
        Copy-item -Path "\\$server\c$\temp\timing.csv" -Destination $filestore\Timings\timing$server$script:date.csv
        }

    Foreach($server in $script:launchers){remove-item -Path "$script:filestore\status\$server.txt"}

        Remove-Item -Path $filestore\status\currentstate.txt
    
    $replace = $filestore -replace "\\","\\"
    $replaceWL = $script:workload -replace "\\","\\"
    ((Get-Content -path $filestore\scripts\start.bat) -replace $replaceWL,"FILESERVER") | Set-Content -Path $filestore\scripts\start.bat -ErrorAction Stop
    ((Get-Content -path $filestore\scripts\workloadfunctions.psm1) -replace $replace,"FILESERVER") | Set-Content -Path $filestore\scripts\workloadfunctions.psm1 -ErrorAction Stop
    ((Get-Content -path $script:workload) -replace $replace,"FILESERVER") | Set-Content -Path $script:workload -ErrorAction Stop

   Get-Runspace -name "progressbar" | ForEach-Object {$_.dispose()}
   update-window -control buttonStart -property Visibility -value "Visible"
   update-window -control buttonStop -property Visibility -value "Hidden"
   update-window -Control labelTestRunning -Property Content -Value "Test Ended"
   update-window -control pbProgress -property value -value "100"
   update-window -control labelDuration -property Content -value ""
   Get-Runspace -name "perfmon" | ForEach-Object {$_.dispose()}
   Get-Runspace -name "sessionInfo" | ForEach-Object {$_.dispose()}
    
}  
       
    $filestore = $script:FileStore
    set-location $filestore   
                                          
    If((get-location | ForEach-Object{$_.ProviderPath}) -match ":")
    {
    update-window -Control labelTestRunning -Property Content -Value "Please run from a FileShare!"
    Get-Runspace -name "StartTest" | ForEach-Object {$_.dispose()}
    Exit
    }
   
   #Look for Launcher Files

   update-window -Control labelTestRunning -Property Content -Value "Checking Launchers"
   
   Foreach ($launcher in $script:Launchers)
            {
                Do{ 
                    if(($launcherReady = (test-path $script:FileStore\status\$launcher.txt)) -eq $True)
                    {$readyLaunchers ++}

                    }
                
   Until($launcherReady -eq $True )
            }          
    #Test Started

    If($script:perfmon -eq $true){
    #region Perfmon
            $x+= "."
        $newRunspace =[runspacefactory]::CreateRunspace()
        $newRunspace.ApartmentState = "STA"
        $newRunspace.Name = "Perfmon"
        $newRunspace.ThreadOptions = "ReuseThread"          
        $newRunspace.Open()
        $newRunspace.SessionStateProxy.SetVariable("SyncHash",$SyncHash) 
        $newRunspace.SessionStateProxy.SetVariable("VDAs",$script:VDAs) 
        $newRunspace.SessionStateProxy.SetVariable("Filestore",$script:Filestore) 
        $PowerShell = [PowerShell]::Create().AddScript({
        #$filestore = $script:Filestore
        set-location $filestore
        $script:date = (Get-Date -format filedatetime)
        #wait-debugger
        
        Get-counter -Counter "\Terminal Services\Total Sessions","\Processor(_Total)\% Processor Time","\Memory\% Committed Bytes In Use" -computername $VDAs -Continuous -SampleInterval 2 | export-counter "$filestore\perfmon\$script:date.blg" -ErrorAction stop

        })
        $PowerShell.Runspace = $newRunspace
        [void]$Jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Runspace = $PowerShell.BeginInvoke()
            }
        ))
        #endregion perfmon
                                  }
    #region progressbar

            $x+= "."
        $newRunspace =[runspacefactory]::CreateRunspace()
        $newRunspace.ApartmentState = "STA"
        $newRunspace.Name = "ProgressBar"
        $newRunspace.ThreadOptions = "ReuseThread"          
        $newRunspace.Open()
        $newRunspace.SessionStateProxy.SetVariable("SyncHash",$SyncHash)
        $newRunspace.SessionStateProxy.SetVariable("Delay",$intDelay) 
        $newRunspace.SessionStateProxy.SetVariable("UserCount",$Script:Users.count) 
        $PowerShell = [PowerShell]::Create().AddScript({

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
 #wait-debugger
    }
 until($displaysecs -lt 1)
        

        })
        $PowerShell.Runspace = $newRunspace
        [void]$Jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Runspace = $PowerShell.BeginInvoke()
            }
        ))


    #endregion progressbar

    #region sessionInfo

            $x+= "."
        $newRunspace =[runspacefactory]::CreateRunspace()
        $newRunspace.ApartmentState = "STA"
        $newRunspace.Name = "SessionInfo"
        $newRunspace.ThreadOptions = "ReuseThread"          
        $newRunspace.Open()
        $newRunspace.SessionStateProxy.SetVariable("SyncHash",$SyncHash)
        $newRunspace.SessionStateProxy.SetVariable("VDAs",$Script:VDAs) 
        $PowerShell = [PowerShell]::Create().AddScript({

 #https://github.com/jeremysprite/ps-quser/blob/master/Get-LoggedOnUsers.ps1
 function Get-LoggedOnUsers {
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

 do{
    foreach($server in $VDAs){
                                
                                $sessions = Get-LoggedOnUsers -server $server
                                 ForEach($session in $sessions){
                                            $username = $session.username
                                            $logontime = $session.logontime
                                            $server = $session.server

                                            $syncHash.Window.Dispatcher.invoke(
                                    [action]{

                                        $script:listsessions = $syncHash.listViewSessions.items
                                        If($script:listsessions.username -notcontains $username){
                                                                                        $synchash.listViewSessions.items.add([pscustomobject]@{'username'="$username";'logintime'="$LogonTime";'server'="$server"})
                                                                                        }
                                    },
                                    "Normal"
                                ) 
                                            
                                        }
                                }
                                
                                
                                Start-Sleep 5
                                
                                }
                             until($x -eq 1)
        

        })
        $PowerShell.Runspace = $newRunspace
        [void]$Jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Runspace = $PowerShell.BeginInvoke()
            }
        ))


    #endregion sessioninfo
    
   publish-test

   Do
   
   {$isFinished = Get-Content "$filestore\status\currentstate.txt"
    $earlyFinish = test-path "$filestore\status\endtest.txt"
        Start-Sleep 5
   }
   Until($isFinished.count -eq $script:launchers.count -or $earlyfinish -eq $True)

   unpublish-test               

            })
        $PowerShell.Runspace = $newRunspace
        [void]$Jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Runspace = $PowerShell.BeginInvoke()
            }
        ))
    })

    $syncHash.buttonStop.Add_Click({
            $x+= "."
        $newRunspace =[runspacefactory]::CreateRunspace()
        $newRunspace.ApartmentState = "STA"
        $newRunspace.ThreadOptions = "ReuseThread"          
        $newRunspace.Open()
        $newRunSpace.name = "StopTest"
        $newRunspace.SessionStateProxy.SetVariable("SyncHash",$SyncHash) 
        $PowerShell = [PowerShell]::Create().AddScript({


        $syncHash.Window.Dispatcher.invoke(
                [action]{
                    $script:VDAs = $syncHash.textVDAs.Text.split()
                    $script:Launchers = $syncHash.textLaunchers.Text.split()
                    $script:Users = $syncHash.textUsers.Text.split()
                    $script:Desktop = $syncHash.textDesktop.Text
                    $script:StorefrontURL = $syncHash.textStorefrontURL.text
                    $script:Delay = $syncHash.textDelay.text
                    $script:Domain = $syncHash.textDomain.Text
                    $script:Filestore = $syncHash.textFileShare.Text
                    $script:Workload = $syncHash.textWorkload.Text
                },
                "Normal"
            )
         
        $filestore = $script:filestore

Function unpublish-test {Param([string]$date)
    $script:date = (Get-Date -format filedatetime)
    new-Item -path $filestore\status\endtest.txt -ItemType File
    remove-item $script:filestore\status\starttest.csv
    remove-item $script:filestore\status\templaunch.csv
    foreach($server in $script:Launchers){remove-item -Path "$script:filestore\status\$server.txt"}

   update-window -control buttonStart -property Visibility -value "Visible"
   update-window -control buttonStop -property Visibility -value "Hidden"
   update-window -Control labelTestRunning -Property Content -Value "Test Ended"
   update-window -control pbProgress -property value -value "100"
   update-window -control labelDuration -property Content -value ""
   Get-Runspace -name "progressbar" | ForEach-Object {$_.dispose()}

    sleep $script:delay
    Foreach($server in $script:VDAs){
        Remove-item "\\$server\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\start.bat"
        Copy-item -Path "\\$server\c$\temp\timing.csv" -Destination $filestore\Timings\timing$server$script:date.csv
                                    }
        
        Remove-Item -Path $filestore\status\currentstate.txt

            Foreach($server in $script:launchers){remove-item -Path "$script:filestore\status\$server.txt"}
    $replace = $filestore -replace "\\","\\"
    $replaceWL = $script:workload -replace "\\","\\"
    ((Get-Content -path $filestore\scripts\start.bat) -replace $replaceWL,"FILESERVER") | Set-Content -Path $filestore\scripts\start.bat -ErrorAction Stop
    ((Get-Content -path $filestore\scripts\workloadfunctions.psm1) -replace $replace,"FILESERVER") | Set-Content -Path $filestore\scripts\workloadfunctions.psm1 -ErrorAction Stop
    ((Get-Content -path $script:workload) -replace $replace,"FILESERVER") | Set-Content -Path $script:workload -ErrorAction Stop
   
   Get-Runspace -name "perfmon" | ForEach-Object {$_.dispose()}
   Get-Runspace -name "sessionInfo" | ForEach-Object {$_.dispose()}
   Get-Runspace -name "startTest" | ForEach-Object {$_.dispose()}
    
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
    

    unpublish-test

        })
        $PowerShell.Runspace = $newRunspace
        [void]$Jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Runspace = $PowerShell.BeginInvoke()
            }
        ))
    })

    #region Window Close 
    $syncHash.Window.Add_Closed({
        Write-Verbose 'Halt runspace cleanup job processing'
        $jobCleanup.Flag = $False

        #Stop all runspaces
        $jobCleanup.PowerShell.Dispose()  
        Get-Runspace | Where-Object {$_.RunspaceAvailability -eq 'Available'} | ForEach-Object {$_.dispose()}    
    })
    #endregion Window Close 
    $syncHash.Window.ShowDialog() | Out-Null
    $syncHash.Error = $Error
    })

$psCmd.Runspace = $newRunspace
$data = $psCmd.BeginInvoke()

#this is a hacky way of keeping the GUI open when run from Console
#do{$something = 0}
#until($something -eq 1)