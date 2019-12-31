Function publish-test{Param([string]$date,[string]$filestore,[string[]]$launchers,[string[]]$VDAs,[string]$workload,[string]$desktop,[int]$intdelay,[string]$storefrontURL,[string[]]$users)
    Write-Log -Message "Publish Test invoked" -Level Info -Path $script:filestore\logs\$date-log.text
    Get-Runspace -name "sessionInfo" | ForEach-Object {$_.dispose()} 
    update-window -Control LabelTestRunning -Property Content -Value "Test Started"
      
 Try{
     ((Get-Content -path $filestore\scripts\start.bat) -replace "FILESERVER",$Workload) | Set-Content -Path $filestore\scripts\start.bat -ErrorAction Stop
     ((Get-Content -path $filestore\scripts\WorkloadFunctions.psm1) -replace "FILESERVER",$filestore) | Set-Content -Path $filestore\scripts\WorkloadFunctions.psm1 -ErrorAction Stop
     ((Get-Content -path $Workload) -replace "FILESERVER",$filestore) | Set-Content -Path $Workload -ErrorAction Stop
    }
 Catch
     {
     [System.Windows.Forms.MessageBox]::Show("Cannot Amend workload files")
     Write-Log -Message "Cannot Amend workload Files" -Level Info -Path $script:filestore\logs\$date-log.text
     exit
     ]}
 
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
 Catch{
     [System.Windows.Forms.MessageBox]::Show("Cannot Prepare VDAs")
     Write-Log -Message "Cannot Prepare VDAs" -Level Info -Path $script:filestore\logs\$date-log.text
     exit
     }
 
 
 $launcherdelay = 0
 $steppeddelay = 0
 foreach($user in $users)   {
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
 
 Write-Log -Message "Test Published" -Level Info -Path $script:filestore\logs\$date-log.text
 }

Function Unpublish-test {Param([string]$date,[string]$filestore,[string[]]$launchers,[string[]]$VDAs,[string]$workload)
    Write-Log -Message "Unpublish Test Invoked" -Level Info -Path $script:filestore\logs\$date-log.text
    new-Item -path $filestore\status\endtest.txt -ItemType File
    remove-item $filestore\status\starttest.csv
    remove-item $filestore\status\templaunch.csv
    Remove-Item $filestore\status\currentstate.txt
    Foreach($server in $Launchers){remove-item -Path "$filestore\status\$server.txt"}

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
            
   Set-WindowControls -Instruction "stop"

   Get-ChildItem $filestore\status | Where-Object {$_.name -ne "endtest.txt"} | Remove-Item -Force
   Write-Log -Message "Test Unpublished" -Level Info -Path $script:filestore\logs\$date-log.text
}  

