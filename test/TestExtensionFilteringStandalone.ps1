# Function-only test for extension filtering
function Get-FilesFromPaths {
    param(
        [array]$Paths,
        [string]$IncludeFilter,
        [string]$ExcludeFilter
    )

    $allFiles = @()
    $originalCount = 0
    $excludedCount = 0

    foreach ($path in $Paths) {
        if (Test-Path $path) {
            if ((Get-Item $path).PSIsContainer) {
                # It's a folder - get all files recursively
                $allFiles += Get-ChildItem -Path $path -Recurse -File
            } else {
                # It's a file
                $allFiles += Get-Item $path
            }
        }
    }

    $originalCount = $allFiles.Count

    # Apply include filter
    if (-not [string]::IsNullOrWhiteSpace($IncludeFilter)) {
        $includePatterns = $IncludeFilter -split ',' | ForEach-Object { $_.Trim() }
        $filteredFiles = @()
        foreach ($pattern in $includePatterns) {
            if ($pattern.StartsWith('*.')) {
                $extension = $pattern.Substring(1)  # Remove the * (keeps the dot)
                $filteredFiles += $allFiles | Where-Object { $_.Extension -eq $extension }
            } else {
                $filteredFiles += $allFiles | Where-Object { $_.Name -like $pattern }
            }
        }
        $allFiles = $filteredFiles | Sort-Object FullName -Unique
    }

    $afterIncludeCount = $allFiles.Count

    # Apply exclude filter
    if (-not [string]::IsNullOrWhiteSpace($ExcludeFilter)) {
        $excludePatterns = $ExcludeFilter -split ',' | ForEach-Object { $_.Trim() }
        $beforeExcludeCount = $allFiles.Count
        foreach ($pattern in $excludePatterns) {
            if ($pattern.StartsWith('*.')) {
                $extension = $pattern.Substring(1)  # Remove the * (keeps the dot)
                $allFiles = $allFiles | Where-Object { $_.Extension -ne $extension }
            } else {
                $allFiles = $allFiles | Where-Object { $_.Name -notlike $pattern }
            }
        }
        $excludedCount = $beforeExcludeCount - $allFiles.Count
    }

    return @{
        Files = ($allFiles | Sort-Object FullName)
        OriginalCount = $originalCount
        AfterIncludeCount = $afterIncludeCount
        ExcludedCount = $excludedCount
        FinalCount = $allFiles.Count
    }
}

Write-Host "Testing Extension Filtering..." -ForegroundColor Yellow
Write-Host ""

# Create test directory structure
$testDir = "TestExtensions"
if (Test-Path $testDir) {
    Remove-Item -Path $testDir -Recurse -Force
}
New-Item -ItemType Directory -Path $testDir | Out-Null

# Create test files with different extensions
$testFiles = @(
    "$testDir\test.cs",
    "$testDir\test.js",
    "$testDir\test.py",
    "$testDir\test.ts",
    "$testDir\test.tsx",
    "$testDir\test.jsx",
    "$testDir\test.mdx",
    "$testDir\test.exe",
    "$testDir\test.dll",
    "$testDir\test.bin",
    "$testDir\test.svg",
    "$testDir\test.ico",
    "$testDir\test.txt",
    "$testDir\README.md"
)

foreach ($file in $testFiles) {
    "// Test content" | Out-File -FilePath $file -Encoding UTF8
}

Write-Host "Created test files:" -ForegroundColor Green
$testFiles | ForEach-Object { Write-Host "  $_" }
Write-Host ""

# Test 1: Include filter only
Write-Host "Test 1: Include filter - '*.cs, *.js, *.py'" -ForegroundColor Cyan
$result1 = Get-FilesFromPaths -Paths @($testDir) -IncludeFilter "*.cs, *.js, *.py" -ExcludeFilter ""
Write-Host "Found files:" -ForegroundColor Green
$result1.Files | ForEach-Object { Write-Host "  $($_.Name)" }
Write-Host "Stats: Original=$($result1.OriginalCount), Final=$($result1.FinalCount), Excluded=$($result1.ExcludedCount)" -ForegroundColor Blue
Write-Host "Expected: test.cs, test.js, test.py" -ForegroundColor Yellow
Write-Host ""

