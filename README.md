# Endjin.ZeroFailed.Build.Vellum

[![Build Status](https://github.com/endjin/Endjin.ZeroFailed.Build.Vellum/actions/workflows/build.yml/badge.svg)](https://github.com/endjin/Endjin.ZeroFailed.Build.Vellum/actions/workflows/build.yml)
[![GitHub Release](https://img.shields.io/github/release/endjin/Endjin.ZeroFailed.Build.Vellum.svg)](https://github.com/endjin/Endjin.ZeroFailed.Build.Vellum/releases)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Endjin.ZeroFailed.Build.Vellum?color=blue)](https://www.powershellgallery.com/packages/Endjin.ZeroFailed.Build.Vellum)
[![License](https://img.shields.io/github/license/endjin/Endjin.ZeroFailed.Build.Vellum.svg)](https://github.com/endjin/Endjin.ZeroFailed.Build.Vellum/blob/main/LICENSE)


A [ZeroFailed](https://github.com/zerofailed/ZeroFailed) extension encapsulating a process to build static web sites using the [Vellum](https://github.com/endjin/Endjin.StaticSiteGen) tooling.

## Overview

| Component Type | Included | Notes                                                                                                                                                         |
| -------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tasks          | yes      |                                                                                                                                                               |
| Functions      | yes      |                                                                                                                                                               |
| Processes      | yes      | Also uses some of the tasks provided by the process defined in the [ZeroFailed.Build.Common](https://github.com/zerofailed/ZeroFailed.Build.Common) extension |

For more information about the different component types, please refer to the [ZeroFailed documentation](https://github.com/zerofailed/ZeroFailed/blob/main/README.md#extensions).

This extension consists of the following feature groups, click the links to see their documentation:

- Installing Vellum global tool (***NOTE**: Requires a GitHub token with access to this [private repo](https://github.com/endjin/Endjin.StaticSiteGen)*)
- Runs the static site generator
- Uses Vite to optimise the generated site

The diagram below shows steps included in this extension's build process.

```mermaid
graph LR
    init[Initialise] --> instVellum[Install Vellum CLI]
    instVellum --> copyAssets[Collate theme assets]
    copyAssets --> gensite[Generate site content]
    gensite --> genViteCfg[Generate Vite config]
    genViteCfg--> runvite[Run Vite]
    runvite --> copyfiles[Copy additional files]
    copyfiles --> buildZip[Create site ZIP]
```

## Pre-Requisites

Using this extension requires the following components to be installed:

- [.NET SDK](https://dotnet.microsoft.com/en-us/download)
- [GitHub CLI](https://cli.github.com/)

## Dependencies

| Extension                                                                        | Reference Type | Version |
| -------------------------------------------------------------------------------- | -------------- | ------- |
| [ZeroFailed.Build.Common](https://github.com/zerofailed/ZeroFailed.Build.Common) | git            | `main`  |

## Getting Started

If you are starting something new and don't yet have a ZeroFailed process setup, then follow the steps here to bootstrap your new project.

Once you have the above setup (or it you already have that), then simply add the following to your list of required extensions (e.g. in `config.ps1`):

```powershell
$zerofailedExtensions = @(
    ...
    # References the extension from its GitHub repository. If not already installed, use latest version from 'main' will be downloaded.
    @{
        Name = "Endjin.ZeroFailed.Build.Vellum"
        GitRepository = "https://github.com/endjin/Endjin.ZeroFailed.Build.Vellum"
        GitRef = "main"     # replace this with a Git Tag or SHA reference if want to pin to a specific version
    }

    # Alternatively, reference the extension from the PowerShell Gallery.
    @{
        Name = "Endjin.ZeroFailed.Build.Vellum"
        Version = ""   # if no version is specified, the latest stable release will be used
    }
)
```

To use the extension to build a web site that uses the Vellum static site generator tooling, simply add the following properties and task reference to your `config.ps1` file.

```powershell
# Load the tasks and process
. ZeroFailed.tasks -ZfPath $here/.zf

...

$SiteName = 'my-site'
$SiteRepositoryUrl = 'https://github.com/myorg/my-site'
$AdditionalVellumArgs = @()

...

# Customise the build process
task . BuildWebSite
```

## Usage

For an example of using this extension to build a .NET project, please take a look at [this example repo](https://github.com/endjin/fabric-weekly-info).