/**
 * 歌曲海 (Gequhai.com) - 热门歌曲排行
 *
 * 获取热门推荐歌曲列表。
 * 注意：热门榜页面结构与搜索页/新歌榜不同，使用多种选择器回退。
 */
import { cli, Strategy } from '../../registry.js';
import { CliError } from '../../errors.js';
import type { IPage } from '../../types.js';

cli({
  site: 'gequhai',
  name: 'hot',
  description: '热门歌曲排行',
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
    const url = 'https://www.gequhai.com/hot-music/';

    await page.goto(url);
    const t1 = Date.now();
    await page.wait({ time: 2 });

    // 诊断日志：探测页面结构
    const diag = await page.evaluate(`
      (() => {
        const tableRows = document.querySelectorAll('table tbody tr');
        const listItems = document.querySelectorAll('.hot-list li, .music-list li, ul li');
        const cards = document.querySelectorAll('.music-card, .song-card, .item-card');
        const firstRowText = tableRows.length > 0 ? tableRows[0].innerText.substring(0, 100) : '';
        return {
          tableRows: tableRows.length,
          listItems: listItems.length,
          cards: cards.length,
          firstRowText
        };
      })()
    `);
    console.error(`[诊断] 热门榜结构: tableRows=${diag.tableRows}, listItems=${diag.listItems}, cards=${diag.cards}`);

    const results = await page.evaluate(`
      (() => {
        const limit = ${limit};
        const results = [];

        // 策略 1: 尝试表格结构（与搜索页相同）
        const tableRows = document.querySelectorAll('table tbody tr');
        if (tableRows.length >= 3) {
          tableRows.forEach((row, index) => {
            if (index >= limit) return;
            const cells = row.querySelectorAll('td');
            if (cells.length < 3) return;
            const rank = cells[0]?.textContent?.trim() || '';
            // 热门榜可能列顺序不同，尝试多种映射
            const songLink = cells[1]?.querySelector('a') || cells[2]?.querySelector('a');
            const song = songLink?.textContent?.trim() || '';
            const songUrl = songLink?.href || '';
            const artistCells = Array.from(cells).filter((_, i) => i !== 0 && !cells[i].querySelector('a'));
            const artist = artistCells.map(c => c.textContent?.trim()).filter(Boolean).join(' ') || '';
            if (song) {
              results.push({ rank, song, artist, url: songUrl });
            }
          });
          if (results.length > 0) return results;
        }

        // 策略 2: 尝试列表结构 (.hot-list li, .music-list li)
        const listItems = document.querySelectorAll('.hot-list li, .music-list li, ul.list li, .rank-list li');
        if (listItems.length >= 3) {
          listItems.forEach((item, index) => {
            if (index >= limit) return;
            const songLink = item.querySelector('a');
            const song = songLink?.textContent?.trim() || '';
            const songUrl = songLink?.href || '';
            const artistEl = item.querySelector('.artist, .singer, .author');
            const artist = artistEl?.textContent?.trim() || '';
            const rankEl = item.querySelector('.rank, .num, .index');
            const rank = rankEl?.textContent?.trim() || String(index + 1);
            if (song) {
              results.push({ rank, song, artist, url: songUrl });
            }
          });
          if (results.length > 0) return results;
        }

        // 策略 3: 尝试卡片结构 (.music-card, .song-card)
        const cards = document.querySelectorAll('.music-card, .song-card, .item-card, .hot-item');
        if (cards.length >= 3) {
          cards.forEach((card, index) => {
            if (index >= limit) return;
            const songLink = card.querySelector('a');
            const song = songLink?.textContent?.trim() || '';
            const songUrl = songLink?.href || '';
            const artistEl = card.querySelector('.artist, .singer, .author, .artist-name');
            const artist = artistEl?.textContent?.trim() || '';
            const rankEl = card.querySelector('.rank, .num, .index, .no');
            const rank = rankEl?.textContent?.trim() || String(index + 1);
            if (song) {
              results.push({ rank, song, artist, url: songUrl });
            }
          });
          if (results.length > 0) return results;
        }

        // 策略 4: 回退 - 查找所有包含歌曲链接的容器
        const allLinks = document.querySelectorAll('a[href*="/play/"]');
        if (allLinks.length >= 3) {
          allLinks.forEach((link, index) => {
            if (index >= limit) return;
            const song = link.textContent?.trim() || '';
            const songUrl = link.href || '';
            // 尝试从父元素获取歌手
            const parent = link.closest('li, tr, div');
            const artist = parent?.querySelector('.artist, .singer, .author')?.textContent?.trim() || '';
            const rank = String(index + 1);
            if (song) {
              results.push({ rank, song, artist, url: songUrl });
            }
          });
          if (results.length > 0) return results;
        }

        return results;
      })()
    `);

    const items = Array.isArray(results) ? results : [];
    if (items.length === 0) {
      throw new CliError(
        'NO_DATA',
        '无法获取热门歌曲数据',
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
