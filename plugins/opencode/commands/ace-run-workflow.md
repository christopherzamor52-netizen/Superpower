---
description: ACE Paradigm 1 - Build and run workflows/nodes
---
# ACE P1 - Run Workflow

Build, compose, and execute workflows using existing device abstractions.

**Note:**
- `run workflow`: Direct execution, no TDD needed
- `build node`: Test-first - write test, build node, verify test passes

## Usage

This command invokes the `ace-run-workflow` skill from the ace plugin.

## Test-First Node Building

```bash
# Step 1: Write test for the node
ace node test --create <node-id>_test.py --description "operation"

# Step 2: Build the node
ace node build --device <device-id> --description "operation"

# Step 3: Run test to verify
ace sandbox test <node-id>_test.py
```

## ACE CLI Commands (Recommended)

### List Devices
```bash
ace device list
```

### List Workflows
```bash
ace workflow list
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
3. For "build": design → check nodes → **test-first for new nodes** → compose → validate
4. Execute with traces
5. Evolution闭环

## Invocation

```
Skill("ace-run-workflow")
```
