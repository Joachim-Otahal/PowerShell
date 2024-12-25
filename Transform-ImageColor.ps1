function Transform-ImageColor {
    <#
    December 2024, Joachim Otahal, https://github.com/Joachim-Otahal
    
    This is a simple implementation to:
    Simple and fast invert an image or picture in Powershell (default)
    Simple and fast transpose, i.e. brighten or darken an image in Powershell
    Simple and fast gamma correct a picture in Powershell
    
    Why posting it?
    The "powershell invert image" and too many "DOTNET invert image" I found use the "do it pixel by pixel" method.
    This is extremly slow, way too slow. So I digged, found the right DOTNET methods, and translated them to use in Powershell.
    My usage: Invert a graph of data drawn in powershell which has color on white background, make it darker, apply a bit gamma so the darkest part get more visible.
    After the picture is saved set it a windows background.
    I.e. -Transform -0.2 -Translate 0.2 -Gamma 0.6

    If the source image is a [string] it will open the file. If it is an [System.Drawing.Bitmap] object, which iy my scenario, it will use that.
    If no destination file [string] is given it will return the inverted [System.Drawing.Bitmap].
    
    This was tested with Powershell 5.1 and the DOTNET supplied with Server 2019 / Windows 10 and higher.
    
    DOTNET Methods used (incomplete list, but you can easily find more manipulation  methods there):
    https://learn.microsoft.com/en-us/dotnet/api/system.drawing.imaging.imageattributes
    https://learn.microsoft.com/en-us/dotnet/api/system.drawing.imaging.colormatrix
    https://learn.microsoft.com/en-us/dotnet/api/system.drawing.imaging.imageattributes.setgamma
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)][ValidateNotNullOrEmpty()][object]$SourceImage,
        [Parameter(Position=1)][string]$DestinationImage,
        [Parameter(Position=2)][float]$Transform = -1, # Invert / Negate
        [Parameter(Position=3)][float]$Translate = 1, # After Negate shift to positive values to have Invert
        [Parameter(Position=4)][float]$Gamma # Apply gamma
    )
    
    # If Source is a string assume a file, else expect [System.Drawing.Bitmap]
    $bmp = $false
    if ($SourceImage.psobject.TypeNames[0] -eq "System.String") { $bmp = [System.Drawing.Bitmap]::FromFile($SourceImage) }
    if ($SourceImage.psobject.TypeNames[0] -eq "System.Drawing.Bitmap") { $bmp = $SourceImage }
    if ($bmp) {

        $ImageAttributes = [System.Drawing.Imaging.ImageAttributes]::new()
        $ColorMatrix = [System.Drawing.Imaging.ColorMatrix]::new( [float[][]] @(
                [float[]]($Transform, 0, 0, 0, 0), # Transform R
                [float[]](0, $Transform, 0, 0, 0), # Transform G
                [float[]](0, 0, $Transform, 0, 0), # Transform B
                [float[]](0, 0, 0, 1, 0),  # Alpha: Do nothing
                [float[]]($Translate, $Translate, $Translate, 0, 1)   # Translate/Offset RGBA
            )
        )
        $ImageAttributes.SetColorMatrix($ColorMatrix)
        if ($Gamma -ne $null) { $ImageAttributes.SetGamma(0.6) }
    
        $bmpinv = [System.Drawing.Bitmap]::new($bmp.Width,$bmp.Height,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $pictinv = [System.Drawing.Graphics]::FromImage($bmpinv)
        $pictinv.DrawImage($bmp,                                         # Source image
            [System.Drawing.Rectangle]::new(0,0,$bmp.Width,$bmp.Height), # Destination rectangle, here same as source
            0,0,$bmp.Width,$bmp.Height,                                  # Source rectangle. If we use "0,0" we end up with a frame on top and left? No,l this is correct, the source is already tainted...
            [System.Drawing.GraphicsUnit]::Pixel,                        # We want 1:1 not inch or whatever
            $ImageAttributes                                             # Finally the matrix, gamma etc
        )
        if ($DestinationImage.Length -ge 1) {
            $bmpinv.Save($DestinationImage,[System.Drawing.Imaging.ImageFormat]::Png)
        } else {
            return $bmpinv
        }
        $pictinv.Dispose()
        $bmpinv.Dispose()
    } else {
        Write-Error "SourceImage is neither a file or a [System.Drawing.Bitmap]"
    }
}