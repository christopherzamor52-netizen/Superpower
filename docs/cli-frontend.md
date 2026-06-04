# ace frontend — 前端开发服务器管理命令

`ace frontend` 是 ACE CLI 的前端管理子命令，用于管理位于 `src/frontend/` 下的 React + Vite 前端工程。无需手动进入 frontend 目录即可安装依赖、启动开发服务器、构建生产版本以及查看/停止服务状态。

---

## 命令概览

```
ace frontend [COMMAND]
```

| 子命令 | 作用 |
|--------|------|
| `install` | 安装前端依赖 (`npm install`) |
| `dev`     | 后台启动 Vite 开发服务器 |
| `build`   | 构建生产版本 (`vite build`) |
| `status`  | 检查开发服务器是否在运行 |
| `stop`    | 停止开发服务器 |

---

## install — 安装依赖

```bash
ace frontend install
```

在 `src/frontend/` 目录下执行 `npm install`，安装 `package.json` 中声明的所有依赖。

**输出示例：**
```
Installing dependencies in /data/codes/ace/src/frontend ...
[npm install output]
Dependencies installed
```

---

## dev — 启动开发服务器

```bash
ace frontend dev [OPTIONS]
```

**选项：**

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `--host` | `0.0.0.0` | 绑定主机地址 |
| `--port` | `5173`    | 绑定端口 |

**示例：**
```bash
ace frontend dev           # 默认端口 5173
ace frontend dev --port 5174
ace frontend dev --host 127.0.0.1 --port 3000
```

**行为说明：**
- 在后台启动 `npx vite dev`，不阻塞当前终端
- 启动成功后将 PID 写入 `/tmp/ace-frontend.pid`
- 如果检测到已有进程在运行（通过 PID 文件），会拒绝重复启动并提示已有实例

**输出示例：**
```
Starting frontend dev server on http://0.0.0.0:5173/ ...
Frontend dev server started (PID: 3724669)
  Visit http://localhost:5173/
  Run 'ace frontend stop' to stop the server
```

---

## build — 构建生产版本

```bash
ace frontend build
```

在 `src/frontend/` 下运行 `npx vite build`，输出到 `src/frontend/dist/`。

**输出示例：**
```
Building frontend for production ...
[vite build output]
Build completed
```

---

## status — 查看服务器状态

```bash
ace frontend status
```

读取 `/tmp/ace-frontend.pid` 并检查对应进程是否存活。

**输出示例：**
```
Frontend dev server: running (PID: 3724669)
```
或
```
Frontend dev server: not running
```

如果 PID 文件存在但进程已不存在，会自动清理过期的 PID 文件并提示 `stopped (stale PID: ...)`。

---

## stop — 停止开发服务器

```bash
ace frontend stop
```

读取 `/tmp/ace-frontend.pid`，向对应进程发送 `SIGTERM` 信号，并删除 PID 文件。

**输出示例：**
```
Sent SIGTERM to frontend dev server (PID: 3724669)
Frontend dev server stopped
```

如果服务器未运行，则提示：
```
Frontend dev server is not running
```

---

## 常见用例

### 用例 1：首次启动前端开发
```bash
ace frontend install   # 安装依赖（首次）
ace frontend dev       # 启动开发服务器
ace frontend status    # 确认运行中
```

### 用例 2：切换端口避免冲突
```bash
ace frontend stop
ace frontend dev --port 5174
```

### 用例 3：部署前构建
```bash
ace frontend build
# 检查 dist/ 目录输出
```

### 用例 4：清理异常退出的残留进程
```bash
ace frontend status    # 发现 stale PID
ace frontend stop      # 清理残留
ace frontend dev       # 重新启动
```

---

## 注意事项

1. **PID 文件位置**：`/tmp/ace-frontend.pid`。该文件用于状态检查和停止操作，请勿手动修改。

2. **dev 是后台进程**：`ace frontend dev` 不会在前台输出 Vite 的日志。如果需要查看实时日志，请直接在前端目录运行 `npx vite dev`。

3. **进程存活检测**：使用 `os.kill(pid, 0)` 检测进程是否存在，这是一种跨平台且无害的检测方式。

4. **信号处理**：停止时发送 `SIGTERM`。如果进程未响应，可手动使用 `kill -9 <pid>` 强制终止。

5. **依赖 npm**：前端命令通过 `npx` 调用 Vite，确保系统已安装 Node.js 和 npm。

6. **前端目录约定**：命令固定操作 `src/frontend/`（相对于 `ace/cli/commands/frontend.py` 解析的路径）。如果前端目录位置变化，需要同步修改 `FRONTEND_DIR` 常量。
