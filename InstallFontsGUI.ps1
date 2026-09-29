<#
.SYNOPSIS
    PowerShell GUI Tool - Install Fonts from a Selected Folder
    • XP Purple Theme + Fira Sans
    • Fully editable path textbox (paste supported)
    • Suppress notifications (silent install) checkbox
    • Fixed: FontUtils class loading issue
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ====================== FONT NAME EXTRACTOR (Fixed) ======================
$csharp = @"
using System;
using System.Drawing;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.IO;

public class FontUtils
{
    [DllImport("gdi32.dll", CharSet = CharSet.Auto)]
    public static extern int AddFontResource(string lpszFilename);

    [DllImport("user32.dll")]
    public static extern int SendMessage(IntPtr hWnd, uint Msg, int wParam, int lParam);

    public static string GetFontName(string filePath)
    {
        try
        {
            using (PrivateFontCollection pfc = new PrivateFontCollection())
            {
                pfc.AddFontFile(filePath);
                if (pfc.Families.Length > 0)
                    return pfc.Families[0].Name;
            }
        }
        catch { }
        return Path.GetFileNameWithoutExtension(filePath);
    }
}
"@

# Fixed Add-Type with proper reference
Add-Type -TypeDefinition $csharp -ReferencedAssemblies "System.Drawing.dll"

# ==================== FORM ====================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Font Installer"
$form.Size = New-Object System.Drawing.Size(720, 460)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(102, 51, 153)   # XP Purple

# Fira Sans Font
$firaRegular = New-Object System.Drawing.Font("Fira Sans", 10)
$firaBold    = New-Object System.Drawing.Font("Fira Sans", 10, [System.Drawing.FontStyle]::Bold)
$firaBig     = New-Object System.Drawing.Font("Fira Sans", 12, [System.Drawing.FontStyle]::Bold)

# ==================== CONTROLS ====================

$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = "Fonts Folder:"
$lblFolder.Location = New-Object System.Drawing.Point(20, 25)
$lblFolder.Size = New-Object System.Drawing.Size(110, 23)
$lblFolder.Font = $firaRegular
$lblFolder.ForeColor = "White"
$form.Controls.Add($lblFolder)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(140, 23)
$txtPath.Size = New-Object System.Drawing.Size(450, 28)
$txtPath.ReadOnly = $false
$txtPath.Font = New-Object System.Drawing.Font("Fira Sans", 10)
$form.Controls.Add($txtPath)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(600, 22)
$btnBrowse.Size = New-Object System.Drawing.Size(100, 30)
$btnBrowse.Font = $firaBold
$btnBrowse.BackColor = [System.Drawing.Color]::FromArgb(180, 120, 255)
$btnBrowse.ForeColor = "White"
$form.Controls.Add($btnBrowse)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install Fonts"
$btnInstall.Location = New-Object System.Drawing.Point(140, 70)
$btnInstall.Size = New-Object System.Drawing.Size(220, 48)
$btnInstall.Font = $firaBig
$btnInstall.BackColor = [System.Drawing.Color]::FromArgb(128, 0, 128)
$btnInstall.ForeColor = "White"
$form.Controls.Add($btnInstall)

$chkSuppress = New-Object System.Windows.Forms.CheckBox
$chkSuppress.Text = "Suppress notifications (silent install - no duplicate warnings)"
$chkSuppress.Location = New-Object System.Drawing.Point(140, 130)
$chkSuppress.Size = New-Object System.Drawing.Size(540, 30)
$chkSuppress.Font = $firaRegular
$chkSuppress.ForeColor = "White"
$form.Controls.Add($chkSuppress)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 175)
$txtLog.Size = New-Object System.Drawing.Size(670, 200)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Fira Sans", 9.5)
$txtLog.BackColor = "#F5F0FF"
$form.Controls.Add($txtLog)

