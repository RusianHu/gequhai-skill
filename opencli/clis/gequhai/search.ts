/**
 * 歌曲海 (Gequhai.com) - 搜索歌曲/歌手
 *
 * 搜索指定关键词的歌曲或歌手，返回搜索结果列表。
 */
import { cli, Strategy } from '../../registry.js';
import { CliError } from '../../errors.js';
import type { IPage } from '../../types.js';

cli({
  site: 'gequhai',
  name: 'search',
  description: '搜索歌曲或歌手',
  domain: 'www.gequhai.com',
  strategy: Strategy.PUBLIC,
  browser: true,
  args: [
    { name: 'keyword', type: 'string', required: true, positional: true, help: '搜索关键词（歌名或歌手）' },
    { name: 'limit', type: 'int', default: 20, help: '返回结果数量（默认20）' },
  ],
  columns: ['rank', 'song', 'artist', 'url'],
  func: async (page: IPage, args) => {
    const t0 = Date.now();
    const keyword = args.keyword;
    const limit = Math.min(Number(args.limit) || 20, 100);
    const url = `https://www.gequhai.com/s/${encodeURIComponent(keyword)}`;

    await page.goto(url);
    const t1 = Date.now();
    await page.wait({ time: 2 });

    const results = await page.evaluate(`
      (() => {
        const rows = document.querySelectorAll('table tbody tr');
        const results = [];
        rows.forEach((row, index) => {
          if (index >= ${limit}) return;
          const cells = row.querySelectorAll('td');
          if (cells.length < 3) return;
          const rank = cells[0]?.textContent?.trim() || '';
          const songLink = cells[1]?.querySelector('a');
          const song = songLink?.textContent?.trim() || '';
          const songUrl = songLink?.href || '';
          const artist = cells[2]?.textContent?.trim() || '';
          if (song) {
            results.push({ rank, song, artist, url: songUrl });
          }
        });
        return results;
      })()
    `);

    const items = Array.isArray(results) ? results : [];
    if (items.length === 0) {
      throw new CliError(
        'NO_DATA',
        `未找到与 "${keyword}" 相关的歌曲`,
        '请尝试其他关键词搜索',
      );
    }

    const totalMs = Date.now() - t0;
    console.error(`[性能] 页面加载: ${t1 - t0}ms | 总耗时: ${totalMs}ms | 结果: ${items.length} 条`);
    return items.map((item: any) => ({
      rank: item.rank,
      song: item.song,
      artist: item.artist,
      url: item.url,
    }));
  },
});
