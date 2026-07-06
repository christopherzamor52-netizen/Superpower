param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("claude", "gemini")]
  [string]$Provider,

  [Parameter(Mandatory = $true)]
  [string]$PlanPath,

  [Parameter(Mandatory = $true)]
  [string]$TaskId,

  [Parameter(Mandatory = $true)]
  [string]$TaskBriefPath,

  [Parameter(Mandatory = $true)]
  [string]$RepoRoot,

  [Parameter(Mandatory = $true)]
  [string]$VerificationCommand,

  [string]$CommitMessage = "",
  [string]$WorktreePath = "",
  [string]$BranchName = "",
  [string]$ReportFile = "",
  [string]$CommandOverride = "",
  [string]$ClaudeModel = "opus",

  [ValidateSet("low", "medium", "high", "xhigh", "max")]
  [string]$ClaudeEffort = "max",

  [string]$GeminiModel = "gemini-2.5-pro",
  [switch]$KeepWorktree,
  [switch]$Json
)

$ErrorActionPreference = "Stop"

function Resolve-StrictPath {
  param([string]$Path)

  return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
}

function Get-TaskMetadata {
  param(
    [string]$FilePath,
    [string]$TargetTaskId
  )

  $content = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
  $blocks = [regex]::Matches($content, '(?ms)```yaml\s*task_metadata:\s*(?<body>.*?)```')

  foreach ($block in $blocks) {
    $body = $block.Groups["body"].Value
    $idMatch = [regex]::Match($body, '(?m)^\s*id:\s*(?<id>[^\r\n]+)')
    if (-not $idMatch.Success -or $idMatch.Groups["id"].Value.Trim() -ne $TargetTaskId) {
      continue
    }

    $titleMatch = [regex]::Match($body, '(?m)^\s*title:\s*(?<title>[^\r\n]+)')
    $scopeSection = [regex]::Match($body, '(?ms)^\s*write_scope:\s*\r?\n(?<items>(?:\s*-\s*[^\r\n]+\r?\n?)*)')
    $scopeItems = New-Object System.Collections.Generic.List[string]

    if ($scopeSection.Success) {
      $itemMatches = [regex]::Matches($scopeSection.Groups["items"].Value, '(?m)^\s*-\s*(?<item>[^\r\n]+)')
      foreach ($itemMatch in $itemMatches) {
        $scopeItems.Add($itemMatch.Groups["item"].Value.Trim())
      }
    }

    return [pscustomobject]@{
      id = $idMatch.Groups["id"].Value.Trim()
      title = if ($titleMatch.Success) { $titleMatch.Groups["title"].Value.Trim() } else { $TargetTaskId }
      write_scope = @($scopeItems)
    }
  }

  throw "Task metadata not found for $TargetTaskId in $FilePath"
}

function Invoke-StrictCommand {
  param(
    [string]$FileName,
    [string[]]$Arguments,
    [string]$WorkingDirectory
  )

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $FileName
  if ($Arguments.Count -gt 0) {
    $psi.Arguments = [string]::Join(" ", $Arguments)
  }
  $psi.WorkingDirectory = $WorkingDirectory
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $psi
  $null = $process.Start()
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()

  if ($process.ExitCode -ne 0) {
    throw "$FileName $([string]::Join(' ', $Arguments)) failed with exit code $($process.ExitCode): $stderr"
  }

  return [pscustomobject]@{
    StdOut = $stdout.TrimEnd()
    StdErr = $stderr.TrimEnd()
  }
}

$repo = Resolve-StrictPath $RepoRoot
$plan = Resolve-StrictPath $PlanPath
$brief = Resolve-StrictPath $TaskBriefPath
$metadata = Get-TaskMetadata -FilePath $plan -TargetTaskId $TaskId

$currentBranch = (git -C $repo branch --show-current).Trim()
if ([string]::IsNullOrWhiteSpace($currentBranch)) {
  throw "RepoRoot must be on a named branch before orchestrating an external task."
}

if ([string]::IsNullOrWhiteSpace($BranchName)) {
  $BranchName = "external-$TaskId-" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
}

if ([string]::IsNullOrWhiteSpace($WorktreePath)) {
  $repoParent = Split-Path -Parent $repo
  $repoName = Split-Path -Leaf $repo
  $worktreeRoot = Join-Path $repoParent ($repoName + "-external-worktrees")
  New-Item -ItemType Directory -Path $worktreeRoot -Force | Out-Null
  $WorktreePath = Join-Path $worktreeRoot $TaskId
}

if (Test-Path -LiteralPath $WorktreePath) {
  throw "Worktree path already exists: $WorktreePath"
}

if ([string]::IsNullOrWhiteSpace($ReportFile)) {
  $reportDir = Join-Path $env:TEMP "superpowers-external-model-workers"
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
  $ReportFile = Join-Path $reportDir ($TaskId + "-report.md")
}

if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
  $CommitMessage = "external-worker: $TaskId"
}

$workerScript = Join-Path $PSScriptRoot "run-worker-with-model.ps1"
$validatorScript = Join-Path (Split-Path -Parent $PSScriptRoot) "..\subagent-driven-development\scripts\validate-plan-metadata.ps1"
$validatorScript = Resolve-StrictPath $validatorScript

git -C $repo worktree add $WorktreePath -b $BranchName | Out-Null

try {
  & $workerScript `
    -Provider $Provider `
    -Role implementer `
    -TaskBriefPath $brief `
    -RepoRoot $repo `
    -WorktreePath $WorktreePath `
    -WriteScope $metadata.write_scope `
    -ReportFile $ReportFile `
    -FocusedTestCommand $VerificationCommand `
    -CommandOverride $CommandOverride `
    -ClaudeModel $ClaudeModel `
    -ClaudeEffort $ClaudeEffort `
    -GeminiModel $GeminiModel | Out-Null

  $changedFiles = @(git -C $WorktreePath diff --name-only --relative)
  if ($changedFiles.Count -eq 0) {
    throw "External worker produced no file changes."
  }

  & $validatorScript -PlanPath $plan -ActiveTaskIds $TaskId -ChangedFiles $changedFiles | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Write-scope validation failed for task $TaskId."
  }

  $verification = Invoke-StrictCommand -FileName "powershell.exe" -Arguments @("-NoProfile", "-Command", $VerificationCommand) -WorkingDirectory $WorktreePath

  git -C $WorktreePath add -- $changedFiles | Out-Null
  git -C $WorktreePath commit -m $CommitMessage | Out-Null
  git -C $repo merge --ff-only $BranchName | Out-Null

  $result = [pscustomobject]@{
    provider = $Provider
    task_id = $TaskId
    branch = $BranchName
    worktree_path = $WorktreePath
    changed_files = @($changedFiles)
    report_file = $ReportFile
    verification_output = $verification.StdOut
  }

  if ($Json) {
    $result | ConvertTo-Json -Depth 6
  }
  else {
    Write-Output "External task $TaskId completed on branch $BranchName."
  }
}
finally {
  if (-not $KeepWorktree -and (Test-Path -LiteralPath $WorktreePath)) {
    git -C $repo worktree remove $WorktreePath --force | Out-Null
    git -C $repo branch -D $BranchName 2>$null | Out-Null
  }
}
