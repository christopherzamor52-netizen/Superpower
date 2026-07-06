param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("claude", "gemini")]
  [string]$Provider,

  [Parameter(Mandatory = $true)]
  [ValidateSet("implementer", "spec-reviewer", "code-quality-reviewer")]
  [string]$Role,

  [Parameter(Mandatory = $true)]
  [string]$TaskBriefPath,

  [Parameter(Mandatory = $true)]
  [string]$RepoRoot,

  [Parameter(Mandatory = $true)]
  [string]$WorktreePath,

  [string[]]$WriteScope = @(),
  [string]$ReportFile = "",
  [string]$DiffFile = "",
  [string]$ImplementerReportFile = "",
  [string]$FocusedTestCommand = "",
  [string]$BaseSha = "",
  [string]$HeadSha = "",
  [string]$ClaudeModel = "opus",

  [ValidateSet("low", "medium", "high", "xhigh", "max")]
  [string]$ClaudeEffort = "max",

  [string]$GeminiModel = "gemini-2.5-pro",
  [string]$CommandOverride = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"

function Resolve-StrictPath {
  param([string]$Path)

  return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
}

function Assert-FileExists {
  param(
    [string]$Path,
    [string]$Label
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Label not found: $Path"
  }
}

function Invoke-Provider {
  param(
    [string]$Prompt,
    [string]$ProviderName,
    [string]$Override,
    [string]$ClaudeModelName,
    [string]$ClaudeEffortLevel,
    [string]$GeminiModelName,
    [string]$WorkingDirectory
  )

  Push-Location $WorkingDirectory
  try {
    if (-not [string]::IsNullOrWhiteSpace($Override)) {
      $psi = New-Object System.Diagnostics.ProcessStartInfo
      $psi.FileName = "powershell.exe"
      $psi.Arguments = "-NoProfile -Command $Override"
      $psi.WorkingDirectory = $WorkingDirectory
      $psi.UseShellExecute = $false
      $psi.RedirectStandardInput = $true
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError = $true

      $process = New-Object System.Diagnostics.Process
      $process.StartInfo = $psi
      $null = $process.Start()
      $process.StandardInput.Write($Prompt)
      $process.StandardInput.Close()
      $stdout = $process.StandardOutput.ReadToEnd()
      $stderr = $process.StandardError.ReadToEnd()
      $process.WaitForExit()

      if ($stdout) {
        Write-Output $stdout.TrimEnd()
      }
      if ($process.ExitCode -ne 0) {
        throw "Override command failed with exit code $($process.ExitCode): $stderr"
      }
      return
    }

    $providerCommand = Get-Command $ProviderName -ErrorAction SilentlyContinue
    if (-not $providerCommand) {
      throw "$ProviderName CLI is not installed or not on PATH."
    }

    if ($ProviderName -eq "claude") {
      $Prompt | claude -p --model $ClaudeModelName --effort $ClaudeEffortLevel --allowedTools all --permission-mode bypassPermissions --no-session-persistence
    }
    elseif ($ProviderName -eq "gemini") {
      $preferredGeminiCommand = if ($env:OS -eq "Windows_NT") { "gemini.cmd" } else { "gemini" }
      $geminiCommand = Get-Command $preferredGeminiCommand -ErrorAction SilentlyContinue
      if (-not $geminiCommand) {
        $geminiCommand = Get-Command "gemini" -ErrorAction SilentlyContinue
      }
      if (-not $geminiCommand) {
        throw "gemini CLI is not installed or not on PATH."
      }

      $psi = New-Object System.Diagnostics.ProcessStartInfo
      if ($env:OS -eq "Windows_NT" -and $geminiCommand.Source.ToLowerInvariant().EndsWith(".cmd")) {
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -Command & '$($geminiCommand.Source)' --model $GeminiModelName --skip-trust --prompt 'Execute the task from stdin. Follow the requested output format exactly.' --approval-mode yolo --output-format text"
      }
      else {
        $psi.FileName = $geminiCommand.Source
        $psi.Arguments = "--model $GeminiModelName --skip-trust --prompt ""Execute the task from stdin. Follow the requested output format exactly."" --approval-mode yolo --output-format text"
      }
      $psi.WorkingDirectory = $WorkingDirectory
      $psi.UseShellExecute = $false
      $psi.RedirectStandardInput = $true
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError = $true

      $process = New-Object System.Diagnostics.Process
      $process.StartInfo = $psi
      $null = $process.Start()
      $process.StandardInput.Write($Prompt)
      $process.StandardInput.Close()
      $stdout = $process.StandardOutput.ReadToEnd()
      $stderr = $process.StandardError.ReadToEnd()
      $process.WaitForExit()

      if ($stdout) {
        Write-Output $stdout.TrimEnd()
      }
      if ($process.ExitCode -ne 0) {
        throw "gemini command failed with exit code $($process.ExitCode): $stderr"
      }
    }
  }
  finally {
    Pop-Location
  }
}

