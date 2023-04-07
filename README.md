# PowerShell
My powershell stuff

## Jpeg-XL
Tools for mass converting JPEG/PNG (GIF commented out) to .JXL, but only keep the .JXL if the result is smaller and there were not errors.

## DFS-N-Tools
Enable DFS-N Access based Enumeration, transfer the NTFS ACl settings if possible, and tick the "Set explicit view permissions on the DFS folder" which Microsoft Documentation says: "Not possible using Powershell". I needed it for a mass job, and dfsutil.exe failed in that environment due to complex active directory forest structure.
