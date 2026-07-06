param(
  [Parameter(Mandatory = $true)]
  [string]$PlanPath,

  [string[]]$ActiveTaskIds = @(),
  [string[]]$CompletedTaskIds = @(),
  [string[]]$ChangedFiles = @(),
  [switch]$Json
)

$ErrorActionPreference = "Stop"

function Split-IdList {
  param([string[]]$Values)

  $result = New-Object System.Collections.Generic.List[string]
  foreach ($value in $Values) {
    foreach ($part in ($value -split ",")) {
      $trimmed = $part.Trim()
      if ($trimmed.Length -gt 0) {
        $result.Add($trimmed)
      }
    }
  }
  return @($result)
}

function Normalize-ScopePath {
  param([string]$Path)

  return ($Path.Trim() -replace "\\", "/").TrimEnd("/").ToLowerInvariant()
}

function New-MetadataObject {
  param([hashtable]$Metadata)

  return [pscustomobject]@{
    id = $Metadata["id"]
    title = $Metadata["title"]
    depends_on = @($Metadata["depends_on"])
    write_scope = @($Metadata["write_scope"])
    risk_level = $Metadata["risk_level"]
    review_required = @($Metadata["review_required"])
    external_review = $Metadata["external_review"]
  }
}

function Test-SharedContractScope {
  param($Task)

  if (@($Task.review_required) -contains "spec") {
    return $true
  }

  foreach ($scope in @($Task.write_scope)) {
    $normalized = Normalize-ScopePath $scope
    if ($normalized -match "(^|/)(api|apis|contract|contracts|schema|schemas|migration|migrations|database|db|storage|security|auth|delete|deletion|types?)(/|\.|$)") {
      return $true
    }
  }

  return $false
}

function Test-ChangedFileAllowed {
  param(
    [string]$ChangedFile,
    [string[]]$AllowedScopes
  )

  $changed = Normalize-ScopePath $ChangedFile
  foreach ($scope in $AllowedScopes) {
    $allowed = Normalize-ScopePath $scope
    if ($changed -eq $allowed -or $changed.StartsWith("$allowed/")) {
      return $true
    }
  }

  return $false
}

if (-not (Test-Path $PlanPath)) {
  throw "Plan file not found: $PlanPath"
}

$lines = Get-Content -Path $PlanPath
$tasks = New-Object System.Collections.Generic.List[object]
$current = $null
$currentField = $null

