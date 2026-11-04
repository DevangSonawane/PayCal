// usage: node render.js <html> <out.png> <w> <h> [scale]
const puppeteer = require('puppeteer-core');
(async () => {
  const [file, out, w, h, scale = 1, hash = ''] = process.argv.slice(2);
  const b = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', args: ['--allow-file-access-from-files'] });
  const p = await b.newPage();
  await p.setViewport({ width: +w, height: +h, deviceScaleFactor: +scale });
  await p.goto('file://' + require('path').resolve(file) + hash, { waitUntil: 'networkidle0' });
  await p.evaluate(() => document.fonts.ready);
  await p.screenshot({ path: out, clip: { x: 0, y: 0, width: +w, height: +h } });
  await b.close();
})();