#https://learn-powershell.net/2012/10/14/powershell-and-wpf-writing-data-to-a-ui-from-a-different-runspace/
Function Update-Window{
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
        if($null -ne ($user | select-string "Disc")){
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

#https://github.com/JimMoyle/YetAnotherWriteLog/blob/master/Write-Log.ps1
Function Write-Log {
    <#
        .SYNOPSIS
        Single function to enable logging to file
        .DESCRIPTION
        The Log file can be output to any directory. A single log entry looks like this:
        2018-01-30 14:40:35 INFO:    'My log text'
        Log entries can be Info, Warning, Error or Debug
        The function takes pipeline input and you can pipe exceptions straight to the function for automatic logging.
        The $PSDefaultParameterValues built-in Variable can be used to conveniently set the path and/or JSONformat switch at the top of the script:
        $PSDefaultParameterValues = @{"Write-Log:Path" = 'C:\YourPathHere.log'}
        $PSDefaultParameterValues = @{"Write-Log:JSONformat" = $true}
        .PARAMETER Message
        This is the body of the log line and should contain the information you wish to log.
        .PARAMETER Level
        One of four logging levels: INFO, WARNING, ERROR or DEBUG.  This is an optional parameter and defaults to INFO
        .PARAMETER Path
        The path where you want the log file to be created.  This is an optional parameter and defaults to "$env:temp\PowershellScript.log"
        .PARAMETER StartNew
        This will blank any current log in the path, it should be used at the start of your code if you don't want to append to an existing log.
        .PARAMETER Exception
        Used to pass a powershell exception to the logging function for automatic logging, this will log the excption message as an error.
        .PARAMETER JSONFormat
        Used to change the logging format from human readable to machine readable format, this will be a single line like the example format below:
        In this format the timestamp will include a much more granular time which will also include timezone information.  The format is optimised for Splunk input, but should work for any other platform.
        {"TimeStamp":"2018-02-01T12:01:24.8908638+00:00","Level":"Warning","Message":"My message"}
        .EXAMPLE
        Write-Log -StartNew
        Starts a new logfile in the default location
        .EXAMPLE
        Write-Log -StartNew -Path c:\logs\new.log
        Starts a new logfile in the specified location
        .EXAMPLE
        Write-Log 'This is some information'
        Appends a new information line to the log.
        .EXAMPLE
        Write-Log -level Warning 'This is a warning'
        Appends a new warning line to the log.
        .EXAMPLE
        Write-Log -level Error 'This is an Error'
        Appends a new Error line to the log.
        .EXAMPLE
        Write-Log -Exception $error[0]
        Appends a new Error line to the log with the message being the contents of the exception message.
        .EXAMPLE
        $error[0] | Write-Log
        Appends a new Error line to the log with the message being the contents of the exception message.
        .EXAMPLE
        'My log message' | Write-Log
        Appends a new Info line to the log with the message being the contents of the string.
        .EXAMPLE
        Write-Log 'My log message' -JSONFormat
        Appends a new Info line to the log with the message. The line will be in JSONFormat.
    #>

    [CmdletBinding(DefaultParametersetName = "LOG")]
    Param (

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'LOG',
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'LOG',
            Position = 1 )]
        [ValidateSet('Error', 'Warning', 'Info', 'Debug')]
        [string]$Level = "Info",

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
        [string]$Path = "$env:temp\PowershellScript.log",

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true)]
        [switch]$JSONFormat,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'STARTNEW')]
        [switch]$StartNew,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'EXCEPTION')]
        [System.Management.Automation.ErrorRecord]$Exception
    )

    BEGIN {
        Set-StrictMode -version Latest #Enforces most strict best practice.
    }

    PROCESS {
        #Switch on parameter set
        switch ($PSCmdlet.ParameterSetName) {
            LOG {
                #Get human readable date
                $formattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

                switch ( $Level ) {
                    'Info' { $levelText = "INFO:   "; break }
                    'Error' { $levelText = "ERROR:  "; break }
                    'Warning' { $levelText = "WARNING:"; break }
                    'Debug' { $levelText = "DEBUG:  "; break }
                }

                #Build an object so we can later convert it

                $logObject = @{
                    #TimeStamp = Get-Date -Format o  #Get machine readable date
                    Level   = $levelText
                    Message = $Message
                }

                if ($JSONFormat) {
                    $logobject = [PSCustomObject][ordered]@{
                        TimeStamp = Get-Date -Format o
                        Level   = $levelText
                        Message = $Message
                    }
                    #Convert to a single line of JSON and add it to the file
                    $logMessage = $logObject | ConvertTo-Json -Compress
                    $logMessage | Add-Content -Path $Path
                }
                else {
                    $logobject = [PSCustomObject][ordered]@{
                        TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        Level   = $levelText
                        Message = $Message
                    }
                    $logMessage = "$formattedDate`t$levelText`t$Message" #Build human readable line
                    $logObject | Export-Csv -Path $Path -Delimiter "`t" -NoTypeInformation -Append
                }

                Write-Verbose $logMessage #Only verbose line in the function

            } #LOG

            EXCEPTION {
                #Splat parameters
                $writeLogParams = @{
                    Level      = 'Error'
                    Message    = $Exception.Exception.Message
                    Path       = $Path
                    JSONFormat = $JSONFormat
                }
                Write-Log @writeLogParams #Call itself to keep code clean
                break

            } #EXCEPTION

            STARTNEW {
                if (Test-Path $Path) {
                    Remove-Item $Path -Force
                }
                #Splat parameters
                $writeLogParams = @{
                    Level      = 'Info'
                    Message    = 'Starting Logfile'
                    Path       = $Path
                    JSONFormat = $JSONFormat
                }
                Write-Log @writeLogParams
                break

            } #STARTNEW

        } #switch Parameter Set
    }

    END {
    }
} #function Write-Log

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
        $newRunspace.SessionStateProxy.SetVariable("intDelay",$intDelay) 
        $newRunspace.SessionStateProxy.SetVariable("UserCount",$UserCount) 
        $newRunspace.SessionStateProxy.SetVariable("Filestore",$Filestore) 
        $PowerShell = [PowerShell]::Create().AddScript({
        import-module $filestore\scripts\ControlFunctions.psm1       
 $totalSeconds = ($intDelay + 15) * $UserCount
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

})        
     
        $PowerShell.Runspace = $newRunspace
        [void]$global:jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Runspace = $PowerShell.BeginInvoke()
            }
        ))
        }

