#region Add Types
Add-Type -AssemblyName PresentationCore, PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
import-module $script:filestore\scripts\ControlFunctions.psm1
#endregion

#region Environment Tests
if((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -eq $false){
    [System.Windows.Forms.MessageBox]::Show("This machine is not joined to a domain")
    set-location logs
    Write-Log -Message "This machine is not joined to a domain" -Level Error -Path "event.log"
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
    #region Workload Button
    
    $syncHash.buttonWorkload.Add_Click({
                                            $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
                                            InitialDirectory = (Get-Location) | ForEach-Object{$_.ProviderPath}
                                            Multiselect = $false
                                            Filter = 'Powershell (*.PS1)|*.PS1'
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
        $global:testDate = (Get-Date -format filedatetime)    
        $x+= "."
        $newRunspace =[runspacefactory]::CreateRunspace()
        $newRunspace.ApartmentState = "STA"
        $newRunspace.ThreadOptions = "ReuseThread"  
        $newRunspace.Name = "StartTest"        
        $newRunspace.Open()
        $newRunspace.SessionStateProxy.SetVariable("testDate",$global:testDate) 
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
            
    import-module $script:filestore\scripts\ControlFunctions.psm1
    #Write-Log -StartNew -Path $script:filestore\logs\event.log
    Write-Log -Message "Start Button Clicked" -Level Info -Path $script:filestore\logs\event.log
    $filestore = $script:FileStore
    set-location $filestore   

    Test-Inputs -delay $script:Delay -filestore $script:filestore -storefrontURL $script:StorefrontURL -VDAs $script:VDAs -users $script:Users -launchers $script:launchers -date $testDate -workload $script:Workload -desktop $script:Desktop
    
    $script:intDelay = [int]$script:Delay
   
    Watch-LauncherStatus -filestore $script:filestore -launchers $script:Launchers -launcherscount $script:Launchers.count

    If($script:perfmon -eq $true){Start-Perfmon -date $testDate -VDAs $Script:VDAs -filestore $script:filestore}
                                  
    Start-ProgressBar -intDelay $script:intDelay -UserCount $Script:Users.count -filestore $script:filestore

    publish-test -date $testDate -filestore $script:FileStore -launchers $script:Launchers -VDAs $script:VDAs -workload $script:Workload -desktop $script:Desktop -intdelay $script:intDelay -storefrontURL $script:StorefrontURL -users $Script:Users

    Start-SessionInfo -VDAs $Script:VDAs -filestore $script:filestore

    Watch-TestStatus -filestore $script:filestore -launchers $script:Launchers -delay $script:intDelay
    
    Unpublish-test -date $testDate -filestore $script:FileStore -launchers $script:Launchers -VDAs $script:VDAs -workload $script:Workload               

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
        $newRunspace.SessionStateProxy.SetVariable("testDate",$global:testDate) 
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
        Write-Log -Message "Stop Button Clicked" -Level Info -Path $script:filestore\logs\event.log
        Get-Runspace -name "StartTest" | ForEach-Object {$_.dispose()} 
        unpublish-test -date $testDate -filestore $script:FileStore -launchers $script:Launchers -VDAs $script:VDAs -workload $script:Workload
        

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
        Write-Log -Message "Program Close" -Level Info -Path $script:filestore\logs\event.log
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

#Get-Runspace | Where-Object {$_.id -ne 1} | ForEach-Object {$_.dispose()}