<#
.Synopsis
Script to fill the Sitecore nuget feed in VSTS. Pushes Sitecore nuget packages to VSTS and promote those packages to a specific view. It's required that he list of all packages is available in the output directory, in form:
"package<space>version"
Script based on script by Rene van Osnabrugge "https://roadtoalm.com/author/osnabrugge/"
original can be found here: https://roadtoalm.com/2017/01/16/programmatically-promote-your-package-quality-with-release-views-in-vsts/
I just added some logic to iterate through all my local packages to upload them to a feed and promote them to a specific view.
#>
Param(
        [parameter(Mandatory=$true)][string] $Subscription,        
        [parameter(Mandatory=$true)][string] $Feed,
        [parameter(Mandatory=$true)][string] $View,
        [parameter(Mandatory=$false, HelpMessage="Sitecore Version")][string] $sitecoreVersion,
        [parameter(Mandatory=$false, HelpMessage="file or sitecoreversion")][string] $filename,
        [parameter(Mandatory=$false, HelpMessage="Alternative nuget packages path")][string] $nugetPackagepath = "C:\Program Files\PackageManagement\NuGet\Packages\"
    )    

<#
.Synopsis
Creates VSTS package management url. Only uses subscription as input
#>
function Create-VSTSPackagemanagementUrl {
    Param(
        [parameter(Mandatory=$true)][string] $Subscription        
    )
    
    $baseurl = "pkgs.visualstudio.com/_apis/packaging"    
    
    [string]$url = "https://$($Subscription).$($baseurl)"
    return $url
}

<#
.Synopsis
Pushes a package to a nuget feed. When using VSTS package management, please note that only the original feed can be used; Pushing to a specific View is not possible. 
#>
function Push-ToNuget {
    Param(
    [parameter(Mandatory=$true)][string] $PackagePath,
    [parameter(Mandatory=$true)][string] $Feed    
    )    

    $nugetToCall = "$PSScriptRoot\CredentialProviderBundle\nuget.exe"
     &$nugetToCall push -Source $Feed -ApiKey VSTS "$PackagePath"

}

<#
.Synopsis
Creates either a Basic Authentication token or a Bearer token depending on where the method is called from VSTS. 
When you send a Personal Access Token that you generate in VSTS it uses this one. Within the VSTS pipeline it uses env:System_AccessToken 
#>
function New-VSTSAuthenticationToken
{
    [CmdletBinding()]
    [OutputType([object])]
         
    $accesstoken = "";
    if([string]::IsNullOrEmpty($env:System_AccessToken)) 
    {
        if([string]::IsNullOrEmpty($env:PersonalAccessToken))
        {
            throw "No token provided. Use either env:PersonalAccessToken for Localruns or use in VSTS Build/Release (System_AccessToken)"
        } 
        Write-Debug $($env:PersonalAccessToken)
        $userpass = ":$($env:PersonalAccessToken)"
        $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($userpass))
        $accesstoken = "Basic $encodedCreds"
    }
    else 
    {
        $accesstoken = "Bearer $env:System_AccessToken"
    }

    return $accesstoken;
}

function Set-PackageQuality
{
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [string] $feedType="nuget",
        [string] $feedName="",
        [string] $packageId="",
        [string] $packageVersion="",
        [string] $packageQuality=""
        
    )

    $token = New-VSTSAuthenticationToken    
    #API URL is slightly different for npm vs. nuget...
    switch($feedType)
    {
        "npm" { $releaseViewURL = "$basepackageurl/feeds/$feedName/npm/$packageId/versions/$($packageVersion)?api-version=5.0-preview.1" }
        "nuget" { $releaseViewURL = "$basepackageurl/feeds/$feedName/nuget/packages/$packageId/versions/$($packageVersion)?api-version=3.0-preview.1" }
        default { $releaseViewURL = "$basepackageurl/feeds/$feedName/nuget/packages/$packageId/versions/$($packageVersion)?api-version=3.0-preview.1" }
    }
    
     $json = @{
        views = @{
            op = "add"
            path = "/views/-"
            value = "$packageQuality"
        }
    }

    $response = Invoke-RestMethod -Uri $releaseViewURL -Headers @{Authorization = $token}   -ContentType "application/json" -Method Patch -Body (ConvertTo-Json $json)
    return $response
}

# url to push packages to
$basepackageurl = Create-VSTSPackagemanagementUrl -Subscription $subscription

if($sitecorepackageSource -eq "file") {
    
    $nugetpackages = "";
}
else {
    $versionstring = ".$($sitecoreVersion).nupkg"
    $nugetpackages = Get-ChildItem -Path $nugetPackagepath -Include "*$versionstring" -Recurse
}

Write-Host "$($nugetpackages.Count) packages found"
$pkg = $null

foreach($pkg in $nugetpackages)
{    
    $nugetpackage = $pkg.Name.Replace(".$sitecoreVersion.nupkg", "")

    Push-ToNuget -PackagePath $pkg -Feed $feed
    Set-PackageQuality -feedName $feed -packageId $nugetpackage -packageVersion $sitecoreVersion -packageQuality $view
}




