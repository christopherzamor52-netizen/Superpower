---
description: ACE Paradigm 1 - Build and run workflows/nodes
---
# ACE P1 - Run Workflow

Build, compose, and execute workflows using existing device abstractions.

**Note:**
- `run workflow`: Direct execution, no TDD needed
- `build node`: Test-first - write test, build node, verify test passes

## Usage

This command invokes the `ace-run-workflow` skill from ace-superpowers.

## ACE CLI Commands (Recommended)

### List Local Devices
```bash
ace device list              # local only (default)
ace device list --source all # include hub-synced
```

### List Workflows
```bash
ace workflow list              # local only (default)
ace workflow list --source all # include hub-synced
```

### Pull from ace-hub (if not found locally)
```bash
ace hub list --type devices    # see available devices
ace hub pull <device_id> --type device

ace hub list --type workflows  # see available workflows
ace hub pull <workflow_id> --type workflow

ace hub list --type nodes      # see available nodes
ace hub pull <node_id> --type node

ace hub list --type simulators # see available simulators
ace hub pull <sim_id> --type simulator
```

### Run a Workflow
```bash
ace workflow run <workflow_id> [--input params.json]
```

**前端实时监控（可选）**

执行工作流时，CLI 会自动检测前端开发服务器是否运行。如果已启动，会输出实时监控页面地址：

```
📊 实时监控: http://localhost:5173/workflow-run/<run-id>
```

在浏览器中打开该链接，可以查看：
- 实时 Timeline 时间轴（每个节点的执行状态）
- AI 生成的节点执行总结
- 结果数据的可视化（图像、文本、JSON）
- 执行完成后的报告视图

启动前端开发服务器：
```bash
ace frontend dev       # 默认端口 5173
ace frontend dev --port 5174
ace frontend status    # 检查状态
ace frontend stop      # 停止服务
```

### Build a Workflow from Description
```bash
ace workflow build "<description>" [--device <device_type>]
```

### Check Workflow Readiness
```bash
ace workflow check-readiness <workflow_id>
```

### Validate Workflow
```bash
ace workflow validate <workflow_id>
```

## Workflow

1. Clarify intent (build new? run existing? modify?)
2. For "run": search → confirm with user → execute
3. For "build": design → check nodes → **TDD for new nodes** → compose → validate
4. Execute with traces
5. Evolution闭环

## Invocation

```
Skill("ace-run-workflow")
```
