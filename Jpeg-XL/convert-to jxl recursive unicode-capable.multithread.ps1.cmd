<# :
@echo off
Set "ScriptName=%~n0"
Set "ScriptLocation=%~f0"
:start
Set "input=%~1"
title %ScriptName% %input%
powershell.exe  -Command "Invoke-Expression ([String]::Join([char]10,(Get-Content \"%ScriptLocation%\")))"
shift
if not "%~1" == "" goto start
title DONE! %ScriptName% %input%
pause
goto :eof

Converts LOSSLESS with Effort 8, unless the source filesize is greater than 50 Megabyte - some astronomy pictures are really large.
If you want non lossless: Go ahead and adjust this script.

This is a hybrid .ps1 / .cmd.
Rename it to .cmd and you can drag and drop directorie(s) on the .cmd and it will execute the .jxl conversion recursively.
Drawback: Cannot handle "&" it path, specifically .cmd cannot handle it.
Rename it to .ps1 and it can handle "&" directories, not files, and convert recursivly. But you lose drag and drop.

Versionlog:
  2021-11-?? 0.0 Wrote first version.
  2023-04-05 0.1 first version to be published, request from https://github.com/libjxl/libjxl/issues/683#issuecomment-1492947842
  2023-04-06 0.2 first multithread version (Powershell 5.1 compatible).
                 Good part: Faster. Bad part: You are blind.
  2023-04-19 0.3 Workaround for that weird random Windows 11 Get-Volume bug.
  2024-02-04 0.4 Added "set my priority to low"
  2026-03-25 0.5 Removes unicode workaround for libjxl tools 0.11.2

by Joachim Otahal, Germany, jou@gmx.net, https://joumxyzptlk.de, https://github.com/Joachim-Otahal?tab=repositories

#>

param (
    [string]$Path
)

# Where is cjxl.exe ?
$cjxl="C:\prog\jpeg-xl\cjxl.exe"

# Selective WhatIf, set to $false if you trust my code, else set to $true and it won't delete the original.
$WhatIf=$false

# How many thread in parallel? Five is a reasonable default, recommended maximum is you SMT-Core count - 20%.
# For a ryzen 9 5950x $MaxThreads=25 is reasonable. Be aware this script ignores if you do not have enough RAM, though your original file will not be replaced if a conversion fails.
$MaxThreads=7

# Check Powershell verison: 5.1 is standard since Server 2016 and Windows 10 1607.
if ([float]([string]$PSVersionTable.PSVersion.Major+"."+[string]$PSVersionTable.PSVersion.Minor) -lt [float]"5.1") {
    Write-Host -BackgroundColor DarkRed -ForegroundColor Yellow  " Powershell less than 5.1. Is included in Windows Management Framework 5.1 `n see https://www.microsoft.com/en-us/download/details.aspx?id=54616 " -Verbose
    $null = Read-Host "Press ENTER to exit"
    break
}

# Handle whether we were called as .cmd
if ($Path.Length -lt 1) {
    $dlist = @(Get-Item -LiteralPath "$env:input")
    $dlist += Get-ChildItem -Recurse -Directory -LiteralPath "$env:input" | Sort-Object FullName
} else {
    $dlist = @(Get-Item -LiteralPath $Path)
    $dlist += Get-ChildItem -Recurse -Directory -LiteralPath $Path | Sort-Object FullName
}

# Set priority of this powershell process to low including IO priority, so all spawned threads will be the same
$CurrentPID = [System.Diagnostics.Process]::GetCurrentProcess().Id
$null = Invoke-CimMethod -Name "SetPriority" -InputObject $(Get-CimInstance Win32_Process).Where({ $_.ProcessId -eq $CurrentPID})[0] -Arguments @{Priority=64} -ErrorAction Ignore

########## Helper to set io priority to low
# https://stackoverflow.com/questions/21700738/how-to-set-low-i-o-background-priority-in-powershell
# https://stackoverflow.com/a/61570473/11454100
Add-Type @"
using System;
using System.Runtime.InteropServices;

