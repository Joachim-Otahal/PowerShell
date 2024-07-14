# Simple script to get all child processes of a given process ID.
# If none is given it gets the current process id as start.
# Is resistand against self referencing PID (i.e. does not loop endless when you use -StartPID 0)
# Joachim Otahal, created 2023, released July 2024.

function Get-ProcessRecursive {
    Param([int]$StartPID=[System.Diagnostics.Process]::GetCurrentProcess().Id)
    $ProcessTree = (Get-CimInstance Win32_Process).Where({ $_.ParentProcessId -eq $StartPID })
    $j=$k=0
    do {
        $j=$k
        for ($k=$j;$k -lt $ProcessTree.Count;$k++) {
            $ProcessTree += (Get-CimInstance Win32_Process).Where({$_.ParentProcessId -eq $ProcessTree[$k].ProcessId -and $ProcessTree.ProcessId -notcontains $_.ProcessId})
        }
    } until ($k -eq $j)
    return $ProcessTree
}
