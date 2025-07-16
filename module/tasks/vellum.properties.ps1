# <copyright file="vellum.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: The path to the vellum cli tool; By default this is handled by the automated installation support
$VellumCmd = $defaultVellumCmd

# Synopsis: The GitHub repository hosting the Vellum .NET global tool
$VellumGitHubRepo = 'endjin/Endjin.StaticSiteGen'

# Synopsis: The name of the NuGet package that distributes the Vellum .NET global tool
$VellumGlobalToolPackageName = 'vellum'

# Synopsis: The version of the vellum cli to use; Defaults to the latest stable release
$vellumVersion = ''         # when empty, the 'Latest' release will be installed

# Synopsis: The name of the folder containing the site's theming assets
$SiteName = 'undefined-site-name'

# Synopsis: The root path containing the web site source files
$SiteBasePath = '.'

# Synopsis: The URL of the site's git repository (e.g. 'https://github.com/myorg/mysite'); Used to populate configuration for Vite package.json file
$SiteRepositoryUrl = 'https://undefined-site-repo-fqdn'

# Synopsis: The path where the vellum cli outputs are generated; Defaults to './.output'
$GeneratedOutputsBasePath = './.zf'

# Synopsis: The path where the vellum cli outputs are generated; Defaults to './.output'
$StaticSiteOutDir = Join-Path $GeneratedOutputsBasePath '.output'

# Synopsis: The path where the final Vite-optimised static site is generated; Defaults to './.dist'
$DistDir = Join-Path $GeneratedOutputsBasePath '.dist'

# Synopsis: When true, enables the preview mode and does not run the vite compilation process
$Preview ??= $false

# Synopsis: When true, enables the watch mode which causes the build to wait indefinitely and reload the site when file changes are detected
$Watch ??= $false

# Synopsis: The GitHub token used to obtain the release artifact for the vellum cli global tool
$VellumReleaseGitHubToken = property ZF_BUILD_VELLUM_RELEASE_GITHUB_TOKEN ''

# Synopsis: Override this property to specify additional arguments on the Vellum CLI command line
$AdditionalVellumArgs = @()
