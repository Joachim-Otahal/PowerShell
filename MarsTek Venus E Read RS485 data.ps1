# Read MARSTEK VENUS E via Powershell and RS485 USB adapter.
# I simply don't like relying on cloud.
# Joachim Otahal June 2025
#
# This is weird, no real documentation or working example on how to send and receive serial binary data via powershell? OK, worked my way through :D.
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

# MARSTEK
# Bus 1, function 3, start at 0x7918, read 2
# Device name
[byte[]]$GetMarstekStatus=(0x01,0x03,0x79,0x18,0x00,0x0a) #
# Softwareversion
# Serialnumer
[byte[]]$GetMarstekStatus=(0x01,0x03,0x79,0xE0,0x00,0x0a) #

if ($GetMarstekStatus.Count -eq 6) {$GetMarstekStatus+=Get-CRC16Modbus -InputObject $GetMarstekStatus } # -Output HexLE
$SerialData = Read-Serial -COM "COM4" -Speed 115200 -Timeout 2 -ResponseWait 50 -Command $GetMarstekStatus
[System.BitConverter]::ToString($SerialData)
([System.Text.Encoding]::ASCII).GetString($SerialData)

# 01 83 03 01 31 = Number of registers to read does not match data field begin / end

# Get Marstek Data
$TimeStamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$MarstekState = [pscustomobject]@{
    Time = $TimeStamp
    BatteryVoltage = [float]0
    BatteryCurrent = [float]0
    # Following is singed int32, therefore roundabout hex since I am too lazy.
    BatteryPower = 0
    BatterySOC = 0
    BatteryTotalEnergy = [float]0
    ACVoltage = 0
    ACCurrent = 0
    ACPower= 0 # Posivie = give power, negative = charge power.
    ACFrequency = 0
    ACOVoltage = 0
    ACOCurrent = 0
    ACOPower = 0
    Temp = 0
    TempMOS1 = 0
    TempMOS2 = 0
    InterterState = 0
    InterterStateHR = ""
}

# Battery data
[byte[]]$GetMarstekStatus=(0x01,0x03,0x7d,0x64,0x00,0x06) ; $GetMarstekStatus+=Get-CRC16Modbus -InputObject $GetMarstekStatus
$SerialData = Read-Serial -COM "COM4" -Speed 115200 -ResponseWait 25 -Timeout 2 -Command $GetMarstekStatus

if ($SerialData) {
    $MarstekState.BatteryVoltage = ($SerialData[3] * 256 + $SerialData[4])/100
    $MarstekState.BatteryCurrent = ($SerialData[5] * 256 + $SerialData[6])/10000
    # Following is singed int32, therefore roundabout hex since I am too lazy. bigint has the advantage to understan s32 and s16.
    $MarstekState.BatteryPower = [bigint]::Parse($SerialData[7].ToString("x2") + $SerialData[8].ToString("x2") + $SerialData[9].ToString("x2") + $SerialData[10].ToString("x2"), 'AllowHexSpecifier')
    $MarstekState.BatterySOC = $SerialData[11] * 256 + $SerialData[12]
    $MarstekState.BatteryTotalEnergy = ($SerialData[13] * 256 + $SerialData[14])/1000
}

# Grid data
[byte[]]$GetMarstekStatus=(0x01,0x03,0x7d,0xc8,0x00,0x05) ; $GetMarstekStatus+=Get-CRC16Modbus -InputObject $GetMarstekStatus
$SerialData = Read-Serial -COM "COM4" -Speed 115200 -ResponseWait 25 -Timeout 2 -Command $GetMarstekStatus

if ($SerialData) {
    $MarstekState.ACVoltage = ($SerialData[3] * 256 + $SerialData[4])/10
    $MarstekState.ACCurrent = ($SerialData[5] * 256 + $SerialData[6])/100
    $MarstekState.ACPower = [bigint]::Parse($SerialData[7].ToString("x2") + $SerialData[8].ToString("x2") + $SerialData[9].ToString("x2") + $SerialData[10].ToString("x2"), 'AllowHexSpecifier')
    $MarstekState.ACFrequency = ($SerialData[11] * 256 + $SerialData[12])/100
}

# Offgrid plug data
[byte[]]$GetMarstekStatus=(0x01,0x03,0x7e,0x2c,0x00,0x04) ; $GetMarstekStatus+=Get-CRC16Modbus -InputObject $GetMarstekStatus
$SerialData = Read-Serial -COM "COM4" -Speed 115200 -ResponseWait 25 -Timeout 2 -Command $GetMarstekStatus

if ($SerialData) {
    $MarstekState.ACOVoltage = ($SerialData[3] * 256 + $SerialData[4])/10
    $MarstekState.ACOCurrent = ($SerialData[5] * 256 + $SerialData[6])/100
    # Following is singed int32, therefore roundabout hex since I am too lazy.
    $MarstekState.ACOPower = [bigint]::Parse($SerialData[7].ToString("x2") + $SerialData[8].ToString("x2") + $SerialData[9].ToString("x2") + $SerialData[10].ToString("x2"), 'AllowHexSpecifier')
}

# Temperature data
[byte[]]$GetMarstekStatus=(0x01,0x03,0x88,0xb8,0x00,0x03) ; $GetMarstekStatus+=Get-CRC16Modbus -InputObject $GetMarstekStatus
$SerialData = Read-Serial -COM "COM4" -Speed 115200 -ResponseWait 25 -Timeout 2 -Command $GetMarstekStatus

if ($SerialData) {
    $MarstekState.Temp = [bigint]::Parse($SerialData[3].ToString("x2") + $SerialData[4].ToString("x2"), 'AllowHexSpecifier')/10
    $MarstekState.TempMOS1 = [bigint]::Parse($SerialData[5].ToString("x2") + $SerialData[6].ToString("x2"), 'AllowHexSpecifier')/10
    # Following is singed int32, therefore roundabout hex since I am too lazy.
    $MarstekState.TempMOS2 = [bigint]::Parse($SerialData[7].ToString("x2") + $SerialData[8].ToString("x2"), 'AllowHexSpecifier')/10
}

# Inverter State
[byte[]]$GetMarstekStatus=(0x01,0x03,0x89,0x1c,0x00,0x01) ; $GetMarstekStatus+=Get-CRC16Modbus -InputObject $GetMarstekStatus
$SerialData = Read-Serial -COM "COM4" -Speed 115200 -ResponseWait 25 -Timeout 2 -Command $GetMarstekStatus

if ($SerialData) {
    $MarstekState.InterterState = $SerialData[3]
    switch ($SerialData[3]) {
        0 {$MarstekState.InterterStateHR="sleep"}
        1 {$MarstekState.InterterStateHR="standby"}
        2 {$MarstekState.InterterStateHR="charge"}
        3 {$MarstekState.InterterStateHR="discharge"}
        4 {$MarstekState.InterterStateHR="backup mode"}
        5 {$MarstekState.InterterStateHR="OTA upgrade"}
        default {$MarstekState.InterterStateHR="illegal value"}
    }
}

$MarstekState