# Test 2: Exclude filter only
Write-Host "Test 2: Exclude filter - '*.exe, *.dll, *.bin'" -ForegroundColor Cyan
$result2 = Get-FilesFromPaths -Paths @($testDir) -IncludeFilter "" -ExcludeFilter "*.exe, *.dll, *.bin"
Write-Host "Found files:" -ForegroundColor Green
$result2.Files | ForEach-Object { Write-Host "  $($_.Name)" }
Write-Host "Stats: Original=$($result2.OriginalCount), Final=$($result2.FinalCount), Excluded=$($result2.ExcludedCount)" -ForegroundColor Blue
Write-Host "Expected: Everything except test.exe, test.dll, test.bin" -ForegroundColor Yellow
Write-Host ""

# Test 3: Both include and exclude filters
Write-Host "Test 3: Include '*.cs, *.js, *.py, *.ts, *.tsx, *.jsx, *.mdx' + Exclude '*.exe, *.dll, *.bin, *.svg, *.ico'" -ForegroundColor Cyan
$result3 = Get-FilesFromPaths -Paths @($testDir) -IncludeFilter "*.cs, *.js, *.py, *.ts, *.tsx, *.jsx, *.mdx" -ExcludeFilter "*.exe, *.dll, *.bin, *.svg, *.ico"
Write-Host "Found files:" -ForegroundColor Green
$result3.Files | ForEach-Object { Write-Host "  $($_.Name)" }
Write-Host "Stats: Original=$($result3.OriginalCount), Final=$($result3.FinalCount), Excluded=$($result3.ExcludedCount)" -ForegroundColor Blue
Write-Host "Expected: test.cs, test.js, test.py, test.ts, test.tsx, test.jsx, test.mdx" -ForegroundColor Yellow
Write-Host ""

# Test 4: No filters
Write-Host "Test 4: No filters (should get all files)" -ForegroundColor Cyan
$result4 = Get-FilesFromPaths -Paths @($testDir) -IncludeFilter "" -ExcludeFilter ""
Write-Host "Found files:" -ForegroundColor Green
$result4.Files | ForEach-Object { Write-Host "  $($_.Name)" }
Write-Host "Stats: Original=$($result4.OriginalCount), Final=$($result4.FinalCount), Excluded=$($result4.ExcludedCount)" -ForegroundColor Blue
Write-Host "Expected: All files" -ForegroundColor Yellow
Write-Host ""

# Test 5: All files excluded scenario
Write-Host "Test 5: Include '*.cs, *.js' + Exclude '*.cs, *.js' (all matching files excluded)" -ForegroundColor Cyan
$result5 = Get-FilesFromPaths -Paths @($testDir) -IncludeFilter "*.cs, *.js" -ExcludeFilter "*.cs, *.js"
Write-Host "Found files:" -ForegroundColor Green
if ($result5.FinalCount -eq 0) {
    Write-Host "  (No files found)" -ForegroundColor Red
} else {
    $result5.Files | ForEach-Object { Write-Host "  $($_.Name)" }
}
Write-Host "Stats: Original=$($result5.OriginalCount), AfterInclude=$($result5.AfterIncludeCount), Final=$($result5.FinalCount), Excluded=$($result5.ExcludedCount)" -ForegroundColor Blue
Write-Host "Expected: No files (all excluded)" -ForegroundColor Yellow
Write-Host ""

# Cleanup
Remove-Item -Path $testDir -Recurse -Force

Write-Host "Test completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "- Test 1 should show only: test.cs, test.js, test.py"
Write-Host "- Test 2 should show all files except: test.exe, test.dll, test.bin"
Write-Host "- Test 3 should show only: test.cs, test.js, test.py, test.ts, test.tsx, test.jsx, test.mdx"
Write-Host "- Test 4 should show all files"
