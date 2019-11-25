[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
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

Function trace-colour
{param([string]$x,[int]$y,[int]$time)

Do{
    $result = Get-ScreenColor -x $x -y $y
    $red = $result.Red
    $green = $result.Green
    $blue = $result.Blue
    write-host "-x $x -y $y -red $Red -green $Green -blue $Blue"
    start-sleep 1   
    $a++
   }
Until($a -eq $time)

}

#just an example
trace-colour -x 20 -y 20 -time 10