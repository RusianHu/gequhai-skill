---
name: gequhai
description: Use this skill whenever the user wants to search songs, singers, lyrics, hot-song charts, new-song charts, MP3 downloads, or Quark high-quality links from Gequhai.com / 歌曲海. Trigger for requests such as 搜歌、找歌词、周杰伦有什么歌、新歌榜、热门歌曲排行、下载这首歌、找高品质链接, even when the user does not explicitly mention gequhai.
---

# gequhai

使用 `opencli gequhai` 作为访问 **歌曲海（Gequhai.com）** 的首选方式。这个 skill 应该帮助 Claude 以最少步骤完成：搜索歌曲、查看榜单、读取歌词与详情、下载 MP3、获取夸克网盘高品质链接。

优先使用 CLI；只有在 CLI 无法覆盖目标页面或结果需要人工校验时，才回退到浏览器自动化。

## 何时使用

当用户有以下意图时，使用本 skill：

- 搜索歌曲、歌手、歌词
- 查询新歌榜、热门歌曲排行、热门歌手排行
- 查看某首歌的详情页、歌词、下载信息
- 下载 MP3 到本地
- 获取夸克网盘高品质链接
- 用户只给出模糊中文意图，例如“帮我找周杰伦的歌”“这首歌能下载吗”“有没有高品质链接”

如果用户的问题与歌曲海无关，或任务本质上不是音乐搜索/下载，不要使用本 skill。

## 执行原则

1. 先判断用户要的是：搜索、榜单、详情、下载，还是高品质链接。
2. 只运行最小必要命令，不要为了回答简单问题执行多余步骤。
3. 优先返回结构化结果；列表场景用表格，详情场景用简洁字段。
4. 如果下载或详情请求依赖受限接口，注意速率限制，不要连续高频调用。
5. 如果站点能力本身不支持某种结果，要明确说明限制，不要臆造高品质直链或不存在的数据。

## 环境缺失处理

如果当前环境里不存在 `opencli gequhai`，或者执行相关命令时报错提示命令不存在、子命令未注册、CLI 文件缺失，则不要假装命令已经可用。

此时应明确告知用户：当前机器尚未安装 gequhai 的 opencli CLI，并引导其从预发布仓库安装：`https://github.com/RusianHu/gequhai-skill`

推荐安装方式：

### Windows / PowerShell

```powershell
pwsh -File ./scripts/install.ps1 -CleanCli
```

### Linux / macOS

如果安装了 PowerShell 7，优先使用同一个安装脚本：

```bash
pwsh -File ./scripts/install.ps1 -CleanCli
```

如果暂时只需要安装 opencli CLI，也可以执行：

```bash
bash ./scripts/sync-opencli.sh --clean
```

只有在用户明确不想安装，或者当前任务只是临时查一个页面结果时，才退回浏览器自动化作为临时方案。

## 命令选择工作流

### 1. 搜索歌曲或歌手

当用户要“找歌 / 搜歌 / 搜歌手 / 查某人有哪些歌”时，优先使用：

```bash
opencli gequhai search "<关键词>" -f json
```

适用示例：

```bash
opencli gequhai search "周杰伦" -f json
opencli gequhai search "晴天 周杰伦" --limit 10 -f json
```

### 2. 查询榜单

- 新歌榜：

```bash
opencli gequhai new --limit 20 -f json
```

- 热门歌曲排行：

```bash
opencli gequhai hot --limit 20 -f json
```

- 热门歌手排行：

```bash
opencli gequhai singers --limit 20 -f json
```

如果用户只想看前几项，显式传 `--limit`，避免返回过长内容。

### 3. 查看歌曲详情、歌词、下载信息

当用户已经给出歌曲 ID，或明确要歌词、详情、下载链接时，使用：

```bash
opencli gequhai detail <id> -f json
```

这个命令适合读取：

- 标题
- 歌手
- 歌词
- 播放页链接
- 下载相关信息

### 4. 下载 MP3 到本地

当用户明确要求把歌曲保存到本地时，使用：

```bash
opencli gequhai download <id> --output <目录>
```

示例：

```bash
opencli gequhai download 553 --output ./downloads
```

下载成功后，优先向用户报告：

- 保存路径
- 文件名
- 码率 / 时长等可用信息

