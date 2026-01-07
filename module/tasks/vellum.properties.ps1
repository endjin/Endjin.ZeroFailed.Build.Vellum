# <copyright file="vellum.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: The path to the vellum cli tool; By default this is handled by the automated installation support
$VellumCmd = $defaultVellumCmd

# Synopsis: The GitHub repository hosting the Vellum .NET global tool
$VellumGitHubRepo = 'endjin/Endjin.StaticSiteGen'

# Synopsis: The name of the NuGet package that distributes the Vellum .NET global tool
$VellumGlobalToolPackageName = 'vellum'

# Synopsis: The version of the vellum cli to use. When empty the latest stable release will be used.
$VellumVersion = ''

# Synopsis: The name of the folder containing the site's theming assets
$SiteName = 'undefined-site-name'

# Synopsis: The root path containing the web site source files
$SiteBasePath = './site'

# Synopsis: The URL of the site's git repository (e.g. 'https://github.com/myorg/mysite'); Used to populate configuration for Vite's package.json file
$SiteRepositoryUrl = 'https://undefined-site-repo-fqdn'

# Synopsis: The path where the vellum-related artefacts are stored (e.g. cli tool, Vite configuration, intermediate & output folders)
$VellumBasePath = Join-Path $here '.vellum'

# Synopsis: The path where the vellum cli outputs are generated
$StaticSiteOutDir = Join-Path $VellumBasePath '.output'

# Synopsis: The path where the final Vite-optimised static site is generated
$DistDir = Join-Path $VellumBasePath '.dist'

# Synopsis: When true, enables the preview mode and does not run the Vite compilation process
$Preview ??= $false

# Synopsis: When true, enables the watch mode which causes the build to wait indefinitely and regenerate the site when file changes are detected
$Watch ??= $false

# Synopsis: The GitHub token used to obtain the release artifact for the vellum cli global tool
$VellumReleaseGitHubToken = property ZF_BUILD_VELLUM_RELEASE_GITHUB_TOKEN ''

# Synopsis: Override this property to specify additional arguments on the Vellum CLI command line
$AdditionalVellumArgs = @()
