# Gets all properties recursively. Useful if you need a list of all sub-proerties.
# V 0.1 Joachim Otahal, May 2024
# V 0.2 adding simple requesion detection and -MaxDepth, default 10, to limit more complex recursion.

# We create an example object, including some unusual property names.
$Car = [PSCustomObject] @{
    Tire          = [PSCustomObject] @{
        Color = "Black"
        Count = 4
    }

    SteeringWheel = [PSCustomObject]@{
        Color   = "Blue"
        Buttons = 15
    }
    'Special Decal' = [PSCustomObject]@{
        'Decal:1' = [bool]$true
    }
    'Windows-Electrical'= [PSCustomObject]@{
        Ordered_Feature = [bool]$true
    }
}


# Helper function to list all properties
function Get-PropertiesRecursive {
    param (
        [Parameter(ValueFromPipeline)][object]$InputObject,
        [String]$ParentName,
        [int]$MaxDepth = 10
    )
    if ($ParentName) {$ParentNameDot ="$ParentName."} else {$ParentNameDot = ""}
    foreach ($Property in $InputObject.psobject.Properties) {
        # This puts special characters in '' like you need it when using it directly with powershell
        if ($Property.Name -like "*:*" -or $Property.Name -like "* *"  -or $Property.Name -like "*-*") {
            $Name = "'$($Property.Name)'"
        } else {
            $Name = $Property.Name
        }
        $PropertyTypeName = $Property.TypeNameOfValue.Split('.')[-1]
        if (($PropertyTypeName -ne "PSCustomObject" -and $PropertyTypeName -notlike "Object*") -or
            # Catch simple recursion
            $ParentName.Split('.')[-1] -eq $Name -or $MaxDepth -le 0) {
            [pscustomobject]@{
                TypeName = $PropertyTypeName
                Property = "$ParentNameDot$Name"
                Value = $Property.Value
            }
        } else {
            Get-PropertiesRecursive $Property.Value -ParentName "$ParentNameDot$Name" -MaxDepth $($MaxDepth-1)
        }
    }
}

# Example. If we add -ParendName this way, the output will include the base object name, else it is excluded.

Get-PropertiesRecursive $Car -ParentName '$Car'
