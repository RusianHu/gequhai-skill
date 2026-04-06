/**
 * 歌曲海 (Gequhai.com) - 歌曲详情
 *
 * 获取指定歌曲的详细信息，包括歌词、下载链接等。
 */
import { cli, Strategy } from '../../registry.js';
import { CliError } from '../../errors.js';
import type { IPage } from '../../types.js';

cli({
  site: 'gequhai',
  name: 'detail',
  description: '获取歌曲详情（歌词、下载链接等）',
  domain: 'www.gequhai.com',
  strategy: Strategy.PUBLIC,
  browser: true,
  args: [
    { name: 'id', type: 'string', required: true, positional: true, help: '歌曲ID（从搜索结果或排行榜获取）' },
  ],
  columns: ['title', 'artist', 'lyrics', 'download_url', 'cover', 'url'],
  func: async (page: IPage, args) => {
    const t0 = Date.now();
    const id = args.id;
    const url = `https://www.gequhai.com/play/${id}`;

    await page.goto(url);
    const t1 = Date.now();
    await page.wait({ time: 2 });

    const result = await page.evaluate(`
      (() => {
        // 尝试多种方式获取歌曲标题
        let title = '';
        const titleEl = document.querySelector('#current-music-title')
          || document.querySelector('h1')
          || document.querySelector('.music-title');
        if (titleEl) title = titleEl.textContent?.trim() || '';

        // 尝试多种方式获取歌手名
        let artist = '';
        const artistEl = document.querySelector('#current-music-author')
          || document.querySelector('.artist-name');
        if (artistEl) artist = artistEl.textContent?.trim() || '';

        // 从页面文本中提取标题（格式通常为 "歌曲名 - 歌手名"）
        // 仅在标题选择器失效时使用，且要求页面有歌词区或下载按钮作为"歌曲页特征"
        let titleFromText = '';
        let artistFromText = '';
        if (!title) {
          const hasLrc = !!document.querySelector('#content-lrc2');
          const hasDownload = !!document.querySelector('#btn-download-mp3');
          const hasAppData = !!window['appData'];
          // 只有存在歌曲页特征时才尝试从文本提取
          if (hasLrc || hasDownload || hasAppData) {
            // 优先从播放器容器或主内容区提取
            const mainContent = document.querySelector('.aplayer, .music-info, .play-container, main') || document.body;
            const textContent = mainContent.textContent || '';
            const titleRegex = new RegExp('(.+?)\\s*-\\s*(.+?)(?:\\n|$)');
            const match = textContent.match(titleRegex);
            if (match) {
              titleFromText = match[1]?.trim() || '';
              artistFromText = match[2]?.trim() || '';
              // 验证提取的标题看起来像歌名（不太长，不含特殊字符过多）
              if (titleFromText.length > 0 && titleFromText.length < 100) {
                title = titleFromText;
                // 如果歌手名为空，用从文本提取的填充
                if (!artist) artist = artistFromText;
              }
            }
          }
        }

        // 获取歌词
        const lrcEl = document.querySelector('#content-lrc2');
        const lyrics = lrcEl?.textContent?.trim() || '';

        // 获取下载链接
        const downloadBtn = document.querySelector('#btn-download-mp3');
        const downloadUrl = downloadBtn?.getAttribute('href') || '';

        // 获取封面图片
        const coverImg = document.querySelector('.aplayer-pic img') || document.querySelector('.aplayer-pic');
        const cover = coverImg?.getAttribute('src') || '';

        return { title, artist, lyrics, download_url: downloadUrl, cover, url: window.location.href };
      })()
    `);

    // 增强成功判定：要求 title 非空且至少满足以下之一：有歌词、有下载链接、有封面
    const hasLyrics = result.lyrics && result.lyrics.length > 10;
    const hasDownloadUrl = result.download_url && result.download_url.startsWith('http');
    const hasCover = result.cover && result.cover.startsWith('http');
    const hasValidContent = hasLyrics || hasDownloadUrl || hasCover;

    if (!result || !result.title || !hasValidContent) {
      throw new CliError(
        'NO_DATA',
        `无法获取歌曲 ID ${id} 的详情`,
        '歌曲可能不存在或页面布局已更改',
      );
    }

    const totalMs = Date.now() - t0;
    console.error(`[性能] 页面加载: ${t1 - t0}ms | 总耗时: ${totalMs}ms`);
    return {
      title: result.title,
      artist: result.artist,
      lyrics: result.lyrics,
      download_url: result.download_url,
      cover: result.cover,
      url: result.url,
    };
  },
});
