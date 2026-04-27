# sync-check-gui.ps1
# A friendly "did I save my work?" checker for Windows, with a GUI.
#
# Shows ALL your projects in one list. Click "Check All" and each row
# turns green / yellow / red depending on its sync state. Click a
# yellow/red row to fix it (commit, push, or pull, with confirmation).
#
# Banner at the top tells you the headline:
#   GREEN  - everything is on GitHub, safe to walk away
#   YELLOW - some projects need attention
#   RED    - something needs a careful hand

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# -------------------- saved projects list --------------------

$settingsDir  = Join-Path $env:APPDATA "sync-check"
$projectsPath = Join-Path $settingsDir "projects.txt"
if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir | Out-Null }

function Get-Projects {
    if (-not (Test-Path $projectsPath)) { return @() }
    $lines = Get-Content $projectsPath | Where-Object { $_ -and $_.Trim() -ne "" }
    return @($lines | Where-Object { Test-Path $_ })
}
function Save-Projects {
    param([string[]]$Projects)
    $Projects | Out-File -FilePath $projectsPath -Encoding utf8
}
function Add-Project {
    param([string]$Path)
    $current = Get-Projects
    if ($current -notcontains $Path) {
        Save-Projects (@($current) + $Path)
    }
}
function Remove-ProjectByPath {
    param([string]$Path)
    Save-Projects (Get-Projects | Where-Object { $_ -ne $Path })
}

# -------------------- the main window --------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Check my code is saved"
$form.Size = New-Object System.Drawing.Size(820, 620)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$form.MinimumSize = New-Object System.Drawing.Size(640, 480)

# --- Big banner across the top ---
$banner = New-Object System.Windows.Forms.Label
$banner.Location = New-Object System.Drawing.Point(20, 20)
$banner.Size = New-Object System.Drawing.Size(765, 70)
$banner.Anchor = "Top, Left, Right"
$banner.TextAlign = "MiddleCenter"
$banner.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$banner.BackColor = [System.Drawing.Color]::LightGray
$banner.ForeColor = [System.Drawing.Color]::Black
$banner.Text = "Click 'Check All' to see how your projects are doing"
$form.Controls.Add($banner)

# --- Project list (one row per project) ---
$list = New-Object System.Windows.Forms.ListView
$list.Location = New-Object System.Drawing.Point(20, 105)
$list.Size = New-Object System.Drawing.Size(765, 380)
$list.Anchor = "Top, Bottom, Left, Right"
$list.View = "Details"
$list.FullRowSelect = $true
$list.GridLines = $true
$list.MultiSelect = $false
$list.HideSelection = $false
$list.Font = New-Object System.Drawing.Font("Segoe UI", 10)
[void]$list.Columns.Add("Project", 320)
[void]$list.Columns.Add("Branch", 110)
[void]$list.Columns.Add("Status", 320)
$form.Controls.Add($list)

# --- Bottom row of buttons ---
$checkAllBtn = New-Object System.Windows.Forms.Button
$checkAllBtn.Text = "Check All"
$checkAllBtn.Location = New-Object System.Drawing.Point(20, 500)
$checkAllBtn.Size = New-Object System.Drawing.Size(160, 50)
$checkAllBtn.Anchor = "Bottom, Left"
$checkAllBtn.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$checkAllBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$checkAllBtn.ForeColor = [System.Drawing.Color]::White
$checkAllBtn.FlatStyle = "Flat"
$form.Controls.Add($checkAllBtn)

$fixBtn = New-Object System.Windows.Forms.Button
$fixBtn.Text = "Fix Selected"
$fixBtn.Location = New-Object System.Drawing.Point(190, 500)
$fixBtn.Size = New-Object System.Drawing.Size(140, 50)
$fixBtn.Anchor = "Bottom, Left"
$fixBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$fixBtn.Enabled = $false
$form.Controls.Add($fixBtn)

$addBtn = New-Object System.Windows.Forms.Button
$addBtn.Text = "Add..."
$addBtn.Location = New-Object System.Drawing.Point(495, 510)
$addBtn.Size = New-Object System.Drawing.Size(95, 32)
$addBtn.Anchor = "Bottom, Right"
$form.Controls.Add($addBtn)

