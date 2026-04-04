# gequhai-skill 

> 歌曲海 (Gequhai.com) 自动化 CLI Skill — 基于 opencli 框架的音乐搜索/排行/歌词获取工具。

> 更新此文档时保持 **精简、高信息熵**

## 架构

```
~/.roo/skills/gequhai/SKILL.md          # Skill 描述（触发词、命令参考、回退策略）
~/.opencli/clis/gequhai/search.ts       # 搜索歌曲/歌手
~/.opencli/clis/gequhai/new.ts          # 新歌榜
~/.opencli/clis/gequhai/hot.ts          # 热门歌曲排行
~/.opencli/clis/gequhai/singers.ts      # 热门歌手排行
~/.opencli/clis/gequhai/detail.ts       # 歌曲详情（歌词+下载链接）
```

## 站点拆分工程

| 发现 | 详情 |
|------|------|
| 页面结构 | 表格布局 (`table tbody tr`)，选择器稳定 |
| API 端点 | `POST /api/music` — `id=<music_id>&type=0`，需 `X-Custom-Header: SecretKey` |
| JS 源码 | `play.js` 含 APlayer 播放器逻辑、localStorage 收藏、夸克网盘下载 |
| 下载机制 | 通过夸克网盘链接分发，MP3 实际源为 kuwo.cn CDN |
| 反爬 | 百度统计 + 广告追踪，无严格反爬 |

## 技术决策

- **Strategy: PUBLIC + browser: true** — 站点无需登录，browser 模式支持 DOM 抓取
- **DOM 选择器** — 基于 `table tbody tr` 结构，各页面列索引不同（新歌榜: rank[0], song[2], artist[3]）
- **等待策略** — `page.wait({ time: 2 })` 替代 `waitForSelector`（IPage 接口限制）
- **detail 命令** — 多回退选择器获取标题/歌手，兼容页面结构变化

## 关键发现

- **play_id 编码** — 页面中 `window.play_id` 是编码后的值（如 `TDecwlvB`），不是原始数字 ID
- **API 调用** — 必须用编码后的 play_id 调用 `/api/music` 才能获取 MP3 直链
- **MP3 源** — kuwo.cn CDN，URL 含时效性 token

## 测试结果

| 命令 | 状态 | 详情 |
|------|------|------|
| `search "周杰伦"` | ✅ | 返回5首歌曲 |
| `new --limit 5` | ✅ | 返回新歌榜 |
| `singers --limit 5` | ✅ | 返回歌手榜 |
| `detail 5863066` | ✅ | 返回完整歌词+下载链接 |
| `download 553` | ✅ | 下载青花瓷.mp3 (3.65MB) |
| `hot --limit 5` | ⚠️ | 页面结构不同 |

## 端到端测试结果

| 测试场景 | 结果 |
|----------|------|
| 搜索 "晴天 周杰伦" | ✅ 返回5条结果（歌名+歌手+URL） |
| 下载 ID 326 | ✅ 晴天 - 周杰伦 [128kbps].mp3 (4.12 MB) |
| 文件名规范性 | ✅ `{歌名} - {歌手} [{码率}].mp3` 含音质信息 |

## 下载后 MP3 详细信息

```json
{
  "title": "晴天",
  "artist": "周杰伦",
  "album": "叶惠美",
  "file_size": "4.12 MB",
  "bitrate": "128kbps",
  "duration": "270s (4.5min)",
  "sample_rate": "44100Hz",
  "channels": "stereo"
}
```

## 使用

```bash
# 搜索 → 获取ID → 下载
opencli gequhai search "晴天 周杰伦" -f table
opencli gequhai download 326 --output ./downloads
```
