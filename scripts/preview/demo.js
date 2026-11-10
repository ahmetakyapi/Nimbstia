// Demo data for the browser preview (same shape the Lua modules send). Nothing here is real.
const now = Math.floor(Date.now()/1000), DAY = 86400;
const ti = (id, text, ago, app, pinned) => ({ id, kind: 'text', text, t: now - ago, app, pinned: !!pinned, len: [...text].length, lines: text.split('\n').length, words: text.split(/\s+/).filter(Boolean).length });
exports.CLIP = { now, items: [
  ti('d1', "const total = cart.items.reduce((sum, item) => sum + item.price, 0);\nconsole.log(`Total: ${total} USD`);", 40, 'Visual Studio Code'),
  ti('d2', 'https://github.com/ahmetakyapi/Nimbstia', 260, 'Google Chrome', true),
  ti('d3', '#0A84FF', 950, 'Figma'),
  ti('d4', 'Release note: clipboard history now always shows the newest item first.', 2500, 'Notes'),
  ti('d5', '~/Projects/Nimbstia/README.md', 5600, 'Terminal'),
  ti('d6', 'hello@example.com', DAY + 3000, 'Mail'),
  ti('d7', '{\n  "name": "Nimbstia",\n  "version": "1.0.0",\n  "license": "MIT"\n}', DAY + 9000, 'Visual Studio Code'),
  ti('d8', '42.195', 2 * DAY + 400, 'Numbers'),
  ti('d9', 'Friday 2 pm · design review', 3 * DAY, 'Calendar'),
]};
const P = '/Users/demo/Projects/';
const proj = (name, o) => Object.assign(o, { name, path: P + name, mtime: o.ct });
exports.PROJECTS = { scanning: false, busy: { fetching: false, pullAll: false, pulling: [], fetched: now - 540 }, items: [
  proj('Nimbstia', { branch: 'main', sha: '4f2c9e1', ct: now - 600, subject: 'feat: menu bar status with VPN check', dirty: 2, ahead: 1, behind: 0 }),
  proj('website', { branch: 'main', sha: 'a91b3d0', ct: now - 5400, subject: 'docs: refresh landing copy', dirty: 0, ahead: 0, behind: 0 }),
  proj('api-server', { branch: 'feature/auth-refresh', sha: '77de210', ct: now - 9000, subject: 'fix: rotate refresh tokens', dirty: 5, ahead: 2, behind: 3 }),
  proj('mobile-app', { branch: 'develop', sha: 'c03f8aa', ct: now - DAY - 4000, subject: 'chore: bump SDK to 51', dirty: 0, ahead: 0, behind: 0 }),
  proj('design-system', { branch: 'main', sha: 'e5a7712', ct: now - DAY - 9000, subject: 'feat: new focus ring tokens', dirty: 1, ahead: 0, behind: 0 }),
  proj('api-server-pr42', { branch: null, sha: '9b0c4f2', ct: now - 3 * DAY, subject: 'review: pagination cursor', dirty: 0, worktree: true }),
  proj('data-pipeline', { branch: 'main', sha: '1d6e9ab', ct: now - 9 * DAY, subject: 'perf: batch writes', dirty: 0, ahead: 0, behind: 12 }),
  proj('docs', { branch: 'main', sha: 'f88a103', ct: now - 20 * DAY, subject: 'docs: install guide', dirty: 0, ahead: 0, behind: 0 }),
]};
exports.LOG = [
  { sha: '4f2c9e1', subject: 'feat: menu bar status with VPN check', author: 'Ahmet', mine: true, t: now - 600, files: 4, added: 86, deleted: 12 },
  { sha: 'b17a0c4', subject: 'fix: newest-first sort in clipboard history', author: 'Aylin', t: now - 7200, files: 2, added: 14, deleted: 9 },
  { sha: '0e92d5b', subject: 'feat: screenshot overlay with annotations', author: 'Ahmet', mine: true, t: now - DAY, files: 9, added: 412, deleted: 31 },
  { sha: '6ac3f10', subject: 'refactor: shared panel wrapper', author: 'Enes', t: now - 2 * DAY, files: 5, added: 120, deleted: 98 },
  { sha: 'd2b8e77', subject: 'chore: initial commit', author: 'Ahmet', mine: true, t: now - 3 * DAY, files: 12, added: 640, deleted: 0 },
];
// Uncommitted work of the first demo project (what `git diff HEAD --numstat` adds up to).
exports.WT = { files: 2, added: 38, deleted: 6, binary: 0, untracked: 1 };
const G = 'https://github.com';
exports.GH = { commits: 12, added: 1840, deleted: 412, prsToday: 2, updatedAgo: '1 dk önce', org: 'acme',
  opened: [{ owner: 'acme', repo: 'api-server', number: 233, title: 'feat: audit log for token refresh', author: 'ahmetakyapi', url: G }, { owner: 'acme', repo: 'website', number: 91, title: 'fix: hero image on small screens', author: 'ahmetakyapi', url: G }],
  commitList: [{ sha: '4f2c9e1', subject: 'feat: menu bar status with VPN check', repo: 'api-server', added: 214, deleted: 38, t: now - 600, url: G }, { sha: 'b17a0c4', subject: 'fix: newest-first sort in clipboard history', repo: 'website', added: 46, deleted: 12, t: now - 7200, url: G }],
  reviewCount: 5, review: [{ owner: 'acme', repo: 'api-server', number: 231, title: 'fix: rotate refresh tokens', author: 'selin', url: G }, { owner: 'acme', repo: 'design-system', number: 57, title: 'feat: new focus ring tokens', author: 'mert', url: G }, { owner: 'acme', repo: 'mobile-app', number: 412, title: 'chore: bump SDK to 51', author: 'deniz', url: G }],
  openCount: 2, open: [{ owner: 'ahmetakyapi', repo: 'Nimbstia', number: 14, title: 'feat: control center hub', author: 'ahmetakyapi', url: G }, { owner: 'acme', repo: 'website', number: 88, title: 'docs: refresh landing copy', author: 'ahmetakyapi', url: G, draft: true }] };
