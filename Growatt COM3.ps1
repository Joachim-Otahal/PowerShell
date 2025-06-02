# Read Growatt MIC TX-L 500-3300 current wattage via Powershell and RS485 USB adapter.
# I simply don't like relying on cloud, and I want it faster than every five Minutes.
# Joachim Otahal April 2024
# little update Aug 2024, correct interpretation of the data from Growatt MIC TX-L.
# June 2025 update: A update of Read-Serial from "MarsTek Venus E Read RS485 data.ps1".
#
# This is weird, no real documentation or working example on how to send and receive binary data via powershell? OK, worked my way through :D.
# And the documentation from growatt is somewhat non existing too, I had to capture the serial communication from Shinebus to know what is real.
# Even worse: Register-ObjectEvent works in PSIE and manually in shell, but NOT when used in script. Most weird powershell bug so far.

function Read-Serial {
    param (
        [string]$COM = "COM3",
        [int]$Timeout = 2,
        [int]$Speed = 9600,
        [Byte[]]$Command = $null,
        [int]$ResponseWait = 250
    )
    if ($Command.Count -eq 0) {
        return $null
    } else {
        $port = New-Object System.IO.Ports.SerialPort $COM,$Speed,None,8,one
        $port.Open()
        $port.Write($Command,0,$Command.Count)
        # Response is not fast, but wait no more than $Timeout seconds
        for ($i=0;$i -lt $Timeout*1000/$ResponseWait;$i++) {
            Start-Sleep -Milliseconds $ResponseWait
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

function Get-CRC16Modbus {
    Param(
        [parameter(Mandatory=$true)]$InputObject,
        [String][ValidateSet("Hex","HexLE", "WORD","WwordLE","Byte","ByteLE")]$Output="ByteLE" # Powershell is mostly on intel x86
    )
    # $HexString="01040bb8007d" Growatt MIC TX-L gimme data
    # Expected CRC16 to append to above: b2 2a

    # None of the examples on the internet for powershell crc16 worked for CRC16\modbus.
    # So I translated this linux C version from https://github.com/LacobusVentura/MODBUS-CRC16
    # to powershell, and finally I had a working CRC16/MODBUS
    #
    # Accepts hex string in various formats, byte or byte-array, int23 or int32 array.
    # Joachim Otahal August 2024

    $CRCTable = 0x0000, 0xc0c1, 0xc181, 0x0140, 0xc301, 0x03c0, 0x0280, 0xc241, 
         0xc601, 0x06c0, 0x0780, 0xc741, 0x0500, 0xc5c1, 0xc481, 0x0440, 
         0xcc01, 0x0cc0, 0x0d80, 0xcd41, 0x0f00, 0xcfc1, 0xce81, 0x0e40, 
         0x0a00, 0xcac1, 0xcb81, 0x0b40, 0xc901, 0x09c0, 0x0880, 0xc841, 
         0xd801, 0x18c0, 0x1980, 0xd941, 0x1b00, 0xdbc1, 0xda81, 0x1a40, 
         0x1e00, 0xdec1, 0xdf81, 0x1f40, 0xdd01, 0x1dc0, 0x1c80, 0xdc41, 
         0x1400, 0xd4c1, 0xd581, 0x1540, 0xd701, 0x17c0, 0x1680, 0xd641, 
         0xd201, 0x12c0, 0x1380, 0xd341, 0x1100, 0xd1c1, 0xd081, 0x1040, 
         0xf001, 0x30c0, 0x3180, 0xf141, 0x3300, 0xf3c1, 0xf281, 0x3240, 
         0x3600, 0xf6c1, 0xf781, 0x3740, 0xf501, 0x35c0, 0x3480, 0xf441, 
         0x3c00, 0xfcc1, 0xfd81, 0x3d40, 0xff01, 0x3fc0, 0x3e80, 0xfe41, 
         0xfa01, 0x3ac0, 0x3b80, 0xfb41, 0x3900, 0xf9c1, 0xf881, 0x3840, 
         0x2800, 0xe8c1, 0xe981, 0x2940, 0xeb01, 0x2bc0, 0x2a80, 0xea41, 
         0xee01, 0x2ec0, 0x2f80, 0xef41, 0x2d00, 0xedc1, 0xec81, 0x2c40, 
         0xe401, 0x24c0, 0x2580, 0xe541, 0x2700, 0xe7c1, 0xe681, 0x2640, 
         0x2200, 0xe2c1, 0xe381, 0x2340, 0xe101, 0x21c0, 0x2080, 0xe041, 
         0xa001, 0x60c0, 0x6180, 0xa141, 0x6300, 0xa3c1, 0xa281, 0x6240, 
         0x6600, 0xa6c1, 0xa781, 0x6740, 0xa501, 0x65c0, 0x6480, 0xa441, 
         0x6c00, 0xacc1, 0xad81, 0x6d40, 0xaf01, 0x6fc0, 0x6e80, 0xae41, 
         0xaa01, 0x6ac0, 0x6b80, 0xab41, 0x6900, 0xa9c1, 0xa881, 0x6840, 
         0x7800, 0xb8c1, 0xb981, 0x7940, 0xbb01, 0x7bc0, 0x7a80, 0xba41, 
         0xbe01, 0x7ec0, 0x7f80, 0xbf41, 0x7d00, 0xbdc1, 0xbc81, 0x7c40, 
         0xb401, 0x74c0, 0x7580, 0xb541, 0x7700, 0xb7c1, 0xb681, 0x7640, 
         0x7200, 0xb2c1, 0xb381, 0x7340, 0xb101, 0x71c0, 0x7080, 0xb041, 
         0x5000, 0x90c1, 0x9181, 0x5140, 0x9301, 0x53c0, 0x5280, 0x9241, 
         0x9601, 0x56c0, 0x5780, 0x9741, 0x5500, 0x95c1, 0x9481, 0x5440, 
         0x9c01, 0x5cc0, 0x5d80, 0x9d41, 0x5f00, 0x9fc1, 0x9e81, 0x5e40, 
         0x5a00, 0x9ac1, 0x9b81, 0x5b40, 0x9901, 0x59c0, 0x5880, 0x9841, 
         0x8801, 0x48c0, 0x4980, 0x8941, 0x4b00, 0x8bc1, 0x8a81, 0x4a40, 
         0x4e00, 0x8ec1, 0x8f81, 0x4f40, 0x8d01, 0x4dc0, 0x4c80, 0x8c41, 
         0x4400, 0x84c1, 0x8581, 0x4540, 0x8701, 0x47c0, 0x4680, 0x8641, 
         0x8201, 0x42c0, 0x4380, 0x8341, 0x4100, 0x81c1, 0x8081, 0x4040
    for ($i=0; $i -lt $CRCTable.Count;$i++) {
        $CRCTable[$i]=[uint16]$CRCTable[$i]
    }
    Write-Verbose "Input is $($InputObject.psobject.TypeNames[0])" -Verbose:$VerbosePreference
    switch ($InputObject.psobject.TypeNames[0]) {
        "System.String" {
            $Hex = $InputObject.Replace("0x","") -replace "[^0-9a-fA-F]",""
            $bytes = [byte[]]::new($Hex.Length / 2)
            For($i=0; $i -lt $Hex.Length; $i+=2){
                $bytes[$i/2] = [convert]::ToByte($Hex.Substring($i, 2), 16)
            }
        }
        "System.Byte[]" {
            $bytes = $InputObject
        }
        "System.Int32" {
            $bytes = @([byte]$InputObject)
        }
        "System.Byte" {
            $bytes = @($InputObject)
        }
        "System.Object[]" {
            # If you create the input like this: $InputObject=(0x01,0x04,0x0b,0xb8,0x00,0x7d)
            # you get an object-array with int32 values. We catch and convert.
            $bytes = @($InputObject | foreach {[byte]$_})
            if ($bytes.Count -eq 0) {Write-Error "cccExpected Hex-String, byte, byte-array";return $null}
        }
        default {Write-Error "Expected Hex-String, byte, byte-array";return $null}
    }

    $CRC = [uint16]0xFFFF
    for ($i=0; $i -lt $bytes.Count;$i++) {
        $index = [byte]($CRC -band 0x00ff -bxor $bytes[$i])
        $CRC = [uint16]($CRC -shr 8 -bxor $CRCTable[$index])
        Write-Verbose "$i+1: $($bytes[$i]) $($bytes[$i].ToString("X2")), CRC $($CRC.ToString("X2")) $CRC" -Verbose:$VerbosePreference
    }
    switch ($Output) {
        "Hex"   { $Result = $CRC.ToString("X2") }
        "HexLE" { $Result = (($CRC -shl 8) + ($CRC -shr 8)).ToString("x2") }
        "Word"  { $Result = $CRC }
        "WordLE"{ $Result = [uint16](($CRC -shl 8) + ($CRC -shr 8)) }
        "Byte"  { $Result = @([byte]($CRC -shr 8),[byte]($CRC -band 0x00ff)) }
        default { $Result = @([byte]($CRC -band 0x00ff),[byte]($CRC -shr 8)) } # ByteLE
    }
    return $Result
}

# Read from 0 on
[byte[]]$GetGrowattStatus=(0x01,0x03,0x00,0x00,0x00,0x7d,0xEB,0x85)

# Default get data Device 1, register 0bb8 (3000), 125 16 bit registers
[byte[]]$GetGrowattStatus=(0x01,0x04,0x0b,0xb8,0x00,0x7d,0xb2,0x2a)
# Default get data Device 2, register 0bb8 (3000), 125 16 bit registers
[byte[]]$GetGrowattStatus=(0x02,0x04,0x0b,0xb8,0x00,0x7d,0xb2,0x19)


# Read a single register, here percentage of max output 0x64 = 100, 0xff no limit
# New-Modbus.RS485.RTU.Protocal.Latest.Ver.pdf Page 35
# Get
[byte[]]$GetGrowattStatus=(0x01,0x03,0x00,0x03,0x00,0x01)#,0x74,0x0a)
# Write a single register, here percentage of max output 0x64 = 100, 0xff no limit
# Changing this is NOT permament, lost after reboot (i.e. lost during night on MIC).
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x00,0x79,0xca) #   0 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x05,0xb9,0xc9) #   5 %
[byte[]]$GetGrowattStatus=(0x02,0x06,0x00,0x03,0x00,0x05,0xb9,0xfa) #   5 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x0A,0xf9,0xcd) #  10 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x0F,0x39,0xce) #  15 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x14,0x79,0xc5) #  20 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x19,0xb8,0x00) #  25 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x1E,0xf9,0xc2) #  30 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x23,0x38,0x13) #  35 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x28,0x79,0xd4) #  40 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x2D,0xb9,0xd7) #  45 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x32,0xf8,0x1f) #  50 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x37,0x38,0x1c) #  55 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x3C,0x79,0xdb) #  60 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x41,0xb9,0xfa) #  65 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x46,0x38,0x38) #  70 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x4B,0x39,0xfd) #  75 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x50,0x79,0xf6) #  80 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x55,0xb9,0xf5) #  85 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x5A,0xf9,0xf1) #  90 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x5F,0x39,0xf2) #  95 %
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0x64,0x78,0x21) # 100 % = default
[byte[]]$GetGrowattStatus=(0x02,0x06,0x00,0x03,0x00,0x64)#,0x78,0x12) # 100 % = default
[byte[]]$GetGrowattStatus=(0x02,0x06,0x00,0x03,0x00,0x64)#,0x78,0x12) # 100 % = default
[byte[]]$GetGrowattStatus=(0x01,0x06,0x00,0x03,0x00,0xFF,0xC9,0x8A) # No Limit
# Respone                                             
# 01,06,was-gesetzt-wurde.

# Write multiple register            start     NoOfReg   Data
#[byte[]]$GetGrowattStatus=(0x01,0x10,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x00,0xEB,0x85) # Example, untested

# Source is Growatt documentation + serial sniffer on COM3 ! pdfcoffee.com_growatt-inverter-modbus-rtu-protocol-ii-v1-24-english-new-pdf-free.pdf
# Modbus command for "give me your data", Growatt MIC TX-L, from register 3000 (0bb8) on, 125 registers
[byte[]]$GetGrowattStatus=(0x01,0x04,0x0b,0xb8,0x00,0x7d,0xb2,0x2a)

# Get Status normal
[byte[]]$GetGrowattStatus=(0x02,0x04,0x0b,0xb8,0x00,0x7d)

# Exportlimit when exportlimit failed
# get enabled (page 15)
[byte[]]$GetGrowattStatus=(0x02,0x04,0x00,0x7a,0x00,0x01)
# get %
[byte[]]$GetGrowattStatus=(0x02,0x04,0x00,0x7b,0x00,0x01)
[byte[]]$GetGrowattStatus=(0x02,0x04,0x0b,0xb8,0x00,0x01)
# set 100,0% 
[byte[]]$GetGrowattStatus=(0x02,0x06,0x00,0x7b,0x03,0xE8)
[byte[]]$GetGrowattStatus=(0x02,0x06,0x0b,0xb8,0x03,0xE8)

# https://www.photovoltaikforum.com/thread/168214-welche-grundeinstellungen-hat-der-growatt-mic-1500tl-x/?postID=2542038#post2542038
# Register 2 = 1 = store, keep during reboot.
# Register 3 active rate = % 
# Read state
[byte[]]$GetGrowattStatus=(0x02,0x04,0x00,0x03,0x00,0x01) # = 2 101 = 613 = 0x02 0x65 ? Default ?
# Actual read state from serial sniffer, has to be 3 not 4
[byte[]]$GetGrowattStatus=(0x02,0x03,0x00,0x03,0x00,0x01) # 2 3 2 0 45 60 89 = OK.
# set 5% = worked.
[byte[]]$GetGrowattStatus=(0x02,0x06,0x00,0x03,0x00,0x05) # 112 Watt
# 10% = worked.
[byte[]]$GetGrowattStatus=(0x02,0x06,0x00,0x03,0x00,0x0A) # 208 Watt
# 40% = worked, supposedly 800 watt
[byte[]]$GetGrowattStatus=(0x02,0x06,0x00,0x03,0x00,40) # 
# 45% = worked, supposedly 900 watt
[byte[]]$GetGrowattStatus=(0x02,0x06,0x00,0x03,0x00,45) # 
# 100% = worked.
[byte[]]$GetGrowattStatus=(0x02,0x06,0x00,0x03,0x00,0x64) # ---



if ($GetGrowattStatus.Count -eq 6) {$GetGrowattStatus+=Get-CRC16Modbus -InputObject $GetGrowattStatus } # -Output HexLE
$SerialData = Read-Serial -COM "COM3" -Timeout 2 -Command $GetGrowattStatus
"$SerialData"
$GrowattCSVfile = (Get-Date).ToString('yyyy-MM-dd') + "-Growatt-COM3.csv"
$TimeStamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

if ($SerialData) {
    $GrowattData = [pscustomobject]@{
        Time = $TimeStamp
        OutputPower = ((($SerialData[49] * 256 + $SerialData[50])*256 + $SerialData[51]) * 256 + $SerialData[52])/10
        OutputPercent = ($SerialData[205] * 256 + $SerialData[206])
        Temp1 = ($SerialData[189] * 256 + $SerialData[190])/10
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
        OutputPercent = 0
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
