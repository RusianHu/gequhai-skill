/**
 * 歌曲海 (Gequhai.com) - 下载歌曲
 *
 * 通过 API 获取 MP3 直链并下载到本地。
 * 关键：play_id 是编码后的值（如 TDecwlvB），不是原始数字 ID。
 * 文件名格式：{歌名} - {歌手} [{码率}].mp3
 */
import { cli, Strategy } from '../../registry.js';
import { CliError } from '../../errors.js';
import type { IPage } from '../../types.js';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as https from 'node:https';
import * as http from 'node:http';

cli({
  site: 'gequhai',
  name: 'download',
  description: '下载歌曲 MP3 到本地（文件名含码率信息）',
  domain: 'www.gequhai.com',
  strategy: Strategy.PUBLIC,
  browser: true,
  args: [
    { name: 'id', type: 'string', required: true, positional: true, help: '歌曲ID（数字ID或编码ID均可）' },
    { name: 'output', type: 'string', default: './downloads', help: '输出目录' },
  ],
  columns: ['title', 'artist', 'album', 'file_path', 'file_size', 'bitrate', 'duration', 'sample_rate', 'channels'],
  func: async (page: IPage, args) => {
    const t0 = Date.now();
    const inputId = args.id;
    const outputDir = args.output || './downloads';

    // 确保输出目录存在
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    // 导航到播放页面
    await page.goto(`https://www.gequhai.com/play/${inputId}`);
    const t1 = Date.now();
    await page.wait({ time: 2 });

    // 从页面 HTML 中提取编码后的 play_id、歌曲信息
    const info = await page.evaluate(`
      (() => {
        const appData = window.appData || {};
        const playId = window.play_id || '';
        const mp3Type = window.mp3_type ?? 0;
        return {
          title: appData.mp3_title || '未知歌曲',
          artist: appData.mp3_author || '未知艺术家',
          play_id: playId,
          mp3_type: mp3Type
        };
      })()
    `);

    if (!info.play_id) {
      throw new CliError(
        'NO_PLAY_ID',
        `无法获取歌曲 ${inputId} 的播放ID`,
        '页面结构可能已更改',
      );
    }

    // 通过 API 获取 MP3 直链
    const apiResult = await page.evaluate(`
      (() => {
        return new Promise((resolve) => {
          fetch('/api/music', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'X-Custom-Header': 'SecretKey',
              'X-Requested-With': 'XMLHttpRequest'
            },
            body: 'id=${info.play_id}&type=${info.mp3_type}'
          })
          .then(r => r.json())
          .then(data => resolve(data))
          .catch(err => resolve({ code: 500, msg: err.message }));
        });
      })()
    `);

    if (!apiResult || apiResult.code !== 200) {
      throw new CliError(
        'API_ERROR',
        `获取 MP3 链接失败: ${apiResult?.msg || '未知错误'}`,
        '歌曲可能不支持下载或有版权限制',
      );
    }

    const mp3Url = apiResult.data?.url || '';
    if (!mp3Url) {
      throw new CliError(
        'NO_URL',
        '未找到 MP3 下载链接',
        '歌曲可能不支持下载',
      );
    }

    // 通过 HEAD 请求获取文件大小
    const tHead = Date.now();
    let fileSizeBytes = 0;
    await new Promise<void>((resolve) => {
      const client = mp3Url.startsWith('https') ? https : http;
      const req = client.request(mp3Url, { method: 'HEAD', timeout: 10000 }, (res) => {
        if (res.headers['content-length']) {
          fileSizeBytes = parseInt(res.headers['content-length'], 10);
        }
        resolve();
      });
      req.on('error', () => resolve());
      req.on('timeout', () => { req.destroy(); resolve(); });
      req.end();
    });
    const headMs = Date.now() - tHead;

    // 先用临时文件名下载
    const tempPath = path.resolve(outputDir, `_temp_${inputId}.mp3`);
    const tDownload = Date.now();

    await new Promise<void>((resolve, reject) => {
      const client = mp3Url.startsWith('https') ? https : http;
      const timeout = setTimeout(() => reject(new Error('Download timeout')), 60000);

      client.get(mp3Url, { timeout: 30000 }, (res) => {
        if (res.statusCode === 302 || res.statusCode === 301) {
          const loc = res.headers.location;
          if (loc) {
            client.get(loc, (res2) => {
              const ws = fs.createWriteStream(tempPath);
              res2.pipe(ws);
              ws.on('finish', () => { ws.close(); clearTimeout(timeout); resolve(); });
              ws.on('error', reject);
            }).on('error', reject);
          }
          return;
        }
        const ws = fs.createWriteStream(tempPath);
        res.pipe(ws);
        ws.on('finish', () => { ws.close(); clearTimeout(timeout); resolve(); });
        ws.on('error', reject);
      }).on('error', reject);
    });

    // 分析 MP3 文件获取码率、时长等信息
    let mp3Info: any = {};
    try {
      const { execSync } = await import('node:child_process');
      const scriptPath = 'C:\\Users\\admin\\.opencli\\clis\\gequhai\\_analyze_mp3.py';
      const result = execSync(`python "${scriptPath}" "${tempPath}"`, { encoding: 'utf8', timeout: 10000 });
      mp3Info = JSON.parse(result);
    } catch {
      // 如果分析失败，跳过
    }

    // 构建含码率的文件名：{歌名} - {歌手} [{码率}].mp3
    const bitrate = mp3Info.bitrate || '';
    const title = mp3Info.title || info.title;
    const artist = mp3Info.artist || info.artist;
    const bitrateTag = bitrate ? ` [${bitrate}]` : '';
    const finalFileName = `${title} - ${artist}${bitrateTag}.mp3`.replace(/[<>:"/\\|?*]/g, '_');
    const filePath = path.resolve(outputDir, finalFileName);

    // 重命名为最终文件名
    if (tempPath !== filePath) {
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath); // 删除已存在的文件
      }
      fs.renameSync(tempPath, filePath);
    }

    const fileSizeMB = mp3Info.file_size || (fileSizeBytes > 0
      ? `${(fileSizeBytes / (1024 * 1024)).toFixed(2)} MB`
      : `${(fs.statSync(filePath).size / (1024 * 1024)).toFixed(2)} MB`);

    const downloadMs = Date.now() - tDownload;
    const analyzeMs = Date.now() - tDownload - downloadMs;
    const totalMs = Date.now() - t0;
    const speedMBps = (fileSizeBytes / 1024 / 1024) / (downloadMs / 1000);
    console.error(`[性能] 页面加载: ${t1 - t0}ms | HEAD: ${headMs}ms | 下载: ${downloadMs}ms (${speedMBps.toFixed(2)} MB/s) | 分析: ${analyzeMs}ms | 总耗时: ${totalMs}ms`);

    return {
      title,
      artist,
      album: mp3Info.album || '',
      file_path: filePath,
      file_size: fileSizeMB,
      bitrate: bitrate || 'N/A',
      duration: mp3Info.duration || 'N/A',
      sample_rate: mp3Info.sample_rate || 'N/A',
      channels: mp3Info.channels || 'N/A',
      mp3_url: mp3Url,
    };
  },
});
