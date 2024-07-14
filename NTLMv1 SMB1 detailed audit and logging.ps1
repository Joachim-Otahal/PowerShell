# Version 0.0 : Some time Oct 2023.
# Version 0.1 : ToDo get the MICROSOFT_AUTHENTICATION_PACKAGE_V1_0 event too, example at
#               https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/event-4776
# Version 0.2 : Faster queries + how many hours should we go back.
# Version 0.3 : Added "End Date Auditing" if the task is planned daily.
########## Enable Audit if not activated yet

# End Day:
# Scenario: Script run daily as planned task.
# If script is run on that day or after: Disable Auditing.
$EndDay = Get-Date "2024-08-28"

#$LogDirectory="$Env:USERPROFILE\Desktop"
$LogDirectory="C:\scripts\SMB1-NTLMv1-logging"

$null = New-Item -Path $LogDirectory -ItemType Directory -ErrorAction Ignore

# How far back in time... Here 90 days.

$OldestEvent = (Get-Date).AddDays(-2)
$OldestEventUTC = ($OldestEvent.ToUniversalTime()).ToString("s")

# Create Date-string for Filename
$DateRange = "from $($OldestEvent.ToString('yyyy-MM-dd')) to $(Get-Date -Format "yyyy-MM-dd")"

if ($EndDay -ge $(Get-Date)) {
    
    # Enable SMB1 Audit
    if (!(Get-SmbServerConfiguration).AuditSmb1Access) {
        Set-SmbServerConfiguration -AuditSmb1Access $true -confirm:$false -Verbose
        Write-Host "SMB1 auditing Set-SmbServerConfiguration activated."
    }
    # Enable SMB1 Audit directly via Registry (should noe execute on modern servers):
    if (!(Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\" -Name AuditSmb1Access).AuditSmb1Access -eq 1) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\" -Name AuditSmb1Access -Value 1 -Type DWORD -Verbose
        Write-Host "SMB1 auditing via registry activated. Reboot may be required."
    }
    # Enable NTLM Audit directly via Registry:
    if (!(Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0\" -Name AuditReceivingNTLMTraffic).AuditReceivingNTLMTraffic -eq 1) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0\" -Name AuditReceivingNTLMTraffic -Value 1 -Type DWORD -Verbose
        Write-Host "NTLM auditing via registry activated. Reboot may be required."
    }
    
    # Check size of Security Eventlog
    $SecurityLogMaxSize = (Get-EventLog -List).Where({$_.log -eq "Security"})[0].MaximumKilobytes
    $InstalledRAM = [int64]((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum / 1024)
    if ($SecurityLogMaxSize -lt 256000) {
        Write-Verbose "Warning! Securitylog less than 256 MB. Increasing MaxSize to 256 MB or at least one fourth of installed RAM recommended." -Verbose
    }
    if ($SecurityLogMaxSize -gt ($InstalledRAM)) {
        Write-Verbose "Warning! Securitylog larger than installed RAM, queries may take a long time." -Verbose
    }
    
    ########## SMB
    Write-Verbose "Getting SMB Events" -Verbose
    $EventsSMB = @(Get-WinEvent -LogName "Microsoft-Windows-SMBServer/Audit" |
        Select-Object SystemData,EventData,XMLData,@{Name="XMLRaw";Expression={$_.ToXml() }},*)
    for ($i=0;$i -lt $EventsSMB.Count;$i++) {
        $EventsSMB[$i].TimeCreated = $EventsSMB[$i].TimeCreated.ToString("yyyy-MM-dd HH:mm:ss.fff")
        $EventsSMB[$i].XMLData = [xml]$EventsSMB[$i].XMLRaw
        $EventsSMB[$i].EventData = $EventsSMB[$i].XMLData.Event.EventData.Data
        $EventsSMB[$i].SystemData = $EventsSMB[$i].XMLData.Event.System
    }
    Write-Verbose "Export SMB Event as $LogDirectory\SMB-Events $Env:COMPUTERNAME $DateRange.csv" -Verbose
    $EventsSMB | Select-Object LogName,TimeCreated,MachineName,Id, LevelDisplayName,
        @{Name="ClientName";Expression={$_.EventData.'#text'}},
        Message,
        @{Name="SystemData";Expression={($_.SystemData | Out-String).Trim()}},
        @{Name="EventData";Expression={($_.EventData | Out-String).Trim()}} |
    #    Sort-Object ClientName -Unique | Sort-Object TimeCreated |
        Export-Csv "$LogDirectory\SMB-Events $Env:COMPUTERNAME $DateRange.csv" -Encoding UTF8 -NoTypeInformation -Delimiter ";"
    
    
    ########## NTLM
    Write-Verbose "Getting NTLM Events - MAY TAKE MUCH TIME!" -Verbose
    
    # This one gets ONLY NTLMv1, for servers where security log size is too big.
    #$EventsNTLM = @(Get-WinEvent -Logname "Security" -FilterXPath "Event[System[(EventID=4624)]]and Event[EventData[Data[@Name='LmPackageName']='NTLM V1']]" | 
    $EventsNTLM = @(Get-WinEvent -LogName "Security" -FilterXPath "Event[System[TimeCreated[@SystemTime>'$OldestEventUTC']][Provider[@Name='Microsoft-Windows-Security-Auditing']][EventID=4624]][EventData[Data[@Name='LmPackageName']='NTLM V1']]" |
        Select-Object SystemData,EventData,XMLData,@{Name="XMLRaw";Expression={$_.ToXml() }},*)
    
    # This one gets ALL NTLM
    #$EventsNTLM = @(Get-WinEvent -LogName "Security" -FilterXPath "Event[System[TimeCreated[@SystemTime>'$OldestEventUTC']][Provider[@Name='Microsoft-Windows-Security-Auditing']][EventID=4624]][EventData[Data[@Name='AuthenticationPackageName']='NTLM']]" |
    #    Select-Object SystemData,EventData,XMLData,@{Name="XMLRaw";Expression={$_.ToXml() }},*)
    
    # Evaluate result
    #Write-Verbose "Export as XML for later reevaluation to $LogDirectory\NTLM-Events $Env:COMPUTERNAME $DateRange.xml" -Verbose
    # Save as "raw data" to reimport and reevaluate for more details later.
    #$EventsNTLM | Export-Clixml "$LogDirectory\NTLM-Events $Env:COMPUTERNAME $DateRange.xml"
    # Import saved "raw data" for re-evaluation
    #$EventsNTLM = Import-Clixml -Path "C:\Users\J.Otahal\Desktop\NTLM-Events DEV-DC-02 2023-09-29.xml"
    $StartDate = Get-Date
    # Analyze Eventdata
    for ($i=0;$i -lt $EventsNTLM.Count;$i++) {
        $EventsNTLM[$i].TimeCreated = $EventsNTLM[$i].TimeCreated.ToString("yyyy-MM-dd HH:mm:ss.fff")
        $EventsNTLM[$i].XMLData = [xml]$EventsNTLM[$i].XMLRaw
        $EventsNTLM[$i].EventData = $EventsNTLM[$i].XMLData.Event.EventData.Data
        $EventsNTLM[$i].SystemData = $EventsNTLM[$i].XMLData.Event.System
        if (($i%1000) -eq 0) {
            if ( ((Get-Date)-$StartDate).TotalSeconds -gt 15) {
                $StartDate = Get-Date
                Write-Verbose "Event-XML-Interpretation for NTLM $($i+1) of $($EventsNTLM.Count)" -Verbose
            }
        }
    }
    Write-Verbose "Export as CSV to $LogDirectory\NTLM-Events $Env:COMPUTERNAME $DateRange.csv" -Verbose
    
    $EventsNTLM | Select-Object LogName,TimeCreated,MachineName,Id, LevelDisplayName,
         @{Name="NTLM";Expression={$_.EventData.Where({$_.Name -eq "LmPackageName"})[0].'#text'}},
         @{Name="WorkstationName";Expression={$_.EventData.Where({$_.Name -eq "WorkstationName"})[0].'#text'}},
         @{Name="IpAddress";Expression={$_.EventData.Where({$_.Name -eq "IpAddress"})[0].'#text'}},
         # Wenn frisch aus der AD:
         Message,
         @{Name="SystemData";Expression={($_.SystemData | Out-String).Trim()}},
         @{Name="EventData";Expression={($_.EventData | Out-String).Trim()}} |
    # Uncomment one of those if you want every IP or workstation to only appear once in the log.
    #    Sort-Object WorkstationName -Unique | 
    #    Sort-Object IpAddress -Unique | 
        Export-Csv "$LogDirectory\NTLM-Events $Env:COMPUTERNAME $DateRange.csv" -Encoding UTF8 -NoTypeInformation -Delimiter ";"
} else {
    # We are beyond the wanted log time, disable NTLM logging
    # Disable SMB1 Audit
    if ((Get-SmbServerConfiguration).AuditSmb1Access) {
        Set-SmbServerConfiguration -AuditSmb1Access $true -Confirm:$false -Verbose
        Write-Host "Disable SMB1 auditing Set-SmbServerConfiguration."
    }
    # Disable SMB1 Audit directly via Registry (should noe execute on modern servers):
    if ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\" -Name AuditSmb1Access).AuditSmb1Access -eq 1) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\" -Name AuditSmb1Access -Value 0 -Type DWORD -Verbose
        Write-Host "Disable SMB1 auditing via registry. Reboot may be required."
    }
    # Disable NTLM Audit directly via Registry:
    if ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0\" -Name AuditReceivingNTLMTraffic).AuditReceivingNTLMTraffic -eq 1) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0\" -Name AuditReceivingNTLMTraffic -Value 0 -Type DWORD -Verbose
        Write-Host "Disable NTLM auditing via registry. Reboot may be required."
    }
}
