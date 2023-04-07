# DFS-N-Tools
Powershell Tools to handle DFS-N

# Enable-DFS-ABE.ps1

This will enable Access Based Enumeration (ABE) on a DFS root, scan alle DFS-links within that root, transfer the existing NTFS permissions to the DFS-link and avtivate "Set explicit view permissions on the DFS folder". By default it will exclude these special accounts when transfering NTFS ACL : "Local Admin", "SYSTEM", "EVERYBODY" and "CREATOR/OWNER". A log file will be placed on your Desktop.

### More detailed:

According to the Microsoft article at https://docs.microsoft.com/en-us/troubleshoot/windows-client/system-management-components/grant-dfsnaccess-not-change-inheritance this is not possible.

![Enable-DFS-ABE-01](https://user-images.githubusercontent.com/10100281/189478943-9d10f80f-1a19-4990-ba59-cbd897edc688.png)

But I needed it for over 100 DFS-N roots and several thousand DFS-Links in a larger multiforest environment, 'cause there is NO WAY I'd be doing this by hand. And I needed to exclude the above mentioned "Well known SID" accounts since tranfering them does not make sense.
It requires the ActiveDirectory and DFSN Module. It has only been tested with Powershell 5.1 on Server 2012 R2 / Server 2016 / Server 2019 and Server 2022. It might work with Powershell 5.1 on Server 2008 R2, but it has not been tested.

Options:

  -DFSNroot "your DFS root"

  -Domaincontroller "FQDN of your domaincontroller"

  -AlwaysUpdateDFSACL:$True or $False. Default is $true, adding and replacing permissions, but not removing any DFS permission.

  -ExcludeSpecialAccounts:$True or $false. Default is $true.


Default usage:

.\Enable-DFS-ABE.ps1 "\\your.domain\yourdfsroot"

Example:
![Enable-DFS-ABE-02](https://user-images.githubusercontent.com/10100281/189477637-3d4394ff-b2df-44e6-a0fc-2098e5dcb6bf.png)

Result: All reasonable NTFS allow/deny ACL are transferred (you may have to hit F5 for refresh in the UI).
![image](https://user-images.githubusercontent.com/10100281/189477379-9a1a41e2-09b3-4ad0-983e-ca2d3956fe37.png)

More complex example which includes the special accounts:
![Enable-DFS-ABE-04](https://user-images.githubusercontent.com/10100281/189477792-41de7180-2a17-4282-8a3c-01c76f603afd.png)

Result: All NTFS allow/deny ACL are transferred, including those which don't make sense (you may have to hit F5 for refresh in the UI).
![Enable-DFS-ABE-05](https://user-images.githubusercontent.com/10100281/189477868-f129fd0c-e149-471a-9623-3d6298644079.png)
