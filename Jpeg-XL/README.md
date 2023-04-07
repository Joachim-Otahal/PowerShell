## Jpeg-XL / cjxl.exe mass converter
These script are published upon the request here: https://github.com/libjxl/libjxl/issues/683
There are two powershell scripts, wrapped in .cmd. You drag and drop a directory or several directories on the .CMD, and it will start the conversion. It can handle UNICODE filenames, whereas the original cjxl.exe cannot handle them.
You need to edit line 36, $cjxl="C:\prog\jpeg-xl\cjxl.exe", to point to your cjxl.exe executable.
It always uses "lossless" setting with Effort 8, unless the input picutre is above 50 MB. Currently it only accepts JPEG and PNG. Adding .GIF is easy, but since cjxl still has to fight "compress better than .gif" problems they are currently skipped.
If the conversion failes due to an error or when the .JXL file is larger than the original the original will be kept.
# convert-to jxl recursive unicode-capable.ps1.cmd
This is the more verbose version, but single threaded.
# convert-to jxl recursive unicode-capable.multithread.ps1.cmd
This is the multithread version. Edit line 45 to select how many threads it should run at max.
