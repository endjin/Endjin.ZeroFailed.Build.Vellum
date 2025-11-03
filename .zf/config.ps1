# Extensions setup
$zerofailedExtensions = @(
    @{
        Name = "ZeroFailed.Build.PowerShell"
        GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.PowerShell.git"
        GitRef = "main"
    }
)

# Load the tasks and process
. ZeroFailed.tasks -ZfPath $here/.zf

# Set the required build options
$PesterTestsDir = "$here/module"
$PesterVersion = "5.7.1"
$PesterCodeCoveragePaths = "$PesterTestsDir/functions"
$PowerShellModulesToPublish = @(
    @{
        ModulePath = "$here/module/Endjin.ZeroFailed.Build.Vellum.psd1"
        FunctionsToExport = @("*")
        CmdletsToExport = @()
        AliasesToExport = @()
    }
)

# Customise the build process
task . FullBuild

#
# Build Process Extensibility Points - uncomment and implement as required
#

# task RunFirst {}
# task PreInit {}
# task PostInit {}
# task PreVersion {}
# task PostVersion {}
task PreBuild {
    if (!$IsRunningOnCICDServer) {
        # When running locally, ensure the lockfile template is up-to-date
        Set-Location (Join-Path $here 'module' 'templates')
        try {
            Copy-Item vite-package.template.json package.json -Force
            exec { npm install --package-lock-only }
            Copy-Item package-lock.json vite-package-lock.template.json
        }
        finally {
            Remove-Item package*.json
        }
    }
}
# task PostBuild {}
# task PreTest {}
# task PostTest {}
# task PreTestReport {}
# task PostTestReport {}
# task PreAnalysis {}
# task PostAnalysis {}
# task PrePackage {}
# task PostPackage {}
# task PrePublish {}
# task PostPublish {}
# task RunLast {}
