<#
.SYNOPSIS
This script provides functions to interact with XML configuration files and GitHub repositories.

.DESCRIPTION
The script includes functions to:
- Retrieve application information from an XML configuration file.
- Update an XML configuration file with the latest application version and download URL.
- Retrieve the latest application information from a GitHub repository.
"https://raw.githubusercontent.com/ErshovIS/CCM_AppUpdate/refs/heads/main/appVersions.json"

.PARAMETER ConfigXML
The path to the XML configuration file.

.PARAMETER applicationName
The name of the application to search or update in the XML configuration file.

.PARAMETER latestVersion
The latest version of the application to update in the XML configuration file.

.PARAMETER DownloadURL
The download URL of the latest version of the application to update in the XML configuration file.

.PARAMETER JSONUrl
The URL of the JSON file containing application information.

.PARAMETER GitHubRep
The GitHub repository name in the format 'owner/repo'.

.PARAMETER filter
The filter to search for specific assets in the GitHub repository.

.PARAMETER architecture
The architecture of the application (default is 'x64').

.EXAMPLE
$xmlConfig = "C:\Temp\config.xml"
$application = "notepad"
$StoredApplicationDetails = Get-AppInfoFromXML -ConfigXML $xmlConfig -applicationName $application
$ActualApplicationDetails = Get-GitHubApplicationInfo -GitHubRep $StoredApplicationDetails.repositoryName -filter '*.exe' -architecture 'x64'
if ($StoredApplicationDetails.latestVersion -lt $ActualApplicationDetails.Version) {
    Write-Output "New version available"
    Write-Output "Current version: $($StoredApplicationDetails.latestVersion)"
    Write-Output "New version: $($ActualApplicationDetails.Version)"
    Write-Output "Download URL: $($ActualApplicationDetails.DownloadURL)"
}

#>


[CmdletBinding()]
param (
    # Parameter help description
    [Parameter(Mandatory = $true, HelpMessage = "Specify XML configuration file path")]
    [string]$xmlConfig,

    # Parameter help description
    [Parameter(Mandatory = $true, HelpMessage = "Specify application to check")]
    [string]$application = ""    
)

function Get-ScriptConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$xmlConfig
    )
    $xmlContent = [xml](Get-Content $xmlConfig)
    return $xmlContent.Node.Configuration  
}

function Get-AppInfoFromXML {   
    param (
        # Path to xml config file
        [Parameter(Mandatory=$true)]
        [string]$ConfigXML,
        # Application name to search
        [Parameter(Mandatory=$true)]
        [string]$applicationName
    )
    $xmlContent = [xml](Get-Content $ConfigXML)   
    return $xmlContent.Node.Applications.Application | Where-Object {$_.ApplicationName -match $applicationName} 
}

function Update-XMLConfigFile {
    param (
        # Path to xml config file
        [Parameter(Mandatory=$true)]
        [string]$ConfigXML,
        [Parameter(Mandatory=$true)]
        [string]$applicationName,
        [Parameter(Mandatory=$true)]
        [string]$latestVersion,
        [Parameter(Mandatory=$true)]
        [string]$DownloadURL,
        [Parameter(Mandatory=$true)]
        [string]$localStoredPath
    )
    $xmlContent = [xml](Get-Content $ConfigXML)
    $xmlContent.Node.Applications.Application | Where-Object {$_.ApplicationName -match $applicationName} | ForEach-Object {
        $_.LatestVersion = $latestVersion
        $_.DownloadURL = $DownloadURL
        $_.LocalStoredPath = $localStoredPath
    }
    $xmlContent.Save($ConfigXML)
}

function Get-GitHubApplicationInfo {
    param (
       # GitHub URL
       #[Parameter(Mandatory=$true)]
       #[string]$GitHubURL,
       # Applicatin repository
       $GitHubRep,
       # Filter to search
       [Parameter(Mandatory=$true)]
       [string]$filter,
       # Architecture
       $architecture = "x64"
    )

    $CurrentRepositoryURL = 'https://api.github.com/repos/' + $GitHubRep + '/releases/latest'
    $CurrentRepositoryURL
    $Application = Invoke-RestMethod -Uri $CurrentRepositoryURL

    return New-Object PSObject @{
        "Version" = $Application.tag_name
        "DownloadURL" = $Application.assets | Where-Object { $_.name -like $filter -and $_.name -match $architecture } | Select-Object -ExpandProperty browser_download_url
        "FileName" = $Application.assets | Where-Object { $_.name -like $filter -and $_.name -match $architecture } | Select-Object -ExpandProperty name
    }
}

write-host "XML Configuration file: $xmlConfig"
$xmlContent = [xml](Get-Content $xmlConfig)   

$script = Get-ScriptConfiguration -xmlConfig $xmlConfig

write-host "Script parameters: $script"

$StoredApplicationDetails = Get-AppInfoFromXML -ConfigXML $xmlConfig -applicationName $application

$ActualApplicationDetails = Get-GitHubApplicationInfo -GitHubRep $StoredApplicationDetails.repositoryName -filter '*.exe' -architecture 'x64'

if ($StoredApplicationDetails.latestVersion -lt $ActualApplicationDetails.Version) {
    Write-Output "New version available"
    Write-Output "Current version: $($StoredApplicationDetails.latestVersion)"
    Write-Output "New version: $($ActualApplicationDetails.Version)"
    Write-Output "Download URL: $($ActualApplicationDetails.DownloadURL)"
}
else {
    Write-Output "No new version available"
}

$pathTemplate = "$($Script.RootFolder)\{0}\{1}\{2}\{3}" -f $StoredApplicationDetails.manufacturer, $StoredApplicationDetails.applicationName, $ActualApplicationDetails.Version, $ActualApplicationDetails.FileName
If (Test-Path -Path (Split-Path $pathTemplate -Parent)) {
    Write-Output "File already exists"
    Exit
} else {
    New-Item -ItemType Directory -Path (Split-Path $pathTemplate -Parent) -Force
}
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $ActualApplicationDetails.DownloadURL -OutFile $pathTemplate -Method Get

Update-XMLConfigFile -ConfigXML $xmlConfig -applicationName $application -latestVersion $ActualApplicationDetails.Version -DownloadURL $ActualApplicationDetails.DownloadURL -localStoredPath $pathTemplate