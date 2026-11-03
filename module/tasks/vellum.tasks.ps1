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

# Synopsis: Ensures a Node.js version supported by Vite 8 is available (v20.19+ or v22.12+)
task EnsureNodeJsVersion {

    # Ref: https://vite.dev/guide/#scaffolding-your-first-vite-project
    # Vite 8 'engines': ^20.19.0 || >=22.12.0
    $supportedVersionsMessage = "v20.19 or later in the v20 line, or v22.12 or later"
    if (!(Get-Command node -ErrorAction Ignore)) {
        throw "A Node.js installation is required to run this build process - please install $supportedVersionsMessage"
    }

    [semver]$currentNodeJsVersion = (exec { & node --version }).TrimStart("v")
    $isSupported = ($currentNodeJsVersion.Major -eq 20 -and $currentNodeJsVersion -ge [semver]"20.19.0") -or
                   ($currentNodeJsVersion -ge [semver]"22.12.0")
    if (!$isSupported) {
        throw "Node.js v$currentNodeJsVersion is not supported by Vite - please install $supportedVersionsMessage"
    }
    else {
        Write-Build Green "`u{2705} Detected Node.js v$currentNodeJsVersion"
    }
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
    Copy-Item -Path $SiteBasePath/theme/$SiteName/public -Destination $StaticSiteOutDir/public -Filter *.* -Recurse -Force
    Copy-Item $SiteBasePath/content/wwwroot/icons/* $StaticSiteOutDir -Verbose
}

# Synopsis: Executes the static site generator
task GenerateWebSite InstallVellum,CopyAssets,{

    # Generate site
    Write-Build White "Generating site..."
    $vellumArgs = @(
        "content"
        "generate"
        "-t"
        "$SiteBasePath/site.yml"
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

# Synopsis: Generates tailored NPM package dependency files needed to run Vite
task GenerateViteNpmPackageJson {

    # Copy the template package.json file
    $templatePackageJsonPath = Join-Path $PSScriptRoot '..' 'templates' 'vite-package.template.json'
    $packageJsonTargetPath = Join-Path $VellumBasePath 'package.json'
    Copy-Item $templatePackageJsonPath $packageJsonTargetPath -Force

    # Copy the template package-lock.json file
    $templatePackageLockJsonPath = Join-Path $PSScriptRoot '..' 'templates' 'vite-package-lock.template.json'
    $packageLockJsonTargetPath = Join-Path $VellumBasePath 'package-lock.json'
    Copy-Item $templatePackageLockJsonPath $packageLockJsonTargetPath -Force

    # Customise the above files for this repo
    $filesToPatch = Get-ChildItem -Path $VellumBasePath -Filter 'package*.json'
    $tokens = @{
        SITE_NAME = $SiteName
        REPO_URL = $SiteRepositoryUrl
    }
    Edit-TokenizedFiles -FilesToProcess $filesToPatch -TokenValuePairs $tokens -Verbose
}

# Synopsis: Generates a tailored vite.config.js file needed to run Vite
task GenerateViteConfig {

    # Copy the template vite.config.js file
    $viteConfigTemplatePath = Join-Path $PSScriptRoot '..' 'templates' 'vite.config.template.js'
    $viteConfigTargetPath = Join-Path $VellumBasePath 'vite.config.js'
    Copy-Item $viteConfigTemplatePath $viteConfigTargetPath -Force

    # Customise for this repo
    $tokens = @{
        OUTPUT_DIR = $StaticSiteOutDir.Replace('\', '/')
        DIST_DIR = $DistDir.Replace('\', '/')
    }
    Edit-TokenizedFiles -FilesToProcess $viteConfigTargetPath -TokenValuePairs $tokens -Verbose
}

$script:ViteWasRun = $false
# Synopsis: Runs the 'vite' tool to optimise the generated site
task RunVite -If { !$Preview } EnsureNodeJsVersion,GenerateViteNpmPackageJson,GenerateViteConfig,{

    if (!(Test-Path (Join-Path $StaticSiteOutDir 'index.html'))) {
        Write-Warning "The generated site does not include an 'index.html' file, Vite build process will be skipped."
    }
    else {        
        exec {
            Set-Location $VellumBasePath
            
            # Only skip 'npm ci' when the existing 'node_modules' folder (e.g. restored from the
            # GitHub Actions cache) was installed from this exact package-lock.json. A marker file
            # records the hash of the lock file used for the last install, so a cache entry from
            # an older template (e.g. a previous Vite major version) is never reused by mistake.
            $lockHash = (Get-FileHash -Algorithm SHA256 -Path (Join-Path $VellumBasePath 'package-lock.json')).Hash
            $lockHashMarkerPath = Join-Path $VellumBasePath 'node_modules' '.zf-package-lock.sha256'
            $installedLockHash = (Test-Path $lockHashMarkerPath) ? (Get-Content -Raw $lockHashMarkerPath).Trim() : $null

            if ($installedLockHash -ne $lockHash) {
                Write-Build White "Installing NPM dependencies"
                exec { & npm ci }
                Set-Content -Path $lockHashMarkerPath -Value $lockHash -NoNewline
            }
            else {
                Write-Build White "NPM dependencies are up-to-date with package-lock.json - skipping install"
            }
            
            # Raise the V8 heap limit for Vite unless the caller already set one via NODE_OPTIONS
            $originalNodeOptions = $env:NODE_OPTIONS
            if ($ViteMaxOldSpaceSizeMb -gt 0 -and $originalNodeOptions -notmatch '--max-old-space-size') {
                $env:NODE_OPTIONS = ("$originalNodeOptions --max-old-space-size=$ViteMaxOldSpaceSizeMb").Trim()
                Write-Build White "Using Node.js heap limit of $ViteMaxOldSpaceSizeMb MB for Vite"
            }

            try {
                Write-Build Green "Running Vite..."
                exec { & npm run prod }
            }
            finally {
                $env:NODE_OPTIONS = $originalNodeOptions
            }
        }

        $script:ViteWasRun = $true
    }
}

# Synopsis: Copies the additional non-generated files required by the web site
task CopyWWWRootFiles -If { $ViteWasRun } RunVite,{
    Write-Build White "Copying other site files..."
    # NOTE: The trailing '\*' on the source path is critical to ensuring a 'wwwroot' folder is not created in the destination
    Copy-Item $StaticSiteOutDir/*.xml -Destination $DistDir -Verbose
    Copy-Item $SiteBasePath/content/wwwroot/icons/* $DistDir -Verbose
    Copy-Item $SiteBasePath/content/wwwroot/* -Destination $DistDir -Exclude README.md -Verbose

    if ($env:LUNR) {
    Copy-Item $StaticSiteOutDir/lunr-index.json -Destination $DistDir -Verbose
    Copy-Item $StaticSiteOutDir/lunr-docs.json -Destination $DistDir -Verbose
    }
}

# Synopsis: Builds a ZIP file containing the final generated site
task BuildZipPackage -If { $ViteWasRun } CopyWWWRootFiles,{
    New-Item -ItemType Directory $PackagesDir -Force | Out-Null
    Compress-Archive -Path $DistDir/* `
                     -DestinationPath (Join-Path $here 'website.zip') `
                     -CompressionLevel Optimal `
                     -Force
}

# Synopsis: [Extensibility Point] Override this task to customise the build process before the site generation stage
task PreGenerateWebSite -Before GenerateWebSite
# Synopsis: [Extensibility Point] Override this task to customise the build process after the site generation stage
task PostGenerateWebSite -After GenerateWebSite
# Synopsis: [Extensibility Point] Override this task to customise the build process before the Vite optimisation stage
task PreRunVite -Before RunVite
# Synopsis: [Extensibility Point] Override this task to customise the build process after the Vite optimisation stage
task PostRunVite -After RunVite
# Synopsis: [Extensibility Point] Override this task to customise the build process before the additional static files are copied
task PreCopyWWWRootFiles -Before CopyWWWRootFiles
# Synopsis: [Extensibility Point] Override this task to customise the build process after the additional static files are copied
task PostCopyWWWRootFiles -After CopyWWWRootFiles

# Synopsis: The entrypoint task for the build process defined in this extension
task BuildWebSite RunFirst,
                  Init,
                  GenerateWebSite,
                  RunVite,
                  CopyWWWRootFiles,
                  BuildZipPackage,
                  RunLast

task . BuildWebSite