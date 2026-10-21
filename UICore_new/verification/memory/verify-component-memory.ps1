param(
    [string]$BuildDirectory = "build",
    [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
    [string]$Configuration = "Release",
    [string]$QtBin,
    [ValidateRange(2, 4096)]
    [int]$ManyCount = 256,
    [ValidateRange(1, 9)]
    [int]$ControlRuns = 3,
    [string[]]$Component,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
if (-not ([System.Management.Automation.PSTypeName]"UICoreMemoryNative").Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class UICoreMemoryNative
{
    [DllImport("psapi.dll", SetLastError = true)]
    private static extern bool QueryWorkingSet(IntPtr hProcess, IntPtr pv,
        int cb);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter,
        int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public static long GetPrivateWorkingSet(IntPtr processHandle)
    {
        const int bufferSize = 16 * 1024 * 1024;
        IntPtr buffer = Marshal.AllocHGlobal(bufferSize);
        try
        {
            if (!QueryWorkingSet(processHandle, buffer, bufferSize))
                throw new System.ComponentModel.Win32Exception();
            long entryCount = Marshal.ReadIntPtr(buffer).ToInt64();
            long privatePages = 0;
            for (long i = 0; i < entryCount; ++i)
            {
                ulong flags = unchecked((ulong)Marshal.ReadIntPtr(
                    buffer, checked((int)((i + 1) * IntPtr.Size))).ToInt64());
                if ((flags & (1UL << 8)) == 0)
                    ++privatePages;
            }
            return privatePages * Environment.SystemPageSize;
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }
}
"@
}

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
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
$qtCoreEntry = $cacheLines |
    Where-Object { $_ -like "Qt5Core_DIR:PATH=*" } |
    Select-Object -First 1
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

if (-not $SkipBuild) {
    $buildArguments = @(
        "--build", $buildPath,
        "--config", $Configuration,
        "--target", "UICoreMemoryVerification"
    )
    Write-Host "cmake $($buildArguments -join ' ')"
    & cmake @buildArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed with exit code $LASTEXITCODE"
    }
}

$executableCandidates = @(
    (Join-Path (Join-Path (Join-Path $buildPath "verification") $Configuration) "UICoreMemoryVerification.exe"),
    (Join-Path (Join-Path $buildPath "verification") "UICoreMemoryVerification.exe"),
    (Join-Path (Join-Path $buildPath $Configuration) "UICoreMemoryVerification.exe"),
    (Join-Path $buildPath "UICoreMemoryVerification.exe")
)
$executablePath = $executableCandidates |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if (-not $executablePath) {
    throw "UICoreMemoryVerification.exe not found for configuration $Configuration"
}
$executablePath = (Resolve-Path -LiteralPath $executablePath).Path

$components = @(Import-Csv -LiteralPath (Join-Path $PSScriptRoot "components.csv"))
if ($Component.Count -gt 0) {
    $unknownComponents = @($Component | Where-Object { $_ -notin $components.Name })
    if ($unknownComponents.Count -gt 0) {
        throw "Unknown component: $($unknownComponents -join ', ')"
    }
    $components = @($components | Where-Object { $_.Name -in $Component })
}

$harnessPath = (Resolve-Path -LiteralPath (
    Join-Path $PSScriptRoot "ComponentMemoryHarness.qml")).Path
$leftScreen = [System.Windows.Forms.Screen]::AllScreens |
    Sort-Object { $_.Bounds.X } |
    Select-Object -First 1
$startedAt = Get-Date
$resultDirectory = Join-Path $buildPath (
    "verification/component-memory/{0}" -f $startedAt.ToString("yyyyMMdd-HHmmss"))
[void](New-Item -ItemType Directory -Path $resultDirectory -Force)

function Measure-PrivateWorkingSet([System.Diagnostics.Process]$process)
{
    $values = for ($index = 0; $index -lt 5; ++$index) {
        $process.Refresh()
        [UICoreMemoryNative]::GetPrivateWorkingSet($process.Handle) / 1MB
        Start-Sleep -Milliseconds 100
    }
    ($values | Measure-Object -Average).Average
}

function Get-Median([double[]]$values)
{
    $sorted = @($values | Sort-Object)
    if ($sorted.Count % 2 -eq 1) {
        return $sorted[[Math]::Floor($sorted.Count / 2)]
    }
    ($sorted[$sorted.Count / 2 - 1] + $sorted[$sorted.Count / 2]) / 2
}

function Invoke-MemoryTest(
    [string]$name,
    [string]$url,
    [int]$count,
    [string]$runId,
    [string]$profile = "",
    [string]$preloadUrl = "")
{
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $executablePath
    $startInfo.WorkingDirectory = Split-Path -Parent $executablePath
    $startInfo.Arguments = "--component-name=$name --component-url=$url --component-count=$count --component-profile=$profile --preload-url=$preloadUrl --harness=`"$harnessPath`""
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables["PATH"] = "$qtBinPath;$($startInfo.EnvironmentVariables['PATH'])"
    $startInfo.EnvironmentVariables["QT_PLUGIN_PATH"] = Join-Path (Split-Path -Parent $qtBinPath) "plugins"
    $startInfo.EnvironmentVariables["QT_FORCE_STDERR_LOGGING"] = "1"

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    try {
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while ($process.MainWindowHandle -eq [IntPtr]::Zero -and -not $process.HasExited) {
            if ([DateTime]::UtcNow -ge $deadline) {
                throw "$name/$count did not create a main window"
            }
            Start-Sleep -Milliseconds 100
            $process.Refresh()
        }
        if ($process.HasExited) {
            throw "$name/$count exited with code $($process.ExitCode)"
        }

        $bounds = $leftScreen.WorkingArea
        [void][UICoreMemoryNative]::SetWindowPos(
            $process.MainWindowHandle, [IntPtr]::Zero,
            $bounds.X + 20, $bounds.Y + 20,
            [Math]::Min(1600, $bounds.Width - 40),
            [Math]::Min(900, $bounds.Height - 40),
            0x0040)
        [void][UICoreMemoryNative]::ShowWindow($process.MainWindowHandle, 5)
        Start-Sleep -Seconds 4

        $before = Measure-PrivateWorkingSet $process
        Start-Sleep -Seconds 3
        $after = Measure-PrivateWorkingSet $process
        [PSCustomObject]@{
            Component = $name
            Count = $count
            RunId = $runId
            BeforeMB = [Math]::Round($before, 2)
            AfterMB = [Math]::Round($after, 2)
            DeltaMB = [Math]::Round($after - $before, 2)
            Error = ""
        }
    } finally {
        if (-not $process.HasExited) {
            $process.Kill()
            $process.WaitForExit()
        }
        $stdoutTask.Result | Set-Content -LiteralPath (
            Join-Path $resultDirectory "$runId.stdout.log") -Encoding UTF8
        $stderrTask.Result | Set-Content -LiteralPath (
            Join-Path $resultDirectory "$runId.stderr.log") -Encoding UTF8
        $process.Dispose()
    }
}

$controls = for ($repeat = 1; $repeat -le $ControlRuns; ++$repeat) {
    $result = Invoke-MemoryTest "EmptyScene" "" 0 "empty-$repeat"
    $result
    Write-Host ("empty #{0}: {1:N2} -> {2:N2} MiB ({3:+0.00;-0.00;0.00})" -f
        $repeat, $result.BeforeMB, $result.AfterMB, $result.DeltaMB)
}
$empty = Get-Median @($controls | Select-Object -ExpandProperty BeforeMB)
$drift = Get-Median @($controls | Select-Object -ExpandProperty DeltaMB)

foreach ($componentItem in $components) {
    [void](Invoke-MemoryTest $componentItem.Name $componentItem.Url 1 `
        "warmup-$($componentItem.Name)" $componentItem.Profile $componentItem.PreloadUrl)
    Write-Host "warmed $($componentItem.Name)"
}

$results = foreach ($count in @(1, $ManyCount)) {
    foreach ($componentItem in $components) {
        $runId = "$($componentItem.Name)-$count"
        try {
            $result = Invoke-MemoryTest $componentItem.Name $componentItem.Url $count `
                $runId $componentItem.Profile $componentItem.PreloadUrl
            $log = Get-Content -Raw -LiteralPath (
                Join-Path $resultDirectory "$runId.stderr.log")
            if ($log -match "COMPONENT_TEST_(LOAD|CREATE)_ERROR|QQmlApplicationEngine failed") {
                $result.Error = ($log -replace "\r?\n", " ").Trim()
            }
        } catch {
            $result = [PSCustomObject]@{
                Component = $componentItem.Name
                Count = $count
                RunId = $runId
                BeforeMB = [double]::NaN
                AfterMB = [double]::NaN
                DeltaMB = [double]::NaN
                Error = $_.Exception.Message
            }
        }
        $result
        Write-Host ("{0} x{1}: {2:N2} -> {3:N2} MiB, delta {4:+0.00;-0.00;0.00} MiB{5}" -f
            $componentItem.Name, $count, $result.BeforeMB, $result.AfterMB,
            $result.DeltaMB, $(if ($result.Error.Length -gt 0) { " ERROR" } else { "" }))
    }
}
@($controls) + @($results) | Export-Csv -LiteralPath (
    Join-Path $resultDirectory "raw.csv") -NoTypeInformation -Encoding UTF8

$summary = foreach ($componentItem in $components) {
    $one = $results | Where-Object {
        $_.Component -eq $componentItem.Name -and $_.Count -eq 1
    } | Select-Object -First 1
    $many = $results | Where-Object {
        $_.Component -eq $componentItem.Name -and $_.Count -eq $ManyCount
    } | Select-Object -First 1
    $firstInstance = $one.DeltaMB - $drift
    $manyInstances = $many.DeltaMB - $drift
    $increment = ($manyInstances - $firstInstance) * 1024 / ($ManyCount - 1)
    $allPageCount = [int]$componentItem.AllPageCount
    $allPageEstimate = if ($allPageCount -gt 0) {
        $firstInstance + ($allPageCount - 1) * $increment / 1024
    } else {
        0
    }
    [PSCustomObject]@{
        Component = $componentItem.Name
        Profile = $componentItem.Profile
        PreloadUrl = $componentItem.PreloadUrl
        Pages = $componentItem.Pages
        AllPageCount = $allPageCount
        EmptySceneMB = [Math]::Round($empty, 2)
        FirstInstanceMB = [Math]::Round($firstInstance, 2)
        OneInstanceProcessMB = [Math]::Round($empty + $firstInstance, 2)
        ManyCount = $ManyCount
        ManyInstancesMB = [Math]::Round($manyInstances, 2)
        ManyInstancesProcessMB = [Math]::Round($empty + $manyInstances, 2)
        IncrementPerInstanceKB = [Math]::Round($increment, 2)
        EstimatedAllPageMB = [Math]::Round($allPageEstimate, 2)
        Error = ($one.Error + " " + $many.Error).Trim()
    }
}
$summary | Export-Csv -LiteralPath (
    Join-Path $resultDirectory "summary.csv") -NoTypeInformation -Encoding UTF8
$summary | Sort-Object FirstInstanceMB -Descending | Export-Csv -LiteralPath (
    Join-Path $resultDirectory "ranked-first-instance.csv") -NoTypeInformation -Encoding UTF8
$summary | Sort-Object IncrementPerInstanceKB -Descending | Export-Csv -LiteralPath (
    Join-Path $resultDirectory "ranked-increment.csv") -NoTypeInformation -Encoding UTF8

$estimatedAllPage = ($summary | Measure-Object EstimatedAllPageMB -Sum).Sum
$estimatedAllPageProcess = $empty + $estimatedAllPage
$generatorEntry = $cacheLines |
    Where-Object { $_ -like "CMAKE_GENERATOR:*" } |
    Select-Object -First 1
$generator = if ($generatorEntry) { ($generatorEntry -split "=", 2)[1] } else { "unknown" }
$qtVersion = (& $qmakePath -query QT_VERSION).Trim()
$metadata = @(
    "StartedAt=$($startedAt.ToString('o'))",
    "Executable=$executablePath",
    "ExecutableSha256=$((Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash)",
    "Configuration=$Configuration",
    "Generator=$generator",
    "QtVersion=$qtVersion",
    "QtBin=$qtBinPath",
    "Screen=$($leftScreen.DeviceName) $($leftScreen.Bounds.Width)x$($leftScreen.Bounds.Height)@$($leftScreen.Bounds.X),$($leftScreen.Bounds.Y)",
    "PrivateWorkingSet=true",
    "QmlDiskCache=warm",
    "EmptySceneMB=$([Math]::Round($empty, 2))",
    "TimeDriftMB=$([Math]::Round($drift, 2))",
    "ManyCount=$ManyCount",
    "EstimatedAllPageMB=$([Math]::Round($estimatedAllPage, 2))",
    "EstimatedAllPageProcessMB=$([Math]::Round($estimatedAllPageProcess, 2))"
)
Set-Content -LiteralPath (Join-Path $resultDirectory "metadata.txt") -Value $metadata -Encoding UTF8

Write-Host "Empty scene median: $([Math]::Round($empty, 2)) MiB"
Write-Host "Time drift median: $([Math]::Round($drift, 2)) MiB"
Write-Host "Estimated all-page component memory: $([Math]::Round($estimatedAllPage, 2)) MiB"
Write-Host "Estimated all-page process memory: $([Math]::Round($estimatedAllPageProcess, 2)) MiB"
Write-Host "Results: $resultDirectory"
$summary |
    Sort-Object FirstInstanceMB -Descending |
    Format-Table Component,AllPageCount,FirstInstanceMB,IncrementPerInstanceKB,EstimatedAllPageMB,Error -AutoSize

if (@($summary | Where-Object { $_.Error.Length -gt 0 }).Count -gt 0) {
    exit 1
}