Function Test-Inputs{
Param([string]$date,[string]$filestore,[string[]]$launchers,[string[]]$VDAs,[string]$workload,[string]$desktop,[string]$delay,[string]$storefrontURL,[string[]]$users)

#Foreach VDA in VDAs, check that the VDA is a computer somehow?
#foreach launcher, check that it is a computer

#test filestore
Set-Location -Path $filestore
If((get-location - | ForEach-Object{$_.ProviderPath}) -match ":")
    {
    update-window -Control labelTestRunning -Property Content -Value "Please run from a FileShare!"
    Write-Log -Message "Not Running from Fileshare" -Level Error -Path $script:filestore\logs\$date-log.text
    Get-Runspace -name "StartTest" | ForEach-Object {$_.dispose()}
    Exit
    }

#test delay is a number
Try{$script:intDelay = [int]$script:Delay}
            Catch{
                [System.Windows.Forms.MessageBox]::Show("Delay is not a number")
                Write-Log -Message "Delay is not a number" -Level Info -Path $script:filestore\logs\$date-log.text
                Get-Runspace -name "StartTest" | ForEach-Object {$_.dispose()}
                Exit
                }

#check storefront URL is valid
#test it is actually an accesible URL
Try{$output = invoke-webrequest $storefrontURL | ForEach-Object{$_.RawContent}}
                Catch{
                [System.Windows.Forms.MessageBox]::Show("Is the Storefront URL and proper URL and site accesible?")
                Write-Log -Message "StorefrontURL is not a valid URL or website is not accesible" -Level Info -Path $script:filestore\logs\$date-log.text
                Get-Runspace -name "StartTest" | ForEach-Object {$_.dispose()}
                Exit
                    }
#Test that the URL is citrix storefront/netscaler
if($output -notmatch "citrix")
                            {
                            [System.Windows.Forms.MessageBox]::Show("Is the URL for Citrix StoreFront?")
                            Write-Log -Message "StorefrontURL is a valid URL, but not a StoreFront site" -Level Info -Path $script:filestore\logs\$date-log.text
                            Get-Runspace -name "StartTest" | ForEach-Object {$_.dispose()}
                            Exit
                            }

#check users

#After everything is tested, disable window controls
Set-WindowControls -Instruction "start"

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
            If($launcherEnd -eq $true){Remove-Item -path $filestore\status\$server-end.txt}
                
                $script:LauncherAdd += New-Object PSObject -property @{Launcher=$launcher;Status="checking"}
                $syncHash.Window.Dispatcher.invoke([action]{$synchash.DataGridLaunchers.itemssource = $script:LauncherAdd},"Normal") 
                
            }  
            Foreach ($launcher in $launchers){
                                                    Do{ 
                                                        if(($launcherReady = (test-path $fileStore\status\$launcher.txt)) -eq $True)
                                                        {
                                                            $update = $script:LauncherAdd | Where-Object {$_.Launcher -eq "$launcher"}
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
                                                            $update = $script:LauncherAdd | Where-Object {$_.Launcher -eq "$launcher"}
                                                            $update.Status = "Finished"
                                                            $syncHash.Window.Dispatcher.invoke([action]{$synchash.DataGridLaunchers.items.refresh()},"Normal") 
                                                        }
                                                        Start-Sleep 5
                                                       }
                                                    Until($launcherFinished -eq $True -or $earlyfinish -eq $True) 
                                                    }
                                                   
                                                    if($earlyFinish -eq $False){start-sleep $delay}
}

Function Set-WindowControls{
    Param([string]$Instruction)

    if($Instruction -eq "start")
        {
        $enabled = $false
        $opacity = "0.3"
        }
    if($Instruction -eq "stop")
        {
        $enabled = $true
        $opacity = "1.0"
        }
    $syncHash.Window.Dispatcher.invoke(
        [action]{
            $syncHash.textVDAs.isEnabled = $enabled
            $syncHash.textLaunchers.isEnabled = $enabled
            $syncHash.textUsers.isEnabled = $enabled
            $syncHash.textDesktop.isEnabled = $enabled
            $syncHash.textStorefrontURL.isEnabled = $enabled
            $syncHash.textDelay.isEnabled = $enabled
            $syncHash.textDomain.isEnabled = $enabled
            $syncHash.textFileShare.isEnabled = $enabled
            $syncHash.checkPerfmon.isEnabled = $enabled
            $syncHash.textWorkload.isEnabled = $enabled
            $syncHash.textWorkload.isEnabled = $enabled
            $syncHash.textVDAs.Opacity = $opacity
            $syncHash.textLaunchers.Opacity = $opacity
            $syncHash.textUsers.Opacity = $opacity
            $syncHash.textDesktop.Opacity = $opacity
            $syncHash.textStorefrontURL.Opacity = $opacity
            $syncHash.textDelay.Opacity = $opacity
            $syncHash.textDomain.Opacity = $opacity
            $syncHash.textFileShare.Opacity = $opacity
            $syncHash.checkPerfmon.Opacity = $opacity
            $syncHash.textWorkload.Opacity = $opacity
            $syncHash.textWorkload.Opacity = $opacity
                            },
        "Normal")




}