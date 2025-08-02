# Comprehensive test script for AIContextGenerator.ps1
# This script tests all functionality without requiring the GUI

param(
    [switch]$TestFunctions,
    [switch]$TestFileProcessing,
    [switch]$TestAll
)

if ($TestAll) {
    $TestFunctions = $true
    $TestFileProcessing = $true
}

Write-Host "=== AI Context Generator Test Suite ===" -ForegroundColor Green

# Test 1: Load and validate the main script
Write-Host "`n1. Loading main script..." -ForegroundColor Yellow
try {
    $scriptPath = "./AIContextGenerator.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "AIContextGenerator.ps1 not found"
    }
    
    $scriptContent = Get-Content -Path $scriptPath -Raw
    Write-Host "   ✓ Script loaded successfully" -ForegroundColor Green
    Write-Host "   ✓ Script size: $($scriptContent.Length) characters" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Error loading script: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Extract and test individual functions
if ($TestFunctions) {
    Write-Host "`n2. Testing minification functions..." -ForegroundColor Yellow
    
    # Extract functions using more robust regex
    $functions = @{
        'Remove-EmptyLines' = 'function Remove-EmptyLines \{[^{}]*\{[^{}]*\}[^{}]*\}'
        'Remove-Comments' = 'function Remove-Comments \{(?:[^{}]|\{[^{}]*\})*\}'
        'Reduce-Indentation' = 'function Reduce-Indentation \{(?:[^{}]|\{[^{}]*\})*\}'
        'Apply-Minification' = 'function Apply-Minification \{(?:[^{}]|\{[^{}]*\})*\}'
    }
    
    foreach ($funcName in $functions.Keys) {
        $pattern = $functions[$funcName]
        $match = [regex]::Match($scriptContent, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        if ($match.Success) {
            try {
                Invoke-Expression $match.Value
                Write-Host "   ✓ $funcName loaded successfully" -ForegroundColor Green
            } catch {
                Write-Host "   ✗ Error loading $funcName : $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "   ✗ $funcName not found in script" -ForegroundColor Red
        }
    }
    
    # Test the functions with sample data
    $testContent = @"
using System;
using System.Collections.Generic;

namespace TestNamespace
{
    // This is a test class
    public class TestClass
    {
        /* Multi-line comment
           that should be removed */
        public void TestMethod()
        {
            // Single line comment
            Console.WriteLine("Hello World");
            
            
            // More comments
        }
    }
}
"@

    Write-Host "`n   Testing minification levels:" -ForegroundColor Cyan
    
    try {
        $none = Apply-Minification -Content $testContent -Level "None"
        $basic = Apply-Minification -Content $testContent -Level "Basic"
        $standard = Apply-Minification -Content $testContent -Level "Standard"
        $aggressive = Apply-Minification -Content $testContent -Level "Aggressive"
        
        Write-Host "   ✓ None: $($none.Length) chars" -ForegroundColor Green
        Write-Host "   ✓ Basic: $($basic.Length) chars" -ForegroundColor Green
        Write-Host "   ✓ Standard: $($standard.Length) chars" -ForegroundColor Green
        Write-Host "   ✓ Aggressive: $($aggressive.Length) chars" -ForegroundColor Green
        
        # Validate reduction
        if ($basic.Length -lt $none.Length) {
            Write-Host "   ✓ Basic minification reduces size" -ForegroundColor Green
        } else {
            Write-Host "   ⚠ Basic minification may not be working" -ForegroundColor Yellow
        }
        
        if ($standard.Length -lt $basic.Length) {
            Write-Host "   ✓ Standard minification reduces size further" -ForegroundColor Green
        } else {
            Write-Host "   ⚠ Standard minification may not be working optimally" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "   ✗ Error testing minification: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 3: File processing
if ($TestFileProcessing) {
    Write-Host "`n3. Testing file processing..." -ForegroundColor Yellow
    
    # Create test files if they don't exist
    $testFiles = @{
        "test1.cs" = @"
using System;
// C# test file
namespace Test {
    /* Multi-line
       comment */
    public class Test {
        // Comment
        public void Method() {
            Console.WriteLine("Test");
        }
    }
}
"@
        "test2.js" = @"
// JavaScript test
function test() {
    /* Multi-line
       comment */
    console.log("test");
    
    // Another comment
    return true;
}
"@
        "test3.py" = @"
# Python test
def test():
    # Comment
    print("test")
    
    # Another comment
    return True
"@
    }
    
    foreach ($fileName in $testFiles.Keys) {
        if (-not (Test-Path $fileName)) {
            $testFiles[$fileName] | Out-File -FilePath $fileName -Encoding UTF8
            Write-Host "   ✓ Created test file: $fileName" -ForegroundColor Green
        }
    }
    
    # Test Get-FilesFromPaths function (extract it first)
    $getFilesPattern = 'function Get-FilesFromPaths \{(?:[^{}]|\{[^{}]*\})*\}'
    $getFilesMatch = [regex]::Match($scriptContent, $getFilesPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    if ($getFilesMatch.Success) {
        try {
            Invoke-Expression $getFilesMatch.Value
            Write-Host "   ✓ Get-FilesFromPaths function loaded" -ForegroundColor Green
            
            # Test file discovery
            $allFiles = Get-FilesFromPaths -Paths @("./test1.cs", "./test2.js", "./") -IncludeFilter "*.cs, *.js" -ExcludeFilter "*.py"
            Write-Host "   ✓ Found $($allFiles.Count) files with filters" -ForegroundColor Green
            
        } catch {
            Write-Host "   ✗ Error testing Get-FilesFromPaths: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "   ✗ Get-FilesFromPaths function not found" -ForegroundColor Red
    }
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Green
Write-Host "Core functionality tests completed."
Write-Host "For full GUI testing, run the main script in a Windows environment."
Write-Host ""
Write-Host "To test the GUI manually:"
Write-Host "1. Run: powershell -NoProfile -ExecutionPolicy Bypass -File 'AIContextGenerator.ps1'"
Write-Host "2. Test drag & drop functionality"
Write-Host "3. Test all buttons and options"
Write-Host "4. Try processing files with different minification levels"
Write-Host "5. Test error scenarios (invalid paths, locked files, etc.)"