<#
    This is for testing deduplication-corruption of Server 2022 and Server 2025 (pre-release), update state October 2024.
    Creates files with simple content, starts deduplication, modifies the files in place, and checks whether the checksum is still the expected.
    Can be run from within Posershell ISE.
    Joachim Otahal, Oct 2024, jou@gmx.net (MS Account: Setsunaaa@hotmail.com)
#>


# Where are we?
$ScriptPath = $MyInvocation.MyCommand.Path
# If within PowershellISE...
if ($ScriptPath -eq $null) { $ScriptPath = $psISE.CurrentFile.FullPath }
if ($ScriptPath -ne $null) {
    $ScriptLocation = $ScriptPath.Split("\")[0..($ScriptPath.Split("\").Count -2)] -join "\"
    $ScriptName = $ScriptPath.Split("\")[-1]
}


$TestFile = $ScriptLocation+"\Dedup-testfile.bin"

# 64 MB data 0x01
$One = [Byte[]] (0x01)*[Math]::Pow(2,26)
# 64 MB data 0x02
$Two = [Byte[]] (0x02)*[Math]::Pow(2,26)
# 64 MB of data 0x00-0xff
$ZeroToFF  = [Byte[]] (0..255)*4*1024*64

########## Functions

function BinaryWriter {
    param (
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][ValidateSet("Create","Modify","Append")][string]$Mode,
        [int64]$Offset=0,
        [Byte[]]$ByteStream = $null,
        [Switch]$WhatIf=$false
    )
    if ($ByteStream) {
        # Verbose
        # Write-Host "$Path, $Mode, $Offset, first five bytes $($ByteStream[0..4] -join "-") $($ByteStream.Count)"
        if ($Mode -eq "Create") {
            $FileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
        } else {
            $FileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open)
        }
        $BinaryWriter = [System.IO.BinaryWriter]::new($FileStream)
        if ($Mode -eq "Append") {
            $Offset = $FileStream.Length
        }
        if ($Mode -eq "Modify" -or $Mode -eq "Append") {
            # Fresh opened, seek 0 not needed
            # $null = $BinaryWriter.Seek(0,0)
            While ($Offset -gt 0) {
                if ($Offset -gt [Math]::Pow(2,30)) {
                    $null = $BinaryWriter.Seek([Math]::Pow(2,30),1)
                    $Offset -= [int64]([Math]::Pow(2,30))
                } else {
                    $null = $BinaryWriter.Seek([int32]$Offset,1)
                    $Offset = 0
                }
            }
        }
        $BinaryWriter.Write($ByteStream)
        $BinaryWriter.Flush()
        $BinaryWriter.Dispose()
        $FileStream.Dispose()
    }
}

########## Script start

do {
    clear
    Write-Host "At which step are we?"
    Write-Host "1: Create the test file ($TestFile)."
    Write-Host "2: Modify test ($TestFile) file AFTER deduplication on L1 host did run."
    Write-Host "3: Check CRC of test file ($TestFile)"
    $ReadHost = Read-Host "Enter nothing to do nothing and exit..."
    
    
    # Create testfile
    switch ($ReadHost) {
        1 {
            Write-Host "Creating 4 GB $TestFile with 0x00-0xFF as content"
            BinaryWriter -Path $TestFile -Mode Create -ByteStream $ZeroToFF
            for ($i=1;$i -lt 64;$i++) {
                BinaryWriter -Path $TestFile -Mode Append -ByteStream $ZeroToFF
            }
        }
        2 {
            Write-Host  "Modify $TestFile in-place"
            for ($i=0;$i -lt 16;$i++) {
                BinaryWriter -Path "$TestFile" -Mode Modify -Offset $([int32][Math]::Pow(2,24)+64MB*$i) -ByteStream $One
                BinaryWriter -Path "$TestFile" -Mode Modify -Offset $([int32][Math]::Pow(2,26)+64MB*$i) -ByteStream $Two
            }
        }
        3 {
            $Hash = (Get-FileHash -Path $TestFile -Algorithm MD5).Hash
            if ($Hash -eq "65BDC1B439180EC5058E2079739751A5") {
                Write-Host -BackgroundColor DarkGreen -ForegroundColor White "$TestFile Hash is expected $Hash"
            } else {
                Write-Host -ForegroundColor Yellow -BackgroundColor DarkRed  "$TestFile Hash error: $Hash. Expected: 65BDC1B439180EC5058E2079739751A5"
            }
            $null = Read-Host "Pause, press enter to continue"
        }
    }
} until (!$ReadHost)
