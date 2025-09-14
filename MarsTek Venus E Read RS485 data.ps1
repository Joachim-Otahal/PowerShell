# Read MARSTEK VENUS E via Powershell and RS485 USB adapter.
# I simply don't like relying on cloud.
# Joachim Otahal June 2025
#                September 2025 updated to read more values, and use newer read-serial version with "burst command per connection"
#
# Modbus Info: https://duravolt.nl/wp-content/uploads/Duravolt-Plug-in-Battery-Modbus.pdf
#
# This is weird, no real documentation or working example on how to send and receive serial binary data via powershell? OK, worked my way through :D.
# And the documentation from growatt is somewhat non existing too, I had to capture the serial communication from Shinebus to know what is real.
# Even worse: Register-ObjectEvent works in PSIE and manually in shell, but NOT when used in script. Most weird powershell bug so far.

function Read-Serial {
    param (
        [string]$COM = "COM3",
        [int]$Timeout = 2,
        [int]$Speed = 9600,
        [Object]$Commandos = $null,
        #[Byte[]]$Command = $null, # old version, where we did not allow hashtable with several [byte[]] arrays.
        [int]$ResponseWait = 250
    )
    # Joachim Otahal, 2025
    # v2, allowing multiple command within one serial connection supplied as hash-array. Avoids the DOTNET issue where consequtively
    # opening a closing a port several times does not work as expected. The commands are done in alphabetical order.
    # v3, updates for more tolerance to hash-array names.
    # https://learn.microsoft.com/en-us/answers/questions/343511/serial-port-unauthorizedaccessexception
    # Please remember that the SerialPort.Close method takes some time to actually close the port.
    $Keys=$null
    if ($Commandos.psobject.TypeNames -contains "System.Object[]") {
        $Commandos=[byte[]]$Commandos # Catches when adding crc16 changes byte array to object array for no reason, and not always?
    }
    if ($Commandos.psobject.TypeNames -contains "System.Collections.Hashtable") {
        $Keys = @($Commandos.Keys | Sort-Object)
        $KeyIndex=0
        if ($Commandos[$Keys[$KeyIndex]].psobject.TypeNames -contains "System.Byte[]") {
            $ReceiveDataHash=@{}
        } else {
            return $null
        }
    }
    if ($Commandos.psobject.TypeNames -notcontains "System.Byte[]" -and $Commandos.psobject.TypeNames -notcontains "System.Collections.Hashtable") {
        return $null
    }
    $port = New-Object System.IO.Ports.SerialPort $COM,$Speed,None,8,one
    if ($port.IsOpen) {
        $port.Close()
        $MaxTry=20
        while ($Port.IsOpen -and $MaxTry -gt 0) { Start-Sleep -Milliseconds 25;$MaxTry-- } # yeah dotnet serial is strangly slow...
    }
    if (!$port.IsOpen) {
        $MaxTry=20
        while (!$Port.IsOpen -and $MaxTry -gt 0) {
            try { $port.Open() } catch { $error.RemoveAt(0) }
            Start-Sleep -Milliseconds 25;$MaxTry--
        } # yeah dotnet serial is strangly slow...
        if ($Port.IsOpen) {$Sending=$true}else{$Sending=$false} # Control whether there are still elements in hasharray...
        while ($Sending) {
            if ($Keys.Count -gt 0) {
                $Command = $Commandos[$Keys[$KeyIndex]]
            } else {
                $Command = $Commandos
                $Sending = $false
            }
            $port.Write($Command,0,$Command.Count)
            # Response is not fast, but wait no more than $Timeout seconds
            for ($i=0;$i -lt $Timeout*1000/$ResponseWait;$i++) {
                Start-Sleep -Milliseconds $ResponseWait
                if ($port.BytesToRead -gt 0) {
                    # Write-Verbose $i -Verbose
                    $ReceiveData=@()
                    while ($port.BytesToRead -gt 0) {
                       $ReceiveData += [byte]$port.ReadByte()
                    }
                    $i=[int]::MaxValue
                }
            }
            if ($Keys.Count -gt 0) { # If input is hasharray of [byte[]]
                $ReceiveDataHash[$Keys[$Keyindex]] = $ReceiveData # Add received to return-hasharray
                $KeyIndex++ # next element please...
                if ($KeyIndex -ge $Keys.Count) {
                    $Sending=$false
                } else {
                    Start-Sleep -Milliseconds $ResponseWait # Might be not needed, just paranoid...
                }
            }
        }
        $port.Close()
        if ($Keys.Count -gt 0) {
            return $ReceiveDataHash
        } else {
            return $ReceiveData
        }
    } else {
        return $null
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
    # Accepts hex string in various formats, byte or byte-array, int32 or int32 array.
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
[byte[]]$SerialCommand=(0x01,0x03,0x79,0x18,0x00,0x0a) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
# Softwareversion
# Serialnumer
[byte[]]$SerialCommand=(0x01,0x03,0x79,0xE0,0x00,0x0a) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand

# RS485 Mode check
[byte[]]$SerialCommand=(0x01,0x03,0xa4,0x10,0x00,0x01) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand

$SerialData = Read-Serial -COM "COM4" -Speed 115200 -Timeout 2 -ResponseWait 50 -Command $SerialCommand
[System.BitConverter]::ToString($SerialData)
([System.Text.Encoding]::ASCII).GetString($SerialData)

# 01 83 03 01 31 = Number of registers to read does not match data field begin / end

# Get Marstek Data
$TimeStamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
# Marstek / Duravolt Data.
$MarstekData = [pscustomobject]@{
    Time = "1601-01-01 00:00:00"
    BatteryVoltage = [float]0
    BatteryCurrent = [float]0
    # Following is singed int32, therefore roundabout hex since I am too lazy.
    BatteryPower = 0
    BatterySOC = 0
    BatteryTotalEnergy = [float]0
    BatteryCharge = 0 # What is set as charge / discharge
    BatteryDischarge = 0 # What is set as charge / discharge
    BatteryMode = 0 # 0=nothing, 1=charge, 2=discharge
    ACVoltage = 0
    ACCurrent = 0
    ACPower = 0 # Positive = give power, negative = charge power.
    ACFrequency = 0
    ACOVoltage = 0
    ACOCurrent = 0
    ACOPower = 0
    Temp = 0
    TempMOS1 = 0
    TempMOS2 = 0
    AlarmState = 0
    AlarmStateHR = "" # Human Readable
    FaultState = 0
    FaultStateHR = "" # Human Readable
    InverterState = 0
    InverterStateHR = ""
}

$SerialCommands=@{}
# Marstek Battery data
[byte[]]$SerialCommand=(0x01,0x03,0x7d,0x64,0x00,0x06) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
$SerialCommands[0]=$SerialCommand
# Marstek Grid data
[byte[]]$SerialCommand=(0x01,0x03,0x7d,0xc8,0x00,0x05) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
$SerialCommands[1]=$SerialCommand
# Offgrid plug data
[byte[]]$SerialCommand=(0x01,0x03,0x7e,0x2c,0x00,0x04) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
$SerialCommands[2]=$SerialCommand
# Temperature data
[byte[]]$SerialCommand=(0x01,0x03,0x88,0xb8,0x00,0x03) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
$SerialCommands[3]=$SerialCommand
# Inverter State
[byte[]]$SerialCommand=(0x01,0x03,0x89,0x1c,0x00,0x01) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
$SerialCommands[4]=$SerialCommand
# Read charge Watt & discharge Watt
[byte[]]$SerialCommand=(0x01,0x03,0xa4,0x24,0x00,0x02) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
$SerialCommands[5]=$SerialCommand
# Read charge mode 0= nothing, 1=charge, 2=discharge
[byte[]]$SerialCommand=(0x01,0x03,0xa4,0x1A,0x00,0x01) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
$SerialCommands[6]=$SerialCommand
# Alarm state
[byte[]]$SerialCommand=(0x01,0x03,0x8C,0xA0,0x00,0x02) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
$SerialCommands[10]=$SerialCommand
# Fault state 36100
[byte[]]$SerialCommand=(0x01,0x03,0x8D,0x04,0x00,0x04) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
$SerialCommands[11]=$SerialCommand
# Read state whether Marstek is in manual RS485 control.
[byte[]]$SerialCommand=(0x01,0x03,0xa4,0x10,0x00,0x01) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
$SerialCommands[100]=$SerialCommand
if ($SerialData -ne $null) { # This check: If the receiving variale is defined as "byte[]" or whatever, for example multimple runs within one shell, it cannot digest/accept the hash table without beeing cleared first.
    Remove-Variable SerialData
}
$SerialData = Read-Serial -COM "COM4" -Speed 115200 -ResponseWait 50 -Timeout 2 -Commandos $SerialCommands
if ($SerialData[0].Count -eq 17) {
    $MarstekData.BatteryVoltage = ($SerialData[0][3] * 256 + $SerialData[0][4])/100
    # Following is float by singed int32 / 100, therefore roundabout hex since I am too lazy. bigint has the advantage to understand s32 and s16.
    $MarstekData.BatteryCurrent = [double]([bigint]::Parse($SerialData[0][5].ToString("x2")+$SerialData[0][6].ToString("x2"), 'AllowHexSpecifier'))/100 # +($SerialData[0][5] * 256 + $SerialData[0][6])/100
    # Following is singed int32, therefore roundabout hex since I am too lazy. bigint has the advantage to understand s32 and s16.
    $MarstekData.BatteryPower = [int]([bigint]::Parse($SerialData[0][7].ToString("x2") + $SerialData[0][8].ToString("x2") + $SerialData[0][9].ToString("x2") + $SerialData[0][10].ToString("x2"), 'AllowHexSpecifier'))
    $MarstekData.BatterySOC = $SerialData[0][11] * 256 + $SerialData[0][12]
    $MarstekData.BatteryTotalEnergy = ($SerialData[0][13] * 256 + $SerialData[0][14])/1000
    $Power.BatV = $MarstekData.BatteryVoltage
    $Power.BatSOC = $MarstekData.BatterySOC
}
if ($SerialData[1].Count -eq 15) {
    $MarstekData.ACVoltage = ($SerialData[1][3] * 256 + $SerialData[1][4])/10
    $MarstekData.ACCurrent = ($SerialData[1][5] * 256 + $SerialData[1][6])/100 # $SerialData[1][5].ToString("x2")+ " " + $SerialData[1][6].ToString("x2") +" " +($SerialData[1][5] * 256 + $SerialData[1][6]).ToString()
    $MarstekData.ACPower = [int]([bigint]::Parse($SerialData[1][7].ToString("x2") + $SerialData[1][8].ToString("x2") + $SerialData[1][9].ToString("x2") + $SerialData[1][10].ToString("x2"), 'AllowHexSpecifier'))
    $MarstekData.ACFrequency = ($SerialData[1][11] * 256 + $SerialData[1][12])/100
    $Power.BatACPow = $MarstekData.ACPower
}
if ($SerialData[2].Count -eq 13) {
    $MarstekData.ACOVoltage = ($SerialData[2][3] * 256 + $SerialData[2][4])/10
    $MarstekData.ACOCurrent = ($SerialData[2][5] * 256 + $SerialData[2][6])/100
    # Following is singed int32, therefore roundabout hex since I am too lazy.
    $MarstekData.ACOPower = [int]([bigint]::Parse($SerialData[2][7].ToString("x2") + $SerialData[2][8].ToString("x2") + $SerialData[2][9].ToString("x2") + $SerialData[2][10].ToString("x2"), 'AllowHexSpecifier'))
}
if ($SerialData[3].Count -eq 11) {
    $MarstekData.Temp = [bigint]::Parse($SerialData[3][3].ToString("x2") + $SerialData[3][4].ToString("x2"), 'AllowHexSpecifier')/10
    $MarstekData.TempMOS1 = [bigint]::Parse($SerialData[3][5].ToString("x2") + $SerialData[3][6].ToString("x2"), 'AllowHexSpecifier')/10
    # Following is singed int32, therefore roundabout hex since I am too lazy.
    $MarstekData.TempMOS2 = [bigint]::Parse($SerialData[3][7].ToString("x2") + $SerialData[3][8].ToString("x2"), 'AllowHexSpecifier')/10
}
if ($SerialData[4].Count -eq 7) {
    $MarstekData.InverterState = $SerialData[4][3]
    switch ($SerialData[4][3]) {
        0 {$MarstekData.InverterStateHR="sleep"}
        1 {$MarstekData.InverterStateHR="standby"}
        2 {$MarstekData.InverterStateHR="charge"}
        3 {$MarstekData.InverterStateHR="discharge"}
        4 {$MarstekData.InverterStateHR="backup mode"}
        5 {$MarstekData.InverterStateHR="OTA upgrade"}
        default {$MarstekData.InverterStateHR="illegal value"}
    }
}
if ($SerialData[5].Count -eq 9) {
    $MarstekData.BatteryCharge = $SerialData[5][3] * 256 + $SerialData[5][4]
    $MarstekData.BatteryDischarge = $SerialData[5][5] * 256 + $SerialData[5][6]
}
if ($SerialData[6].Count -eq 7) {
    $MarstekData.BatteryMode = $SerialData[6][4]
}
if ($SerialData[10].Count -eq 9) {
    $MarstekData.AlarmState = $SerialData[5][3].ToString("x2")+$SerialData[5][4].ToString("x2")
    if ($SerialData[5][3] -band 0x01 -gt 0) {$MarstekData.AlarmStateHR += "PLL Abnormal Restart,"}
    if ($SerialData[5][3] -band 0x02 -gt 0) {$MarstekData.AlarmStateHR += "Overtemperature Limit,"}
    if ($SerialData[5][3] -band 0x04 -gt 0) {$MarstekData.AlarmStateHR += "Low Temperature Limit,"}
    if ($SerialData[5][3] -band 0x08 -gt 0) {$MarstekData.AlarmStateHR += "Fan Abnormal Warning,"}
    if ($SerialData[5][3] -band 0x10 -gt 0) {$MarstekData.AlarmStateHR += "Low Battery SOC Warning,"}
    if ($SerialData[5][3] -band 0x20 -gt 0) {$MarstekData.AlarmStateHR += "Output Overcurrent Warnung,"}
    if ($SerialData[5][3] -band 0x40 -gt 0) {$MarstekData.AlarmStateHR += "Abnormal Line Sequence Detection,"}
    if ($SerialData[5][5] -band 0x01 -gt 0) {$MarstekData.AlarmStateHR += "WIFI abnormal,"}
    if ($SerialData[5][5] -band 0x02 -gt 0) {$MarstekData.AlarmStateHR += "BLE abnormal,"}
    if ($SerialData[5][5] -band 0x04 -gt 0) {$MarstekData.AlarmStateHR += "Network abnormal,"}
    if ($SerialData[5][5] -band 0x08 -gt 0) {$MarstekData.AlarmStateHR += "CT connection abnormal,"}
}
if ($SerialData[11].Count -eq 13) {
    $MarstekData.FaultState = $SerialData[6][3].ToString("x2")+$SerialData[6][4].ToString("x2")+$SerialData[6][5].ToString("x2")+$SerialData[6][6].ToString("x2")
    if ($SerialData[6][3] -band 0x01 -gt 0) {$MarstekData.AlarmStateHR += "Grid Overvoltage,"}
    if ($SerialData[6][3] -band 0x02 -gt 0) {$MarstekData.AlarmStateHR += "Grid Undervoltage,"}
    if ($SerialData[6][3] -band 0x04 -gt 0) {$MarstekData.AlarmStateHR += "Grid Overfrequency,"}
    if ($SerialData[6][3] -band 0x08 -gt 0) {$MarstekData.AlarmStateHR += "Grid Underfrequency,"}
    if ($SerialData[6][3] -band 0x10 -gt 0) {$MarstekData.AlarmStateHR += "Grid peak voltage abnormal,"}
    if ($SerialData[6][3] -band 0x20 -gt 0) {$MarstekData.AlarmStateHR += "Current Dcover,"}
    if ($SerialData[6][3] -band 0x40 -gt 0) {$MarstekData.AlarmStateHR += "Voltage Dcover,"}
    if ($SerialData[6][5] -band 0x01 -gt 0) {$MarstekData.AlarmStateHR += "Bat Overvoltage,"}
    if ($SerialData[6][5] -band 0x02 -gt 0) {$MarstekData.AlarmStateHR += "Bat Undervoltage,"}
    if ($SerialData[6][5] -band 0x04 -gt 0) {$MarstekData.AlarmStateHR += "Bat low SOC,"}
    if ($SerialData[6][5] -band 0x08 -gt 0) {$MarstekData.AlarmStateHR += "Bat communication failure,"}
    if ($SerialData[6][5] -band 0x10 -gt 0) {$MarstekData.AlarmStateHR += "BMS protect,"}
    # From here on Duravolt documentation states register 36103/36104, but they seem to be 36102/36103 ?
    if ($SerialData[6][7] -band 0x01 -gt 0) {$MarstekData.AlarmStateHR += "hardware Bus overvoltage,"}
    if ($SerialData[6][7] -band 0x02 -gt 0) {$MarstekData.AlarmStateHR += "hardware Output overcurrent,"}
    if ($SerialData[6][7] -band 0x04 -gt 0) {$MarstekData.AlarmStateHR += "hardware trand overcurrent,"}
    if ($SerialData[6][7] -band 0x08 -gt 0) {$MarstekData.AlarmStateHR += "hardware Battery overcurrent,"}
    if ($SerialData[6][7] -band 0x10 -gt 0) {$MarstekData.AlarmStateHR += "Hardware protection,"}
    if ($SerialData[6][7] -band 0x20 -gt 0) {$MarstekData.AlarmStateHR += "Output overcurrent,"}
    if ($SerialData[6][7] -band 0x40 -gt 0) {$MarstekData.AlarmStateHR += "High voltage bus overvoltage,"}
    if ($SerialData[6][7] -band 0x80 -gt 0) {$MarstekData.AlarmStateHR += "Hugh voltage bus ondervoltage,"}
    if ($SerialData[6][6] -band 0x01 -gt 0) {$MarstekData.AlarmStateHR += "Overpower protection,"}
    if ($SerialData[6][6] -band 0x02 -gt 0) {$MarstekData.AlarmStateHR += "FSM abnormal,"}
    if ($SerialData[6][6] -band 0x04 -gt 0) {$MarstekData.AlarmStateHR += "Overtemperature protection,"}
    if ($SerialData[6][6] -band 0x08 -gt 0) {$MarstekData.AlarmStateHR += "Inverter soft start timeout,"}
    if ($SerialData[6][9] -band 0x01 -gt 0) {$MarstekData.AlarmStateHR += "self-test fault,"}
    if ($SerialData[6][9] -band 0x02 -gt 0) {$MarstekData.AlarmStateHR += "eeprom fault,"}
    if ($SerialData[6][9] -band 0x04 -gt 0) {$MarstekData.AlarmStateHR += "other system fault,"}
}
# Check whether Marstek is in manual RS485 control. If not: Activate it.
if ($SerialData[100].Count -eq 7) {
    if ($SerialData[100][3] -ne 85 -or $SerialData[100][4] -ne 170) {
        [byte[]]$SerialCommand=(0x01,0x06,0xa4,0x10,0x55,0xAA) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
        $SerialData = Read-Serial -COM "COM4" -Speed 115200 -Timeout 2 -ResponseWait 50 -Commandos $SerialCommand
    }
}


$MarstekData | fl

$null = Read-Host "From here on it takes care about SETTING the charge / discharge. Enter to continue, or CTRL+C to stop"

$ACPowerFlag = $false
# Calculate carge / discharge power change. Case if charge: start at -11, and even then 10 less than possible to avoid paying for charge.
# Positive = Feed to grid, negative = charge
if (($totalpower -lt 0 -and $totalpower -ge -10 -and $MarstekData.ACPower -eq 0) -or
    ($MarstekData.ACPower -gt 0 -and -$totalpower-25 -gt $MarstekData.ACPower)) {
    $ACPower = 0
} else {
    if ($ACPower-$MarstekData.ACPower -lt 60 -or $MarstekData.ACPower-$ACPower -lt 60 -or $ACPower -eq 0) { # set value for smaller jumps
        $ACPower = [int](($totalpower+2)*0.96+10*($totalpower+2 -lt -15)+$MarstekData.ACPower) # +2 = dance discharge around -2 instead of zero. This seems to quiet down the reguilation and prevent overshoot too?
        #"$TimeStamp S3EM $($totalpower), PRE Marstek ($($MarstekData.BatterySOC)% charge), set from $($MarstekData.ACPower)W to Charge $($ACPower)W" | Tee-Object -FilePath $Logfile -Append
    } else {
        $ACPower = $MarstekData.ACPower-$totalpower*0.9 # Set value directly, for bigger jumps, but not directly to target since Marstek cannot change that fast.
    }
}
# Check charge limits / value too low / Boiler off before discharge
# Absolut max limit
if  ($ACPower -lt -1500 -or $MarstekData.ACPower -lt -1500) { $ACPower = -1500}
if  ($ACPower -gt  2000 -or $MarstekData.ACPower -gt  2000) { $ACPower =  2000}
# "Depending on" Limits
if  ($MarstekData.BatterySOC -gt 70 -and ($ACPower -lt  -999 -or $MarstekData.ACPower -lt  -999)) { $ACPower = -999}
if  ($MarstekData.BatterySOC -gt 80 -and ($ACPower -lt  -500 -or $MarstekData.ACPower -lt  -500)) { $ACPower = -500}
if  ($MarstekData.BatterySOC -gt 86 -and ($ACPower -lt  -350 -or $MarstekData.ACPower -lt  -350)) { $ACPower = -350}
if (($MarstekData.BatterySOC -gt 93 -and ($ACPower -lt     0 -or $MarstekData.ACPower -lt     0)) -or
    ($MarstekData.BatterySOC -lt 10 -and ($ACPower -gt     0 -or $MarstekData.ACPower -gt     0)) -or
    ($MarstekData.BatteryVoltage -lt 47.00 -and ($ACPower -gt 0 -or $MarstekData.ACPower -gt  0)) -or
    ([Math]::Abs($ACPower)   -lt  6 -and [Math]::Abs($MarstekData.ACPower) -lt 6) -or
    ($Power.BoilerWatt -gt 30 -and $MarstekData.ACPower -gt 0)){ $ACPower =     0}
# Stop
if ($ACPower -eq 0 -and $MarstekData.BatteryMode -ne 0) { # $MarstekData.ACPower -ne 0) {
    "$TimeStamp S3EM $($totalpower), Marstek ($($MarstekData.BatterySOC)% charge), set from $($MarstekData.ACPower)W to 0W" | Tee-Object -FilePath $Logfile -Append
    $SerialCommands=@{}
    # Set Mode stop
    [byte[]]$SerialCommand=(0x01,0x06,0xa4,0x1A,0,0) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
    $SerialCommands[0]=$SerialCommand
    # Set charge Watt
    [byte[]]$SerialCommand=(0x01,0x06,0xa4,0x24,0,0) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
    $SerialCommands[1]=$SerialCommand
    # Set discharge Watt
    [byte[]]$SerialCommand=(0x01,0x06,0xa4,0x25,0,0) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
    $SerialCommands[2]=$SerialCommand
    $SerialData = Read-Serial -COM "COM4" -Speed 115200 -Timeout 2 -ResponseWait 50 -Commandos $SerialCommands
}
# if read ACPower and Read BatteyCharge power are too far away skip this round, it needs a few more seconds to settle.
if ($MarstekData.ACPower-$BatteryCharge -lt 6) {
    # ignore too tiny changes. 6 to decrease discharge, 2 to increase discharge.
    if ($MarstekData.ACPower-$ACPower -gt 6 -or $ACPower-$MarstekData.ACPower -gt 2) {
        $ACPowerFlag = $true
        # Feed to grid
        if ($ACPower -gt 0 -and $Power.BoilerWatt -lt 30) {
            "$TimeStamp S3EM $($totalpower), Marstek ($($MarstekData.BatterySOC)% charge), set from $($MarstekData.ACPower)W to discharge $($ACPower)W" | Tee-Object -FilePath $Logfile -Append
            $ACPowerHigh = [Byte]([Math]::Floor([Math]::Abs($ACPower)/256))
            $ACPowerLow = [Byte]([math]::abs($ACPower)%256)
            $SerialCommands=@{}
            # Set discharge Watt
            [byte[]]$SerialCommand=(0x01,0x06,0xa4,0x25,$ACPowerHigh,$ACPowerLow) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
            $SerialCommands[1]=$SerialCommand
            if ($MarstekData.BatteryCharge -ne 0) {
                # Set charge Watt 0
                [byte[]]$SerialCommand=(0x01,0x06,0xa4,0x24,0x00,0x00) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
                $SerialCommands[0]=$SerialCommand
            }
            if ($MarstekData.BatteryMode -ne 2) {
                # Set Mode discharge
                [byte[]]$SerialCommand=(0x01,0x06,0xa4,0x1A,0x00,0x02) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
                $SerialCommands[2]=$SerialCommand
            }
            $SerialData = Read-Serial -COM "COM4" -Speed 115200 -Timeout 2 -ResponseWait 50 -Commandos $SerialCommands
        }
    }
    # ignore too tiny changes. 15 to increase charge, 3 to decrease charge.
    if ($MarstekData.ACPower-$ACPower -gt 6 -or $ACPower-$MarstekData.ACPower -gt 3) {
        $ACPowerFlag = $true
        # Charge battery
        if (($ACPower -lt -40  -and $MarstekData.BatterySOC -lt 93) -or ($ACPower -lt 0 -and $MarstekData.ACPower -lt 0)) { # if at 96% charge only more if carging already runs. This catches "got from 97% discharge to 96%" no, wait until 95% before charging again.
            "$TimeStamp S3EM $($totalpower), Marstek ($($MarstekData.BatterySOC)% charge), set from $($MarstekData.ACPower)W to charge $($ACPower)W" | Tee-Object -FilePath $Logfile -Append
            $ACPowerHigh = [Byte]([Math]::Floor([math]::abs($ACPower)/256))
            $ACPowerLow = [Byte]([math]::abs($ACPower)%256)
            $SerialCommands=@{}
            # Set charge Watt
            [byte[]]$SerialCommand=(0x01,0x06,0xa4,0x24,$ACPowerHigh,$ACPowerLow) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
            $SerialCommands[1]=$SerialCommand
            if ($MarstekData.BatteryDischarge -ne 0) {
                # Set discharge Watt 0
                [byte[]]$SerialCommand=(0x01,0x06,0xa4,0x25,0,0) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
                $SerialCommands[0]=$SerialCommand
            }
            if ($MarstekData.BatteryMode -ne 1) {
                # Set Mode charge
                [byte[]]$SerialCommand=(0x01,0x06,0xa4,0x1A,0x00,0x01) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
                $SerialCommands[2]=$SerialCommand
            }
            $SerialData = Read-Serial -COM "COM4" -Speed 115200 -Timeout 2 -ResponseWait 50 -Commandos $SerialCommands
        }
    }
}

# reboot the Marstek - commented out ;D.
[byte[]]$SerialCommand=(0x01,0x06,0xa0,0x28,0x55,0xAA) ; $SerialCommand+=Get-CRC16Modbus -InputObject $SerialCommand
#$SerialData = Read-Serial -COM "COM4" -Speed 115200 -Timeout 2 -ResponseWait 50 -Command $SerialCommand
#[System.BitConverter]::ToString($SerialData)
