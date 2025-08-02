# Simple test to verify the minification functions work
Write-Host "Testing minification functions..." -ForegroundColor Green

# Define test content
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

Write-Host "Original content length: $($testContent.Length) characters"
Write-Host "Original line count: $(($testContent -split "`n").Count) lines"

# Test basic empty line removal
$basicResult = ($testContent -split "`n" | Where-Object { $_ -notmatch '^\s*$' }) -join "`n"
Write-Host "After removing empty lines: $($basicResult.Length) characters"
Write-Host "Line count after basic: $(($basicResult -split "`n").Count) lines"

# Test comment removal
$lines = $basicResult -split "`r?`n"
$processedLines = @()

foreach ($line in $lines) {
    # Remove single-line comments
    $line = $line -replace '(?<!:)//.*$', ''
    $line = $line -replace '(?<!\w)#.*$', ''
    $processedLines += $line
}

$result = $processedLines -join "`n"
# Remove multi-line comments
$result = $result -replace '(?s)/\*.*?\*/', ''

Write-Host "After removing comments: $($result.Length) characters"
Write-Host "Reduction: $(100 - [math]::Round(($result.Length / $testContent.Length) * 100, 1))%"

Write-Host "`nSample of processed content:" -ForegroundColor Cyan
Write-Host $result.Substring(0, [math]::Min(300, $result.Length))

# Test with real files
Write-Host "`nTesting with real files:" -ForegroundColor Green
$files = Get-ChildItem -Include "*.cs", "*.js", "*.py" -Recurse | Select-Object -First 3

foreach ($file in $files) {
    if (Test-Path $file.FullName) {
        $content = Get-Content -Path $file.FullName -Raw
        $processed = ($content -split "`n" | Where-Object { $_ -notmatch '^\s*$' }) -join "`n"
        $reduction = 100 - [math]::Round(($processed.Length / $content.Length) * 100, 1)
        Write-Host "  $($file.Name): $($content.Length) -> $($processed.Length) chars ($reduction% reduction)"
    }
}

Write-Host "`nTo run the full application:" -ForegroundColor Yellow
Write-Host "powershell -NoProfile -ExecutionPolicy Bypass -File '.\AIContextGenerator.ps1'"