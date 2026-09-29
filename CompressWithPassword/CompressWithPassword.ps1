# CompressWithPassword.ps1
# Context-menu version of the dual-pane Compress-WithPassword function.
# Place 7za.exe in the same folder as this script (or have it on PATH).

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

try {
    if ($args.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "No items selected.",
            "Compress with Password",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        exit 0
    }

    # Resolve 7za.exe – script directory first, then PATH
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $7zaPath = Join-Path $scriptDir "7za.exe"

    if (-not (Test-Path -LiteralPath $7zaPath)) {
        $cmd = Get-Command "7za.exe" -ErrorAction SilentlyContinue
        if ($cmd) {
            $7zaPath = $cmd.Source
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "7za.exe not found in script directory or PATH!",
                "Compress with Password",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            exit 1
        }
    }

    # Clean and validate the paths Explorer passed us
    $items = @()
    foreach ($a in $args) {
        $clean = $a.Trim('"')
        if (Test-Path -LiteralPath $clean) {
            $items += $clean
        }
    }

    if ($items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "No valid items selected.",
            "Compress with Password",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        exit 0
    }

    # ----- Password dialog (identical to dual-pane version) -----
    $pwdDlg = New-Object System.Windows.Forms.Form
    $pwdDlg.Text = "Enter Password"
    $pwdDlg.Size = New-Object System.Drawing.Size(300, 130)
    $pwdDlg.StartPosition = 'CenterScreen'
    $pwdDlg.FormBorderStyle = 'FixedDialog'
    $pwdDlg.MaximizeBox = $false
    $pwdDlg.MinimizeBox = $false
    $pwdDlg.TopMost = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Password:"
    $label.Location = New-Object System.Drawing.Point(15, 15)
    $label.AutoSize = $true
    $pwdDlg.Controls.Add($label)

    $pwdBox = New-Object System.Windows.Forms.TextBox
    $pwdBox.Location = New-Object System.Drawing.Point(15, 40)
    $pwdBox.Width = 250
    $pwdBox.UseSystemPasswordChar = $true
    $pwdDlg.Controls.Add($pwdBox)

    $okBtn = New-Object System.Windows.Forms.Button
    $okBtn.Text = "OK"
    $okBtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $okBtn.Location = New-Object System.Drawing.Point(100, 70)
    $pwdDlg.Controls.Add($okBtn)
    $pwdDlg.AcceptButton = $okBtn

    if ($pwdDlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        exit 0
    }

    $password = $pwdBox.Text.Trim()
    if ($password -eq "") {
        [System.Windows.Forms.MessageBox]::Show(
            "Empty password.",
            "Compress with Password",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        exit 0
    }

    # ----- Progress form (replaces the dual-pane progressBar + statusLabel) -----
    $progressForm = New-Object System.Windows.Forms.Form
    $progressForm.Text = "Compressing with Password..."
    $progressForm.Size = New-Object System.Drawing.Size(450, 130)
    $progressForm.StartPosition = 'CenterScreen'
    $progressForm.FormBorderStyle = 'FixedDialog'
    $progressForm.MaximizeBox = $false
    $progressForm.MinimizeBox = $false
    $progressForm.TopMost = $true
    $progressForm.ControlBox = $false

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "Preparing..."
    $statusLabel.Location = New-Object System.Drawing.Point(15, 15)
    $statusLabel.Size = New-Object System.Drawing.Size(410, 20)
    $progressForm.Controls.Add($statusLabel)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(15, 45)
    $progressBar.Size = New-Object System.Drawing.Size(410, 25)
    $progressBar.Style = 'Continuous'
    $progressBar.Maximum = 100
    $progressBar.Value = 0
    $progressForm.Controls.Add($progressBar)

    $progressForm.Show()
    $progressForm.Refresh()
    [System.Windows.Forms.Application]::DoEvents()

    $i = 0
    $total = $items.Count
    $failures = @()

    foreach ($item in $items) {
        $i++
        $zip = "$item.7z"
        $leaf = Split-Path -Leaf $item

        $statusLabel.Text = "Compressing ($i/$total): $leaf → $leaf.7z"
        $progressBar.Value = 0
        $progressForm.Refresh()
        [System.Windows.Forms.Application]::DoEvents()

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $7zaPath
        $psi.Arguments = "a -t7z `"$zip`" `"$item`" -p`"$password`" -mx=1 -bso0 -bsp1 -y"
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.Start() | Out-Null

        while (-not $proc.StandardOutput.EndOfStream) {
            $line = $proc.StandardOutput.ReadLine()
            if ($line -match '(\d+)%') {
                $progressBar.Value = [Math]::Min(100, [int]$Matches[1])
                $progressForm.Refresh()
                [System.Windows.Forms.Application]::DoEvents()
            }
        }

        $proc.WaitForExit()

        if ($proc.ExitCode -ne 0) {
            $failures += $leaf
            $statusLabel.Text = "Failed: $leaf"
        } else {
            $statusLabel.Text = "Done: $leaf.7z"
        }

        $overall = [Math]::Min(100, [int](($i / $total) * 100))
        $progressBar.Value = $overall
        $progressForm.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
    }

    $progressBar.Value = 100
    $statusLabel.Text = "Completed."
    $progressForm.Refresh()
    Start-Sleep -Milliseconds 400
    $progressForm.Close()
    $progressForm.Dispose()

    if ($failures.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to compress:`n$($failures -join "`n")",
            "Compress with Password",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Error: $($_.Exception.Message)",
        "Compress with Password",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
}