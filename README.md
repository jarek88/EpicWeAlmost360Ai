# EpicWeAlmost360Ai

**Because every stupid solution deserves a stupid answer**


EpicWeAlmost360Ai is a small PowerShell automation script that periodically moves the mouse and can send random arrow-key input to a selected application during configured working hours. It also uses the Windows API to prevent the system and display from entering idle sleep states.

## Configuration

All main settings are located at the top of the script:

```powershell
$StartTime = "08:00"
$EndTime   = "18:00"

$IdleActivationSeconds = 5
$IdleTypingSeconds = 30

$MinDelaySeconds = 5
$MaxDelaySeconds = 12

$MinMovePixels = 5
$MaxMovePixels = 20
```

For example, to run it between **07:30 and 17:00**:

```powershell
$StartTime = "07:30"
$EndTime   = "17:00"
```

You can also adjust how often the cursor moves, how far it moves, and after how much inactivity keyboard input is generated.

## Default application

The script currently targets **Visual Studio Code**. The relevant function is:

```powershell
function Get-OrStartVSCode
```

and the keyboard input is sent by:

```powershell
function Send-RandomVSCodeArrowKey
```

To use another application, the application lookup and startup command need to be changed. For example, for Microsoft Word you would replace the VS Code process lookup:

```powershell
Get-Process -Name Code
```

with the appropriate process name:

```powershell
Get-Process -Name WINWORD
```

and replace:

```powershell
Start-Process code
```

with:

```powershell
Start-Process winword
```

The rest of the window activation logic can remain unchanged.

## How it works

During the configured time window, the script:

* checks the current user idle time;
* periodically moves the mouse by a small random distance;
* after the configured idle period, sends a random arrow key to the configured application;
* supports multiple monitors by using the complete virtual desktop area;
* keeps the Windows system/display awake while running.

Outside the configured working hours, no mouse or keyboard automation is performed.