exports.POP = { health: 'ok', status: { text: 'Her Şey Yolunda', tone: 'ok' },
  dev: { name: 'DEV', title: 'Office VPN', host: '10.0.0.10', status: 'Bağlı · 18 ms', checkedAgo: 'az önce', ms: 18 },
  vpn: { connected: true, since: Math.floor(Date.now() / 1000) - 4520 }, github: exports.GH, forti: false,
  ports: [{ port: 3000, cmd: 'node', folder: 'Nimbstia-site' }, { port: 5173, cmd: 'node', folder: 'design-system' }, { port: 8000, cmd: 'Python', folder: 'api-server' }],
  claude: { plan: 'Max', updatedAgo: '2 dk önce', limits: [{ label: 'Haftalık Limit', percent: 33, resets: 'Cumartesi 12:00', today: 7 }, { label: 'Oturum Limiti', percent: 71, resets: '14:20' }],
    sessions: [{ name: 'Nimbstia docs', busy: true, url: 'https://claude.ai' }, { name: 'api-server', busy: true, url: 'https://claude.ai' }, { name: 'website', busy: false, url: 'https://claude.ai' }] },
  tools: [{ id: 'clip', name: 'Pastia', what: 'Pano', keys: '⌃V' }, { id: 'shot', name: 'Clipstia', what: 'Ekran Görüntüsü', keys: '⌃.' }, { id: 'layout', name: 'Panestia', what: 'Düzen', keys: '⌃Space' }, { id: 'repo', name: 'Repostia', what: 'Projeler', keys: '⌃⇧P' }, { id: 'text', name: 'Lexstia', what: 'Metin Oku', keys: '⌃⇧O' }],
  toggles: { awake: true, mic: false, meetings: false, appearance: false },
  system: { battery: { pct: 82, charging: false }, mem: 58, disk: 412, diskUsed: 57 },
  theme: 'auto', shortcuts: [{ keys: '⌃V', label: 'Pastia · Pano Geçmişi' }, { keys: '⌃.', label: 'Clipstia · Ekran Görüntüsü' }], errors: [] };
