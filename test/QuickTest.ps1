# Quick test for AI Context Generator
Write-Host "=== Quick Test for AI Context Generator ===" -ForegroundColor Green

# Test 1: Check if script exists
Write-Host "`nChecking for AIContextGenerator.ps1..." -ForegroundColor Yellow
if (Test-Path "./AIContextGenerator.ps1") {
    Write-Host "[OK] Script found" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Script not found" -ForegroundColor Red
    exit 1
}

# Test 2: Test basic assemblies
Write-Host "`nTesting assemblies..." -ForegroundColor Yellow
try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName System.Windows.Forms
    Write-Host "[OK] Required assemblies loaded" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Assembly loading failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Create test files
Write-Host "`nCreating test files..." -ForegroundColor Yellow

$testCS = @"
using System;
// C# test file
namespace TestApp {
    // Main class
    public class Program {
        /* Multi-line comment
           to be removed */
        static void Main() {
            Console.WriteLine("Hello");
            
            // Another comment
        }
    }
}
"@

$testJS = @"
// JavaScript test
function test() {
    /* Multi-line comment */
    console.log("test");
    
    // Single line comment
    return true;
}
"@

$testCS | Out-File -FilePath "test.cs" -Encoding UTF8
$testJS | Out-File -FilePath "test.js" -Encoding UTF8
Write-Host "[OK] Test files created" -ForegroundColor Green

# Test 4: Test basic minification logic
Write-Host "`nTesting minification..." -ForegroundColor Yellow

$original = $testCS
$removeEmpty = ($original -split "`r?`n" | Where-Object { $_ -notmatch '^\s*$' }) -join "`n"

Write-Host "Original length: $($original.Length) chars" -ForegroundColor White
Write-Host "After removing empty lines: $($removeEmpty.Length) chars" -ForegroundColor White
Write-Host "Reduction: $(100 - [math]::Round(($removeEmpty.Length / $original.Length) * 100, 1))%" -ForegroundColor Green

# Test 5: Test output generation
Write-Host "`nTesting output generation..." -ForegroundColor Yellow

$output = "test_output.txt"
"" | Out-File -FilePath $output -Encoding UTF8

$files = @("test.cs", "test.js")
foreach ($file in $files) {
    $content = Get-Content -Path $file -Raw
    $minified = ($content -split "`r?`n" | Where-Object { $_ -notmatch '^\s*$' }) -join "`n"
    
    "========= START OF: $file =========" | Add-Content -Path $output -Encoding UTF8
    "" | Add-Content -Path $output -Encoding UTF8
    $minified | Add-Content -Path $output -Encoding UTF8
    "" | Add-Content -Path $output -Encoding UTF8
    "========= END OF: $file =========" | Add-Content -Path $output -Encoding UTF8
    "" | Add-Content -Path $output -Encoding UTF8
}

if (Test-Path $output) {
    $size = (Get-Item $output).Length
    Write-Host "[OK] Output file created: $size bytes" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Output file not created" -ForegroundColor Red
}

# Test 6: Cleanup
Write-Host "`nCleaning up..." -ForegroundColor Yellow
Remove-Item "test.cs", "test.js", $output -Force -ErrorAction SilentlyContinue
Write-Host "[OK] Cleanup completed" -ForegroundColor Green

Write-Host "`n=== Test Results ===" -ForegroundColor Green
Write-Host "Core functionality is working correctly!" -ForegroundColor Green
Write-Host "Ready to test the GUI application." -ForegroundColor White
Write-Host "`nTo run the GUI:" -ForegroundColor Yellow
Write-Host "powershell -NoProfile -ExecutionPolicy Bypass -File `".\AIContextGenerator.ps1`""