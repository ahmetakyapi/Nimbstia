// Browser preview of every Nimbstia panel with demo data: no Mac, no Hammerspoon needed.
//   npm i -D playwright && npx playwright install chromium   (once)
//   node scripts/preview/shoot.js [outdir] [panel...]        -> <outdir>/<panel>-<light|dark>.png
//   node scripts/preview/shoot.js --readme                   -> regenerates assets/screens/*.png + hero
// Panels: clipboard projects layouts pulstia shot. The webkit message bridge is stubbed; messages a
// panel posts are collected in window.__msgs. Pages load theme.css straight from the repo.
const path = require('path'), fs = require('fs');
const { chromium } = require('playwright');
const D = require('./demo.js');
const ROOT = path.resolve(__dirname, '../..');
//   --lang en (anywhere in the arguments) renders the English interface; --readme always uses English.
const argv = process.argv.slice(2), li = argv.indexOf('--lang');
const args = li >= 0 ? argv.filter((_, i) => i !== li && i !== li + 1) : argv, readme = args[0] === '--readme';
const lang = li >= 0 ? (argv[li + 1] || 'tr') : (readme ? 'en' : 'tr');
const out = readme ? path.join(ROOT, 'assets/screens') : (args[0] || path.join(__dirname, 'out'));
const only = readme ? [] : args.slice(1);
const scale = readme ? 2 : 1;

// The Clipstia demo: select the report window of desktop.html and mark two things on it.
const WIN = { x: 245, y: 108, w: 950, h: 648 };
const rel = (x, y) => [(x - WIN.x) / WIN.w, (y - WIN.y) / WIN.h];
const OBJS = [
  { t: 'rect', a: rel(508, 208), b: rel(730, 340), color: '#ff3b30', w: 4 },
  { t: 'num', at: rel(508, 208), n: 1, color: '#ff3b30', r: 14 },
  { t: 'rect', a: rel(966, 390), b: rel(1055, 682), color: '#ff3b30', w: 4 },
  { t: 'num', at: rel(966, 390), n: 2, color: '#ff3b30', r: 14 },
  { t: 'text', at: rel(560, 420), text: 'Rekor gün: Cumartesi', color: '#ff3b30', fs: 24 },
  { t: 'arrow', a: rel(800, 445), b: rel(950, 470), color: '#ff3b30', w: 4 },
];

const PANELS = {
  clipboard: { w: 1060, h: 660, run: `Clip.setItems(${JSON.stringify(D.CLIP)});Clip.open();` },
  projects: { w: 1060, h: 660, run: `Projects.setGitHub(${JSON.stringify(D.GH)});Projects.setItems(${JSON.stringify(D.PROJECTS)});Projects.log('/Users/demo/Projects/nimbstia','4f2c9e1',${JSON.stringify(D.LOG)});Projects.open();` },
  layouts: { w: 980, h: 680, run: `Layouts.setData(${JSON.stringify(D.LAYOUTS)});Layouts.open();` },
  pulstia: { w: 470, h: 1000, file: 'popover', run: `Pulse.set(${JSON.stringify(D.POP)});Pulse.open();`, fit: true },
  shot: { w: 1440, h: 900, file: 'screenshot', desktop: true, clip: { x: 205, y: 68, width: 1060, height: 740 },
    run: `Shot.begin({w:1440,h:900,hint:false});Shot.setSrc(__desk);setTimeout(()=>Shot.test(${JSON.stringify(WIN)},{objs:${JSON.stringify(OBJS)}}),300);` },
};

(async () => {
  fs.mkdirSync(out, { recursive: true });
  const b = await chromium.launch();
  let desk = null;
  for (const [name, P] of Object.entries(PANELS)) {
    if (only.length && !only.includes(name)) continue;
    if (P.desktop && !desk) {
      const pg = await b.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: scale });
      await pg.goto('file://' + path.join(__dirname, 'desktop.html'));
      await pg.waitForTimeout(400);
      desk = 'data:image/png;base64,' + (await pg.screenshot()).toString('base64');
      await pg.close();
    }
    for (const theme of ['light', 'dark']) {
      const pg = await b.newPage({ viewport: { width: P.w, height: P.h }, deviceScaleFactor: scale, colorScheme: theme });
      const errs = [];
      pg.on('pageerror', e => errs.push(e.message));
      await pg.addInitScript(([d, lang]) => {
        window.__msgs = []; window.__desk = d; window.NB_LANG = lang;
        const h = { postMessage: m => window.__msgs.push(m) };
        window.webkit = { messageHandlers: new Proxy({}, { get: () => h }) };
      }, [desk, lang]);
      await pg.goto('file://' + path.join(ROOT, name + '.html'));
      await pg.evaluate(t => { document.documentElement.dataset.theme = t; }, theme);
      await pg.evaluate(P.run);
      await pg.waitForTimeout(1100);
      if (P.fit) {
        const h = await pg.evaluate(() => Math.ceil(document.getElementById('app').getBoundingClientRect().bottom + 10));
        await pg.setViewportSize({ width: P.w, height: h });
        await pg.waitForTimeout(100);
      }
      const file = path.join(out, `${readme ? (P.file || name) : name}-${theme}.png`);
      await pg.screenshot({ path: file, omitBackground: true, clip: P.clip });
      if (errs.length) console.log(`${name} (${theme}):\n  ` + errs.join('\n  '));
      await pg.close();
    }
  }
  if (readme) { // compose the README hero from the fresh screenshots
    for (const theme of ['light', 'dark']) {
      const pg = await b.newPage({ viewport: { width: 1600, height: 980 }, deviceScaleFactor: 1.5 });
      await pg.goto('file://' + path.join(ROOT, 'assets/hero.html') + '?theme=' + theme);
      await pg.waitForFunction(() => document.title === 'ready');
      await pg.screenshot({ path: path.join(ROOT, `assets/hero-${theme}.png`), omitBackground: true });
      await pg.close();
    }
  }
  await b.close();
})();
