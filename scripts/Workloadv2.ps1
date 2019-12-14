#region scriptSetup

Add-Type -AssemblyName System.Windows.Forms
$wshell = New-Object -ComObject wscript.shell;
$global:processes = ("Chrome", "Notepad")
$filestore = "FILESERVER"
Import-Module "$filestore\scripts\WorkloadFunctions.psm1"

#endregion scriptSetup

#region testFunctions
Function global:initialize-session
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

Function global:Start-Test
{
Do {
        exit-session
        initialize-sleep -seconds 5 -texttodisplay "initialising"

                            #Open Chrome
                            $global:labelTask.text = "Open Chrome"
                            $global:form.Refresh()
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
                            $global:labelTask.text =  "Typing"
                            $global:labelTime.text = ""
                            $global:form.Refresh()
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

                            foreach($procs in $global:processes){get-process -name $procs -ErrorAction SilentlyContinue | Where-Object {$_.CPU} | stop-process}

    }
Until ($global:testend -eq "$True")
}

Start-FeedbackForm

Initialize-Session

Start-Test
