# Gets all properties recursively. Useful if you need a list of all sub-proerties.
# V 0.1 Joachim Otahal, May 2024

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

function Get-PropertiesRecursive {
    param (
        [Parameter(ValueFromPipeline)][object]$InputObject,
        [String]$ParentName
    )
    if ($ParentName) {$ParentName +="."}
    foreach ($Property in $InputObject.psobject.Properties) {
        # This puts special characters in '' like you need it when using
        if ($Property.Name -like "*:*" -or $Property.Name -like "* *"  -or $Property.Name -like "*-*") {
            $Name = "'$($Property.Name)'"
        } else {
            $Name = $Property.Name
        }
        if ($Property.TypeNameOfValue.Split(".")[-1] -ne "PSCustomObject") {
            [pscustomobject]@{
                TypeName = $Property.TypeNameOfValue.Split(".")[-1]
                Property = "$ParentName$Name"
                Value = $Property.Value
            }
        } else {
            Get-PropertiesRecursive $Property.Value -ParentName "$ParentName$Name"
        }
    }
}

# Example. If we add -ParendName this way, the output will include the base object name, else it is excluded.

Get-PropertiesRecursive $Car -ParentName '$Car'
