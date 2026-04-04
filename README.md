# gequhai-skill

基于 [歌曲海](Gequhai.com) 的自动化 Skill + opencli CLI 项目。

通过这个 skill 可以 **让自动化工具从互联网中下载公开的MP3歌曲**。

<img width="1118" height="281" alt="image" src="https://github.com/user-attachments/assets/14810c74-139d-461f-bb6c-8e7e16370ccb" />

<img width="519" height="371" alt="image" src="https://github.com/user-attachments/assets/d8f60262-b355-4801-8ee5-7bf13228087a" />

---

## 一句话完成安装（推荐）

和你的 AI AGENT 工具说：

```text
帮我安装这个 skill （https://github.com/RusianHu/gequhai-skill）
```

## opencli 默认安装位置

### Windows

- opencli CLI：`C:/Users/<用户名>/.opencli/clis/gequhai`

### Linux / macOS

- opencli CLI：`$HOME/.opencli/clis/gequhai`

脚本默认使用以上位置，也允许通过参数覆盖。

## 同步 CLI 到 opencli 目录

### Windows PowerShell

复制模式（推荐，最稳妥）：

```powershell
pwsh -File ./scripts/sync-opencli.ps1 -Clean
```

符号链接模式（适合本地开发联调）：

```powershell
pwsh -File ./scripts/sync-opencli.ps1 -Mode symlink
```

### Windows BAT 入口

```bat
scripts\sync-opencli.bat -Clean
scripts\sync-opencli.bat -Mode symlink
```

### Linux / macOS

复制模式：

```bash
bash ./scripts/sync-opencli.sh --clean
```

符号链接模式：

```bash
bash ./scripts/sync-opencli.sh --mode symlink
```

## 首次安装（opencli CLI 缺失时）

如果当前环境里还没有 `~/.opencli/clis/gequhai`，或者执行 `opencli gequhai ...` 提示命令不存在，按下面方式进行首次安装。

### 1. 获取项目

```bash
git clone https://github.com/RusianHu/gequhai-skill
cd gequhai-skill
```

如果你是从压缩包解压得到项目，进入项目根目录后直接执行下面的安装命令即可。

### 2. 安装 Skill + CLI

#### PowerShell 统一安装入口

```powershell
pwsh -File ./scripts/install.ps1 -CleanCli
```

符号链接模式：

```powershell
pwsh -File ./scripts/install.ps1 -Mode symlink
```

只安装 Skill：

```powershell
pwsh -File ./scripts/install.ps1 -SkipCli
```

只安装 CLI：

```powershell
pwsh -File ./scripts/install.ps1 -SkipSkill -CleanCli
```

## 使用示例

```bash
opencli gequhai search "周杰伦" -f json
opencli gequhai search "晴天 周杰伦" --limit 10 -f json
opencli gequhai new --limit 5 -f json
opencli gequhai singers --limit 5 -f json
opencli gequhai detail 5863066 -f json
opencli gequhai download 553 --output ./downloads
opencli gequhai quark 553
```

## 发布前最小验证

建议至少运行以下命令：

```bash
opencli gequhai search "周杰伦" -f json
opencli gequhai new --limit 5 -f json
opencli gequhai singers --limit 5 -f json
opencli gequhai detail 5863066 -f json
opencli gequhai quark 553
```

如果要验证下载链路，再额外测试：

```bash
opencli gequhai download 553 --output ./downloads
```

注意：`detail` / `download` 依赖受限接口，建议两次请求之间保留至少约 20 秒间隔。

## 已知限制

- 普通 MP3 直链通常是标准品质（常见为 128kbps）
- 高品质资源通常通过夸克网盘分发，使用 [`opencli gequhai quark`](opencli/clis/gequhai/quark.ts) 获取
- 某些榜单页面结构可能变化，必要时需要根据 [`AGENTS.md`](AGENTS.md) 中的页面结构说明回退到浏览器自动化
- Windows 下创建符号链接通常需要开发者模式或管理员权限

## 后续建议

为了进一步完善打包发布，下一步可以继续补：

- [`scripts/package.ps1`](scripts/package.ps1)：生成 `dist/` 发布压缩包
- [`tests/smoke.ps1`](tests/smoke.ps1)：自动化冒烟验证
- [`CHANGELOG.md`](CHANGELOG.md)：版本记录

当前仓库已经具备“源码归档 + 跨平台同步 + 统一安装”的基础发布结构。

## 许可证

[`LICENSE`](LICENSE)
