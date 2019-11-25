#region scriptSetup

Add-Type -AssemblyName System.Windows.Forms
$wshell = New-Object -ComObject wscript.shell;
$bounds = [Drawing.Rectangle]::FromLTRB(0, 0, 1900, 800)
$filestore = "FILESERVER"
$retryTime = 30
$failTime = 60

#endregion scriptSetup

#region basicFunctions

#https://gallery.technet.microsoft.com/scriptcenter/Get-the-position-of-a-c91a5f1f
Function Get-Window 
{
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach-Object {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

#https://stackoverflow.com/questions/2969321/how-can-i-do-a-screen-capture-in-windows-powershell
Function Get-Screenie([Drawing.Rectangle]$bounds, $path) 
{

   $bmp = New-Object Drawing.Bitmap $bounds.width, $bounds.height
   $graphics = [Drawing.Graphics]::FromImage($bmp)

   $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)

   $bmp.Save($path)

   $graphics.Dispose()
   $bmp.Dispose()
}

#https://community.spiceworks.com/scripts/show/4263-get-screencolor
Function Get-ScreenColor 
{

    [CmdletBinding(DefaultParameterSetName='None')]

    param(
        [Parameter(
            Mandatory=$true,
            ParameterSetName="Pos"
        )]
        [Int]
        $X,
        [Parameter(
            Mandatory=$true,
            ParameterSetName="Pos"
        )]
        [Int]
        $Y
    )
    
    if ($PSCmdlet.ParameterSetName -eq 'None') {
        $pos = [System.Windows.Forms.Cursor]::Position
    } else {
        $pos = New-Object psobject
        $pos | Add-Member -MemberType NoteProperty -Name "X" -Value $X
        $pos | Add-Member -MemberType NoteProperty -Name "Y" -Value $Y
    }
    $map = [System.Drawing.Rectangle]::FromLTRB($pos.X, $pos.Y, $pos.X + 1, $pos.Y + 1)
    $bmp = New-Object System.Drawing.Bitmap(1,1)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.CopyFromScreen($map.Location, [System.Drawing.Point]::Empty, $map.Size)
    $pixel = $bmp.GetPixel(0,0)
    $red = $pixel.R
    $green = $pixel.G
    $blue = $pixel.B
    $result = New-Object psobject
    if ($PSCmdlet.ParameterSetName -eq 'None') {
        $result | Add-Member -MemberType NoteProperty -Name "X" -Value $([System.Windows.Forms.Cursor]::Position).X
        $result | Add-Member -MemberType NoteProperty -Name "Y" -Value $([System.Windows.Forms.Cursor]::Position).Y
    }
    $result | Add-Member -MemberType NoteProperty -Name "Red" -Value $red
    $result | Add-Member -MemberType NoteProperty -Name "Green" -Value $green
    $result | Add-Member -MemberType NoteProperty -Name "Blue" -Value $blue
    return $result
}

Function Trace-Colour
{param([string]$x,[int]$y,[int]$red,[int]$green,[int]$blue,[string]$inputtype)
$checker = 0

Do{
    $result = Get-ScreenColor -x $x -y $y
    Start-Sleep -milliseconds 500
    $checker = $checker + 0.5
    $labelTime.text =  "$checker seconds" 
    $form.Refresh()
    if ($checker -eq $retryTime -and $inputtype -eq "click"){pop-mousebutton}
    if ($checker -eq $retryTime -and $inputtype -eq "enter"){$wshell.SendKeys('~')}
    if ($checker -gt $failTime){$global:errorcount ++
                          debug-error
                          }
   }
Until($result.red -eq $red -and $result.green -eq $green -and $result.blue -eq $blue)

}

Function Initialize-Sleep
{param([int]$seconds,[string]$texttodisplay)

$labelTask.text = "$texttodisplay for"
$labelTime.text = "$seconds seconds"
$form.Refresh()
Start-Sleep $seconds
}

Function Write-Logtime
{param([TimeSpan]$time,[string]$taskname)
    $users = query user
    $userscount = ($users.count - 1)
    $timeinsecs=[math]::Round($time.totalseconds / 1.00,2)
    $TimeAdd = New-Object PSObject -property @{action=$taskname;Duration=$timeinsecs;username=$env:username;Time=Get-Date;Users=$userscount}
    $TimeAdd | export-csv c:\temp\timing.csv -Append -NoTypeInformation
}

Function Start-Task
{param([string]$labeltext,[string]$taskname,[int]$x,[int]$y,[int]$red,
       [int]$green,[int]$blue,[string]$inputtype,[string]$cursorpos,
       [int]$sleep,[string]$collecttime,[string]$checkcolour)

                            $labelTask.text =  $labeltext
                            $form.Refresh()
                            
                            $time = Measure-Command{
                                                            if($inputtype -eq "click"){ 
                                                                                        [Windows.Forms.Cursor]::position = $cursorpos
                                                                                        pop-mousebutton
                                                                                        }
                                                            if($inputtype -eq "enter"){$wshell.SendKeys('~')}
                                                            Start-Sleep 1
                                                            if($checkcolour -ne "No")
                                                            {
                                                            trace-colour -x $x -y $y -red $red -green $green -blue $blue -inputtype $inputtype}
                                                            }
                            if ($Collecttime -eq "yes"){
                                                        write-logtime -time $time -taskname $taskname
                                                        }
                            initialize-sleep -seconds $sleep -texttodisplay "Thinking" 
                            exit-session
}

#https://stackoverflow.com/questions/42566799/how-to-bring-focus-to-window-by-process-name/42567337#42567337
Function Set-WindowFocus 
{param([string] $proc="chrome", [string]$adm)
Clear-Host

Add-Type @"
  using System;
  using System.Runtime.InteropServices;
  public class WinAp {
     [DllImport("user32.dll")]
     [return: MarshalAs(UnmanagedType.Bool)]
     public static extern bool SetForegroundWindow(IntPtr hWnd);

     [DllImport("user32.dll")]
     [return: MarshalAs(UnmanagedType.Bool)]
     public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  }

"@
$p = Get-Process -name $proc | Where-Object {$_.mainWindowTItle }

if (($null -eq $p) -and ($adm -ne ""))
{
    write-host "Process not running"
}

else
{
    $h = $p.MainWindowHandle

    [void] [WinAp]::SetForegroundWindow($h)
}}

#https://social.technet.microsoft.com/Forums/en-US/48f12259-213c-43a5-99fa-5814928b0145/mouse-click?forum=winserverpowershell
Function Pop-MouseButton
{
exit-session
    $signature=@' 
      [DllImport("user32.dll",CharSet=CharSet.Auto, CallingConvention=CallingConvention.StdCall)]
      public static extern void mouse_event(long dwFlags, long dx, long dy, long cButtons, long dwExtraInfo);
'@ 

    $SendMouseClick = Add-Type -memberDefinition $signature -name "Win32MouseEventNew" -namespace Win32Functions -passThru 

        $SendMouseClick::mouse_event(0x00000002, 0, 0, 0, 0);
        $SendMouseClick::mouse_event(0x00000004, 0, 0, 0, 0);
}

Function exit-session
{

$global:TestEnd = Test-Path -Path $filestore\status\endtest.txt
If ($global:testend -eq "$True"){

initialize-sleep -seconds 15 -texttodisplay "Test Ending"
Logoff}
}

Function debug-error
{

    exit-session
    $date = (Get-Date -format filedatetime)
    #Close Session
    if($errorcount -eq 3){
                            Get-Screenie $bounds "$filestore\errors\$env:username$date.jpg"
                            new-item $filestore\status\endtest.txt
                            exit-session
                            }
    Else{
            
            get-process -name chrome  -ErrorAction SilentlyContinue | Where-Object {$_.CPU} | stop-process
            get-process -name notepad -ErrorAction SilentlyContinue | Where-Object {$_.CPU} | stop-process
            start-test
            }
}

Function Start-Typing
{param([string]$sentence, [int]$delay)
$array = $sentence.toCharArray()

foreach($letter in $array){
                            $wshell.SendKeys($letter)
                            Start-Sleep -Milliseconds $delay
                            }
}
#endregion basicFunctions

#region testFunctions
Function initialize-session
{

start-process chrome -WindowStyle Maximized
trace-colour -x 33 -y 136 -red 255 -green 255 -blue 255
[Windows.Forms.Cursor]::position = "145,51"

pop-mousebutton
$wshell.SendKeys('chrome://extensions')
$wshell.SendKeys('~')
initialize-sleep -seconds 5 -texttodisplay "Checking Extension"
get-process -name chrome | Where-Object {$_.CPU} | stop-process

}

Function Start-Test
{
Do {
        exit-session
        initialize-sleep -seconds 5 -texttodisplay "initialising"

                            #Open Chrome
                            $labelTask.text = "Open Chrome"
                            $form.Refresh()
                            $time = measure-command{
                            start-process https://bbc.com -WindowStyle Maximized
                            trace-colour -x 30 -y 15 -red 0 -green 0 -blue 0
                            }
                            write-logtime -time $time -taskname "0-OpenChrome"
                            initialize-sleep -seconds 5 -texttodisplay "Contemplating"


                            #Open News
                            start-task -labeltext "Open News" -taskname "1-BBCNews" -x 30 -y 15 -red 0 -green 0 -blue 0 -inputtype "click" -cursorpos "720,90" -sleep 5 -collecttime "yes"


                            #Open Sport
                            start-task -labeltext "Open Sport" -taskname "2-BBCSport" -x 30 -y 15 -red 0 -green 0 -blue 0 -inputtype "click" -cursorpos "795,90" -sleep 5 -collecttime "yes"

                            #Open Notepad
                            start-process notepad.exe -WindowStyle maximized

                            #Type some stuff     
                            $labelTask.text =  "Typing"
                            $labelTime.text = ""
                            $form.Refresh()
                            initialize-sleep -seconds 3 -texttodisplay "chilling"
                            Start-Typing "I am typing out some stuff to see how this part of the script works" -delay 50
                            $wshell.SendKeys('~~')
                            initialize-sleep -seconds 3 -texttodisplay "chatting"
                            Start-Typing -sentence "Is the presentation going ok?" -delay 50
                            $wshell.SendKeys('~~')
                            initialize-sleep -seconds 3 -texttodisplay "thinking"
                            Start-Typing -sentence "Hopefully it is not too boring" -delay 50
                            $wshell.SendKeys('~~')
                            initialize-sleep -seconds 3 -texttodisplay "pondering"
                            Start-Typing -sentence "Did they laugh?" -delay 50
                            $wshell.SendKeys('~~')
                            initialize-sleep -seconds 3 -texttodisplay "nattering"
                            Start-Typing -sentence "If not, just show some more memes!" -delay 50
                            $wshell.SendKeys('~~')
                            initialize-sleep -seconds 3 -texttodisplay "plotting"
                         
                            #switch back to Chrome
                            set-windowfocus chrome
                            trace-colour -x 30 -y 15 -red 0 -green 0 -blue 0

                            initialize-sleep -seconds 4 -texttodisplay "pausing before restarting"

                            get-process -name chrome | Where-Object {$_.CPU} | stop-process
                            get-process -name notepad | Where-Object {$_.CPU} | stop-process

    }
Until ($global:testend -eq "$True")
}
#endregion testFunctions

#region feedbackForm
$form = New-Object Windows.Forms.Form
$form.Location = New-Object System.Drawing.Point(10,700);
$Form.Size = New-Object System.Drawing.Size 250,250
$form.text = "Script Feedback"
$form.StartPosition = "manual"
$Form.MinimizeBox = $False
$Form.MaximizeBox = $False
$Form.AutoSize = $True
$Form.AutoSizeMode = "GrowAndShrink"
$Form.FormBorderStyle = "0"
$form.UseWaitCursor = $false
$form.BackColor = "200,200,200"

# LabelTask
$labelTask = New-Object Windows.Forms.Label
$labelTask.Location = New-Object Drawing.Point 5,0
$labelTask.Size = New-Object Drawing.Point 230,25
$labelTask.Font = New-Object System.Drawing.Font("calibri",12,[System.Drawing.FontStyle]::Bold)

# LabelTime
$labelTime = New-Object Windows.Forms.Label
$labelTime.Location = New-Object Drawing.Point 5,50
$labelTime.Size = New-Object Drawing.Point 230,25
$labelTime.Font = New-Object System.Drawing.Font("calibri",12,[System.Drawing.FontStyle]::Bold)

# Add the controls to the Form
$form.controls.add($labelTask)
$form.controls.add($labelTime)
$form.Topmost = $True
#$form.FormBorderStyle = "FixedSingle"

# Display the dialog
$form.Show() | Out-Null
#endregion feedbackForm

Initialize-Session

Start-Test
