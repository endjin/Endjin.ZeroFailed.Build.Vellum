# <copyright file="vellum.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Internal properties
$defaultVellumCmd = { Join-Path $VellumBasePath 'bin' 'vellum' }

. $PSScriptRoot/vellum.properties.ps1

# Synopsis: Ensures that the presence of GitHub CLI is checked
task ForceEnsureGitHubCli -Before Init {
    # Workaround issue with InvokeBuild 'property' keyword overriding other values
    $script:SkipEnsureGitHubCli = $false
}

# Synopsis: Handles lazy evaluation of Vellum tool path for customisation scenarios
task ResolveVellumCmdPath {
    $script:defaultVellumCmd = Resolve-Value $defaultVellumCmd
    $script:VellumCmd = Resolve-Value $VellumCmd
}

# Synopsis: Installs the vellum global tool via a GitHub release on a private repo
task InstallVellum -If {$VellumCmd -eq $defaultVellumCmd} ResolveVellumCmdPath,EnsureGitHubCli,{

    if ($VellumReleaseGitHubToken) {
        if (Test-Path env:/GH_TOKEN) {
            # Store any the current value for the GH_TOKEN environment variable, before we override it
            $_zfSavedGhToken = $env:GH_TOKEN
        }
        $env:GH_TOKEN = $VellumReleaseGitHubToken
    }

    try {
        if (!$vellumVersion) {
            # Find the version number of the 'Latest' GitHub release
            $latestVersion = exec { & gh release list -R $VellumGitHubRepo } |
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
            New-Item -ItemType Directory $vellumDownloadPath -Force | Out-Null
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
            $vellumPackageFullName = "{0}.{1}.nupkg" -f $VellumGlobalToolPackageName, $latestVersion
            Write-Build White "Downloading vellum .NET tool package $vellumPackageFullName"
            exec { & gh release download -R $VellumGitHubRepo $latestVersion -p $vellumPackageFullName -D $vellumDownloadPath --clobber }
        
            Install-DotNetTool @dotnetToolBaseArgs -AdditionalArgs @("--add-source", $vellumDownloadPath) -Verbose
        }
        else {
            Write-Build White "Required version of vellum .NET tool already installed ($latestVersion)"
        }
    }
    finally {
        # Restore the environment back to its original state
        if (Test-Path variable:/_zfSavedGhToken) {
            $env:GH_TOKEN = $_zfSavedGhToken
        }
        elseif (Test-Path env:/GH_TOKEN) {
            Remove-Item env:/GH_TOKEN
        }
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

    if ($AdditionalVellumArgs) {
        Write-Build White "AdditionalVellumArgs: $($AdditionalVellumArgs | ConvertTo-Json)"
        $vellumArgs += $AdditionalVellumArgs
    }

    Write-Build White "VellumCmd: & $VellumCmd $($vellumArgs -join " ")"
    exec {
        & $VellumCmd $vellumArgs
    }
}

task GenerateViteNpmPackageJson {

    # Read in the template package.json file
    $templatePackageJsonPath = Join-Path $PSScriptRoot '..' 'templates' 'vite-package.template.json'
    $templatePackageJson = Get-Content -Raw $templatePackageJsonPath | ConvertFrom-Json -Depth 100

    # Read in the template package-lock.json file
    $templatePackageLockJsonPath = Join-Path $PSScriptRoot '..' 'templates' 'vite-package-lock.template.json'
    $templatePackageLockJson = Get-Content -Raw $templatePackageLockJsonPath | ConvertFrom-Json -Depth 100 -AsHashtable

    # Customise the template for the current project
    $templatePackageJson.name = $SiteName
    $templatePackageJson.repository.url = "git+$SiteRepositoryUrl"
    $templatePackageJson.bugs.url = "https://$SiteRepositoryUrl/issues"
    $templatePackageJson.homepage = "https://$SiteRepositoryUrl#readme"

    $templatePackageLockJson.name = $SiteName
    $templatePackageLockJson.packages[""].name = $SiteName

    # Copy the customised template into the project
    Write-Build Green "Generating 'package.json' from template [$templatePackageJsonPath]"
    Set-Content -Path (Join-Path $VellumBasePath 'package.json') -Value ($templatePackageJson | ConvertTo-Json -Depth 100) -Force
    Write-Build Green "Generating 'package-lock.json' from template [$templatePackageLockJsonPath]"
    Set-Content -Path (Join-Path $VellumBasePath 'package-lock.json') -Value ($templatePackageLockJson | ConvertTo-Json -Depth 100) -Force
}

# Synopsis: Runs the 'vite' tool to optimise the generated site
$script:ViteWasRun = $false
task RunVite -If { !$Preview } GenerateViteNpmPackageJson,{

    if (!(Test-Path (Join-Path $StaticSiteOutDir 'index.html'))) {
        Write-Warning "The generated site does not include an 'index.html' file, Vite build process will be skipped."
    }
    else {        
        exec {
            Set-Location $VellumBasePath
            
            # The NPM_CACHE_HIT environment variable will be set by GitHub Actions when an
            # up-to-date 'node_modules' folder was retrieved from cache.
            if ($env:NPM_CACHE_HIT -ne 'true') {
                Write-Build White "Installing NPM dependencies"
                exec { & npm ci }
            }
            else {
                Write-Build White "NPM dependencies restore from cache"
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

# Build process extensibility points
task PreGenerateWebSite -Before GenerateWebSite
task PostGenerateWebSite -After GenerateWebSite
task PreRunVite -Before RunVite
task PostRunVite -After RunVite
task PreCopyWWWRootFiles -Before CopyWWWRootFiles
task PostCopyWWWRootFiles -After CopyWWWRootFiles

# Define the build process, using the basic structure provided by ZeroFailed.Build.Common
task BuildWebSite RunFirst,
                  Init,
                  GenerateWebSite,
                  RunVite,
                  CopyWWWRootFiles,
                  RunLast

task . BuildWebSite