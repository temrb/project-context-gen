# Test script for minification functions
$testContent = @"
using System;
using System.Collections.Generic;

namespace TestNamespace
{
    // This is a test class
    public class TestClass
    {
        // A simple property
        public string Name { get; set; }
        
        /* This is a multi-line
           comment that should be
           removed in standard mode */
        public void TestMethod()
        {
            // Single line comment
            Console.WriteLine("Hello World");
            
            var list = new List<string>();
            
            
            // More comments here
        }
    }
}
"@

# Load the minification functions from the main script
$scriptPath = "./AIContextGenerator.ps1"
$scriptContent = Get-Content -Path $scriptPath -Raw

# Extract function definitions
$removeEmptyLinesMatch = [regex]::Match($scriptContent, 'function Remove-EmptyLines \{[^}]*\}[^}]*\}')
$removeCommentsMatch = [regex]::Match($scriptContent, 'function Remove-Comments \{[^}]*\}[^}]*\}')
$reduceIndentationMatch = [regex]::Match($scriptContent, 'function Reduce-Indentation \{[^}]*\}[^}]*\}')
$applyMinificationMatch = [regex]::Match($scriptContent, 'function Apply-Minification \{[^}]*\}[^}]*\}')

if ($removeEmptyLinesMatch.Success) {
    Invoke-Expression $removeEmptyLinesMatch.Value
}
if ($removeCommentsMatch.Success) {
    Invoke-Expression $removeCommentsMatch.Value
}
if ($reduceIndentationMatch.Success) {
    Invoke-Expression $reduceIndentationMatch.Value
}
if ($applyMinificationMatch.Success) {
    Invoke-Expression $applyMinificationMatch.Value
}

Write-Host "=== ORIGINAL CONTENT ==="
Write-Host $testContent

Write-Host "`n=== BASIC MINIFICATION ==="
$basic = Apply-Minification -Content $testContent -Level "Basic"
Write-Host $basic

Write-Host "`n=== STANDARD MINIFICATION ==="
$standard = Apply-Minification -Content $testContent -Level "Standard"
Write-Host $standard

Write-Host "`n=== AGGRESSIVE MINIFICATION ==="
$aggressive = Apply-Minification -Content $testContent -Level "Aggressive"
Write-Host $aggressive

Write-Host "`n=== TESTING FILE PROCESSING ==="
# Test with actual files
$testFiles = @("./test1.cs", "./test2.js")
foreach ($file in $testFiles) {
    if (Test-Path $file) {
        Write-Host "`nProcessing: $file"
        $content = Get-Content -Path $file -Raw
        $minified = Apply-Minification -Content $content -Level "Standard"
        Write-Host "Original length: $($content.Length)"
        Write-Host "Minified length: $($minified.Length)"
        Write-Host "Reduction: $(100 - [math]::Round(($minified.Length / $content.Length) * 100, 1))%"
    }
}