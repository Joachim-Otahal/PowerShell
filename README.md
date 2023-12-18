# PowerShell
My miscancellous powershell stuff

## Jpeg-XL
Tools for mass converting JPEG/PNG (GIF commented out) to .JXL, but only keep the .JXL if the result is smaller and conversion went without errors.

## DFS-N-Tools
Enable DFS-N-ABE, Access Based Enumeration, transfer the NTFS ACL settings if possible, and tick the "Set explicit view permissions on the DFS folder" which Microsoft Documentation says: "Not possible using Powershell". I needed it for a mass job, and dfsutil.exe failed in that environment due to complex active directory forest structure. So not much of a choice than to do it using Powershell.

## NTFS-Compression
Use NTFS compression as pure powershell method, without calling compact.exe. Side effect: Can handle unicode and long paths.

## NTLMv1 SMB1 detailed audit and logging.ps1
This activates detailled SMB1 and NTLM auditing/logging AND analyzes the eventlogs with appriopriate methods to get what needed. Requires at least Server 2012 with Powershell 5.1 and current updates.
On subsequent runs it only analyzes the event logs when auditing/logging. Reports saved as .CSV on Desktop. Default delimiter is ";" for Germany, edit the script if you need it different.
#### NTLMv1 SMB1 detailed audit and logging Scheduled Task.xml
Task scheduler -> import. For a daily report, expecially on busy domain controllers where the security log does not span several weeks.

## WakeOnLAN.ps1
Actually working (in Server 2022 and Windows 11) example for Wake On LAN in pure powershell. Skips unconfigured adapters and does a correct broadcast address calculation in contrast to many other examples I foun don the net.
