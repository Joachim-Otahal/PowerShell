# Joachim Otahal, 2026-05-16
# Issue since Server 2022, but Windows 11 21h2 up the current Server 2025 and Windows 11 25h2:
# If you try Get-ChildItem -LiteralPath "\\?\C:\" you get an "Get-ChildItem : Illegal characters in path." error.
# See (example): https://learn.microsoft.com/en-us/answers/questions/1688032/powershell-ise-illegal-characters-in-path-with-lit
#
# Then, when incorporation "Powershell 7 in Powershell ISE" I had the idea that this might be a workaround for this issue as well.
# And it is: We abuse RunSapce.
# Include the below stuff in your script, and it will activate the workaround.

# Version 0 : 2026-05-16 First "It works! Ship it!" version
# Version 1 : 2026-05-18 Do NOT leave the started powershell(s) behind if you exit powershell-ISE.

# Pre-Check whether -LiteralPath would work in first place.
$longpathsupported = $true
if ((Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -lt 394802) {
    Write-Verbose "Long Path support: Missing DotNet at least 4.6.2" -Verbose
    Write-Verbose "Check https://support.microsoft.com/en-us/topic/microsoft-net-framework-4-8-offline-installer-for-windows-9d23f658-3b97-68ab-d013-aa3c3e7495e0" -Verbose
    $null = Read-Host "Do you really want to continue? Then press enter, else CTRL+C to stop, or close this window."
    $longpathsupported = $false
}
if ([float]([string]$PSVersionTable.PSVersion.Major+"."+[string]$PSVersionTable.PSVersion.Minor) -lt [float]"5.1") {
    Write-Verbose "Long Path support: Powershell less than 5.1. Is included in Windows Management Framework 5.1`nsee https://www.microsoft.com/en-us/download/details.aspx?id=54616" -Verbose
    $null = Read-Host "Do you really want to continue? Then press enter, else CTRL+C to stop, or close this window."
    $longpathsupported = $false
}
if ($longpathsupported) {
    Write-Verbose "Powershell is at least 5.1 and DOTNET recent enough for long path support. Testing..." -Verbose
}

try {
    $null = Get-ChildItem -LiteralPath "\\?\C:\" -ErrorAction Stop
    Write-Verbose "-LiteralPath works." -Verbose
    $PSISELiteralPathBug = $false
} catch {
    $Error.RemoveAt(0) # Clean up the provoked error.
    $PSISELiteralPathBug = $true
}

if ($PSISELiteralPathBug -and $longpathsupported) {
    Write-Verbose "Powershell -LiteralPath bug active, known for Windows 11 21h2 and Server 2022 and later.`nActivating workaround abusing RunSpace" -Verbose
    function New-OutOfProcRunspace {
        param($ProcessId)
        $connectionInfo = New-Object -TypeName System.Management.Automation.Runspaces.NamedPipeConnectionInfo -ArgumentList @($ProcessId)
        $TypeTable = [System.Management.Automation.Runspaces.TypeTable]::LoadDefaultTypeFiles()
        $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($connectionInfo,$Host,$TypeTable)
        $RunSpace.Name = "PowerShell5.1_ISE"
        $Runspace.Open()
        $Runspace
    }
    # Check for broken Runspaces
    foreach ($RunSpace in @(Get-Runspace).Where({$_.Name -like "PowerShell*_ISE" -and $_.RunspaceStateInfo.State -eq "Broken"})) {
        $RunSpace.Dispose()
    }
    # Check if already running runspaces...
    $RunSpaces = @(Get-Runspace).Where({$_.Id -gt 1}) # Runspace1 is normally PS ISE first self.
    if ($RunSpaces.count -gt 0) {
        Write-Verbose "Already running following runspaces:`n $(($RunSpaces | Out-String).Trim())" -Verbose
    } else {
        $PowerShellExecutable = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
        if (Test-Path -Path $PowerShellExecutable) {
            $ArgumentList = @("-NoExit","-Command",
                "Start-Job -ScriptBlock {while ((Get-Process -id $PID -ErrorAction Ignore).Responding) {Start-Sleep 30};"+'Stop-Process -Force -Id $using:PID}'
            )
            $PowerShellProcess = Start-Process $PowerShellExecutable -ArgumentList $ArgumentList -PassThru -WindowStyle Hidden
            $RunspacePowerShell = New-OutOfProcRunspace -ProcessId $PowerShellProcess.Id
            $Host.PushRunspace($RunspacePowerShell)
            Write-Verbose "Workaround activated. You can rund this script again and -LiteralPath will work." -Verbose
            Write-Verbose "PID is $($PowerShellProcess.Id), it won't exit when you close PS_ISE." -Verbose
            break
        } else {
            Write-Verbose "Missing: $PowerShellExecutable" -Verbose
        }
    }
}

