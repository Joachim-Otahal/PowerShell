# Created as quickhack 18th December 2023 since all those examples on the internet did not work with my network configuration.
# For example: They tried to use "localhost", or the unconnected WLAN adapter and so on.
# 23rd December 2023: Go through all network adapters and added ipv6 variant
# Jun 2024: A bit cleanup, honor -Verbose
# Joachim Otahal / jou@gmx.net / https://www.joumxyzptlk.de / https://github.com/Joachim-Otahal/PowerShell

function WakeOnLan {
    param (
        [string]$Mac = "70:85:c2:82:53:c8" # Target mac example
    )
    $MacByteArray = $Mac -split "[:-]" | ForEach-Object { [Byte] "0x$_"}
    [Byte[]] $MagicPacket = (,0xFF * 6) + ($MacByteArray  * 16) # 0xFFFFFFFFFFFF + 16 * mac
    
    # Get the full ipconfig of actual adapter with ipv4
    $NetIPConfig=@(Get-NetIPAddress | Select-Object *)
    $IPConfig = $NetIPConfig.Where({
        ($_.IPv4Address -ne "127.0.0.1" -and !($_.IPv6Address)) -or
        $_.IPv6Address -like "fe80::*:*:*:*"
    })
    for ($i = 0 ; $i -lt $IPConfig.Count;$i++) {
        if ($IPConfig[$i].IPAddress -like "*.*.*.*") {
            [System.Net.IPAddress]$castaddress = 0
            [System.Net.IPAddress]$subnet = 0
            $subnet = [System.Net.IPAddress]::HostToNetworkOrder([int64]::MaxValue -shl (64 - $IPConfig[$i].PrefixLength))
            # only ipv4 accepted, i.e. prefixlength 32 or less
            $ip = ([System.Net.IPAddress][String]($IPConfig[$i].IPAddress)).Address
            $network = $ip -band $subnet.Address
            # If we don't force uint32 in $subnet.address the system uses int64,
            # which gives us a negative value with -bnot...
            $castaddress = ([System.Net.IPAddress]($network -bor -bnot [uint32]$subnet.Address)).IPAddressToString
            # Source port may be blocked, therefore try until success.
            do {
                try {
                    $UdpClient = New-Object System.Net.Sockets.UdpClient((Get-Random -Minimum 4097 -Maximum 65535), [System.Net.Sockets.AddressFamily]::InterNetwork)
                } catch {}
            } until ($UdpClient)
            # Port 7 = Echo, many use Port 9, it actually does not matter
            # Finally send packet
            $UdpClient.Connect($castaddress,7)
            $result = $UdpClient.Send($MagicPacket,$MagicPacket.Length)
            Write-Verbose "IP $($IPConfig[$i].IPAddress), broadcast $castaddress sending, Result $result $(if ($result -eq 102) {'(OK)'})" -Verbose:$VerbosePreference
            $UdpClient.Close()
        }
        if ($IPConfig[$i].IPAddress -like "fe80::*:*:*:*") {
            [System.Net.IPAddress]$castaddress = "FF02::1"
            # Source port may be blocked, therefore try until success.
            do {
                try {
                    $UdpClient = New-Object System.Net.Sockets.UdpClient((Get-Random -Minimum 4097 -Maximum 65535), [System.Net.Sockets.AddressFamily]::InterNetworkV6)
                } catch {}
            } until ($UdpClient)
            # Port 7 = Echo, many use Port 9, it actually does not matter
            $UdpClient.Connect($castaddress,7)
            $result = $UdpClient.Send($MagicPacket,$MagicPacket.Length)
            Write-Verbose "IP $($IPConfig[$i].IPAddress), broadcast $castaddress sending, Result $result $(if ($result -eq 102) {'(OK)'})" -Verbose:$VerbosePreference
            $UdpClient.Close()
        }
    }
}
