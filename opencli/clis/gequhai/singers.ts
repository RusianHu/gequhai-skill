/**
 * 歌曲海 (Gequhai.com) - 热门歌手排行
 *
 * 获取热门歌手排行榜。
 */
import { cli, Strategy } from '../../registry.js';
import { CliError } from '../../errors.js';
import type { IPage } from '../../types.js';

cli({
  site: 'gequhai',
  name: 'singers',
  description: '热门歌手排行',
  domain: 'www.gequhai.com',
  strategy: Strategy.PUBLIC,
  browser: true,
  args: [
    { name: 'limit', type: 'int', default: 20, help: '返回结果数量（默认20，最大100）' },
  ],
  columns: ['rank', 'singer', 'url'],
  func: async (page: IPage, args) => {
    const t0 = Date.now();
    const limit = Math.min(Number(args.limit) || 20, 100);
    const url = 'https://www.gequhai.com/singer';

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
          const singerLink = cells[1]?.querySelector('a');
          const singer = singerLink?.textContent?.trim() || cells[2]?.textContent?.trim() || '';
          const singerUrl = singerLink?.href || '';
          if (singer) {
            results.push({ rank, singer, url: singerUrl });
          }
        });
        return results;
      })()
    `);

    const items = Array.isArray(results) ? results : [];
    if (items.length === 0) {
      throw new CliError(
        'NO_DATA',
        '无法获取热门歌手数据',
        '网站可能暂时不可用或布局已更改',
      );
    }

    const totalMs = Date.now() - t0;
    console.error(`[性能] 页面加载: ${t1 - t0}ms | 总耗时: ${totalMs}ms | 结果: ${items.length} 条`);
    return items.map((item: any) => ({
      rank: item.rank,
      singer: item.singer,
      url: item.url,
    }));
  },
});