### 5. 获取夸克网盘高品质链接（不能直链下载）

当用户明确要“高品质 / SQ / 无损替代来源 / 夸克链接”时，使用：

```bash
opencli gequhai quark <id>
```

如果用户只是说“下载这首歌”，默认优先完成普通 MP3 下载；只有当用户明确要高品质版本，或普通直链无法满足时，再使用 `quark`。

## 输出规范

### 列表场景

搜索结果、榜单结果尽量整理成简洁表格，优先包含：

- 序号
- 歌名
- 歌手
- 链接

推荐格式：

```text
| # | 歌名 | 歌手 | 链接 |
|---|------|------|------|
| 1 | 青花瓷 | 周杰伦 | https://www.gequhai.com/play/553 |
```

规则：

- 保留站点原始歌名，不要臆造翻译。
- 如果已知官方中文名或用户明确要求翻译，可以补充说明，但不要强制改写原始标题。
- 链接优先给歌曲详情页链接，便于用户继续查看歌词或下载。

### 详情场景

歌曲详情尽量压缩为稳定字段，例如：

```json
{
  "title": "那天下雨了",
  "artist": "周杰伦",
  "lyrics": "[00:00.00]那天下雨了 - 周杰伦\n...",
  "url": "https://www.gequhai.com/play/5863066",
  "download_url": "https://pan.quark.cn/s/..."
}
```

如果歌词很长，只展示前几行并说明可继续展开。

### 下载场景

下载完成后明确写出：

- 已下载成功 / 失败原因
- 文件保存位置
- 文件名
- 码率、时长、文件大小（如果命令有返回）

## 关键事实与限制

### 下载与音质

- 站点普通 MP3 直链来自 kuwo.cn CDN，链接通常带时效性 token。
- 直链通常只提供标准品质（常见为 128kbps）。
- 高品质资源不一定有直链；如果用户要 SQ 或更高品质，优先尝试 `quark` 命令获取夸克网盘链接。
- 不要把普通 MP3 直链误报为高品质资源。

### 详情页与接口特点

- 页面中的 `window.play_id` 是编码后的值，不是原始数字 ID。
- 获取 MP3 直链时，站点依赖编码后的 `play_id` 调用接口。
- 这些实现细节主要用于理解站点行为；正常情况下应优先依赖现成的 `opencli gequhai` 子命令，而不是手写接口调用。

### 速率限制

- `/api/music` 相关能力存在频率限制。
- `detail` / `download` 等依赖该能力的请求之间，应保留至少约 20 秒安全间隔。
- 如果站点返回类似“请 N 秒后再试”或 `code: 429`，应把等待时间明确告知用户，而不是重复轰炸接口。

## 回退策略

如果 `opencli gequhai` 无法覆盖某个页面、某个榜单结构发生变化，或需要人工确认页面内容，可回退到浏览器自动化。

回退顺序：

1. 打开目标页面
2. 读取页面结构
3. 必要时点击、输入或滚动
4. 提取结果后再整理为面向用户的结构化输出

回退只用于补足 CLI 能力，不应替代已有命令的常规使用。

## 示例命令

```bash
# 搜索歌曲
opencli gequhai search "周杰伦" -f json

# 搜索更具体的关键词
opencli gequhai search "晴天 周杰伦" --limit 10 -f json

# 新歌榜
opencli gequhai new --limit 10 -f json

# 热门歌曲排行
opencli gequhai hot --limit 10 -f json

# 热门歌手排行
opencli gequhai singers --limit 10 -f json

# 查看歌曲详情
opencli gequhai detail 5863066 -f json

# 下载歌曲
opencli gequhai download 553 --output ./downloads

# 获取夸克高品质链接
opencli gequhai quark 553
```

## 失败处理

- 搜索无结果：直接告知未命中，并建议更换关键词或补充歌手名。
- 榜单解析异常：说明页面结构可能变化，并尝试浏览器回退。
- 下载失败：说明是接口限制、链接失效还是目标资源不存在。
- 高品质不可用：明确说明该站点的高品质通常通过夸克网盘分发，而不是普通 MP3 直链。

## 目标

让 Claude 在涉及歌曲海的任务中，稳定地做到：

- 正确选择命令
- 少走弯路
- 不误报音质或下载能力
- 输出清晰、简洁、可直接交付给用户