$removeBtn = New-Object System.Windows.Forms.Button
$removeBtn.Text = "Remove"
$removeBtn.Location = New-Object System.Drawing.Point(595, 510)
$removeBtn.Size = New-Object System.Drawing.Size(95, 32)
$removeBtn.Anchor = "Bottom, Right"
$removeBtn.Enabled = $false
$form.Controls.Add($removeBtn)

$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = "Close"
$closeBtn.Location = New-Object System.Drawing.Point(695, 510)
$closeBtn.Size = New-Object System.Drawing.Size(90, 32)
$closeBtn.Anchor = "Bottom, Right"
$closeBtn.Add_Click({ $form.Close() })
$form.Controls.Add($closeBtn)

# -------------------- helpers --------------------

$COLOR_GOOD = [System.Drawing.Color]::FromArgb(200, 230, 201)
$COLOR_WARN = [System.Drawing.Color]::FromArgb(255, 236, 179)
$COLOR_BAD  = [System.Drawing.Color]::FromArgb(255, 205, 210)
$COLOR_GREY = [System.Drawing.Color]::FromArgb(238, 238, 238)

function Set-Banner {
    param([string]$Text, [string]$State)
    $banner.Text = $Text
    switch ($State) {
        "good"    { $banner.BackColor = [System.Drawing.Color]::FromArgb(76, 175, 80);  $banner.ForeColor = [System.Drawing.Color]::White }
        "warn"    { $banner.BackColor = [System.Drawing.Color]::FromArgb(255, 193, 7);  $banner.ForeColor = [System.Drawing.Color]::Black }
        "bad"     { $banner.BackColor = [System.Drawing.Color]::FromArgb(244, 67, 54);  $banner.ForeColor = [System.Drawing.Color]::White }
        "neutral" { $banner.BackColor = [System.Drawing.Color]::LightGray;              $banner.ForeColor = [System.Drawing.Color]::Black }
    }
    $form.Refresh()
}

function Confirm-Yes {
    param([string]$Question, [string]$Title = "Sync check")
    # Guard against MessageBox truncation when the question gets too long
    if ($Question.Length -gt 800) {
        $Question = $Question.Substring(0, 800) + "`r`n`r`n[message truncated]"
    }
    $r = [System.Windows.Forms.MessageBox]::Show($Question, $Title,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)
    return ($r -eq [System.Windows.Forms.DialogResult]::Yes)
}