foreach ($line in $lines) {
  if ($line -match "^\s*task_metadata:\s*$") {
    if ($null -ne $current) {
      $tasks.Add((New-MetadataObject $current))
    }

    $current = @{
      depends_on = @()
      write_scope = @()
      review_required = @()
      external_review = @{}
    }
    $currentField = $null
    continue
  }

  if ($null -eq $current) {
    continue
  }

  if ($line -match "^\s*```\s*$") {
    $tasks.Add((New-MetadataObject $current))
    $current = $null
    $currentField = $null
    continue
  }

  if ($line -match "^\s{2}([A-Za-z_]+):\s*(.*)\s*$") {
    $field = $Matches[1]
    $value = $Matches[2].Trim()
    $currentField = $field

    if ($field -in @("depends_on", "write_scope", "review_required")) {
      if ($value -eq "[]") {
        $current[$field] = @()
        $currentField = $null
      }
      else {
        $current[$field] = @()
      }
    }
    elseif ($field -eq "external_review") {
      $current[$field] = @{}
    }
    else {
      $current[$field] = $value.Trim("'`"")
      $currentField = $null
    }

    continue
  }

  if ($line -match "^\s{4}-\s*(.+?)\s*$") {
    if ($currentField -in @("depends_on", "write_scope", "review_required")) {
      $current[$currentField] += $Matches[1].Trim()
    }
    continue
  }

  if ($line -match "^\s{4}([A-Za-z_]+):\s*(true|false)\s*$") {
    if ($currentField -eq "external_review") {
      $current["external_review"][$Matches[1]] = [bool]::Parse($Matches[2])
    }
  }
}

if ($null -ne $current) {
  $tasks.Add((New-MetadataObject $current))
}

$errors = New-Object System.Collections.Generic.List[string]
$tasksById = @{}

if ($tasks.Count -eq 0) {
  $errors.Add("no task_metadata blocks found")
}

foreach ($task in $tasks) {
  foreach ($required in @("id", "title", "risk_level")) {
    if ([string]::IsNullOrWhiteSpace($task.$required)) {
      $errors.Add("task metadata missing required field: $required")
    }
  }

  if ($null -eq $task.depends_on) {
    $errors.Add("task $($task.id) missing depends_on")
  }

  if (@($task.write_scope).Count -eq 0) {
    $errors.Add("task $($task.id) missing write_scope")
  }

  if (@($task.review_required).Count -eq 0) {
    $errors.Add("task $($task.id) missing review_required")
  }

  if ($null -eq $task.external_review -or -not $task.external_review.ContainsKey("claude") -or -not $task.external_review.ContainsKey("gemini")) {
    $errors.Add("task $($task.id) missing external_review claude/gemini flags")
  }

  if ($task.risk_level -and $task.risk_level -notin @("low", "medium", "high")) {
    $errors.Add("task $($task.id) has invalid risk_level: $($task.risk_level)")
  }

  if ($task.id) {
    if ($tasksById.ContainsKey($task.id)) {
      $errors.Add("duplicate task id: $($task.id)")
    }
    else {
      $tasksById[$task.id] = $task
    }
  }

  if ($task.risk_level -eq "high") {
    if (-not (@($task.review_required) -contains "spec") -or -not (@($task.review_required) -contains "code_quality")) {
      $errors.Add("high-risk task $($task.id) must require spec and code_quality review")
    }
  }
}

foreach ($task in $tasks) {
  foreach ($dependency in @($task.depends_on)) {
    if (-not $tasksById.ContainsKey($dependency)) {
      $errors.Add("task $($task.id) depends_on missing task id: $dependency")
    }
  }
}

$visitState = @{}
function Visit-Task {
  param(
    [string]$TaskId,
    [string[]]$Stack
  )

  if (-not $tasksById.ContainsKey($TaskId)) {
    return
  }

  if ($visitState[$TaskId] -eq "visiting") {
    $cycle = (@($Stack) + $TaskId) -join " -> "
    $errors.Add("circular dependency: $cycle")
    return
  }

  if ($visitState[$TaskId] -eq "visited") {
    return
  }

  $visitState[$TaskId] = "visiting"
  foreach ($dependency in @($tasksById[$TaskId].depends_on)) {
    Visit-Task $dependency (@($Stack) + $TaskId)
  }
  $visitState[$TaskId] = "visited"
}

foreach ($taskId in $tasksById.Keys) {
  Visit-Task $taskId @()
}

$activeIds = Split-IdList $ActiveTaskIds
$completedIds = Split-IdList $CompletedTaskIds
$completedSet = @{}
foreach ($id in $completedIds) {
  $completedSet[$id] = $true
}

foreach ($id in $activeIds) {
  if (-not $tasksById.ContainsKey($id)) {
    $errors.Add("active task id does not exist: $id")
  }
}

if ($activeIds.Count -gt 1) {
  foreach ($id in $activeIds) {
    if (-not $tasksById.ContainsKey($id)) {
      continue
    }

    $task = $tasksById[$id]
    if ($task.risk_level -eq "high") {
      $errors.Add("high-risk tasks are never dispatched in parallel: $id")
    }

    foreach ($dependency in @($task.depends_on)) {
      if ($activeIds -contains $dependency) {
        $errors.Add("dependency relationship between active tasks: $id depends on $dependency")
      }
      elseif ($completedIds.Count -gt 0 -and -not $completedSet.ContainsKey($dependency)) {
        $errors.Add("unfinished dependency: $id depends on $dependency")
      }
    }
  }

  for ($i = 0; $i -lt $activeIds.Count; $i++) {
    for ($j = $i + 1; $j -lt $activeIds.Count; $j++) {
      if (-not $tasksById.ContainsKey($activeIds[$i]) -or -not $tasksById.ContainsKey($activeIds[$j])) {
        continue
      }

      $left = $tasksById[$activeIds[$i]]
      $right = $tasksById[$activeIds[$j]]
      $leftScopes = @($left.write_scope) | ForEach-Object { Normalize-ScopePath $_ }
      $rightScopes = @($right.write_scope) | ForEach-Object { Normalize-ScopePath $_ }

      foreach ($scope in $leftScopes) {
        if ($rightScopes -contains $scope) {
          $errors.Add("overlapping write_scope: $scope used by $($left.id) and $($right.id)")
        }
      }
    }
  }
}

if ($ChangedFiles.Count -gt 0) {
  if ($activeIds.Count -ne 1) {
    $errors.Add("ChangedFiles enforcement requires exactly one ActiveTaskIds value")
  }
  elseif ($tasksById.ContainsKey($activeIds[0])) {
    $task = $tasksById[$activeIds[0]]
    foreach ($file in $ChangedFiles) {
      if (-not (Test-ChangedFileAllowed $file @($task.write_scope))) {
        $errors.Add("out-of-scope change: $file is not in write_scope for $($task.id)")
      }
    }
  }
}

$routing = foreach ($task in $tasks) {
  $route = "parallel_candidate"
  $reason = "risk_level is low"

  if ($task.risk_level -eq "high") {
    $route = "sequential"
    $reason = "high risk"
  }
  elseif ($task.risk_level -eq "medium" -and (Test-SharedContractScope $task)) {
    $route = "sequential"
    $reason = "medium risk touches shared contracts or requires spec review"
  }
  elseif (@($task.depends_on).Count -gt 0) {
    $reason = "parallel only after dependencies complete"
  }

  [pscustomobject]@{
    id = $task.id
    route = $route
    reason = $reason
  }
}

$result = [pscustomobject]@{
  plan = (Resolve-Path $PlanPath).Path
  task_count = $tasks.Count
  errors = @($errors)
  routing = @($routing)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
}
elseif ($errors.Count -eq 0) {
  Write-Output "Plan metadata valid: $($tasks.Count) task(s)."
  foreach ($item in $routing) {
    Write-Output "$($item.id): $($item.route) ($($item.reason))"
  }
}
else {
  foreach ($errorMessage in $errors) {
    Write-Output "ERROR: $errorMessage"
  }
}

if ($errors.Count -gt 0) {
  $global:LASTEXITCODE = 1
  return
}

$global:LASTEXITCODE = 0
