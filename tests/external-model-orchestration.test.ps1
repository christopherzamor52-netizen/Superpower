$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$geminiReference = Join-Path $root "skills/using-superpowers/references/gemini-tools.md"
$reviewSkill = Join-Path $root "skills/cross-model-review/SKILL.md"
$reviewScript = Join-Path $root "skills/cross-model-review/scripts/review-with-model.ps1"
$workerSkill = Join-Path $root "skills/external-model-workers/SKILL.md"
$workerScript = Join-Path $root "skills/external-model-workers/scripts/run-worker-with-model.ps1"

function Assert-True {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

function Assert-Contains {
  param(
    [string]$Text,
    [string]$Pattern,
    [string]$Message
  )

  if ($Text -notmatch [regex]::Escape($Pattern)) {
    throw $Message
  }
}

Assert-True (Test-Path $reviewSkill) "cross-model-review skill must exist."
Assert-True (Test-Path $reviewScript) "review-with-model.ps1 must exist."
Assert-True (Test-Path $workerSkill) "external-model-workers skill must exist."
Assert-True (Test-Path $workerScript) "run-worker-with-model.ps1 must exist."
Assert-True (Test-Path $geminiReference) "Gemini bootstrap reference file must exist for GEMINI.md imports."

$reviewText = Get-Content -Raw $reviewSkill
Assert-Contains $reviewText "Use Claude CLI or Gemini CLI as an independent reviewer" "cross-model-review skill must describe external reviewers."
Assert-Contains $reviewText "Do not let external models edit files or execute project mutations." "cross-model-review skill must keep reviews read-only."
$reviewScriptText = Get-Content -Raw $reviewScript
Assert-Contains $reviewScriptText "--skip-trust" "review wrapper must opt Gemini into trusted headless execution."

$workerText = Get-Content -Raw $workerSkill
Assert-Contains $workerText "create isolated worktrees" "external-model-workers skill must require isolated worktrees."
Assert-Contains $workerText "inspect diffs" "external-model-workers skill must require diff inspection."
Assert-Contains $workerText "run tests" "external-model-workers skill must require tests."
Assert-Contains $workerText "enforce write scope" "external-model-workers skill must require write-scope enforcement."
$workerScriptText = Get-Content -Raw $workerScript
Assert-Contains $workerScriptText "--skip-trust" "worker wrapper must opt Gemini into trusted headless execution."

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("superpowers-external-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp | Out-Null

try {
  $providerScript = Join-Path $temp "fake-provider.ps1"
  $providerOutput = Join-Path $temp "provider-output.txt"
  $providerInvocations = Join-Path $temp "provider-invocations.log"
  $planFile = Join-Path $temp "plan.md"
  $artifactFile = Join-Path $temp "artifact.md"
  $taskBrief = Join-Path $temp "task-1-brief.md"
  $reportFile = Join-Path $temp "task-1-report.md"
  $repoRoot = Join-Path $temp "repo"
  $worktree = Join-Path $temp "repo"

  New-Item -ItemType Directory -Path $repoRoot | Out-Null
  @'
# Sample artifact

The task metadata is valid.
'@ | Set-Content -Path $artifactFile -Encoding UTF8

  @'
# Sample plan

### Task 1: Worker

```yaml
task_metadata:
  id: task-1
  title: Worker
  depends_on: []
  write_scope:
    - src/worker.ts
  risk_level: low
  review_required:
    - spec
    - code_quality
  external_review:
    claude: true
    gemini: true
```
'@ | Set-Content -Path $planFile -Encoding UTF8

  @'
### Task 1: Worker

Implement the worker.
'@ | Set-Content -Path $taskBrief -Encoding UTF8

  @'
param(
  [string]$OutputPath,
  [string]$InvocationLogPath
)

$inputText = [Console]::In.ReadToEnd()
Set-Content -Path $OutputPath -Value $inputText -Encoding UTF8
Add-Content -Path $InvocationLogPath -Value ("ARGS=" + ($args -join " "))
@"
Status: DONE
Commits created: none
Test summary: mocked
Report path: mocked
"@
'@ | Set-Content -Path $providerScript -Encoding UTF8

  Push-Location $repoRoot
  try {
    git init | Out-Null
    git config user.name "Codex"
    git config user.email "codex@example.com"
    New-Item -ItemType Directory -Path (Join-Path $repoRoot "src") | Out-Null
    Set-Content -Path (Join-Path $repoRoot "src/worker.ts") -Value "export const worker = 1`n" -Encoding UTF8
    git add .
    git commit -m "init" | Out-Null
  }
  finally {
    Pop-Location
  }

  & $reviewScript `
    -Provider claude `
    -Mode spec `
    -InputPath $artifactFile `
    -RepoRoot $repoRoot `
    -CommandOverride "powershell -File `"$providerScript`" -OutputPath `"$providerOutput`" -InvocationLogPath `"$providerInvocations`"" `
    -Json | Out-Null

  Assert-True ($LASTEXITCODE -eq 0) "review-with-model.ps1 should succeed with a mock provider."
  $reviewPrompt = Get-Content -Raw $providerOutput
  Assert-Contains $reviewPrompt "You are reviewing a product/technical spec." "review script must send the spec prompt."
  Assert-Contains $reviewPrompt "Artifact begins:" "review script must include artifact boundaries."

  Remove-Item $providerOutput

  & $workerScript `
    -Provider gemini `
    -Role implementer `
    -TaskBriefPath $taskBrief `
    -RepoRoot $repoRoot `
    -WorktreePath $worktree `
    -WriteScope "src/worker.ts" `
    -ReportFile $reportFile `
    -CommandOverride "powershell -File `"$providerScript`" -OutputPath `"$providerOutput`" -InvocationLogPath `"$providerInvocations`"" `
    -Json | Out-Null

  Assert-True ($LASTEXITCODE -eq 0) "run-worker-with-model.ps1 should succeed with a mock provider."
  $workerPrompt = Get-Content -Raw $providerOutput
  Assert-Contains $workerPrompt "You are an external implementer working inside an isolated task worktree." "worker script must send the implementer prompt."
  Assert-Contains $workerPrompt "Allowed write scope:" "worker script must include write scope."
  Assert-Contains $workerPrompt "Write your full report to:" "worker script must include the report contract."
}
finally {
  Remove-Item -Recurse -Force $temp
}

Write-Host "External model orchestration checks passed."
