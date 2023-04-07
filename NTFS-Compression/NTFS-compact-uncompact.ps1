# Credits for the C# snippet go to https://stackoverflow.com/questions/31032834/set-file-compression-attribute
# Extended to include decompacting
$MethodDefinition= @'
public static class FileTools
{
  private const int FSCTL_SET_COMPRESSION = 0x9C040;
  private const short COMPRESSION_FORMAT_DEFAULT = 1;
  private const short COMPRESSION_FORMAT_DISABLE = 0;
  [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
  private static extern int DeviceIoControl(
      IntPtr hDevice,
      int dwIoControlCode,
      ref short lpInBuffer,
      int nInBufferSize,
      IntPtr lpOutBuffer,
      int nOutBufferSize,
      ref int lpBytesReturned,
      IntPtr lpOverlapped);
  public static bool Compact(IntPtr handle)
  {
    int lpBytesReturned = 0;
    short lpInBuffer = COMPRESSION_FORMAT_DEFAULT;
    return DeviceIoControl(handle, FSCTL_SET_COMPRESSION,
        ref lpInBuffer, sizeof(short), IntPtr.Zero, 0,
        ref lpBytesReturned, IntPtr.Zero) != 0;
  }
  public static bool Uncompact(IntPtr handle)
  {
    int lpBytesReturned = 0;
    short lpInBuffer = COMPRESSION_FORMAT_DISABLE;
    return DeviceIoControl(handle, FSCTL_SET_COMPRESSION,
        ref lpInBuffer, sizeof(short), IntPtr.Zero, 0,
        ref lpBytesReturned, IntPtr.Zero) != 0;
  }
}
'@

$Kernel32 = Add-Type -MemberDefinition $MethodDefinition -Name ‘Kernel32’ -Namespace ‘Win32’ -PassThru

$logfilespec = "c:\Logfolder\*.log"

# compact anything older than three days
foreach ($File in (Get-ChildItem -Path $logfilespec -Recurse -File).Where({$_.LastWriteTime -lt (Get-Date).AddDays(-3) -and $_.Attributes  -notmatch [System.IO.FileAttributes]::Compressed})) {
    $FileObject = [System.IO.File]::Open($File.FullName,'Open','ReadWrite','None')
    $Method = [Win32.Kernel32+FileTools]::Compact($FileObject.Handle)
    $FileObject.Close()
}

# decompact
foreach ($File in (Get-ChildItem -Path $logfilespec -Recurse -File).Where({$_.Attributes  -match [System.IO.FileAttributes]::Compressed})) {
    $FileObject = [System.IO.File]::Open($File.FullName,'Open','ReadWrite','None')
    $Method = [Win32.Kernel32+FileTools]::Uncompact($FileObject.Handle)
    $FileObject.Close()
}