function Build-ImplementerPrompt {
  param(
    [string]$BriefText,
    [string]$Worktree,
    [string[]]$Scope,
    [string]$ReportPath,
    [string]$TestCommand
  )

  $scopeText = if ($Scope.Count -gt 0) { ($Scope | ForEach-Object { "- $_" }) -join "`n" } else { "- No write scope was provided." }
  $testLine = if ([string]::IsNullOrWhiteSpace($TestCommand)) { "Run the focused tests you judge necessary and report them." } else { "Run this focused test command before reporting: $TestCommand" }

  return @"
You are an external implementer working inside an isolated task worktree.

Task brief:

$BriefText

Worktree path:
$Worktree

Allowed write scope:
$scopeText

Rules:
- Do not edit files outside the allowed write scope.
- Do not change git remotes, branch topology, or merge history.
- Run tests inside the worktree.
- If the task forces out-of-scope edits, stop and report that explicitly.

$testLine

Write your full report to:
$ReportPath

Your report must include:
- Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- What you changed
- Tests run and results
- Files changed
- Concerns or blockers

After writing the report, print a short terminal summary with:
- Status
- Test summary
- Report path
"@
}

function Build-SpecReviewerPrompt {
  param(
    [string]$BriefText,
    [string]$DiffPath,
    [string]$ImplementerReportPath,
    [string]$Base,
    [string]$Head
  )

  return @"
You are an external spec reviewer.

Task brief:

$BriefText

Implementer report:
$ImplementerReportPath

Diff under review:
- Base: $Base
- Head: $Head
- Diff file: $DiffPath

Read the task brief, implementer report, and diff. Stay read-only.

Return:
- Spec compliance verdict
- Missing requirements
- Extra behavior
- Misunderstandings
- File/line references where possible
"@
}

function Build-QualityReviewerPrompt {
  param(
    [string]$BriefText,
    [string]$DiffPath,
    [string]$ImplementerReportPath,
    [string]$Base,
    [string]$Head
  )

  return @"
You are an external code-quality reviewer.

Task brief:

$BriefText

Implementer report:
$ImplementerReportPath

Diff under review:
- Base: $Base
- Head: $Head
- Diff file: $DiffPath

Read the task brief, implementer report, and diff. Stay read-only.

Check:
- bugs
- regressions
- weak tests
- maintainability risks
- safety issues

Return:
- Quality verdict
- Findings by severity
- File/line references where possible
"@
}

$repo = Resolve-StrictPath $RepoRoot
$worktree = Resolve-StrictPath $WorktreePath
$brief = Resolve-StrictPath $TaskBriefPath
Assert-FileExists $brief "Task brief"

$briefText = Get-Content -LiteralPath $brief -Raw -Encoding UTF8

if ($Role -eq "implementer") {
  if ([string]::IsNullOrWhiteSpace($ReportFile)) {
    throw "ReportFile is required for implementer role."
  }
  if ($WriteScope.Count -eq 0) {
    throw "WriteScope is required for implementer role."
  }
  $prompt = Build-ImplementerPrompt -BriefText $briefText -Worktree $worktree -Scope $WriteScope -ReportPath $ReportFile -TestCommand $FocusedTestCommand
}
elseif ($Role -eq "spec-reviewer") {
  if ([string]::IsNullOrWhiteSpace($DiffFile) -or [string]::IsNullOrWhiteSpace($ImplementerReportFile)) {
    throw "DiffFile and ImplementerReportFile are required for reviewer roles."
  }
  $prompt = Build-SpecReviewerPrompt -BriefText $briefText -DiffPath $DiffFile -ImplementerReportPath $ImplementerReportFile -Base $BaseSha -Head $HeadSha
}
else {
  if ([string]::IsNullOrWhiteSpace($DiffFile) -or [string]::IsNullOrWhiteSpace($ImplementerReportFile)) {
    throw "DiffFile and ImplementerReportFile are required for reviewer roles."
  }
  $prompt = Build-QualityReviewerPrompt -BriefText $briefText -DiffPath $DiffFile -ImplementerReportPath $ImplementerReportFile -Base $BaseSha -Head $HeadSha
}

Invoke-Provider -Prompt $prompt -ProviderName $Provider -Override $CommandOverride -ClaudeModelName $ClaudeModel -ClaudeEffortLevel $ClaudeEffort -GeminiModelName $GeminiModel -WorkingDirectory $worktree

$result = [pscustomobject]@{
  provider = $Provider
  role = $Role
  repo_root = $repo
  worktree_path = $worktree
  report_file = $ReportFile
}

if ($Json) {
  $result | ConvertTo-Json -Depth 4
}
else {
  Write-Output "External worker request sent to $Provider for $Role."
}
