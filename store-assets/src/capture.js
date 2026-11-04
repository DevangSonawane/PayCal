// usage: node capture.js video.html out.mp4 [fps]  — seeks the page frame by frame and pipes PNGs into ffmpeg
const puppeteer = require('puppeteer-core'), { spawn } = require('child_process'), path = require('path');
(async () => {
  const [file, out, fps = 30] = process.argv.slice(2);
  const b = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', args: ['--allow-file-access-from-files'] });
  const p = await b.newPage();
  await p.setViewport({ width: 1920, height: 1080 });
  await p.goto('file://' + path.resolve(file), { waitUntil: 'networkidle0' });
  await p.evaluate(() => document.fonts.ready);
  const dur = await p.evaluate(() => window.DURATION), n = Math.round(dur * fps);
  const ff = spawn('ffmpeg', ['-y', '-f', 'image2pipe', '-framerate', String(fps), '-i', '-', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18', '-preset', 'slow', '-movflags', '+faststart', out], { stdio: ['pipe', 'ignore', 'inherit'] });
  for (let i = 0; i < n; i++) {
    await p.evaluate(t => seek(t), i / fps);
    const buf = await p.screenshot({ type: 'png' });
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
    if (i % 120 === 0) console.log(`frame ${i}/${n}`);
  }
  ff.stdin.end(); await new Promise(r => ff.on('close', r)); await b.close();
})();
