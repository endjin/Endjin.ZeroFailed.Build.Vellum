Endjin.ZeroFailed.Build.Vellum - Reference Sheet

## Vellum

This contains the functionality to generate, optimise and package a web site that uses the [Vellum](https://github.com/endjin/Endjin.StaticSiteGen) tooling.

### Properties

| Name                          | Default Value                      | ENV Override                           | Description                                                                                                                                |
| ----------------------------- | ---------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `AdditionalVellumArgs`        | @()                                |                                        | Override this property to specify additional arguments on the Vellum CLI command line                                                      |
| `DistDir`                     | '`<VellumBasePath>`/.dist'         |                                        | The path where the final Vite-optimised static site is generated                                                                           |
| `Preview`                     | $false                             |                                        | When true, enables the preview mode and does not run the Vite compilation process                                                          |
| `SiteBasePath`                | '.'                                |                                        | The root path containing the web site source files                                                                                         |
| `SiteName`                    | 'undefined-site-name'              |                                        | The name of the folder containing the site's theming assets                                                                                |
| `SiteRepositoryUrl`           | 'https://undefined-site-repo-fqdn' |                                        | The URL of the site's git repository (e.g. 'https://github.com/myorg/mysite'); Used to populate configuration for Vite's package.json file |
| `StaticSiteOutDir`            | '`<VellumBasePath>`/.output'       |                                        | The path where the vellum cli outputs are generated                                                                                        |
| `VellumBasePath`              | './.vellum'                        |                                        | The path where the vellum-related artefacts are stored (e.g. cli tool, Vite configuration, intermediate & output folders)                  |
| `VellumCmd`                   | '`<VellumBasePath>`/bin/vellum'    |                                        | The path to the vellum cli tool; By default this is handled by the automated installation support                                          |
| `VellumGitHubRepo`            | 'endjin/Endjin.StaticSiteGen'      |                                        | The GitHub repository hosting the Vellum .NET global tool                                                                                  |
| `VellumGlobalToolPackageName` | 'vellum'                           |                                        | The name of the NuGet package that distributes the Vellum .NET global tool                                                                 |
| `VellumReleaseGitHubToken`    | ''                                 | `ZF_BUILD_VELLUM_RELEASE_GITHUB_TOKEN` | The GitHub token used to obtain the release artifact for the vellum cli global tool                                                        |
| `VellumVersion`               | ''                                 |                                        | The version of the vellum cli to use. When empty the latest stable release will be used.                                                   |
| `Watch`                       | $false                             |                                        | When true, enables the watch mode which causes the build to wait indefinitely and regenerate the site when file changes are detected       |

<!-- START_GENERATED_HELP -->

### Tasks

| Name                         | Description                                                                                                           |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `BuildWebSite`               | The entrypoint task for the build process defined in this extension                                                   |
| `BuildZipPackage`            | Builds a ZIP file containing the final generated site                                                                 |
| `CleanOutput`                | Removes previously generated version                                                                                  |
| `CopyAssets`                 | Copies web site assets to output folder                                                                               |
| `CopyWWWRootFiles`           | Copies the additional non-generated files required by the web site                                                    |
| `EnsureNodeJsVersion`        | Ensures Node.js v20.19 or later is available                                                                          |
| `ForceEnsureGitHubCli`       | Ensures that the presence of GitHub CLI is checked                                                                    |
| `GenerateViteConfig`         | Generates a tailored vite.config.js file needed to run Vite                                                           |
| `GenerateViteNpmPackageJson` | Generates tailored NPM package dependency files needed to run Vite                                                    |
| `GenerateWebSite`            | Executes the static site generator                                                                                    |
| `InstallVellum`              | Installs the vellum global tool via a GitHub release on a private repo                                                |
| `PostCopyWWWRootFiles`       | [Extensibility Point] Override this task to customise the build process after the additional static files are copied  |
| `PostGenerateWebSite`        | [Extensibility Point] Override this task to customise the build process after the site generation stage               |
| `PostRunVite`                | [Extensibility Point] Override this task to customise the build process after the Vite optimisation stage             |
| `PreCopyWWWRootFiles`        | [Extensibility Point] Override this task to customise the build process before the additional static files are copied |
| `PreGenerateWebSite`         | [Extensibility Point] Override this task to customise the build process before the site generation stage              |
| `PreRunVite`                 | [Extensibility Point] Override this task to customise the build process before the Vite optimisation stage            |
| `ResolveVellumCmdPath`       | Handles lazy evaluation of Vellum tool path for customisation scenarios                                               |
| `RunVite`                    | Runs the 'vite' tool to optimise the generated site                                                                   |


<!-- END_GENERATED_HELP -->
