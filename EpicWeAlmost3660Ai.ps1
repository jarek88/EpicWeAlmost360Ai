# USTAWIENIA

$StartTime = "08:00"
$EndTime   = "18:00"

$IdleActivationSeconds = 5
$IdleTypingSeconds = 30

$MinDelaySeconds = 5
$MaxDelaySeconds = 12

$MinMovePixels = 5
$MaxMovePixels = 20

$MinKeyPressDelaySeconds = 2
$MaxKeyPressDelaySeconds = 6

$CheckIntervalSeconds = 1

# WINDOWS API

# guard against "type already exists" when the script is re-run in the same PowerShell session
if (-not ("EpicMouseControl" -as [type]))
{
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class EpicMouseControl
{
[DllImport("user32.dll")]
public static extern bool SetCursorPos(int X, int Y);


[DllImport("user32.dll")]
public static extern bool GetCursorPos(out POINT point);

[DllImport("user32.dll")]
public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

[DllImport("user32.dll")]
public static extern int GetSystemMetrics(int nIndex);

[DllImport("kernel32.dll", SetLastError = true)]
public static extern uint SetThreadExecutionState(uint esFlags);

[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

[DllImport("user32.dll")]
public static extern bool SetForegroundWindow(IntPtr hWnd);

[DllImport("user32.dll")]
public static extern bool IsIconic(IntPtr hWnd);

public struct POINT
{
    public int X;
    public int Y;
}

public struct LASTINPUTINFO
{
    public uint cbSize;
    public uint dwTime;
}

public const int SM_XVIRTUALSCREEN  = 76;
public const int SM_YVIRTUALSCREEN  = 77;
public const int SM_CXVIRTUALSCREEN = 78;
public const int SM_CYVIRTUALSCREEN = 79;

public const uint ES_CONTINUOUS = 0x80000000;
public const uint ES_SYSTEM_REQUIRED = 0x00000001;
public const uint ES_DISPLAY_REQUIRED = 0x00000002;

public const int SW_RESTORE = 9;

public static uint GetIdleTime()
{
    LASTINPUTINFO info = new LASTINPUTINFO();
    info.cbSize = (uint)Marshal.SizeOf(info);

    if (!GetLastInputInfo(ref info))
        return 0;

    return ((uint)Environment.TickCount - info.dwTime);
}

// Tells Windows the system/display is in use, blocking idle-triggered sleep and screensaver lock
public static void KeepSystemAwake()
{
    SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);
}


}
"@
}

Add-Type -AssemblyName System.Windows.Forms

function Get-IdleSeconds
{
$IdleMilliseconds = [EpicMouseControl]::GetIdleTime()


return [math]::Floor(
    $IdleMilliseconds / 1000
)


}

function Test-WorkingHours
{
$Now = Get-Date


$Start = [datetime]::ParseExact(
    $StartTime,
    "HH:mm",
    $null
)

$End = [datetime]::ParseExact(
    $EndTime,
    "HH:mm",
    $null
)

$Start = $Now.Date.Add($Start.TimeOfDay)
$End   = $Now.Date.Add($End.TimeOfDay)

return ($Now -ge $Start -and $Now -lt $End)


}

