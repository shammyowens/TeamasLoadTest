#File is partly based on https://github.com/1RedOne/BlogPosts/blob/master/GUI%20Part%20V/PowerShell_GUI_Template.ps1

#region Add Types
Add-Type -AssemblyName PresentationCore, PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
#endregion

#region Environment Tests
if((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -eq $false){
    [System.Windows.Forms.MessageBox]::Show("This machine is not joined to a domain")
exit
}
#endregion

$Global:syncHash = [hashtable]::Synchronized(@{})
$newRunspace =[runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"
$newRunspace.Name = "GUI"
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
    $global:jobs = [system.collections.arraylist]::Synchronized((New-Object System.Collections.ArrayList))

    #region Background runspace to clean up jobs
    $jobCleanup.Flag = $True
    $newRunspace =[runspacefactory]::CreateRunspace()
    $newRunspace.ApartmentState = "STA"
    $newRunspace.ThreadOptions = "ReuseThread"          
    $newRunspace.Name = "CleanUp"
    $newRunspace.Open()        
    $newRunspace.SessionStateProxy.SetVariable("jobCleanup",$jobCleanup)     
    $newRunspace.SessionStateProxy.SetVariable("jobs",$global:jobs) 
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
    $global:hidecontrols=("textVDAs","textLaunchers","textUsers","textDomain","textDesktop","textStorefrontURL","textDelay","textWorkload","textFileshare")
    
    #region Workload Button
    
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

    #endregion

    #region Start Button
    $syncHash.buttonStart.Add_Click({
            $x+= "."
        $newRunspace =[runspacefactory]::CreateRunspace()
        $newRunspace.ApartmentState = "STA"
        $newRunspace.ThreadOptions = "ReuseThread"  
        $newRunspace.Name = "StartTest"        
        $newRunspace.Open()
        $newRunspace.SessionStateProxy.SetVariable("SyncHash",$SyncHash) 
        $newRunspace.SessionStateProxy.SetVariable("jobs",$global:jobs)
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
            $global:date = (Get-Date -format filedatetime)
    import-module $script:filestore\scripts\ControlFunctions.psm1       
    $filestore = $script:FileStore
    set-location $filestore   
                                          
    If((get-location | ForEach-Object{$_.ProviderPath}) -match ":")
    {
    update-window -Control labelTestRunning -Property Content -Value "Please run from a FileShare!"
    Get-Runspace -name "StartTest" | ForEach-Object {$_.dispose()}
    Exit
    }
    Inspect-Inputs
   
    #Wait-Debugger

    Watch-LauncherStatus -filestore $script:filestore -launchers $script:Launchers -launcherscount $script:Launchers.count

    If($script:perfmon -eq $true){Start-Perfmon -date $global:date -VDAs $Script:VDAs -filestore $script:filestore}
                                  
    Start-ProgressBar -intDelay $intDelay -UserCount $Script:Users.count -filestore $script:filestore

    publish-test -date $global:date -filestore $script:FileStore -launchers $script:Launchers -VDAs $script:VDAs -workload $script:Workload -desktop $script:Desktop -delay $script:Delay -storefrontURL $script:StorefrontURL -users $Script:Users

    Start-SessionInfo -VDAs $Script:VDAs -filestore $script:filestore

    Watch-TestStatus -filestore $script:filestore -launchers $script:Launchers -delay $script:delay
    
    Unpublish-test -date $global:date -filestore $script:FileStore -launchers $script:Launchers -VDAs $script:VDAs -workload $script:Workload               

            })
        $PowerShell.Runspace = $newRunspace
        [void]$global:jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Runspace = $PowerShell.BeginInvoke()
            }
        ))
    })

    #endregion


    #region Stop Button
    $syncHash.buttonStop.Add_Click({
            $x+= "."
        $newRunspace =[runspacefactory]::CreateRunspace()
        $newRunspace.ApartmentState = "STA"
        $newRunspace.ThreadOptions = "ReuseThread"          
        $newRunspace.Open()
        $newRunSpace.name = "StopTest"
        $newRunspace.SessionStateProxy.SetVariable("SyncHash",$SyncHash) 
        $newRunspace.SessionStateProxy.SetVariable("Date",$global:date) 
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
        import-module $script:filestore\scripts\ControlFunctions.psm1       
        Get-Runspace -name "StartTest" | ForEach-Object {$_.dispose()} 
        unpublish-test -date $global:date -filestore $script:FileStore -launchers $script:Launchers -VDAs $script:VDAs -workload $script:Workload
        

        })
        $PowerShell.Runspace = $newRunspace
        [void]$global:jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Runspace = $PowerShell.BeginInvoke()
            }
        ))
    })

    #endregion

    #region Window Close 
    $syncHash.Window.Add_Closed({
        Write-Verbose 'Halt runspace cleanup job processing'
        $jobCleanup.Flag = $False

        #Stop all runspaces
        $jobCleanup.PowerShell.Dispose()  
        Get-Runspace | Where-Object {$_.id -ne 1} | ForEach-Object {$_.dispose()}    
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
