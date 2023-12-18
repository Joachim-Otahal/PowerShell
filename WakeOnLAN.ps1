# Created as quickhack 18th December 2023 since all those examples on the internet did not work with my network configuration.
# For example: They tried to use "localhost", or the unconnected WLAN adapter and so on.
# Joachim Otahal / jou@gmx.net / https://www.joumxyzptlk.de / 

# Create magic packet
$Mac = "70:85:c2:82:53:c8"
$MacByteArray = $Mac -split "[:-]" | ForEach-Object { [Byte] "0x$_"}
[Byte[]] $MagicPacket = (,0xFF * 6) + ($MacByteArray  * 16)

# Get the full ipconfig of actual adapter with ipv4
$NetIPConfig=@(Get-NetIPAddress | Select-Object *)
$IPConfig = $NetIPConfig.Where({
    $_.IPv4Address -ne "127.0.0.1" -and
    $_.IPv4Address -notlike "169.254.*" -and
    $_.IPv6Address -ne "::1" -and 
    $_.IPv6Address -eq $null
})[0]
[IPAddress]$subnet = 0
$subnet = [IPAddress]::HostToNetworkOrder([int64]::MaxValue -shl (64 - $IPConfig.PrefixLength))
[IPAddress]$broadcast = 0
# only ipv4 accepted, i.e. prefixlength 32 or less
if ($IPConfig.PrefixLength -le 32) {
    $ip = ([IPAddress][String]($IPConfig.IPAddress)).Address
    $network = $ip -band $subnet.Address
    # If we don't force uint32 in $subnet.address the system uses int64,
    # which gives us a negative value with -bnot...
    $broadcast = ([IPAddress]($network -bor -bnot [uint32]$subnet.Address)).IPAddressToString
}

# Finally send packet
$UdpClient = New-Object System.Net.Sockets.UdpClient
$UdpClient.Connect($broadcast,7)
$UdpClient.Send($MagicPacket,$MagicPacket.Length)
$UdpClient.Close()


