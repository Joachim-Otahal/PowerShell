# PowerShell
My powershell stuff

## Jpeg-XL
Tools for mass converting JPEG/PNG (GIF commented out) to .JXL, but only keep the .JXL if the result is smaller and conversion went without errors.

## DFS-N-Tools
Enable DFS-N-ABE, Access Based Enumeration, transfer the NTFS ACL settings if possible, and tick the "Set explicit view permissions on the DFS folder" which Microsoft Documentation says: "Not possible using Powershell". I needed it for a mass job, and dfsutil.exe failed in that environment due to complex active directory forest structure. So not much of a choice than to do it using Powershell.

## NTFS-Compression
Use NTFS compression as pure powershell method, without calling compact.exe