namespace SysWin32
{
    public enum PROCESS_INFORMATION_CLASS
    {
        ProcessMemoryPriority,
        ProcessInformationClassMax,
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(System.Runtime.InteropServices.LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION
    {
        public uint Information;
    }

    public partial class NativeMethods {
        [System.Runtime.InteropServices.DllImportAttribute("kernel32.dll", EntryPoint="GetCurrentProcess", SetLastError=true)]
        public static extern System.IntPtr GetCurrentProcess();

        [System.Runtime.InteropServices.DllImportAttribute("kernel32.dll", EntryPoint="OpenProcess", SetLastError=true)]
        public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, uint dwProcessId);

        [System.Runtime.InteropServices.DllImportAttribute("kernel32.dll", EntryPoint="SetProcessInformation", SetLastError=true)]
        public static extern bool SetProcessInformation(System.IntPtr hProcess, PROCESS_INFORMATION_CLASS ProcessInformationClass, System.IntPtr ProcessInformation, uint ProcessInformationSize) ;
    }
}

namespace SysWinNT
{
    public enum PROCESS_INFORMATION_CLASS
    {
        ProcessBasicInformation,
        ProcessQuotaLimits,
        ProcessIoCounters,
        ProcessVmCounters,
        ProcessTimes,
        ProcessBasePriority,
        ProcessRaisePriority,
        ProcessDebugPort,
        ProcessExceptionPort,
        ProcessAccessToken,
        ProcessLdtInformation,
        ProcessLdtSize,
        ProcessDefaultHardErrorMode,
        ProcessIoPortHandlers,          // Note: this is kernel mode only
        ProcessPooledUsageAndLimits,
        ProcessWorkingSetWatch,
        ProcessUserModeIOPL,
        ProcessEnableAlignmentFaultFixup,
        ProcessPriorityClass,
        ProcessWx86Information,
        ProcessHandleCount,
        ProcessAffinityMask,
        ProcessPriorityBoost,
        ProcessDeviceMap,
        ProcessSessionInformation,
        ProcessForegroundInformation,
        ProcessWow64Information,
        ProcessImageFileName,
        ProcessLUIDDeviceMapsEnabled,
        ProcessBreakOnTermination,
        ProcessDebugObjectHandle,
        ProcessDebugFlags,
        ProcessHandleTracing,
        ProcessIoPriority,
        ProcessExecuteFlags,
        ProcessTlsInformation,
        ProcessCookie,
        ProcessImageInformation,
        ProcessCycleTime,
        ProcessPagePriority,
        ProcessInstrumentationCallback,
        ProcessThreadStackAllocation,
        ProcessWorkingSetWatchEx,
        ProcessImageFileNameWin32,
        ProcessImageFileMapping,
        ProcessAffinityUpdateMode,
        ProcessMemoryAllocationMode,
        ProcessGroupInformation,
        ProcessTokenVirtualizationEnabled,
        ProcessConsoleHostProcess,
        ProcessWindowInformation,
        MaxProcessInfoClass             // MaxProcessInfoClass should always be the last enum
    }