function Move-RandomCursor
{
$Position = New-Object EpicMouseControl+POINT


[EpicMouseControl]::GetCursorPos(
    [ref]$Position
)

# bounds of the whole multi-monitor desktop, not just the primary monitor
$VirtualLeft   = [EpicMouseControl]::GetSystemMetrics([EpicMouseControl]::SM_XVIRTUALSCREEN)
$VirtualTop    = [EpicMouseControl]::GetSystemMetrics([EpicMouseControl]::SM_YVIRTUALSCREEN)
$VirtualRight  = $VirtualLeft + [EpicMouseControl]::GetSystemMetrics([EpicMouseControl]::SM_CXVIRTUALSCREEN)
$VirtualBottom = $VirtualTop + [EpicMouseControl]::GetSystemMetrics([EpicMouseControl]::SM_CYVIRTUALSCREEN)

$DirectionX = if ($Random.Next(0, 2) -eq 0) { -1 } else { 1 }
$DirectionY = if ($Random.Next(0, 2) -eq 0) { -1 } else { 1 }

# flip direction near desktop edges so the move is never clamped to a no-op
if ($Position.X -le $VirtualLeft + $MaxMovePixels) { $DirectionX = 1 }
if ($Position.X -ge $VirtualRight - $MaxMovePixels) { $DirectionX = -1 }
if ($Position.Y -le $VirtualTop + $MaxMovePixels) { $DirectionY = 1 }
if ($Position.Y -ge $VirtualBottom - $MaxMovePixels) { $DirectionY = -1 }

$MoveX = $Random.Next(
    $MinMovePixels,
    $MaxMovePixels + 1
) * $DirectionX

$MoveY = $Random.Next(
    $MinMovePixels,
    $MaxMovePixels + 1
) * $DirectionY

$NewX = $Position.X + $MoveX
$NewY = $Position.Y + $MoveY

[EpicMouseControl]::SetCursorPos(
    $NewX,
    $NewY
) | Out-Null


}

function Set-WindowActive
{
param(
    [Parameter(Mandatory = $true)]
    [int]$Handle
)

$WindowHandle = [intptr]$Handle

if ([EpicMouseControl]::IsIconic($WindowHandle))
{
    [EpicMouseControl]::ShowWindowAsync(
        $WindowHandle,
        [EpicMouseControl]::SW_RESTORE
    ) | Out-Null
}

[EpicMouseControl]::SetForegroundWindow($WindowHandle) | Out-Null

}

function Get-OrStartVSCode
{
$VSCode = Get-Process -Name Code -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Select-Object -First 1

if (-not $VSCode)
{
    try
    {
        Start-Process code | Out-Null
    }
    catch
    {
        return $null
    }

    Start-Sleep -Milliseconds 1200

    $VSCode = Get-Process -Name Code -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -First 1
}

return $VSCode

}

function Send-RandomVSCodeArrowKey
{
$VSCode = Get-OrStartVSCode

if (-not $VSCode)
{
    return $false
}

Set-WindowActive -Handle $VSCode.MainWindowHandle

$ArrowKeys = @("{UP}", "{DOWN}", "{LEFT}", "{RIGHT}")
$KeyToSend = $ArrowKeys[$Random.Next(0, $ArrowKeys.Count)]

[System.Windows.Forms.SendKeys]::SendWait($KeyToSend)

return $true

}

$Random = New-Object System.Random
$NextMoveTime = Get-Date
$NextKeyPressTime = Get-Date

while ($true)
{
# keep refreshing so Windows never triggers an idle-based sleep/screensaver lock
[EpicMouseControl]::KeepSystemAwake()

if (Test-WorkingHours)
{
$IdleSeconds = Get-IdleSeconds


    if ($IdleSeconds -lt $IdleActivationSeconds)
    {
        $NextMoveTime = Get-Date
        $NextKeyPressTime = Get-Date

        Start-Sleep -Seconds $CheckIntervalSeconds

        continue
    }

    if ((Get-Date) -ge $NextMoveTime)
    {
        Move-RandomCursor

        $Delay = $Random.Next(
            $MinDelaySeconds,
            $MaxDelaySeconds + 1
        )

        $NextMoveTime = (Get-Date).AddSeconds($Delay)
    }

    if ($IdleSeconds -ge $IdleTypingSeconds -and (Get-Date) -ge $NextKeyPressTime)
    {
        [void](Send-RandomVSCodeArrowKey)

        $KeyDelay = $Random.Next(
            $MinKeyPressDelaySeconds,
            $MaxKeyPressDelaySeconds + 1
        )

        $NextKeyPressTime = (Get-Date).AddSeconds($KeyDelay)
    }
}
else
{
    $NextMoveTime = Get-Date
    $NextKeyPressTime = Get-Date
}

Start-Sleep -Seconds $CheckIntervalSeconds

}
