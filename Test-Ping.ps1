# Why write this thing?
# Powershell 5.1 Test-Connection has no "pure ping" and no "timeout"
# Test-NetConnection is TOO SLOW and needs more than five seconds, unaccaptable.
# Reference: https://learn.microsoft.com/en-us/dotnet/api/system.net.networkinformation.ping
# Joachim Otahal March 2024, little cleanup June 2024

function Test-Ping {
    param (
        [Parameter(ValueFromPipeline)][string]$ComputerName="127.0.0.1",
        [ValidateRange(0,250)][int32]$TTL=29,
        [ValidateRange(0,32000)][int32]$TimeOut=200,
        [ValidateRange(0,250)][int32]$Retry=3,
        [switch]$DontFragment
    )
    $RetryStart = $Retry
    Do {
        try {
            $PingReply = [System.Net.NetworkInformation.Ping]::new().Send(
                $ComputerName,$TimeOut,[byte[]]0*32,[System.Net.NetworkInformation.PingOptions]::new($TTL,$DontFragment)
            )
        } catch {
            $PingReply = [pscustomobject]@{
                Status = [string]"Error"
                RoundtripTime = [int64]-1
            }
        }
        if ($PingReply.Status -eq "Success" -or $Retry -le 0) {
            return $PingReply
        }
        $Retry--
        Write-Verbose "$ComputerName Retry $($RetryStart - $Retry)" -Verbose:$VerbosePreference
    } until ($Retry -lt 0) # This condition should never be met, return comes first...
}
