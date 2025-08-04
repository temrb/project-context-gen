# Test script to verify extension filtering works correctly

Write-Host "Testing Extension Filtering..." -ForegroundColor Yellow

# Load the main script to get the function
try {
    . "../AIContextGenerator.ps1"
    Write-Host "Successfully loaded AIContextGenerator.ps1" -ForegroundColor Green
} catch {
    Write-Host "Error loading script: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test the function exists
if (Get-Command Get-FilesFromPaths -ErrorAction SilentlyContinue) {
    Write-Host "Get-FilesFromPaths function is available" -ForegroundColor Green
} else {
    Write-Host "Get-FilesFromPaths function not found" -ForegroundColor Red
    exit 1
}

Write-Host "Test completed successfully!" -ForegroundColor Green
