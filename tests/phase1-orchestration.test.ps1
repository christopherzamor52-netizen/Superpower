$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$writingPlans = Get-Content -Raw (Join-Path $root "skills/writing-plans/SKILL.md")
$sdd = Get-Content -Raw (Join-Path $root "skills/subagent-driven-development/SKILL.md")
$parallel = Get-Content -Raw (Join-Path $root "skills/dispatching-parallel-agents/SKILL.md")
$validator = Join-Path $root "skills/subagent-driven-development/scripts/validate-plan-metadata.ps1"

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

foreach ($field in @("task_metadata:", "id:", "depends_on:", "write_scope:", "risk_level:", "review_required:", "external_review:")) {
  Assert-Contains $writingPlans $field "writing-plans must require metadata field '$field'."
}

Assert-Contains $writingPlans 'Do not write `parallel_safe` in plans; controllers compute parallel eligibility from metadata.' "writing-plans must prohibit manual parallel_safe metadata."
Assert-Contains $writingPlans "Metadata Validation" "writing-plans must add a metadata validation self-review gate."

foreach ($rule in @(
  "all task IDs are unique",
  "all depends_on references exist",
  "dependency graph has no circular dependencies",
  "write_scope is present for every implementation task",
  "high-risk tasks are never dispatched in parallel",
  "Claude and Gemini remain external reviewers only"
)) {
  Assert-Contains $sdd $rule "subagent-driven-development must include controller rule: $rule"
}

foreach ($rule in @(
  "parallel_safe is computed, never authored",
  "no dependency relationship",
  "no overlapping write_scope entries",
  "risk_level is low",
  "medium risk tasks are parallel only when they do not touch shared contracts"
)) {
  Assert-Contains $parallel $rule "dispatching-parallel-agents must include routing rule: $rule"
}

if (-not (Test-Path $validator)) {
  throw "metadata validator script is missing: $validator"
}

$sampleDir = Join-Path ([System.IO.Path]::GetTempPath()) ("superpowers-phase1-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $sampleDir | Out-Null

try {
  $validPlan = Join-Path $sampleDir "valid-plan.md"
  @'
# Valid Plan

### Task 1: Core Contract

```yaml
task_metadata:
  id: task-1
  title: Core Contract
  depends_on: []
  write_scope:
    - src/contract.ts
  risk_level: high
  review_required:
    - spec
    - code_quality
  external_review:
    claude: true
    gemini: true
```

### Task 2: UI Copy

```yaml
task_metadata:
  id: task-2
  title: UI Copy
  depends_on:
    - task-1
  write_scope:
    - src/copy.ts
  risk_level: low
  review_required:
    - code_quality
  external_review:
    claude: false
    gemini: false
```
'@ | Set-Content -Path $validPlan -Encoding UTF8

  & $validator -PlanPath $validPlan -Json | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "validator should accept valid metadata."
  }

  $invalidPlan = Join-Path $sampleDir "invalid-plan.md"
  @'
# Invalid Plan

### Task 1: One

```yaml
task_metadata:
  id: task-1
  title: One
  depends_on:
    - task-2
  write_scope:
    - src/shared.ts
  risk_level: low
  review_required:
    - code_quality
  external_review:
    claude: false
    gemini: false
```

### Task 2: Two

```yaml
task_metadata:
  id: task-2
  title: Two
  depends_on:
    - task-1
  write_scope:
    - src/shared.ts
  risk_level: low
  review_required:
    - code_quality
  external_review:
    claude: false
    gemini: false
```
'@ | Set-Content -Path $invalidPlan -Encoding UTF8

  $output = & $validator -PlanPath $invalidPlan -ActiveTaskIds task-1,task-2 2>&1
  if ($LASTEXITCODE -eq 0) {
    throw "validator should reject circular dependencies and overlapping active write scopes."
  }

  $joined = $output -join "`n"
  foreach ($expected in @("circular dependency", "overlapping write_scope")) {
    if ($joined -notmatch [regex]::Escape($expected)) {
      throw "validator output should mention '$expected'. Actual output: $joined"
    }
  }
}
finally {
  Remove-Item -Recurse -Force $sampleDir
}

Write-Host "Phase 1 orchestration checks passed."
