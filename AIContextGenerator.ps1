# AI Context Generator Tool
# Standalone PowerShell script with Windows Forms GUI for collecting and minifying source code
# Usage: .\AIContextGenerator.ps1 [-TestMode]

param(
    [switch]$TestMode
)

# Test function for validation (defined early for test mode)
function Test-AllFunctions {
    if ($TestMode) {
        Write-Host "Testing minification functions..." -ForegroundColor Yellow
        
        $testContent = @"
using System;
// Test comment
namespace Test {
    /* Multi-line
       comment */
    public class Test {
        public void Method() {
            Console.WriteLine("Test");
        }
    }
}
"@

        try {
            $none = Apply-Minification -Content $testContent -Level "None"
            $basic = Apply-Minification -Content $testContent -Level "Basic"
            $standard = Apply-Minification -Content $testContent -Level "Standard"
            $aggressive = Apply-Minification -Content $testContent -Level "Aggressive"
            
            Write-Host "[OK] None: $($none.Length) chars" -ForegroundColor Green
            Write-Host "[OK] Basic: $($basic.Length) chars" -ForegroundColor Green
            Write-Host "[OK] Standard: $($standard.Length) chars" -ForegroundColor Green
            Write-Host "[OK] Aggressive: $($aggressive.Length) chars" -ForegroundColor Green
            
            if ($standard.Length -lt $none.Length) {
                Write-Host "[OK] Minification working correctly" -ForegroundColor Green
            } else {
                Write-Host "[WARN] Minification may not be working" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "[ERROR] Error in minification functions: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Write-Host "Test completed." -ForegroundColor Green
    }
}

# If in test mode, run tests and exit
if ($TestMode) {
    Test-AllFunctions
    exit
}

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$global:fileList = @()
$global:isProcessing = $false
$global:form = $null

# Minification functions
function Remove-EmptyLines {
    param([string]$Content)
    if ([string]::IsNullOrEmpty($Content)) { return "" }
    $lines = $Content -split "`r?`n"
    $nonEmptyLines = $lines | Where-Object { $_ -notmatch '^\s*$' }
    return $nonEmptyLines -join "`n"
}

function Remove-Comments {
    param([string]$Content)
    
    # Split into lines for line-by-line processing
    $lines = $Content -split "`r?`n"
    $processedLines = @()
    
    foreach ($line in $lines) {
        # Remove single-line comments (// and #) but preserve URLs and other valid uses
        $line = $line -replace '(?<!:)//.*$', ''
        $line = $line -replace '(?<!\w)#.*$', ''
        $processedLines += $line
    }
    
    $result = $processedLines -join "`n"
    
    # Remove multi-line C-style comments (/* */)
    $result = $result -replace '(?s)/\*.*?\*/', ''
    
    # Remove HTML/XML comments (<!-- -->)
    $result = $result -replace '(?s)<!--.*?-->', ''
    
    return $result
}

function Reduce-Indentation {
    param([string]$Content)
    
    $lines = $Content -split "`n"
    $processedLines = @()
    
    foreach ($line in $lines) {
        if ($line -match '^\s+') {
            $processedLines += $line -replace '^\s+', ' '
        } else {
            $processedLines += $line
        }
    }
    
    return $processedLines -join "`n"
}

function Apply-Minification {
    param(
        [string]$Content,
        [string]$Level
    )
    
    switch ($Level) {
        "None" { return $Content }
        "Basic" { 
            return Remove-EmptyLines -Content $Content 
        }
        "Standard" { 
            $Content = Remove-EmptyLines -Content $Content
            return Remove-Comments -Content $Content
        }
        "Aggressive" { 
            $Content = Remove-EmptyLines -Content $Content
            $Content = Remove-Comments -Content $Content
            return Reduce-Indentation -Content $Content
        }
        default { return $Content }
    }
}

# File processing functions
function Get-FilesFromPaths {
    param(
        [array]$Paths,
        [string]$IncludeFilter,
        [string]$ExcludeFilter
    )
    
    $allFiles = @()
    
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
    
    # Apply include filter
    if (-not [string]::IsNullOrWhiteSpace($IncludeFilter)) {
        $includePatterns = $IncludeFilter -split ',' | ForEach-Object { $_.Trim() }
        $filteredFiles = @()
        foreach ($pattern in $includePatterns) {
            if ($pattern.StartsWith('*.')) {
                $extension = $pattern.Substring(1)  # Remove the *
                $filteredFiles += $allFiles | Where-Object { $_.Extension -eq $extension }
            } else {
                $filteredFiles += $allFiles | Where-Object { $_.Name -like $pattern }
            }
        }
        $allFiles = $filteredFiles | Sort-Object FullName -Unique
    }
    
    # Apply exclude filter
    if (-not [string]::IsNullOrWhiteSpace($ExcludeFilter)) {
        $excludePatterns = $ExcludeFilter -split ',' | ForEach-Object { $_.Trim() }
        foreach ($pattern in $excludePatterns) {
            if ($pattern.StartsWith('*.')) {
                $extension = $pattern.Substring(1)  # Remove the *
                $allFiles = $allFiles | Where-Object { $_.Extension -ne $extension }
            } else {
                $allFiles = $allFiles | Where-Object { $_.Name -notlike $pattern }
            }
        }
    }
    
    return $allFiles | Sort-Object FullName
}

# GUI Event handlers
function Add-Files {
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Multiselect = $true
    $openFileDialog.Title = "Select Files"
    $openFileDialog.Filter = "All Files (*.*)|*.*"
    
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($file in $openFileDialog.FileNames) {
            if ($global:fileList -notcontains $file) {
                $global:fileList += $file
            }
        }
        Update-FileList
    }
}

function Add-Folder {
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select Folder"
    
    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if ($global:fileList -notcontains $folderDialog.SelectedPath) {
            $global:fileList += $folderDialog.SelectedPath
        }
        Update-FileList
    }
}

