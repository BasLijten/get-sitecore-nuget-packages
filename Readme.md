# How to use
This readme describes how to use the scripts to fill the VSTS feeds for Sitecore

## gather sitecore nuget packages and its dependencies
First, run the snippet below. The sitecoreversion is the revision of Sitecore: 

sitecore version | revision
:--- | :---
Sitecore 9.0 update 1 | 9.0.171219
Sitecore 9.0 update 2 | 9.0.180604

the ```Install``` parameter is used to install _all_ dependencies locally. This is required a a first step to push them to VSTS package management afterwards.

```powershell
build-flat-dependency-graph.ps1 -sitecoreVersion "<version>" -Install $true
```

as a bonus, two files we be generated:

* \output\\*revision*-flat-dependency-graph.txt which displays all packages and its dependencies
* \output\\*revision*-allpackages-with-dependencies.txt displays a list of all packges for this release of sitecore

## push to nuget and add to view

to upload all the packages, run the following script:

```powershell
push-to-feed.ps1 -Subscription $subscription -Feed $feed -View $viewname -sitecoreVersion $revision -filename $filename
```

parameter | description
:--- | :---
```subscription``` | the vsts tenant
```feed``` | the package management feed to which the nuget packages should be pushed to
```View``` | the view that is used. for example Release-9.0-update-1 or Release-9.0-update-2. This correlates with the ```$sitecoreVersion```
```SitecoreVersion``` | when not using a file as input, the packagefeed will be queried for the sitecore version. The revision number (9.0.171219 or 9.0.180604 for example, should be used)
```filename``` | link to the ```/output/<revision>-allpackages-with-dependencies.txt```. The script will iterate through it and upload all packages in this list.
_optional_ ```nugetPackagepath``` | location on disk where all downloaded nuget packages are stored. Default is ```C:\Program Files\PackageManagement\NuGet\Packages\```

> An own list can be provided as well. Make sure that the list with packages is in form of "packagename" "Version" and that  the package is available in the nugetPackagePath

