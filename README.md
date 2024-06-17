# PowerShell
My miscancellous powershell stuff

## Jpeg-XL
Tools for mass converting JPEG/PNG (GIF commented out) to .JXL, but only keep the .JXL if the result is smaller and conversion went without errors.

## DFS-N-Tools
Enable DFS-N-ABE, Access Based Enumeration, transfer the NTFS ACL settings if possible, and tick the "Set explicit view permissions on the DFS folder" which Microsoft Documentation says: "Not possible using Powershell". I needed it for a mass job, and dfsutil.exe failed in that environment due to complex active directory forest structure. So not much of a choice than to do it using Powershell.

## Growatt COM3.ps1 ##
Actually WORKING example how to send and read from the serial power with Powershell. Let alone sending and revieving BINARY data. In this case reading the current power from a Growatt 600 MIC using an RS485-to-USB adapter. Does anyone have the REAL documentation of Growatt Mic RS485 commands? I only found RS485 documentation for the big Growatt devices.

Rant: A lot of serial port examples on the internet are half, and Register-ObjectEvent works in PSIE and manually in shell, but NOT when used in script (most weird powershell bug so far). It is like those people never actually tried to implement it.

## NTFS-Compression
Use NTFS compression as pure powershell method, without calling compact.exe. Side effect: Can handle unicode and long paths.

## NTLMv1 SMB1 detailed audit and logging.ps1
This activates detailled SMB1 and NTLM auditing/logging AND analyzes the eventlogs with appriopriate methods to get what needed. Requires at least Server 2012 with Powershell 5.1 and current updates.
On subsequent runs it only analyzes the event logs when auditing/logging. Reports saved as .CSV on Desktop. Default delimiter is ";" for Germany, edit the script if you need it different.
#### NTLMv1 SMB1 detailed audit and logging Scheduled Task.xml
Task scheduler -> import. For a daily report, expecially on busy domain controllers where the security log does not span several weeks.

## Test-Ping-ps1 ##
This is a ping in pure powershell. I needed something "faster than Test-Netconnection". It sends, by default, four pings withing 800 ms, really only pings, and then gives up. You can change the TTL, Timeout and Retry settings with -TTL -TimeOut and -Retry.

## WakeOnLAN.ps1
Actually working (tested with PS 5.1 on Server 2022 and Windows 11) example for Wake On LAN in pure powershell. Skips unconfigured adapters and does a correct broadcast address calculation in contrast to many other examples I found on the net + works on IPv6 as well.

## Get-PropertiesRecursive.ps1
It will show all properties of an object, with all sub-properties. Output looks like this for the example:

![image](https://github.com/Joachim-Otahal/PowerShell/assets/10100281/5af65eca-224f-48f3-9788-db54277a57b7)

