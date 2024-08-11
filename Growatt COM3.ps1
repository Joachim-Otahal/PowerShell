# Read Growatt MIC TX-L 500-3300 current wattage via Powershell and RS485 USB adapter.
# I simply don't like relying on cloud, and I want it faster than every five Minutes.
# Joachim Otahal April 2024
# little update Aug 2024, correct interpretation of the data gtom Growatt MIC TX-L.
#
# This is weird, no real documentation or working example on how to send and receive binary data via powershell? OK, worked my way through :D.
# And the documentation from growatt is somewhat non existing too, I had to capture the serial communication from Shinebus to know what is real.
# Even worse: Register-ObjectEvent works in PSIE and manually in shell, but NOT when used in script. Most weird powershell bug so far.

function Read-Serial {
    param (
        [string]$COM = "COM3",
        [int]$Timeout = 2,
        [Byte[]]$Command = $null
    )
    if ($Command.Count -eq 0) {
        return $null
    } else {
        $port = New-Object System.IO.Ports.SerialPort $COM,9600,None,8,one
        $port.Open()
        $port.Write($Command,0,$Command.Count)
        # Response is not fast, but wait no more than $Timeout seconds
        for ($i=0;$i -lt $Timeout*4;$i++) {
            Start-Sleep -Milliseconds 250
            if ($port.BytesToRead -gt 0) {
                #Write-Verbose $i -Verbose
                $ReceiveData=@()
                while ($port.BytesToRead -gt 0) {
                   $ReceiveData += [byte]$port.ReadByte()
                }
                $i=[int]::MaxValue
            }
        }
        $port.Close()
        if ($ReceiveData.Count -eq 0) {
            return $null
        } else {
            return $ReceiveData
        }
    }
}

# Source is Growatt documentation + serial sniffer on COM3 ! pdfcoffee.com_growatt-inverter-modbus-rtu-protocol-ii-v1-24-english-new-pdf-free.pdf
# Modbus command for "give me your data", Growatt MIC TX-L, from register 3000 (0bb8) on, 125 registers
[byte[]]$GetGrowattStatus2=(0x01,0x04,0x0b,0xb8,0x00,0x7d,0xb2,0x2a)

$SerialData = Read-Serial -COM "COM3" -Timeout 2 -Command $GetGrowattStatus2
$GrowattCSVfile = $CurrentDate.ToString('yyyy-MM-dd') + "-Growatt-COM3.csv"
$TimeStamp = $CurrentDate.ToString('yyyy-MM-dd HH:mm:ss')

if ($SerialData) {
    $GrowattData = [pscustomobject]@{
        Time = $TimeStamp
        OutputPower = ((($SerialData[49] * 256 + $SerialData[50])*256 + $SerialData[51]) * 256 + $SerialData[52])/10
        Temp1 = ($SerialData[181] * 256 + $SerialData[182])/10
        Temp5 = ($SerialData[197] * 256 + $SerialData[198])/10
        TodayEnergy = ((($SerialData[101] * 256 + $SerialData[102])*256 + $SerialData[103]) * 256 + $SerialData[104])/10
        TotalEnergy = ((($SerialData[105] * 256 + $SerialData[106])*256 + $SerialData[107]) * 256 + $SerialData[108])/10
        PVPower = ((($SerialData[5] * 256 + $SerialData[6])*256 + $SerialData[7]) * 256 + $SerialData[8])/10
        PV1Voltage = ($SerialData[9] * 256 + $SerialData[10])/10
        PV1Current = ($SerialData[11] * 256 + $SerialData[12])/10
        PV1Power = ((($SerialData[13] * 256 + $SerialData[14])*256 + $SerialData[15]) * 256 + $SerialData[16])/10
        GridFrequency = ($SerialData[53] * 256 + $SerialData[54])/100
        Phase1Voltage = ($SerialData[55] * 256 + $SerialData[56])/10
        Phase1Current = ($SerialData[57] * 256 + $SerialData[58])/10
    }
} else {
    $GrowattData = [pscustomobject]@{
        Time = $TimeStamp
        OutputPower = 0
        Temp1 = 0
        Temp5 = 0
        TodayEnergy = 0
        TotalEnergy = 0
        PVPower = 0
        PV1Voltage = 0
        PV1Current = 0
        PV1Power = 0
        GridFrequency = 0
        Phase1Voltage = 0
        Phase1Current = 0
    }
}

# IF we are in powershell ISE just put it on screen. Else .CSV it.
if (!$psISE) {
    $GrowattData | Export-Csv -Delimiter ";" -Encoding ASCII -NoTypeInformation -Append -Path $GrowattCSVfile
} else {
    ($GrowattData | fl | Out-String).Trim()
}
