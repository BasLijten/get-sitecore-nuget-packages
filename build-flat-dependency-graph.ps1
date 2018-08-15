#Param(
#    [parameter(Mandatory=$true, HelpMessage="Version"][ValidateNotNull()][String] $Provider,
#    [parameter(Mandatory=$true, HelpMessage="Version"][ValidateNotNull()][String] $Version
#)

# check if packagesource exists
#Register-PackageSource -Name "sitecore-myget" -Location "https://sitecore.myget.org/F/sc-packages/api/" -ProviderName "nuget"
#Register-PackageSource -Name "nuget2" -Location "http://www.nuget.org/api/v2/" -ProviderName "nuget"

$sc_version = "9.0.171219"; #Sitecore 9.0.1
$file = "<path>\flat-dependency-graph-$sc_version.txt"

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
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()] $Package    
    )
    Write-Host "Dependencies of $($Package.Name) - $($Package.Dependencies.Count)"

    $nameversion = $null;
    foreach($dependency in $Package.Dependencies)
    {        
        $nameversion = $dependency.Split(":")[1].Split("/")
        $name = $name = $nameversion[0]
        $version = $nameversion[1].Replace("[", "").Replace("]", "")

        #recursive call to Install-Package
        $dep = Create-Dependency -Package $Package -DependencyName $name -DependencyVersion $version        
        Install-Nuget-Package-Dependency-From-Source -Name $name -Version $version -Source "bla"
        Add-Content $file $dep       
    }    
}

function Install-Nuget-Package-Dependency-From-Source
{
    Param(
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Name,
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Version,    
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Source  
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
    if($pkg -ne $null)
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
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Source  
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
            Write-Dependencies -Package $pkg                                    
        }
        #after installing dependencies, install package
        if(!$isInstalled) {
            Install-Package -Name $pkg.Name -RequiredVersion $pkg.Version -Source $pkg.Source -Force -Confirm:$false -ForceBootstrap:$true
        }
    }
}

# $packages = Find-Package -Source "sitecore-myget" -AllVersions 
$packages901 = $packages | where {$_.Version -eq "$sc_version" } 
$packages901WithReferences = $packages901 | where {$_.Name -notlike "*NoReferences"}
$packages901NoReferences = $packages901 | where {$_.Name -like "*NoReferences"}

foreach($package in $packages901WithReferences)
{    
    Write-Host "installing $($package.Name)"     

    Install-Nuget-Package-From-Source -Name $package.Name -Version $package.Version -Source $package.Source

    Write-Host "Installed $($package.Name)"
    Write-Host ""
}