// layouts
const COLORS = { code: '#2f80ed', chrome: '#f2b100', claude: '#d97757', teams: '#6264a7', outlook: '#0f6cbd', whatsapp: '#25d366', terminal: '#7c7c88', win1: '#0a84ff', win2: '#8e5cf7' };
const NAMES = { code: 'VS Code', chrome: 'Chrome', claude: 'Claude', teams: 'Teams', outlook: 'Outlook', whatsapp: 'WhatsApp', terminal: 'Terminal', win1: 'Visual Studio Code', win2: 'Google Chrome' };
const apps = {}; for (const k in COLORS) apps[k] = { name: NAMES[k], color: COLORS[k], icon: false, running: k !== 'outlook' };
const cols = (a, b, r) => [{ app: a, rect: [0, 0, r, 1] }, { app: b, rect: [r, 0, 1 - r, 1] }];
const ms = (a, b, c, r) => [{ app: a, rect: [0, 0, r, 1] }, { app: b, rect: [r, 0, 1 - r, .5] }, { app: c, rect: [r, .5, 1 - r, .5] }];
const L = (id, group, name, cells, ratio, extra) => Object.assign({ id, group, name, cells, adjustable: ratio != null, ratio, custom: false, hideOthers: false }, extra);
exports.LAYOUTS = { apps, aspect: 1.6, last: 'code', canUndo: true, win: { app: 'Visual Studio Code', key: 'code', title: 'Nimbstia — init.lua', icon: false },
  layouts: [L('browser', 'İki Uygulama', 'Tarayıcı Ağırlıklı', cols('code', 'chrome', .35), .35), L('pair', 'İki Uygulama', 'Son İki Pencere Yan Yana', cols('win1', 'win2', .5), .5), L('code', 'İki Uygulama', 'Kod Ağırlıklı', cols('code', 'chrome', .6), .6), L('half', 'İki Uygulama', 'Yarı Yarıya', cols('code', 'chrome', .5), .5), L('claude', 'İki Uygulama', 'Claude Yanında', cols('code', 'claude', .65), .65), L('terminal', 'İki Uygulama', 'Terminal Yanında', cols('code', 'terminal', .6), .6),
    L('dev', 'Üç Uygulama', 'Geliştirme', ms('code', 'chrome', 'terminal', .5), .5), L('ai', 'Üç Uygulama', 'Kod · Tarayıcı · Claude', [{ app: 'code', rect: [0, 0, .42, 1] }, { app: 'chrome', rect: [.42, 0, .32, 1] }, { app: 'claude', rect: [.74, 0, .26, 1] }], .42), L('comms', 'Üç Uygulama', 'İletişim', ms('outlook', 'teams', 'whatsapp', .5), .5),
    L('focusCode', 'Odak', 'Odak: VS Code', [{ app: 'code', rect: [.08, .04, .84, .92] }], null, { hideOthers: true }), L('focusChrome', 'Odak', 'Odak: Chrome', [{ app: 'chrome', rect: [.08, .04, .84, .92] }], null, { hideOthers: true })],
  actions: [['left', 'Sol Yarı', [0, 0, .5, 1]], ['right', 'Sağ Yarı', [.5, 0, .5, 1]], ['top', 'Üst Yarı', [0, 0, 1, .5]], ['bottom', 'Alt Yarı', [0, .5, 1, .5]], ['max', 'Tam Ekran', [0, 0, 1, 1]], ['center', 'Ortala', [.15, .08, .7, .84]], ['l3', 'Sol Üçte Bir', [0, 0, 1 / 3, 1]], ['c3', 'Orta Üçte Bir', [1 / 3, 0, 1 / 3, 1]], ['r3', 'Sağ Üçte Bir', [2 / 3, 0, 1 / 3, 1]], ['l23', 'Sol Üçte İki', [0, 0, 2 / 3, 1]], ['r23', 'Sağ Üçte İki', [1 / 3, 0, 2 / 3, 1]], ['tl', 'Sol Üst', [0, 0, .5, .5]], ['tr', 'Sağ Üst', [.5, 0, .5, .5]], ['bl', 'Sol Alt', [0, .5, .5, .5]], ['br', 'Sağ Alt', [.5, .5, .5, .5]]].map(([id, name, rect]) => ({ id, name, rect, nextScreen: false })) };
