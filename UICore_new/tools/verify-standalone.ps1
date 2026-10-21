param(
    [string]$BuildDirectory = "build",
    [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
    [string]$Configuration = "Release",
    [string]$QtBin,
    [int]$TimeoutSeconds = 15,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$buildPath = if ([System.IO.Path]::IsPathRooted($BuildDirectory)) {
    $BuildDirectory
} else {
    Join-Path $repositoryRoot $BuildDirectory
}
$buildPath = (Resolve-Path -LiteralPath $buildPath).Path
$cachePath = Join-Path $buildPath "CMakeCache.txt"
if (-not (Test-Path -LiteralPath $cachePath)) {
    throw "CMake cache not found: $cachePath"
}

$cacheLines = Get-Content -LiteralPath $cachePath
$qtCoreEntry = $cacheLines | Where-Object { $_ -like "Qt5Core_DIR:PATH=*" } | Select-Object -First 1
if (-not $qtCoreEntry) {
    throw "Qt5Core_DIR is missing from $cachePath"
}

$qtCoreCMakeDirectory = ($qtCoreEntry -split "=", 2)[1]
if ([string]::IsNullOrWhiteSpace($QtBin)) {
    $qtPrefix = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $qtCoreCMakeDirectory))
    $QtBin = Join-Path $qtPrefix "bin"
}
$qtBinPath = (Resolve-Path -LiteralPath $QtBin).Path
$qmakePath = Join-Path $qtBinPath "qmake.exe"
if (-not (Test-Path -LiteralPath $qmakePath)) {
    throw "qmake.exe not found: $qmakePath"
}

$buildArguments = @("--build", $buildPath, "--config", $Configuration, "--target", "UICoreStandalone")
if (-not $SkipBuild) {
    Write-Host "cmake $($buildArguments -join ' ')"
    & cmake @buildArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed with exit code $LASTEXITCODE"
    }
}

$executableCandidates = @(
    (Join-Path (Join-Path $buildPath $Configuration) "UICoreStandalone.exe"),
    (Join-Path $buildPath "UICoreStandalone.exe")
)
$executablePath = $executableCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $executablePath) {
    throw "UICoreStandalone.exe not found for configuration $Configuration"
}
$executablePath = (Resolve-Path -LiteralPath $executablePath).Path

$generatorEntry = $cacheLines | Where-Object { $_ -like "CMAKE_GENERATOR:*" } | Select-Object -First 1
$generator = if ($generatorEntry) { ($generatorEntry -split "=", 2)[1] } else { "unknown" }
$qtVersion = (& $qmakePath -query QT_VERSION).Trim()
$gitCommit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$gitBranch = (& git -C $repositoryRoot branch --show-current).Trim()
$gitStatus = @(& git -C $repositoryRoot status --short)
$executableHash = (Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash

$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = $executablePath
$startInfo.Arguments = "--smoke-test"
$startInfo.WorkingDirectory = Split-Path -Parent $executablePath
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.EnvironmentVariables["PATH"] = $qtBinPath + ";" + $startInfo.EnvironmentVariables["PATH"]
$startInfo.EnvironmentVariables["QT_PLUGIN_PATH"] = Join-Path (Split-Path -Parent $qtBinPath) "plugins"
$startInfo.EnvironmentVariables["QT_FORCE_STDERR_LOGGING"] = "1"

$standaloneProcess = New-Object System.Diagnostics.Process
$standaloneProcess.StartInfo = $startInfo
$startedAt = Get-Date
[void]$standaloneProcess.Start()
$stdoutTask = $standaloneProcess.StandardOutput.ReadToEndAsync()
$stderrTask = $standaloneProcess.StandardError.ReadToEndAsync()
$exitedNaturally = $standaloneProcess.WaitForExit($TimeoutSeconds * 1000)
if (-not $exitedNaturally) {
    $standaloneProcess.Kill()
}
$standaloneProcess.WaitForExit()
$stdoutText = $stdoutTask.Result
$stderrText = $stderrTask.Result
$exitCode = $standaloneProcess.ExitCode
$standaloneProcess.Dispose()

$stderrLines = @($stderrText -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$bindingLoopLines = @($stderrLines | Where-Object { $_ -match "Binding loop detected" })
$layoutLoopLines = @($stderrLines | Where-Object {
    $_ -match "recursive rearrange|polish\(\) loop|Polish loop"
})
$qmlErrorLines = @($stderrLines | Where-Object {
    $_ -match "QQmlApplicationEngine failed|ReferenceError:|TypeError:|is not a type|Cannot assign|module .+ is not installed|Cannot load"
})

$logDirectory = Join-Path $buildPath "verification"
[void](New-Item -ItemType Directory -Path $logDirectory -Force)
$logPath = Join-Path $logDirectory ("standalone-{0}-{1}.log" -f $Configuration.ToLowerInvariant(), $startedAt.ToString("yyyyMMdd-HHmmss"))
$statusLines = if ($gitStatus.Count -eq 0) { @("clean") } else { $gitStatus }
$logLines = @(
    "StartedAt=$($startedAt.ToString('o'))",
    "Command=$executablePath --smoke-test",
    "Configuration=$Configuration",
    "Generator=$generator",
    "QtVersion=$qtVersion",
    "QtBin=$qtBinPath",
    "GitBranch=$gitBranch",
    "GitCommit=$gitCommit",
    "ExecutableSha256=$executableHash",
    "ExitedNaturally=$exitedNaturally",
    "ExitCode=$exitCode",
    "BindingLoops=$($bindingLoopLines.Count)",
    "LayoutLoops=$($layoutLoopLines.Count)",
    "QmlErrors=$($qmlErrorLines.Count)",
    "GitStatus:",
    $statusLines,
    "--- stderr ---",
    $stderrText.TrimEnd(),
    "--- stdout ---",
    $stdoutText.TrimEnd()
)
Set-Content -LiteralPath $logPath -Value $logLines -Encoding UTF8

Write-Host "Qt $qtVersion | $Configuration | $generator"
Write-Host "ExitCode=$exitCode BindingLoops=$($bindingLoopLines.Count) LayoutLoops=$($layoutLoopLines.Count) QmlErrors=$($qmlErrorLines.Count)"
Write-Host "Log=$logPath"

if (-not $exitedNaturally -or $exitCode -ne 0 -or $bindingLoopLines.Count -ne 0 -or $layoutLoopLines.Count -ne 0 -or $qmlErrorLines.Count -ne 0) {
    Write-Host "Standalone verification failed." -ForegroundColor Red
    exit 1
}

Write-Host "Standalone verification passed." -ForegroundColor Green
