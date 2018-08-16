<#
.Synopsis
Builds dependency graph and installs all packages and its dependencies to the local feed, if $install flag is set to $true
#>
Param(    
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $sitecoreVersion,
    [parameter(Mandatory=$false, HelpMessage="Version")][ValidateNotNull()]$Install = $false
)

# check if packagesource exists
#Register-PackageSource -Name "sitecore-myget" -Location "https://sitecore.myget.org/F/sc-packages/api/" -ProviderName "nuget"
#Register-PackageSource -Name "nuget2" -Location "http://www.nuget.org/api/v2/" -ProviderName "nuget"

<#
.Synopsis
Creates dependency in form of "parent-package-name version" -> "child-package-name version"
#>
function Create-Dependency
{
    Param(
        [parameter(Mandatory=$true)][ValidateNotNull()]$Package,
        [parameter(Mandatory=$true)][ValidateNotNull()]$DependencyName,
        [parameter(Mandatory=$true)][ValidateNotNull()]$DependencyVersion
    )

    $dependency = "`"$($Package.Name) $($Package.Version)`" -> `"$($DependencyName) $($DependencyVersion)`""
    return $dependency
}

function Check-If-Installed
{
Param(
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Name,
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Version    
    )
    $pkg = $null
    $pkg = Get-package -Name $Name -RequiredVersion $Version -ErrorAction SilentlyContinue    
    return $pkg
}

function Write-Dependencies {
    Param(
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()] $Package,
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()] $install,
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()] $list
    )
    Write-Host "Dependencies of $($Package.Name) - $($Package.Dependencies.Count)"

    $nameversion = $null;
    foreach($dependency in $Package.Dependencies)
    {        
        $nameversion = $dependency.Split(":")[1].Split("/")
        $name = $name = $nameversion[0]
        $version = $nameversion[1].Replace("[", "").Replace("]", "")
        $list = Add-PackageToList -List $list -PackageName $name -PackageVersion $version
        #recursive call to Install-Package
        $dep = Create-Dependency -Package $Package -DependencyName $name -DependencyVersion $version        
        Install-Nuget-Package-Dependency-From-Source -Name $name -Version $version -install $install
        Add-Content $dependencyGraphfile $dep                       
    }    

    return $list
}

function Install-Nuget-Package-Dependency-From-Source
{
    Param(
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Name,
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Version,        
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()] $install     
    )    

    #Check if installed - using Get-Package
    $pkg = Check-If-Installed -Name $Name -Version $Version        
    if($pkg -ne $null)
    {
        Write-Host "$Name already installed - next dependency"
        return;
    }

    # If not installed, try to find the package
    if($pkg -eq $null)
    {                
        $pkg = Find-Package -Name $Name -RequiredVersion $Version -Source "sitecore-myget" -ErrorAction SilentlyContinue
        #if not existent, fallback to nuget.org
        if($pkg -eq $null)
        {
            $pkg = Find-Package -Name $Name -RequiredVersion $Version -Source "nuget2" -ErrorAction SilentlyContinue
        }                
    }    

    #if package found (in feed or in local storage)
    if(($pkg -ne $null) -and $install)
    {     
        #after installing dependencies, install package
        Install-Package -Name $pkg.Name -RequiredVersion $pkg.Version -Source $pkg.Source -Force -Confirm:$false -ForceBootstrap:$true -SkipDependencies        
    }
}

function Install-Nuget-Package-From-Source
{
    Param(
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Name,
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Version,    
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Source,  
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()] $install ,
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()] $list      
    )
    $isInstalled = $false

    #Check if installed - using Get-Package
    $pkg = Check-If-Installed -Name $Name -Version $Version        
    # If not installed, try to find the package
    if($pkg -eq $null)
    {                
        $pkg = Find-Package -Name $Name -RequiredVersion $Version -Source "sitecore-myget" -ErrorAction SilentlyContinue
        #if not existent, fallback to nuget.org
        if($pkg -eq $null)
        {
            $pkg = Find-Package -Name $Name -RequiredVersion $Version -Source "nuget2" -ErrorAction SilentlyContinue
        }                
    }
    else {$isInstalled = $True}

    #if package found (in feed or in local storage)
    if($pkg -ne $null)
    {
        Write-Host "$($pkg.Name) found in $($pkg.Source) - now checking dependencies"
        #install dependencies
        if($pkg.Dependencies.Count -gt 0)
        {
            $list = Write-Dependencies -Package $pkg -install $install -list $list                                    
        }
        #after installing dependencies, install package
        if(!$isInstalled -and $install) {
            Install-Package -Name $pkg.Name -RequiredVersion $pkg.Version -Source $pkg.Source -Force -Confirm:$false -ForceBootstrap:$true
        }
    }
    return $list
}

function Add-PackageToList
{
    Param(
        [parameter(Mandatory=$true)]$List,
        [parameter(Mandatory=$true)][ValidateNotNull()][String] $PackageName,
        [parameter(Mandatory=$true)][ValidateNotNull()][String] $PackageVersion
    )

    $pkg = "$PackageName $PackageVersion"
    if(!$List.Contains($pkg))
    {
        $List += $pkg
    }  
    
    return $list
}

$sc_version = $sitecoreVersion; 
$dependencyGraphfile = "$PSScriptRoot\output\$($sc_version)-flat-dependency-graph.txt"
$allpackagesFile = "$PSScriptRoot\output\$($sc_version)-allpackages-with-dependencies.txt"

#$packages = Find-Package -Source "sitecore-myget" -AllVersions 
$packages901 = $packages | where {$_.Version -eq "$sc_version" } 
$packages901WithReferences = $packages901 | where {$_.Name -notlike "*NoReferences"}
$packages901NoReferences = $packages901 | where {$_.Name -like "*NoReferences"}

[string[]]$list = ""

foreach($package in $packages901)
{    
    $list = Add-PackageToList -List $list -PackageName $package.Name -PackageVersion $package.Version
    Write-Host "installing $($package.Name)"     

    $list = Install-Nuget-Package-From-Source -Name $package.Name -Version $package.Version -Source $package.Source -install $Install -list $list

    Write-Host "Installed $($package.Name)"
    Write-Host ""
}

$list > $allpackagesFile