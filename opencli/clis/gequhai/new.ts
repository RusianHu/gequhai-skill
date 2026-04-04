/**
 * 歌曲海 (Gequhai.com) - 新歌榜
 *
 * 获取最新上传的歌曲列表。
 */
import { cli, Strategy } from '../../registry.js';
import { CliError } from '../../errors.js';
import type { IPage } from '../../types.js';

cli({
  site: 'gequhai',
  name: 'new',
  description: '新歌榜 - 最新上传的歌曲',
  domain: 'www.gequhai.com',
  strategy: Strategy.PUBLIC,
  browser: true,
  args: [
    { name: 'limit', type: 'int', default: 20, help: '返回结果数量（默认20，最大100）' },
  ],
  columns: ['rank', 'song', 'artist', 'url'],
  func: async (page: IPage, args) => {
    const t0 = Date.now();
    const limit = Math.min(Number(args.limit) || 20, 100);
    const url = 'https://www.gequhai.com/top/new';

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
          if (cells.length < 4) return;
          const rank = cells[0]?.textContent?.trim() || '';
          const songLink = cells[2]?.querySelector('a');
          const song = songLink?.textContent?.trim() || '';
          const songUrl = songLink?.href || '';
          const artist = cells[3]?.textContent?.trim() || '';
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
        '无法获取新歌榜数据',
        '网站可能暂时不可用或布局已更改',
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