function Remove-Selected {
    $selectedItems = @($global:form.Controls["FileListBox"].SelectedItems)
    if ($selectedItems.Count -gt 0) {
        foreach ($item in $selectedItems) {
            $global:fileList = $global:fileList | Where-Object { $_ -ne $item.ToString() }
        }
        Update-FileList
    }
}

function Clear-All {
    $global:fileList = @()
    Update-FileList
}

function Update-FileList {
    $listBox = $global:form.Controls["FileListBox"]
    $listBox.Items.Clear()
    foreach ($item in $global:fileList) {
        $listBox.Items.Add($item) | Out-Null
    }
}

function Browse-OutputPath {
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Title = "Select Output File"
    $saveFileDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    $saveFileDialog.DefaultExt = "txt"
    $saveFileDialog.FileName = "GeneratedContext.txt"
    
    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:form.Controls["OutputPathBox"].Text = $saveFileDialog.FileName
    }
}

function Start-Processing {
    if ($global:isProcessing) { return }
    
    $global:isProcessing = $true
    $generateBtn = $global:form.Controls["GenerateBtn"]
    $statusLabel = $global:form.Controls["StatusLabel"]
    $progressBar = $global:form.Controls["ProgressBar"]
    
    # Disable button and update status
    $generateBtn.Enabled = $false
    $statusLabel.Text = "Initializing..."
    $statusLabel.ForeColor = [System.Drawing.Color]::Black
    $progressBar.Value = 0
    
    # Get configuration
    $outputPath = $global:form.Controls["OutputPathBox"].Text
    $includeFilter = $global:form.Controls["IncludeExtBox"].Text
    $excludeFilter = $global:form.Controls["ExcludeExtBox"].Text
    
    # Determine minification level
    $minifyLevel = "None"
    if ($global:form.Controls["MinifyBasic"].Checked) { $minifyLevel = "Basic" }
    elseif ($global:form.Controls["MinifyStandard"].Checked) { $minifyLevel = "Standard" }
    elseif ($global:form.Controls["MinifyAggressive"].Checked) { $minifyLevel = "Aggressive" }
    
    try {
        # Validate input
        if ($global:fileList.Count -eq 0) {
            throw "No files or folders selected for processing."
        }
        
        # Validate output path
        if ([string]::IsNullOrWhiteSpace($outputPath)) {
            throw "Output path cannot be empty."
        }
        
        # Get all files to process
        $statusLabel.Text = "Building file list..."
        $global:form.Refresh()
        
        $filesToProcess = Get-FilesFromPaths -Paths $global:fileList -IncludeFilter $includeFilter -ExcludeFilter $excludeFilter
        
        if ($filesToProcess.Count -eq 0) {
            throw "No files found to process. Check your include/exclude filters."
        }
        
        
        # Clear output file
        "" | Out-File -FilePath $outputPath -Encoding UTF8
        
        # Process files
        for ($i = 0; $i -lt $filesToProcess.Count; $i++) {
            $file = $filesToProcess[$i]
            $fileName = $file.Name
            $statusLabel.Text = "Processing $fileName... ($($i+1)/$($filesToProcess.Count))"
            $progressBar.Value = [math]::Round((($i + 1) / $filesToProcess.Count) * 100)
            
            # Update UI
            $global:form.Refresh()
            [System.Windows.Forms.Application]::DoEvents()
            
            try {
                # Read file content
                $content = ""
                if ((Get-Item $file.FullName).Length -eq 0) {
                    $content = "[Empty File]"
                } else {
                    try {
                        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
                        if ([string]::IsNullOrEmpty($content)) {
                            $content = "[Empty File]"
                        }
                    } catch {
                        $content = "[Error reading file: $($_.Exception.Message)]"
                    }
                }
                
                # Apply minification
                $processedContent = Apply-Minification -Content $content -Level $minifyLevel
                
                # Create separator and append to output
                $separator = "========= START OF: $($file.FullName) ========="
                $endSeparator = "========= END OF: $($file.FullName) ========="
                
                $separator | Add-Content -Path $outputPath -Encoding UTF8
                "" | Add-Content -Path $outputPath -Encoding UTF8
                $processedContent | Add-Content -Path $outputPath -Encoding UTF8
                "" | Add-Content -Path $outputPath -Encoding UTF8
                $endSeparator | Add-Content -Path $outputPath -Encoding UTF8
                "" | Add-Content -Path $outputPath -Encoding UTF8
                
            } catch {
                # Log error but continue processing
                $errorMsg = "ERROR processing $($file.FullName): $($_.Exception.Message)"
                $errorMsg | Add-Content -Path $outputPath -Encoding UTF8
                "" | Add-Content -Path $outputPath -Encoding UTF8
            }
        }
        
        # Completion
        $progressBar.Value = 100
        $statusLabel.Text = "Done! Generated: $outputPath"
        $statusLabel.ForeColor = [System.Drawing.Color]::Green
        
        # Show completion message but don't close the application
        [System.Windows.Forms.MessageBox]::Show("Context generation completed successfully!`n`nOutput saved to: $outputPath", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        
        # Create timer to reset UI after 3 seconds
        $resetTimer = New-Object System.Windows.Forms.Timer
        $resetTimer.Interval = 3000  # 3 seconds
        $resetTimer.Add_Tick({
            $global:form.Controls["StatusLabel"].Text = "Ready"
            $global:form.Controls["StatusLabel"].ForeColor = [System.Drawing.Color]::Black
            $global:form.Controls["ProgressBar"].Value = 0
            $this.Stop()
            $this.Dispose()
        })
        $resetTimer.Start()
        
    } catch {
        $statusLabel.Text = "Error: $($_.Exception.Message)"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        
        # Create timer to reset UI after error display (3 seconds)
        $resetTimer = New-Object System.Windows.Forms.Timer
        $resetTimer.Interval = 3000  # 3 seconds
        $resetTimer.Add_Tick({
            $global:form.Controls["StatusLabel"].Text = "Ready"
            $global:form.Controls["StatusLabel"].ForeColor = [System.Drawing.Color]::Black
            $global:form.Controls["ProgressBar"].Value = 0
            $this.Stop()
            $this.Dispose()
        })
        $resetTimer.Start()
    } finally {
        $generateBtn.Enabled = $true
        $global:isProcessing = $false
    }
}

# Drag and drop handlers
function Handle-DragEnter {
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    } else {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::None
    }
}

