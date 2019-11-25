Add-Type -AssemblyName System.Windows.Forms
#General Form option
$form = New-Object Windows.Forms.Form
$form.Location = New-Object System.Drawing.Point(10,800);
$form.Size = New-Object System.Drawing.Size 250,250
$form.text = "Cursor Colour"
$form.StartPosition = "manual"
$form.MinimizeBox = $False
$form.MaximizeBox = $False
$form.AutoSize = $True
$form.AutoSizeMode = "GrowAndShrink"
$form.FormBorderStyle = "5"
$form.Cursor = "hand"
$form.BackColor = "200,200,200"

# LabelX
$labelX = New-Object Windows.Forms.Label
$labelX.Location = New-Object Drawing.Point 0,5
$labelX.Size = New-Object Drawing.Point 50,15
$labelX.Text = "X"
# LabelY
$labelY = New-Object Windows.Forms.Label
$labelY.Location = New-Object Drawing.Point 0,20
$labelY.Size = New-Object Drawing.Point 50,15
$labelY.Text = "Y"
# LabelRed
$labelRed = New-Object Windows.Forms.Label
$labelRed.Location = New-Object Drawing.Point 0,35
$labelRed.Size = New-Object Drawing.Point 50,15
$labelRed.Text = "Red"
# LabelGreen
$labelGreen = New-Object Windows.Forms.Label
$labelGreen.Location = New-Object Drawing.Point 0,50
$labelGreen.Size = New-Object Drawing.Point 50,15
$labelGreen.Text = "Green"
# LabelBlue
$labelBlue = New-Object Windows.Forms.Label
$labelBlue.Location = New-Object Drawing.Point 0,65
$labelBlue.Size = New-Object Drawing.Point 50,15
$labelBlue.Text = "Blue"

# LabelXResult
$labelXResult = New-Object Windows.Forms.Label
$labelXResult.Location = New-Object Drawing.Point 55,5
$labelXResult.Size = New-Object Drawing.Point 50,15
$labelXResult.Text = "X"
# LabelYResult
$labelYResult = New-Object Windows.Forms.Label
$labelYResult.Location = New-Object Drawing.Point 55,20
$labelYResult.Size = New-Object Drawing.Point 50,15
$labelYResult.Text = "Y"
# LabelRedResult
$labelRedResult = New-Object Windows.Forms.Label
$labelRedResult.Location = New-Object Drawing.Point 55,35
$labelRedResult.Size = New-Object Drawing.Point 50,15
$labelRedResult.Text = "Red"
# LabelGreenResult
$labelGreenResult = New-Object Windows.Forms.Label
$labelGreenResult.Location = New-Object Drawing.Point 55,50
$labelGreenResult.Size = New-Object Drawing.Point 50,15
$labelGreenResult.Text = "Green"
# LabelBlueTResult
$labelBlueResult = New-Object Windows.Forms.Label
$labelBlueResult.Location = New-Object Drawing.Point 55,65
$labelBlueResult.Size = New-Object Drawing.Point 50,15
$labelBlueResult.Text = "Blue"

# Add the controls to the Form
$form.controls.add($labelX)
$form.controls.add($labelY)
$form.controls.add($labelRed)
$form.controls.add($labelGreen)
$form.controls.add($labelBlue)
$form.controls.add($labelXResult)
$form.controls.add($labelYResult)
$form.controls.add($labelRedResult)
$form.controls.add($labelGreenResult)
$form.controls.add($labelBlueResult)
$form.Topmost = $True
# Display the dialog
$form.Show()

function Test-KeyPress
{
    <#
        .SYNOPSIS
        Checks to see if a key or keys are currently pressed.

        .DESCRIPTION
        Checks to see if a key or keys are currently pressed. If all specified keys are pressed then will return true, but if 
        any of the specified keys are not pressed, false will be returned.

        .PARAMETER Keys
        Specifies the key(s) to check for. These must be of type "System.Windows.Forms.Keys"

        .EXAMPLE
        Test-KeyPress -Keys ControlKey

        Check to see if the Ctrl key is pressed

        .EXAMPLE
        Test-KeyPress -Keys ControlKey,Shift

        Test if Ctrl and Shift are pressed simultaneously (a chord)

        .LINK
        Uses the Windows API method GetAsyncKeyState to test for keypresses
        http://www.pinvoke.net/default.aspx/user32.GetAsyncKeyState

        The above method accepts values of type "system.windows.forms.keys"
        https://msdn.microsoft.com/en-us/library/system.windows.forms.keys(v=vs.110).aspx

        .LINK
        http://powershell.com/cs/blogs/tips/archive/2015/12/08/detecting-key-presses-across-applications.aspx

        .INPUTS
        System.Windows.Forms.Keys

        .OUTPUTS
        System.Boolean
    #>
    
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Windows.Forms.Keys[]]
        $Keys
    )
    
    # use the User32 API to define a keypress datatype
    $Signature = @'
    [DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
    public static extern short GetAsyncKeyState(int virtualKeyCode); 
'@
    $API = Add-Type -MemberDefinition $Signature -Name 'Keypress' -Namespace Keytest -PassThru
    
    # test if each key in the collection is pressed
    $Result = foreach ($Key in $Keys)
    {
        [bool]($API::GetAsyncKeyState($Key) -eq -32767)
    }
    
    # if all are pressed, return true, if any are not pressed, return false
    $Result -notcontains $false
}

Function Get-ScreenColor 
{
    <#
    .SYNOPSIS
    Gets the color of the pixel under the mouse, or of the specified space.
    .DESCRIPTION
    Returns the pixel color either under the mouse, or of a location onscreen using X/Y locating.  If no parameters are supplied, the mouse cursor position will be retrived and used.

    Current Version - 1.0
    .EXAMPLE
    Mouse-Color
    Returns the color of the pixel directly under the mouse cursor.
    .EXAMPLE
    Mouse-Color -X 300 -Y 300
    Returns the color of the pixel 300 pixels from the top of the screen and 300 pixels from the left.
    .PARAMETER X
    Distance from the top of the screen to retrieve color, in pixels.
    .PARAMETER Y
    Distance from the left of the screen to retrieve color, in pixels.
    .NOTES

    Revision History
    Version 1.0
        - Live release.  Contains two parameter sets - an empty default, and an X/Y set.
    #>

    

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

   Do{$output = Get-ScreenColor
   $x=$output.x
   $y=$output.y
   $red=$output.red
   $green=$output.green
   $blue=$output.blue

   $labelXResult.text = $output.x
   $labelYResult.text = $output.y
   $labelRedResult.text = $output.red
   $labelGreenResult.text = $output.green
   $labelBlueResult.text = $output.blue
   [System.Windows.Forms.Application]::DoEvents()
   if (Test-KeyPress -Keys End){
                                        $copyoutput = "-x $x -y $y -red $red -green $green -blue $blue"
                                        $copyoutput
                                        $copyoutput | clip}
 start-sleep -Milliseconds 100}
 Until($var -eq "1")
 
 Start-Sleep 500