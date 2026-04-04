/**
 * 歌曲海 (Gequhai.com) - 获取夸克网盘高品质链接
 *
 * 从页面提取 window.mp3_extra_url 并解码为夸克网盘高品质下载链接。
 * 解码算法: decodeModifiedBase64 — 替换 #→H, %→S, 然后 base64 解码。
 */
import { cli, Strategy } from '../../registry.js';
import { CliError } from '../../errors.js';
import type { IPage } from '../../types.js';

cli({
  site: 'gequhai',
  name: 'quark',
  description: '获取歌曲的夸克网盘高品质链接（SQ 品质）',
  domain: 'www.gequhai.com',
  strategy: Strategy.PUBLIC,
  browser: true,
  args: [
    { name: 'id', type: 'string', required: true, positional: true, help: '歌曲ID（数字ID或编码ID均可）' },
  ],
  columns: ['title', 'artist', 'quark_url'],
  func: async (page: IPage, args) => {
    const t0 = Date.now();
    const inputId = args.id;

    // 导航到播放页面
    await page.goto(`https://www.gequhai.com/play/${inputId}`);
    const t1 = Date.now();
    await page.wait({ time: 2 });

    // 提取夸克网盘链接
    const info = await page.evaluate(`
      (() => {
        const appData = window.appData || {};
        const mp3ExtraUrl = window.mp3_extra_url || '';
        // 解码夸克网盘链接: #→H, %→S, 然后 base64 解码
        let quarkUrl = '';
        if (mp3ExtraUrl) {
          try {
            const decoded = mp3ExtraUrl.replace(/#/g, 'H').replace(/%/g, 'S');
            quarkUrl = atob(decoded);
          } catch (e) {
            quarkUrl = mp3ExtraUrl;
          }
        }
        return {
          title: appData.mp3_title || '未知歌曲',
          artist: appData.mp3_author || '未知艺术家',
          quark_url: quarkUrl
        };
      })()
    `);

    if (!info.quark_url) {
      throw new CliError(
        'NO_QUARK_URL',
        `歌曲 ${inputId} 未找到夸克网盘链接`,
        '该歌曲可能不提供高品质下载',
      );
    }

    const totalMs = Date.now() - t0;
    console.error(`[性能] 页面加载: ${t1 - t0}ms | 总耗时: ${totalMs}ms`);

    return {
      title: info.title,
      artist: info.artist,
      quark_url: info.quark_url,
    };
  },
});