    public partial class NativeMethods {
        [System.Runtime.InteropServices.DllImportAttribute("ntdll.dll", EntryPoint="NtSetInformationProcess")]
        public static extern int NtSetInformationProcess(System.IntPtr hProcess, PROCESS_INFORMATION_CLASS processInformationClass, System.IntPtr ProcessInformation, uint ProcessInformationSize);
    }
}
"@
# Same for IO priority
# https://stackoverflow.com/questions/21700738/how-to-set-low-i-o-background-priority-in-powershell
# https://stackoverflow.com/a/61570473/11454100
#    4096 or     0x1000 = PROCESS_QUERY_LIMITED_INFORMATION
# 1056763 or 0x00101ffb = PROCESS_ALL_ACCESS
$DesiredAccess = 0x00101ffb
$InheritHandle = $false
$hProcess = [SysWin32.NativeMethods]::OpenProcess($DesiredAccess, $InheritHandle, $CurrentPID);
$LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
if ($hProcess -ne 0) {
    # If we have a handle set IO Priority to "lowest"
    $ioInfo = New-Object SysWin32.PROCESS_INFORMATION
    $ioInfo.Information = 0
    $ioInfoSize = [System.Runtime.Interopservices.Marshal]::SizeOf($ioInfo)
    $ioInfoPtr = [System.Runtime.Interopservices.Marshal]::AllocHGlobal($ioInfoSize)
    [System.Runtime.Interopservices.Marshal]::StructureToPtr($ioInfo, $ioInfoPtr, $false)
    $result = [SysWinNT.NativeMethods]::NtSetInformationProcess($hProcess, [SysWinNT.PROCESS_INFORMATION_CLASS]::ProcessIoPriority, $ioInfoPtr, $ioInfoSize)
    $LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
}


if ($dlist[0].FullName.StartsWith("\") -or $dlist[0].PSIsContainer -ne $true) {
    Write-Host -BackgroundColor DarkRed -ForegroundColor Yellow " Expecting a directory, not a file. And I cannot work with an UNC path. "
    $null = Read-Host "Press ENTER to exit"
    break
} else {
    for ($j = 0 ; $j -lt $dlist.Count ; $j++) {
        # Yes, excluding GIF for now, fails too often to compess better especially with Dilbert comics. (cjxl version 0.7)
        $list = (Get-ChildItem -Recurse -File -LiteralPath $dlist[$j].FullName ).Where({$_.Extension -match "png" -or $_.Extension -match "jpg" -or $_.Extension -match "jpeg" -or $_.Extension -match "jfif"})
        # We have to enter the directory to avoid problems with a directory that contains unicode characters.
        if ($list.count -eq 0) {
            Write-Host "No supported files found in $($dlist[$j].FullName)"
        }
        for ($i = 0 ; $i -lt $list.Count ; $i++) {
            Set-Location -LiteralPath $list[0].DirectoryName
            if (Test-Path -LiteralPath $($list[$i].FullName) ) {
                Write-Output -InputObject "Directory $($j+1) of $($dlist.Count), file $($i+1) of $($list.Count), $($list[$i].FullName)"

                $JobCount = (Get-Job -State Running).count
                while ($JobCount -ge $MaxThreads) {
                    Start-Sleep 2 ; $JobCount = (Get-Job -State Running).count
                }

                # Start conversion as job... But we cannot use $array[$i] in a job this way...
                #$JobItem = $list[$i]
                $null = Start-Job -ScriptBlock {
                    $SourceFile = Get-Item -LiteralPath $args[0]
                    Set-Location -LiteralPath $SourceFile.DirectoryName
                    $output = $($SourceFile.FullName).replace($($SourceFile.Extension),".jxl")
                    $outputname = $SourceFile.BaseName+".jxl"
                    $effort="7"
                    # If the file is below 50 MBytes use effort 8
                    if ($SourceFile.Length -lt 50000000) { $effort="8" }
                    # not unicode
                    &$using:cjxl "$($SourceFile.Name)" "$outputname" -d 0 -e $effort 2>&1 | %{ "$_" }
                    (Get-Item -LiteralPath $output -ErrorAction Ignore).CreationTime  = $SourceFile.CreationTime
                    (Get-Item -LiteralPath $output -ErrorAction Ignore).LastWriteTime = $SourceFile.LastWriteTime
                    $outputresult = Get-Item -LiteralPath $output -ErrorAction Ignore
                    # we kill the original only if the .jxl result is smaller and no errors occured.
                    if ($outputresult.Length -lt $SourceFile.Length -and $outputresult.Length -gt "0") {
                        # Worked, kill original.
                        Remove-Item -LiteralPath $SourceFile.FullName -Confirm:$false -WhatIf:$using:WhatIf
                    } else {
                        # Failed, kill the .jxl if available.
                        # Write-Host -BackgroundColor DarkRed -ForegroundColor Yellow " compression fail, source size $($SourceFile.Length), result $($outputresult.Length) -> remove .jxl file. "
                        if ($outputresult.FullName) {
                            Remove-Item -LiteralPath $outputresult.FullName -Confirm:$false -WhatIf:$using:WhatIf
                        }
                    }
                } -ArgumentList $list[$i].FullName # Start-Job -ScriptBlock
                Get-Job -State Completed | Remove-Job
            }
        } # for ($i = 0 ; $i -lt $list.Count ; $i++)
    } # for ($j = 0 ; $j -lt $dlist.Count ; $j++)
    Write-Host -NoNewline "`nWaiting for these many job(s) to finish: "
    $JobCount = (Get-Job -State Running).count
    while ($JobCount -gt 0 ) {
        Get-Job -State Completed | Remove-Job
        if ($JobCount -ne $JobCountPrevious) {
            Write-Host -NoNewline "$JobCount "
        }
        Start-Sleep 5
        $JobCountPrevious = $JobCount
        $JobCount = (Get-Job -State Running).count
    }
    Get-Job -State Completed | Remove-Job
} # if ($dlist[0].FullName.StartsWith("\"))
