### Script based on script by Rene van Osnabrugge "https://roadtoalm.com/author/osnabrugge/"
### original can be found here: https://roadtoalm.com/2017/01/16/programmatically-promote-your-package-quality-with-release-views-in-vsts/
### I just added some logic to iterate through all my local packages to upload them to a feed and promote them to a specific view.


function Create-VSTSPackagemanagementUrl {
    Param(
        [parameter(Mandatory=$true)][string] $Subscription        
    )
    
    $baseurl = "pkgs.visualstudio.com/_apis/packaging"    
    
    [string]$url = "https://$($Subscription).$($baseurl)"
    return $url
}

function Push-ToNuget {
    Param(
    [parameter(Mandatory=$true)][string] $PackagePath,
    [parameter(Mandatory=$true)][string] $Feed,
    [parameter(Mandatory=$false)][string] $View = ""
    )

    if(![String]::IsNullOrEmpty($View)) {
        $Feed = $Feed + "@" + $View
    }

    $nugetToCall = "C:\git\get-sitecore-packages\CredentialProviderBundle\nuget.exe"
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
 


$feed = "xxxx.Sitecore"
$view = ""
$view = "Release-9.0-update-1"
$subscription = "xxx-xxxxxxx-xxx"

$basepackageurl = Create-VSTSPackagemanagementUrl -Subscription $subscription

#?? needed or just needed to register a source?
#
#$fullurl = Create-VSTSPackagemanagementUrl -Subscription $subscription -Feed $feed -View $view

$path = "C:\Program Files\PackageManagement\NuGet\Packages\"

$sc_version = "9.0.180604";
$versionstring = ".NoReferences.$($sc_version).nupkg"

$nugetpackages = Get-ChildItem -Path $path -Include "*$versionstring" -Recurse
Write-Host "$($nugetpackages.Count) packages found"
$pkg = $null

foreach($pkg in $nugetpackages)
{    
    $nugetpackage = $pkg.Name.Replace(".$sc_version.nupkg", "")

    Push-ToNuget -PackagePath $pkg -Feed $feed
    Set-PackageQuality -feedName $feed -packageId $nugetpackage -packageVersion $sc_version -packageQuality $view
}



