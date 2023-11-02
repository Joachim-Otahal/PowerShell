# PowerShell
My miscancellous powershell stuff

## Jpeg-XL
Tools for mass converting JPEG/PNG (GIF commented out) to .JXL, but only keep the .JXL if the result is smaller and conversion went without errors.

## DFS-N-Tools
Enable DFS-N-ABE, Access Based Enumeration, transfer the NTFS ACL settings if possible, and tick the "Set explicit view permissions on the DFS folder" which Microsoft Documentation says: "Not possible using Powershell". I needed it for a mass job, and dfsutil.exe failed in that environment due to complex active directory forest structure. So not much of a choice than to do it using Powershell.

## NTFS-Compression
Use NTFS compression as pure powershell method, without calling compact.exe. Side effect: Can handle unicode and long paths.

## NTLMv1 SMB1 detailled logging..ps1
This activates detailled SMB1 and NTLM auditing/logging AND analyzes the eventlogs with appriopriate methods to get what needed.
On subsequent runs it only analyzes the event logs when auditing/logging.
Reports saved as .CSV on Desktop.
If you are from Germany which uses ";" as default delimiter for CSV in Excel instead of "," check the last line of the script and remote the #.