function Handle-DragDrop {
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $files = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
        foreach ($file in $files) {
            if ($global:fileList -notcontains $file) {
                $global:fileList += $file
            }
        }
        Update-FileList
    }
}

# Create and show the form
try {
    # Create main form
    $global:form = New-Object System.Windows.Forms.Form
    $global:form.Text = "AI Context Generator"
    $global:form.Size = New-Object System.Drawing.Size(900, 520)
    $global:form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $global:form.MinimumSize = New-Object System.Drawing.Size(800, 500)
    $global:form.MaximizeBox = $false
    
    # Create controls
    
    # Left panel - File List
    $fileListLabel = New-Object System.Windows.Forms.Label
    $fileListLabel.Text = "Input Files and Folders:"
    $fileListLabel.Location = New-Object System.Drawing.Point(10, 10)
    $fileListLabel.Size = New-Object System.Drawing.Size(200, 20)
    $fileListLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    
    $fileListBox = New-Object System.Windows.Forms.ListBox
    $fileListBox.Name = "FileListBox"
    $fileListBox.Location = New-Object System.Drawing.Point(10, 35)
    $fileListBox.Size = New-Object System.Drawing.Size(400, 300)
    $fileListBox.AllowDrop = $true
    $fileListBox.SelectionMode = [System.Windows.Forms.SelectionMode]::MultiExtended
    $fileListBox.Add_DragEnter({ Handle-DragEnter @args })
    $fileListBox.Add_DragDrop({ Handle-DragDrop @args })
    
    # File management buttons
    $addFilesBtn = New-Object System.Windows.Forms.Button
    $addFilesBtn.Name = "AddFilesBtn"
    $addFilesBtn.Text = "Add Files"
    $addFilesBtn.Location = New-Object System.Drawing.Point(10, 345)
    $addFilesBtn.Size = New-Object System.Drawing.Size(80, 30)
    $addFilesBtn.Add_Click({ Add-Files })
    
    $addFolderBtn = New-Object System.Windows.Forms.Button
    $addFolderBtn.Name = "AddFolderBtn"
    $addFolderBtn.Text = "Add Folder"
    $addFolderBtn.Location = New-Object System.Drawing.Point(95, 345)
    $addFolderBtn.Size = New-Object System.Drawing.Size(80, 30)
    $addFolderBtn.Add_Click({ Add-Folder })
    
    $removeBtn = New-Object System.Windows.Forms.Button
    $removeBtn.Name = "RemoveBtn"
    $removeBtn.Text = "Remove"
    $removeBtn.Location = New-Object System.Drawing.Point(180, 345)
    $removeBtn.Size = New-Object System.Drawing.Size(70, 30)
    $removeBtn.Add_Click({ Remove-Selected })
    
    $clearBtn = New-Object System.Windows.Forms.Button
    $clearBtn.Name = "ClearBtn"
    $clearBtn.Text = "Clear All"
    $clearBtn.Location = New-Object System.Drawing.Point(255, 345)
    $clearBtn.Size = New-Object System.Drawing.Size(70, 30)
    $clearBtn.Add_Click({ Clear-All })
    
    # Right panel - Configuration
    $configLabel = New-Object System.Windows.Forms.Label
    $configLabel.Text = "Configuration:"
    $configLabel.Location = New-Object System.Drawing.Point(430, 10)
    $configLabel.Size = New-Object System.Drawing.Size(200, 20)
    $configLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    
    # Output path
    $outputLabel = New-Object System.Windows.Forms.Label
    $outputLabel.Text = "Output Path:"
    $outputLabel.Location = New-Object System.Drawing.Point(430, 40)
    $outputLabel.Size = New-Object System.Drawing.Size(100, 20)
    
    $outputPathBox = New-Object System.Windows.Forms.TextBox
    $outputPathBox.Name = "OutputPathBox"
    $outputPathBox.Location = New-Object System.Drawing.Point(430, 60)
    $outputPathBox.Size = New-Object System.Drawing.Size(350, 25)
    $outputPathBox.Text = [System.IO.Path]::Combine([Environment]::GetFolderPath("Desktop"), "GeneratedContext.txt")
    
    $browseBtn = New-Object System.Windows.Forms.Button
    $browseBtn.Name = "BrowseBtn"
    $browseBtn.Text = "Browse..."
    $browseBtn.Location = New-Object System.Drawing.Point(790, 60)
    $browseBtn.Size = New-Object System.Drawing.Size(80, 25)
    $browseBtn.Add_Click({ Browse-OutputPath })
    
    # Include extensions
    $includeLabel = New-Object System.Windows.Forms.Label
    $includeLabel.Text = "Include Extensions (*.cs, *.js, *.py):"
    $includeLabel.Location = New-Object System.Drawing.Point(430, 100)
    $includeLabel.Size = New-Object System.Drawing.Size(250, 20)
    
    $includeExtBox = New-Object System.Windows.Forms.TextBox
    $includeExtBox.Name = "IncludeExtBox"
    $includeExtBox.Location = New-Object System.Drawing.Point(430, 120)
    $includeExtBox.Size = New-Object System.Drawing.Size(440, 25)
    
    # Exclude extensions
    $excludeLabel = New-Object System.Windows.Forms.Label
    $excludeLabel.Text = "Exclude Extensions (*.exe, *.dll, *.bin):"
    $excludeLabel.Location = New-Object System.Drawing.Point(430, 155)
    $excludeLabel.Size = New-Object System.Drawing.Size(250, 20)
    
    $excludeExtBox = New-Object System.Windows.Forms.TextBox
    $excludeExtBox.Name = "ExcludeExtBox"
    $excludeExtBox.Location = New-Object System.Drawing.Point(430, 175)
    $excludeExtBox.Size = New-Object System.Drawing.Size(440, 25)
    
    # Minification options
    $minifyLabel = New-Object System.Windows.Forms.Label
    $minifyLabel.Text = "Minification Level:"
    $minifyLabel.Location = New-Object System.Drawing.Point(430, 210)
    $minifyLabel.Size = New-Object System.Drawing.Size(150, 20)
    $minifyLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    
    $minifyNone = New-Object System.Windows.Forms.RadioButton
    $minifyNone.Name = "MinifyNone"
    $minifyNone.Text = "None (Direct Copy)"
    $minifyNone.Location = New-Object System.Drawing.Point(430, 235)
    $minifyNone.Size = New-Object System.Drawing.Size(200, 25)
    
    $minifyBasic = New-Object System.Windows.Forms.RadioButton
    $minifyBasic.Name = "MinifyBasic"
    $minifyBasic.Text = "Basic (Remove Empty Lines)"
    $minifyBasic.Location = New-Object System.Drawing.Point(430, 265)
    $minifyBasic.Size = New-Object System.Drawing.Size(250, 25)
    
    $minifyStandard = New-Object System.Windows.Forms.RadioButton
    $minifyStandard.Name = "MinifyStandard"
    $minifyStandard.Text = "Standard (Remove Comments & Empty Lines)"
    $minifyStandard.Location = New-Object System.Drawing.Point(430, 295)
    $minifyStandard.Size = New-Object System.Drawing.Size(300, 25)
    $minifyStandard.Checked = $true
    
    $minifyAggressive = New-Object System.Windows.Forms.RadioButton
    $minifyAggressive.Name = "MinifyAggressive"
    $minifyAggressive.Text = "Aggressive (Standard + Reduce Indentation)"
    $minifyAggressive.Location = New-Object System.Drawing.Point(430, 325)
    $minifyAggressive.Size = New-Object System.Drawing.Size(350, 25)
    
    # Bottom panel - Processing
    $processLabel = New-Object System.Windows.Forms.Label
    $processLabel.Text = "Processing:"
    $processLabel.Location = New-Object System.Drawing.Point(10, 385)
    $processLabel.Size = New-Object System.Drawing.Size(100, 20)
    $processLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Name = "ProgressBar"
    $progressBar.Location = New-Object System.Drawing.Point(10, 405)
    $progressBar.Size = New-Object System.Drawing.Size(860, 20)
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Name = "StatusLabel"
    $statusLabel.Text = "Ready"
    $statusLabel.Location = New-Object System.Drawing.Point(10, 435)
    $statusLabel.Size = New-Object System.Drawing.Size(600, 25)
    $statusLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    
    $generateBtn = New-Object System.Windows.Forms.Button
    $generateBtn.Name = "GenerateBtn"
    $generateBtn.Text = "Generate Context"
    $generateBtn.Location = New-Object System.Drawing.Point(750, 430)
    $generateBtn.Size = New-Object System.Drawing.Size(120, 35)
    $generateBtn.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $generateBtn.BackColor = [System.Drawing.Color]::LightGreen
    $generateBtn.Add_Click({ Start-Processing })
    
    # Add all controls to form
    $global:form.Controls.AddRange(@(
        $fileListLabel, $fileListBox, $addFilesBtn, $addFolderBtn, $removeBtn, $clearBtn,
        $configLabel, $outputLabel, $outputPathBox, $browseBtn,
        $includeLabel, $includeExtBox, $excludeLabel, $excludeExtBox,
        $minifyLabel, $minifyNone, $minifyBasic, $minifyStandard, $minifyAggressive,
        $processLabel, $progressBar, $statusLabel, $generateBtn
    ))
    
    # Show form (this will keep the script running until form is closed)
    [System.Windows.Forms.Application]::Run($global:form)
    
} catch {
    # For EXE compatibility, don't output to console
    if ($TestMode) {
        Write-Error "Failed to initialize GUI: $($_.Exception.Message)"
        Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
        Read-Host "Press Enter to exit"
    } else {
        # Show error in a message box instead of console
        [System.Windows.Forms.MessageBox]::Show("Failed to initialize GUI: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}