$lblNote = New-Object System.Windows.Forms.Label
$lblNote.Text = "Note: Must be run as Administrator.`nOnly .ttf and .otf files are supported."
$lblNote.Location = New-Object System.Drawing.Point(20, 385)
$lblNote.Size = New-Object System.Drawing.Size(670, 50)
$lblNote.ForeColor = "#E0D0FF"
$lblNote.Font = New-Object System.Drawing.Font("Fira Sans", 9)
$form.Controls.Add($lblNote)

# ==================== EVENTS ====================

$btnBrowse.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select the folder containing your fonts"
    $folderBrowser.ShowNewFolderButton = $true
    $folderBrowser.RootFolder = [System.Environment+SpecialFolder]::MyComputer
    
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $txtPath.Text = $folderBrowser.SelectedPath
        $txtLog.Clear()
        $txtLog.AppendText("Folder selected: $($folderBrowser.SelectedPath)`n")
    }
})

$btnInstall.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtPath.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter or select a folder first.", "Warning", "OK", "Warning")
        return
    }

    $folder = $txtPath.Text.Trim()
    if (-not (Test-Path $folder -PathType Container)) {
        [System.Windows.Forms.MessageBox]::Show("The entered path is not a valid folder.", "Invalid Folder", "OK", "Error")
        return
    }

    $btnInstall.Enabled = $false
    $txtLog.Clear()
    $txtLog.AppendText("Starting font installation from:`n$folder`n`n")

    try {
        $fontFiles = Get-ChildItem -Path $folder -Include "*.ttf", "*.otf" -Recurse -File -ErrorAction Stop

        if ($fontFiles.Count -eq 0) {
            $txtLog.AppendText("No .ttf or .otf files found.`n")
            [System.Windows.Forms.MessageBox]::Show("No font files found.", "Information")
            return
        }

        $txtLog.AppendText("Found $($fontFiles.Count) font file(s).`n")
        $txtLog.AppendText("Mode: $(if ($chkSuppress.Checked) { 'Silent' } else { 'Normal' })`n`n")

        $installedCount = 0
        $shell = New-Object -ComObject Shell.Application
        $fontsFolder = $shell.Namespace(0x14)

        foreach ($font in $fontFiles) {
            try {
                $txtLog.AppendText("Processing: $($font.Name)`n")

                if ($chkSuppress.Checked) {
                    # Silent install
                    $destFile = Join-Path "$env:windir\Fonts" $font.Name
                    Copy-Item -Path $font.FullName -Destination $destFile -Force
                    $fontName = [FontUtils]::GetFontName($font.FullName)
                    $suffix = if ($font.Extension -ieq ".otf") { "(OpenType)" } else { "(TrueType)" }
                    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
                    Set-ItemProperty -Path $regKey -Name "$fontName $suffix" -Value $font.Name -Force
                    [void][FontUtils]::AddFontResource($destFile)
                    $installedCount++
                    $txtLog.AppendText("   → Installed silently`n")
                }
                else {
                    # Normal install
                    $fontsFolder.CopyHere($font.FullName)
                    $installedCount++
                    $txtLog.AppendText("   → Installed`n")
                }
            }
            catch {
                $txtLog.AppendText("   → Failed: $($_.Exception.Message)`n")
            }
        }

        if ($chkSuppress.Checked) {
            [void][FontUtils]::SendMessage([IntPtr]::new(0xffff), 0x001D, 0, 0)  # WM_FONTCHANGE
        }

        $txtLog.AppendText("`n=====================================`n")
        $txtLog.AppendText("COMPLETED! $installedCount of $($fontFiles.Count) fonts installed.`n")
        $txtLog.AppendText("=====================================`n")

        [System.Windows.Forms.MessageBox]::Show("$installedCount font(s) installed successfully!", "Success", "OK", "Information")

    }
    catch {
        $txtLog.AppendText("Critical Error: $($_.Exception.Message)`n")
        [System.Windows.Forms.MessageBox]::Show("An error occurred:`n$($_.Exception.Message)", "Error", "OK", "Error")
    }
    finally {
        $btnInstall.Enabled = $true
    }
})

$form.ShowDialog() | Out-Null