# Show-LongText shows arbitrary-length text in a scrollable window.
# Use this anywhere we'd otherwise stuff git output into a MessageBox.
function Show-LongText {
    param(
        [string]$Title,
        [string]$Header,
        [string]$Body,
        [string]$ConfirmButton = $null  # if set, dialog has Yes/No instead of OK
    )
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = $Title
    $dlg.Size = New-Object System.Drawing.Size(700, 500)
    $dlg.StartPosition = "CenterParent"
    $dlg.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $dlg.MinimumSize = New-Object System.Drawing.Size(500, 350)

    $hdr = New-Object System.Windows.Forms.Label
    $hdr.Text = $Header
    $hdr.Location = New-Object System.Drawing.Point(15, 15)
    $hdr.Size = New-Object System.Drawing.Size(660, 50)
    $hdr.Anchor = "Top, Left, Right"
    $dlg.Controls.Add($hdr)

    $box = New-Object System.Windows.Forms.TextBox
    $box.Location = New-Object System.Drawing.Point(15, 75)
    $box.Size = New-Object System.Drawing.Size(660, 340)
    $box.Anchor = "Top, Bottom, Left, Right"
    $box.Multiline = $true
    $box.ReadOnly = $true
    $box.ScrollBars = "Both"
    $box.WordWrap = $false
    $box.Font = New-Object System.Drawing.Font("Consolas", 10)
    $box.BackColor = [System.Drawing.Color]::White
    $box.Text = $Body
    $dlg.Controls.Add($box)

    if ($ConfirmButton) {
        $yes = New-Object System.Windows.Forms.Button
        $yes.Text = $ConfirmButton
        $yes.DialogResult = "Yes"
        $yes.Location = New-Object System.Drawing.Point(420, 425)
        $yes.Size = New-Object System.Drawing.Size(130, 35)
        $yes.Anchor = "Bottom, Right"
        $dlg.Controls.Add($yes); $dlg.AcceptButton = $yes

        $no = New-Object System.Windows.Forms.Button
        $no.Text = "Cancel"
        $no.DialogResult = "No"
        $no.Location = New-Object System.Drawing.Point(560, 425)
        $no.Size = New-Object System.Drawing.Size(115, 35)
        $no.Anchor = "Bottom, Right"
        $dlg.Controls.Add($no); $dlg.CancelButton = $no
    }
    else {
        $ok = New-Object System.Windows.Forms.Button
        $ok.Text = "OK"
        $ok.DialogResult = "OK"
        $ok.Location = New-Object System.Drawing.Point(560, 425)
        $ok.Size = New-Object System.Drawing.Size(115, 35)
        $ok.Anchor = "Bottom, Right"
        $dlg.Controls.Add($ok); $dlg.AcceptButton = $ok; $dlg.CancelButton = $ok
    }

    $result = $dlg.ShowDialog($form)
    return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Show-Error {
    param([string]$Message, [string]$Title = "Sync check")
    # If the error text is long (e.g. a big git error dump), use the
    # scrollable window instead of a MessageBox that may silently drop it.
    if ($Message.Length -gt 600 -or ($Message -split "`n").Count -gt 8) {
        [void](Show-LongText -Title $Title -Header "Something went wrong:" -Body $Message)
    }
    else {
        [void][System.Windows.Forms.MessageBox]::Show($Message, $Title,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Ask-Text {
    param([string]$Prompt, [string]$Default = "")
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Sync check"
    $dlg.Size = New-Object System.Drawing.Size(480, 180)
    $dlg.StartPosition = "CenterParent"
    $dlg.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $dlg.FormBorderStyle = "FixedDialog"
    $dlg.MinimizeBox = $false; $dlg.MaximizeBox = $false

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Prompt
    $lbl.Location = New-Object System.Drawing.Point(15, 15)
    $lbl.Size = New-Object System.Drawing.Size(440, 25)
    $dlg.Controls.Add($lbl)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = New-Object System.Drawing.Point(15, 45)
    $tb.Size = New-Object System.Drawing.Size(440, 25)
    $tb.Text = $Default
    $dlg.Controls.Add($tb)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "OK"; $ok.DialogResult = "OK"
    $ok.Location = New-Object System.Drawing.Point(265, 90)
    $ok.Size = New-Object System.Drawing.Size(90, 32)
    $dlg.Controls.Add($ok); $dlg.AcceptButton = $ok

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "Cancel"; $cancel.DialogResult = "Cancel"
    $cancel.Location = New-Object System.Drawing.Point(365, 90)
    $cancel.Size = New-Object System.Drawing.Size(90, 32)
    $dlg.Controls.Add($cancel); $dlg.CancelButton = $cancel

    if ($dlg.ShowDialog($form) -eq "OK") { return $tb.Text } else { return $null }
}

function Run-Git {
    param([string]$Folder, [string[]]$GitArgs)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "git"
    $psi.Arguments = ($GitArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.WorkingDirectory = $Folder
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $out = $proc.StandardOutput.ReadToEnd()
    $err = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return @{ Code = $proc.ExitCode; Out = $out.Trim(); Err = $err.Trim() }
}

function Inspect-Project {
    param([string]$Path)
    $r = @{ Path = $Path; Branch = ""; State = "error"; Ahead = 0; Behind = 0; Message = ""; FileCount = 0 }

    if (-not (Test-Path $Path)) {
        $r.State = "missing"; $r.Message = "Folder no longer exists"
        return $r
    }
    $check = Run-Git $Path @("rev-parse", "--is-inside-work-tree")
    if ($check.Code -ne 0) {
        $r.State = "not-git"; $r.Message = "Not a git project anymore"
        return $r
    }

    $r.Branch = (Run-Git $Path @("rev-parse", "--abbrev-ref", "HEAD")).Out

    $status = (Run-Git $Path @("status", "--porcelain")).Out
    if ($status) {
        $count = ($status -split "`r?`n" | Where-Object { $_ -ne "" }).Count
        $r.State = "uncommitted"
        $r.FileCount = $count
        $r.Message = "$count file(s) with unsaved changes"
        return $r
    }

    $up = Run-Git $Path @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
    if ($up.Code -ne 0) {
        $r.State = "unpushed-branch"
        $r.Message = "Branch '$($r.Branch)' has never been pushed to GitHub"
        return $r
    }

    $fetch = Run-Git $Path @("fetch")
    if ($fetch.Code -ne 0) {
        $r.State = "offline"
        $r.Message = "Couldn't reach GitHub (offline?)"
        return $r
    }
    $r.Ahead  = [int](Run-Git $Path @("rev-list", "--count", "@{u}..HEAD")).Out
    $r.Behind = [int](Run-Git $Path @("rev-list", "--count", "HEAD..@{u}")).Out

    if ($r.Ahead -gt 0 -and $r.Behind -gt 0) {
        $r.State = "diverged"
        $r.Message = "$($r.Ahead) here, $($r.Behind) on GitHub - needs care"
    }
    elseif ($r.Ahead -gt 0) {
        $r.State = "ahead"
        $r.Message = "$($r.Ahead) commit(s) not yet on GitHub"
    }
    elseif ($r.Behind -gt 0) {
        $r.State = "behind"
        $r.Message = "$($r.Behind) commit(s) on GitHub not yet here"
    }
    else {
        $r.State = "good"
        $r.Message = "All saved on GitHub"
    }
    return $r
}

function Update-Row {
    param($Item, $Result)
    $Item.SubItems[1].Text = $Result.Branch
    $Item.SubItems[2].Text = $Result.Message
    switch ($Result.State) {
        "good"            { $Item.BackColor = $COLOR_GOOD }
        "uncommitted"     { $Item.BackColor = $COLOR_WARN }
        "unpushed-branch" { $Item.BackColor = $COLOR_WARN }
        "ahead"           { $Item.BackColor = $COLOR_WARN }
        "behind"          { $Item.BackColor = $COLOR_WARN }
        "diverged"        { $Item.BackColor = $COLOR_BAD  }
        "offline"         { $Item.BackColor = $COLOR_GREY }
        "missing"         { $Item.BackColor = $COLOR_BAD  }
        "not-git"         { $Item.BackColor = $COLOR_BAD  }
        default           { $Item.BackColor = $COLOR_GREY }
    }
    $Item.Tag = $Result
}

function Refresh-List {
    $list.Items.Clear()
    foreach ($p in Get-Projects) {
        $row = New-Object System.Windows.Forms.ListViewItem $p
        [void]$row.SubItems.Add("")
        [void]$row.SubItems.Add("Not checked yet")
        $row.BackColor = $COLOR_GREY
        [void]$list.Items.Add($row)
    }
}

function Update-HeadlineBanner {
    if ($list.Items.Count -eq 0) {
        Set-Banner "Click 'Add...' to add your first project" "neutral"
        return
    }
    $results = @($list.Items | ForEach-Object { $_.Tag } | Where-Object { $_ })
    if ($results.Count -eq 0) {
        Set-Banner "Click 'Check All' to see how your projects are doing" "neutral"
        return
    }
    $bad  = @($results | Where-Object { $_.State -in @("diverged","missing","not-git") }).Count
    $warn = @($results | Where-Object { $_.State -in @("uncommitted","unpushed-branch","ahead","behind","offline") }).Count
    $good = @($results | Where-Object { $_.State -eq "good" }).Count
    $total = $results.Count

    if ($bad -gt 0) {
        Set-Banner "$bad PROJECT(S) NEED A CAREFUL HAND" "bad"
    }
    elseif ($warn -gt 0) {
        Set-Banner "$warn OF $total PROJECT(S) NEED ATTENTION" "warn"
    }
    elseif ($good -eq $total) {
        Set-Banner "ALL $total PROJECT(S) SAFE ON GITHUB" "good"
    }
}

# -------------------- Check All --------------------

$checkAllBtn.Add_Click({
    if ($list.Items.Count -eq 0) {
        Set-Banner "Click 'Add...' to add your first project" "neutral"
        return
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Set-Banner "GIT IS NOT INSTALLED" "bad"
        Show-Error "I couldn't find git on this computer.`r`n`r`nInstall Git for Windows from https://git-scm.com/download/win and try again."
        return
    }

    Set-Banner "Checking..." "neutral"
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    foreach ($item in $list.Items) {
        $item.SubItems[2].Text = "Checking..."
        $item.BackColor = $COLOR_GREY
        $list.Refresh()
        $result = Inspect-Project -Path $item.Text
        Update-Row -Item $item -Result $result
    }
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    Update-HeadlineBanner
})

# -------------------- Fix Selected --------------------

# Builds a short preview of git status output (first N lines) so we can
# put it in a normal MessageBox safely. The full list is always available
# via Show-LongText if the user wants to see it.
function Get-StatusPreview {
    param([string]$StatusOut, [int]$MaxLines = 5)
    $lines = $StatusOut -split "`r?`n" | Where-Object { $_ -ne "" }
    if ($lines.Count -le $MaxLines) {
        return ($lines -join "`r`n")
    }
    $shown = $lines | Select-Object -First $MaxLines
    $extra = $lines.Count - $MaxLines
    return (($shown -join "`r`n") + "`r`n... and $extra more")
}

function Fix-Project {
    param($Item)
    $r = $Item.Tag
    if (-not $r) { return }
    $path = $r.Path

    switch ($r.State) {
        "good" {
            [void][System.Windows.Forms.MessageBox]::Show(
                "This project is already safe on GitHub. Nothing to fix.",
                "Sync check", "OK", "Information")
            return
        }
        "missing" {
            if (Confirm-Yes "This folder no longer exists:`r`n`r`n$path`r`n`r`nRemove it from the list?") {
                Remove-ProjectByPath $path
                Refresh-List
                Update-HeadlineBanner
            }
            return
        }
        "not-git" {
            if (Confirm-Yes "This folder isn't a git project anymore:`r`n`r`n$path`r`n`r`nRemove it from the list?") {
                Remove-ProjectByPath $path
                Refresh-List
                Update-HeadlineBanner
            }
            return
        }
        "offline" {
            Show-Error "Couldn't reach GitHub for this project.`r`n`r`nCheck your internet connection and try Check All again."
            return
        }
        "diverged" {
            Show-Error "This project has different work on this computer AND on GitHub.`r`n`r`nThis needs a careful hand - please ask for help before doing anything else.`r`n`r`n(Don't pull or push until you've talked to someone.)"
            return
        }
        "uncommitted" {
            $statusOut = (Run-Git $path @("status", "--short")).Out
            $count = $r.FileCount
            if ($count -le 0) {
                $count = ($statusOut -split "`r?`n" | Where-Object { $_ -ne "" }).Count
            }

            # For small numbers of files, show them inline. For a lot of files
            # (which is what was breaking before), use a scrollable window.
            $proceed = $false
            if ($count -le 8) {
                $proceed = Confirm-Yes "These files have uncommitted changes:`r`n`r`n$statusOut`r`n`r`nCommit them all now?"
            }
            else {
                $preview = Get-StatusPreview -StatusOut $statusOut -MaxLines 8
                $header = "You have $count files with uncommitted changes. Here are the first few:"
                $body = "$preview`r`n`r`n--- full list below ---`r`n`r`n$statusOut`r`n`r`nDo you want to commit all $count files now?"
                $proceed = Show-LongText -Title "Sync check" -Header $header -Body $body -ConfirmButton "Commit all $count files"
            }
            if (-not $proceed) { return }

            $msg = Ask-Text "Type a short message describing what you changed:" "Work in progress"
            if ($null -eq $msg) { return }
            if ([string]::IsNullOrWhiteSpace($msg)) { $msg = "Work in progress (auto-commit from sync-check)" }

            $a = Run-Git $path @("add", "-A")
            if ($a.Code -ne 0) { Show-Error "Couldn't stage changes:`r`n`r`n$($a.Err)"; return }
            $c = Run-Git $path @("commit", "-m", $msg)
            if ($c.Code -ne 0) { Show-Error "Commit failed:`r`n`r`n$($c.Err)"; return }

            $up = Run-Git $path @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
            if ($up.Code -ne 0) {
                if (Confirm-Yes "Committed.`r`n`r`nThe branch hasn't been pushed before. Push it to GitHub now?") {
                    $p = Run-Git $path @("push", "-u", "origin", $r.Branch)
                    if ($p.Code -ne 0) { Show-Error "Push failed:`r`n`r`n$($p.Err)" }
                }
            }
            else {
                if (Confirm-Yes "Committed.`r`n`r`nPush to GitHub now?") {
                    $p = Run-Git $path @("push")
                    if ($p.Code -ne 0) { Show-Error "Push failed:`r`n`r`n$($p.Err)" }
                }
            }
        }
        "unpushed-branch" {
            if (-not (Confirm-Yes "Branch '$($r.Branch)' has never been pushed to GitHub.`r`n`r`nPush it now?")) { return }
            $p = Run-Git $path @("push", "-u", "origin", $r.Branch)
            if ($p.Code -ne 0) { Show-Error "Push failed:`r`n`r`n$($p.Err)"; return }
        }
        "ahead" {
            if (-not (Confirm-Yes "$($r.Ahead) commit(s) on this computer aren't on GitHub yet.`r`n`r`nPush them now?")) { return }
            $p = Run-Git $path @("push")
            if ($p.Code -ne 0) { Show-Error "Push failed:`r`n`r`n$($p.Err)"; return }
        }
        "behind" {
            if (-not (Confirm-Yes "GitHub has $($r.Behind) commit(s) that aren't on this computer yet.`r`n`r`nPull them down now?")) { return }
            $p = Run-Git $path @("pull", "--ff-only")
            if ($p.Code -ne 0) {
                Show-Error "Pull didn't go cleanly:`r`n`r`n$($p.Err)`r`n`r`nAsk for help before doing anything else."
                return
            }
        }
    }

    $newResult = Inspect-Project -Path $path
    Update-Row -Item $Item -Result $newResult
    Update-HeadlineBanner
}

$fixBtn.Add_Click({
    if ($list.SelectedItems.Count -eq 0) { return }
    Fix-Project -Item $list.SelectedItems[0]
})

$list.Add_DoubleClick({
    if ($list.SelectedItems.Count -eq 0) { return }
    Fix-Project -Item $list.SelectedItems[0]
})

$list.Add_SelectedIndexChanged({
    $hasSelection = $list.SelectedItems.Count -gt 0
    $removeBtn.Enabled = $hasSelection
    if ($hasSelection -and $list.SelectedItems[0].Tag) {
        $state = $list.SelectedItems[0].Tag.State
        $fixBtn.Enabled = ($state -ne "good")
    }
    else {
        $fixBtn.Enabled = $false
    }
})

# -------------------- Add / Remove --------------------

$addBtn.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Pick the folder of a project to add to the list"
    if ($dialog.ShowDialog() -eq "OK") {
        $picked = $dialog.SelectedPath
        if (-not (Test-Path (Join-Path $picked ".git"))) {
            $proceed = [System.Windows.Forms.MessageBox]::Show(
                "This folder doesn't look like a git project (no .git folder inside).`r`n`r`nAdd it to the list anyway?",
                "Sync check", "YesNo", "Warning")
            if ($proceed -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        }
        Add-Project $picked
        Refresh-List
        Update-HeadlineBanner
    }
})

$removeBtn.Add_Click({
    if ($list.SelectedItems.Count -eq 0) { return }
    $path = $list.SelectedItems[0].Text
    if (Confirm-Yes "Remove this project from the list?`r`n`r`n$path`r`n`r`n(This only takes it off the list - it doesn't delete any files.)") {
        Remove-ProjectByPath $path
        Refresh-List
        Update-HeadlineBanner
    }
})

# -------------------- startup --------------------

Refresh-List
Update-HeadlineBanner
[void]$form.ShowDialog()
