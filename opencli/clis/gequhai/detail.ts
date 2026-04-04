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
        
        // 从页面文本中提取标题（格式通常为 "歌曲名 - 歌手名"）
        if (!title) {
          const textContent = document.body.textContent || '';
          const match = textContent.match(/(.+?)\s*-\s*(.+?)\n/);
          if (match) title = match[1]?.trim() || '';
        }

        // 尝试多种方式获取歌手名
        let artist = '';
        const artistEl = document.querySelector('#current-music-author')
          || document.querySelector('.artist-name');
        if (artistEl) artist = artistEl.textContent?.trim() || '';

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

    if (!result || !result.title) {
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
