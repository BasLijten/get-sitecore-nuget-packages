#Param(
#    [parameter(Mandatory=$true, HelpMessage="Version"][ValidateNotNull()][String] $Provider,
#    [parameter(Mandatory=$true, HelpMessage="Version"][ValidateNotNull()][String] $Version
#)

# check if packagesource exists
#Register-PackageSource -Name "sitecore-myget" -Location "https://sitecore.myget.org/F/sc-packages/api/" -ProviderName "nuget"
#Register-PackageSource -Name "nuget2" -Location "http://www.nuget.org/api/v2/" -ProviderName "nuget"

function Check-If-Installed
{
Param(
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Name,
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Version    
    )
    $a = Get-package -Name $Name -RequiredVersion $Version -ErrorAction SilentlyContinue
    if($a -eq $null) { return $False }
    return $True
}

function Install-Dependencies {
    Param(
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()] $Package    
    )
    Write-Host "Dependencies of $($package.Name) - $($package.Dependencies.Count)"

    $nameversion = $null;
    foreach($dependency in $package.Dependencies)
    {        
        $nameversion = $dependency.Split(":")[1].Split("/")
        $name = $name = $nameversion[0]
        $version = $nameversion[1].Replace("[", "").Replace("]", "")

        #recursive call to Install-Package
        Write-Host "About to install dependency $name of $($package.Name)"
        Install-Nuget-Package-From-Source -Name $name -Version $version -Source $package.Source
    }
}


function Install-Nuget-Package-From-Source
{
    Param(
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Name,
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Version,    
    [parameter(Mandatory=$true, HelpMessage="Version")][ValidateNotNull()][String] $Source  
    )

    #Check if installed
    $isInstalled = Check-If-Installed -Name $Name -Version $Version

    # If not installed, install
    if(!$isInstalled)
    {
        #Find package in source
        if($Name -eq "HtmlAgilityPack")
        {
        }

        $package = Find-Package -Name $Name -RequiredVersion $Version -Source "sitecore-myget" -ErrorAction SilentlyContinue
        #if not existent, fallback to nuget.org
        if($package -eq $null)
        {
            $package = Find-Package -Name $Name -RequiredVersion $Version -Source "nuget2" -ErrorAction SilentlyContinue
        }

        #if package found
        if($package -ne $null)
        {
            Write-Host "$($package.Name) found in $($package.Source) - now checking dependencies"
            #install dependencies
            if($package.Dependencies.Count -gt 0)
            {
                Install-Dependencies -Package $package
            }
            #after installing dependencies, install package
            Install-Package -Name $Name -RequiredVersion $Version -Source $package.Source -Force -Confirm:$false -ForceBootstrap:$true
        }
        else
        {
        }
    }
}

$packages = Find-Package -Source "sitecore-myget" -AllVersions | where {$_.Version -eq "9.0.171219" } 

foreach($package in $packages)
{    
    Write-Host "installing $($package.Name)"     

    Install-Nuget-Package-From-Source -Name $package.Name -Version $package.Version -Source $package.Source

    Write-Host "Installed $($package.Name)"
    Write-Host ""
}