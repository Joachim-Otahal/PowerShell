# Read Growatt MIC 500-3300 current wattage via Powershell and RS485 USB adapter.
# I simply don't like relying on cloud, and I want it faster than every five Minutes.
# Joachim Otahal April 2024
#
# This is weird, no real documentation or working example on how to send and receive binary data via powershell? OK, worked my way through :D.
# And the documentation from growatt is somewhat non existing too, I had to capture the serial communication from Shinebus to know what is real.
# Even worse: Register-ObjectEvent works in PSIE and manually in shell, but NOT when used in script. Most weird powershell bug so far.

[string]$COM = "COM3"
[int]$Timeout = 4

# Modbus command for "give me your data"
[byte[]]$GetGrowattStatus=(0x01,0x04,0x0b,0xb8,0x00,0x7d,0xb2,0x2a)

$port = New-Object System.IO.Ports.SerialPort $COM,9600,None,8,one
$port.Open()
$port.Write($GetGrowattStatus,0,$GetGrowattStatus.Count)
# Response is not fast, but wait no more than $Timeout seconds
for ($i=0;$i -lt $Timeout*4;$i++) {
    Start-Sleep -Milliseconds 250
    if ($port.BytesToRead -gt 0) {
        #Write-Verbose $i -Verbose
        $Data=@()
        while ($port.BytesToRead -gt 0) {
           $Data += [byte]$port.ReadByte()
        }
        $GrowattWatt = ($Data[7] * 256 + $Data[8])/10
        $i=[int]::MaxValue
    }
}
$port.Close()
$GrowattWatt

# Hints for more:
# 7,8 = current wattage, 15,16 current wattage, 53,54 Frequency, 55,56 = Volt, 79,80 = Volt
# 107,108 kWh Cumulative (???).
