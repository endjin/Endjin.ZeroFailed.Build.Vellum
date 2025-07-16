# <copyright file="vellum.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Internal properties
$defaultVellumCmd = Join-Path $here ".zf" "vellum"
$SkipEnsureGitHubCli = $false

. $PSScriptRoot/vellum.properties.ps1

# Synopsis: Installs the vellum global tool via a GitHub release on a private repo
task InstallVellum -If {$VellumCmd -eq $defaultVellumCmd} EnsureGitHubCli,{

    if (!$vellumVersion) {
        # Find the version number of the 'Latest' GitHub release
        $latestVersion = exec { gh release list -R endjin/Endjin.StaticSiteGen } |
                            ConvertFrom-Csv -Header title,type,"tag name",published -Delimiter `t |
                            Where-Object { $_.type -eq "Latest" } |
                            Select-Object -ExpandProperty "tag name"
        
        if (!$latestVersion) {
            throw "Unable to determine the latest version of the vellum .NET tool"
        }
    }
    else {
        $latestVersion = $vellumVersion
    }
    Write-Verbose "Required version: $latestVersion"

    $vellumDownloadPath = Split-Path -Parent $defaultVellumCmd
    if (!(Test-Path $vellumDownloadPath)) {
        New-Item -ItemType Directory $vellumDownloadPath | Out-Null
    }

    $dotnetToolBaseArgs = @{
        Name = "vellum"
        Version = $latestVersion
        ToolPath = $vellumDownloadPath
    }

    # Check whether the required version is already installed. This would be handled by the 'Install-DotNetTool'
    # cmdlet, but we need to know whether to download the NuGet package first.
    $existingTool = Get-DotNetTool @dotnetToolBaseArgs -Verbose
    if (!$existingTool -or $existingTool.Version -ne $latestVersion) {
        Write-Build White "Downloading vellum .NET tool package $latestVersion"
        exec { & gh release download -R 'endjin/Endjin.StaticSiteGen' $latestVersion -p vellum.$($latestVersion).nupkg -D $vellumDownloadPath --clobber }
    
        Install-DotNetTool @dotnetToolBaseArgs -AdditionalArgs @("--add-source", $vellumDownloadPath) -Verbose
    }
    else {
        Write-Build White "Required version of vellum .NET tool already installed ($latestVersion)"
    }
}

# Synopsis: Removes previously generated version
task CleanOutput {

    if (Test-Path $StaticSiteOutDir) {
        Write-Build White "Deleting previous version..."
        Get-ChildItem -Recurse -Path $StaticSiteOutDir -Filter *.* | Remove-Item -Recurse -Force
    }
    else {
        New-Item -Path $StaticSiteOutDir -ItemType Directory | Out-Null
    }
}

# Synopsis: Copies web site assets to output folder
task CopyAssets CleanOutput,{

    Write-Build White "Copying web site assets..."
    Copy-Item -Path $SiteBasePath/site/theme/$SiteName/public -Destination $StaticSiteOutDir/public -Filter *.* -Recurse -Force
    Copy-Item $SiteBasePath/site/content/wwwroot/icons/* $StaticSiteOutDir -Verbose
}

# Synopsis: Executes the static site generator
task GenerateWebSite InstallVellum,CopyAssets,{

    # Generate site
    Write-Build White "Generating site..."
    $vellumArgs = @(
        "content"
        "generate"
        "-t"
        "$SiteBasePath/site/site.yml"
        "-o"
        "$StaticSiteOutDir"
    )

    $vellumArgs += "--export"
    $vellumArgs += "--enable-suggestions"
    $vellumArgs += "--feeds"
    $vellumArgs += "--rebuild-search-index"

    if ($Preview) {
        $vellumArgs += "--preview"
    }

    if ($Watch) {
        $vellumArgs += "--watch"
    }

    Write-Build White "VellumCmd: & $VellumCmd $($vellumArgs -join " ")"
    exec {
        & $VellumCmd $vellumArgs
    }
}

task generateNpmPackageJson GitVersion,{

    # Read in the template file
    $templatePackageJsonPath = Join-Path $PSScriptRoot 'vite-package.template.json'
    $templatePackageJson = Get-Content -Raw $templatePackageJsonPath | ConvertFrom-Json -Depth 100

    # Customise the template for the current project
    $templatePackageJson.name = $SiteName
    $templatePackageJson.version = $GitVersion.SemVer
    $templatePackageJson.repository.url = "git+$SiteRepositoryUrl"
    $templatePackageJson.bugs.url = "https://$SiteRepositoryUrl/issues"
    $templatePackageJson.homepage = "https://$SiteRepositoryUrl#readme"

    # Copy the customised template into the project
    Write-Build Green "Generating 'package.json' from template [$templatePackageJsonPath]"
    Set-Content -Path (Join-Path $GeneratedOutputsBasePath 'package.json') -Value ($templatePackageJson | ConvertTo-Json -Depth 100) -Force
}

# Synopsis: Runs the 'vite' tool to optimise the generated site
$script:ViteWasRun = $false
task RunVite -If { !$Preview } generateNpmPackageJson,{

    if (!(Test-Path (Join-Path $StaticSiteOutDir 'index.html'))) {
        Write-Warning "The generated site does not include an 'index.html' file, Vite build process will be skipped."
    }
    else {        
        exec {
            Set-Location $GeneratedOutputsBasePath
            
            # The NPM_CACHE_HIT environment variable will be set by GitHub Actions when an
            # up-to-date 'node_modules' folder was retrieved from cache.
            if ($env:NPM_CACHE_HIT -ne 'true') {
                Write-Build White "Installing NPM dependencies"
                if (Test-Path 'package.lock.json') {
                    exec { & npm ci }
                }
                else {
                    exec { & npm install }
                }
            }
            
            Write-Build Green "Running Vite..."
            exec { & npm run prod }
        }

        $script:ViteWasRun = $true
    }
}

# Synopsis: Copies the additional non-generated files required by the web site
task CopyWWWRootFiles -If { $ViteWasRun } {
    Write-Build White "Copying other site files..."
    # NOTE: The trailing '\*' on the source path is critical to ensuring a 'wwwroot' folder is not created in the destination
    Copy-Item $StaticSiteOutDir/*.xml -Destination $DistDir -Verbose
    Copy-Item $SiteBasePath/site/content/wwwroot/icons/* $DistDir -Verbose
    Copy-Item $SiteBasePath/site/content/wwwroot/* -Destination $DistDir -Exclude README.md -Verbose
    Copy-Item $StaticSiteOutDir/lunr-index.json -Destination $DistDir -Verbose
    Copy-Item $StaticSiteOutDir/lunr-docs.json -Destination $DistDir -Verbose
}

task BuildWebSite Init,GenerateWebSite,RunVite,CopyWWWRootFiles

task . BuildWebSite