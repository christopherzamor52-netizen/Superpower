param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("claude", "gemini")]
  [string]$Provider,

  [Parameter(Mandatory = $true)]
  [ValidateSet("spec", "plan", "diff", "release")]
  [string]$Mode,

  [string]$InputPath = "",
  [string]$RepoRoot = ".",
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

function Get-PromptTemplate {
  param([string]$PromptMode)

  switch ($PromptMode) {
    "spec" {
      return @"
You are reviewing a product/technical spec.

Return findings only if they are actionable.
Order findings by severity.
Focus on missing requirements, contradictions, unclear acceptance criteria, edge cases, implementation risks, and testability gaps.

Do not rewrite the spec.
Do not suggest unrelated features.
Do not assume access to files not provided.

Output:
Findings
Open Questions
Suggested Edits
"@
    }
    "plan" {
      return @"
You are reviewing an implementation plan.

Focus on wrong sequencing, missing dependencies, missing tests, migration or compatibility risk, vague execution steps, and verification gaps.

Do not implement anything.
Do not rewrite the plan unless suggesting a specific edit.

Output:
Findings
Open Questions
Suggested Plan Changes
"@
    }
    "diff" {
      return @"
You are reviewing a code diff.

Prioritize bugs, regressions, data loss, race conditions, security/privacy issues, and missing tests.
Do not comment on style unless it affects behavior.
Return file/line references when possible.

Output:
Findings
Test Gaps
Residual Risk
"@
    }
    "release" {
      return @"
You are reviewing release readiness.

Focus on missing verification, documentation gaps, rollback risk, user-impacting behavior changes, migration/setup risk, and unresolved high-risk TODOs.
Do not suggest broad new product work.

Output:
Blockers
Warnings
Recommended Follow-Up
"@
    }
  }
}

function Get-ArtifactText {
  param(
    [string]$PromptMode,
    [string]$Path,
    [string]$Root
  )

  if ($PromptMode -eq "diff" -and [string]::IsNullOrWhiteSpace($Path)) {
    Push-Location $Root
    try {
      $diff = git diff -- . ':!*.lock' ':!*.png' ':!*.jpg' ':!*.jpeg' ':!*.gif' ':!*.wav' ':!*.mp3' ':!*.mp4' ':!*.sqlite'
      if ([string]::IsNullOrWhiteSpace($diff)) {
        throw "No git diff found in $Root."
      }
      return $diff
    }
    finally {
      Pop-Location
    }
  }

  if ([string]::IsNullOrWhiteSpace($Path)) {
    throw "InputPath is required for mode '$PromptMode'."
  }

  $resolvedInput = Resolve-StrictPath $Path
  $item = Get-Item -LiteralPath $resolvedInput
  if ($item.PSIsContainer) {
    throw "InputPath must be a file, not a directory."
  }
  if ($item.Length -gt 2MB) {
    throw "Input file is larger than 2MB. Pass a narrower artifact."
  }
  if ($item.Name -match '(^\.env|secret|token|credential|private|key)' -or $item.Extension -in @(".pem", ".key", ".pfx", ".sqlite", ".db", ".wav", ".mp3", ".mp4")) {
    throw "Refusing to send likely secret, database, binary, or recording file: $($item.Name)"
  }

  return Get-Content -LiteralPath $resolvedInput -Raw -Encoding UTF8
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
      $Prompt | claude -p --model $ClaudeModelName --effort $ClaudeEffortLevel --tools "" --permission-mode plan --no-session-persistence
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
        $psi.Arguments = "-NoProfile -Command & '$($geminiCommand.Source)' --model $GeminiModelName --skip-trust --prompt 'Review the artifact from stdin. Follow the requested output format exactly.' --approval-mode plan --output-format text"
      }
      else {
        $psi.FileName = $geminiCommand.Source
        $psi.Arguments = "--model $GeminiModelName --skip-trust --prompt ""Review the artifact from stdin. Follow the requested output format exactly."" --approval-mode plan --output-format text"
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

$repo = Resolve-StrictPath $RepoRoot
$template = Get-PromptTemplate $Mode
$artifact = Get-ArtifactText -PromptMode $Mode -Path $InputPath -Root $repo
$prompt = @"
$template

Artifact begins:

$artifact

Artifact ends.
"@

Invoke-Provider -Prompt $prompt -ProviderName $Provider -Override $CommandOverride -ClaudeModelName $ClaudeModel -ClaudeEffortLevel $ClaudeEffort -GeminiModelName $GeminiModel -WorkingDirectory $repo

$result = [pscustomobject]@{
  provider = $Provider
  mode = $Mode
  repo_root = $repo
}

if ($Json) {
  $result | ConvertTo-Json -Depth 4
}
else {
  Write-Output "Review request sent to $Provider for $Mode."
}
