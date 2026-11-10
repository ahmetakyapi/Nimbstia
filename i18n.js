// Interface language for every panel. The panels are written in Turkish; this file translates what they
// show into another language right in the DOM, so no render function needs to change.
//   Language: window.NB_LANG (panel.lua sets it from config.language), else ?lang=xx, else "tr".
//   "tr" does nothing at all. "en" translates text nodes and a few attributes that hold visible text.
// Safety: only strings found in the tables below (exact entries or rules) are ever replaced, and the
// containers that hold user data (clipboard text, project names, commit subjects, window titles…) are
// skipped, so user data is never translated.
(function () {
  'use strict';
  var W = window, D = document;
  var lang = W.NB_LANG;
  if (!lang) { var qm = /[?&]lang=([A-Za-z-]+)/.exec(location.search || ''); lang = qm ? qm[1] : 'tr'; }
  lang = String(lang).toLowerCase().slice(0, 2);
  if (lang !== 'en') return;
  W.NB_LANG = 'en';
  D.documentElement.lang = 'en';

  // ---------------------------------------------------------------- locale: 'tr' / 'tr-TR' -> 'en-GB'
  var isTR = function (l) { return typeof l === 'string' && /^tr([-_]|$)/i.test(l); };
  var fixLoc = function (l) {
    if (isTR(l)) return 'en-GB';
    if (Array.isArray(l)) return l.map(function (x) { return isTR(x) ? 'en-GB' : x; });
    return l;
  };
  ['toLocaleDateString', 'toLocaleTimeString', 'toLocaleString'].forEach(function (k) {
    var o = Date.prototype[k];
    Date.prototype[k] = function (l, opt) { return o.call(this, fixLoc(l), opt); };
  });
  var numLoc = Number.prototype.toLocaleString;
  Number.prototype.toLocaleString = function (l, opt) { return numLoc.call(this, fixLoc(l), opt); };
  ['DateTimeFormat', 'NumberFormat', 'RelativeTimeFormat', 'PluralRules', 'ListFormat'].forEach(function (k) {
    var O = W.Intl && Intl[k];
    if (!O) return;
    var F = function (l, opt) { return new O(fixLoc(l), opt); };
    F.prototype = O.prototype;
    if (O.supportedLocalesOf) F.supportedLocalesOf = O.supportedLocalesOf.bind(O);
    Intl[k] = F;
  });
  // Upper-casing English with Turkish rules turns "i" into "İ" (FRİDAY). Lower-casing stays Turkish:
  // the panels use it for search, on user data and query alike.
  var upLoc = String.prototype.toLocaleUpperCase;
  String.prototype.toLocaleUpperCase = function (l) { return upLoc.call(this, isTR(l) ? 'en' : l); };

  // ---------------------------------------------------------------- strings
  // Exact Turkish UI strings -> English (whole text node / attribute value, trimmed).
  var EN = {
    // shared chrome
    'Kapat': 'Close', 'Kapat · Esc': 'Close · Esc', 'kapat': 'close',
    'Açık Tema': 'Light Theme', 'Koyu Tema': 'Dark Theme',
    'Filtreleri Temizle': 'Clear Filters', 'Filtreleri Kaldır': 'Remove Filters', 'Filtreyi Kaldır': 'Remove Filter',
    'Farklı bir kelime dene ya da Esc ile aramayı temizle.': 'Try another word, or press Esc to clear the search.',
    'Bugün': 'Today', 'Dün': 'Yesterday', 'dün': 'yesterday', 'Yarın': 'Tomorrow', 'Bu Hafta': 'This Week', 'Daha Eski': 'Older',
    'şimdi': 'now', 'az önce': 'just now', 'Tümü': 'All', 'Sonuçlar': 'Results', 'Yükleniyor…': 'Loading…',
    'Bilinmiyor': 'Unknown', 'Bilinmiyor (eski kayıt)': 'Unknown (old entry)',
    'Kopyala': 'Copy', 'Yapıştır': 'Paste', 'Kaydet': 'Save', 'Vazgeç': 'Cancel', 'Düzenle': 'Edit', 'Aç': 'Open',
    'Sil': 'Delete', 'Çöpe At': 'Move to Trash', 'Sabitle': 'Pin', 'Sabitli': 'Pinned', 'Sabitlenenler': 'Pinned',
    'Geri': 'Back', 'Geri Al': 'Undo', 'Yinele': 'Redo', 'Filtre': 'Filter', 'Ad': 'Name', 'Renk': 'Color',
    'Metin': 'Text', 'Görsel': 'Image', 'Ekran Görüntüsü': 'Screenshot', 'Bağlantı': 'Connection',

    // Pastia (clipboard.html, clipboard.lua)
    'Pano geçmişinde ara…': 'Search clipboard history…',
    'Çok Satırlı Metin': 'Multi-Line Text', 'E-Posta': 'Email', 'Dosya Yolu': 'File Path', 'Sayı': 'Number',
    'Kopyalanan Görsel': 'Copied Image', 'Her Zaman': 'Any Time', '7 Gün': '7 Days', '30 Gün': '30 Days',
    'Pano Geçmişi Boş': 'Clipboard History Is Empty', 'Bir şey kopyaladığında burada görünür.': 'Anything you copy shows up here.',
    'Tür': 'Type', 'Boyut': 'Size', 'Dosya': 'File', 'Uzunluk': 'Length', 'Kaynak': 'Source',
    'Çekildi': 'Captured', 'Güncellendi': 'Updated', 'Kopyalandı': 'Copied', 'Öğe': 'Items', 'Finder': 'Finder',
    'Bu metin düzenlemek için çok uzun': 'This text is too long to edit', 'Boş metin kaydedilmez': 'Empty text is not saved',
    'Öğe okunamadı': 'Could not read the item', 'Panoya kopyalandı': 'Copied to clipboard',
    "Çöp Sepeti'ne taşındı": 'Moved to Trash', 'Silinemedi': 'Could not delete', 'Seçili öğe yok': 'Nothing selected',

    // Repostia (projects.html, projects.lua)
    'Projelerde ara: ad, dal, son commit…': 'Search projects: name, branch, last commit…',
    'Ara: dal, klasör, son commit…': 'Search: branch, folder, last commit…',
    'Commit’lenmemiş': 'Uncommitted', 'Push Bekleyen': 'Unpushed', 'Geride': 'Behind',
    'Bütün projeler': 'All projects', 'Commit’lenmemiş değişikliği ya da yeni dosyası olanlar': 'Uncommitted changes or new files',
    'Uzak dala gönderilmemiş commit’i olanlar': 'Commits not pushed to the remote yet',
    'Uzak dalda henüz çekilmemiş commit olanlar': 'The remote has commits not pulled yet',
    'Commit’lenmemiş Değişiklikler': 'Uncommitted Changes', 'Değişen Dosya': 'Changed Files', 'Yeni Dosya': 'New Files',
    'Hesaplanıyor…': 'Calculating…', 'Değişiklik yok': 'No changes', 'Ana Klon': 'Main Clone', 'Klon (Kopya)': 'Clone (Copy)',
    'Worktree': 'Worktree', 'Satır farkı yok (yalnız izin/mod değişikliği olabilir).': 'No line changes (maybe only mode changes).',
    'Yenileniyor…': 'Refreshing…', 'Tüm Projeler': 'All Projects', 'Değişiklik Var': 'Has Changes',
    'Ana Kopyalar': 'Main Clones', 'PR/Çalışma Kopyaları': 'PR/Work Copies', 'Son Kullanılan': 'Last Used',
    'Projeler Taranıyor…': 'Scanning Projects…', 'Proje Bulunamadı': 'No Projects Found',
    '~/Projects altındaki git kopyaları burada listelenir.': 'Git repositories under ~/Projects are listed here.',
    'Değişiklik': 'Changes', 'Yolu Kopyala': 'Copy Path', 'Temiz': 'Clean', 'Yukarı Akış Yok': 'No Upstream',
    'Güncel': 'Up to Date', "VS Code'da Aç": 'Open in VS Code', 'Çalışma Kopyası · Worktree': 'Work Copy · Worktree',
    'Çalışma Kopyası · Klon': 'Work Copy · Clone', 'Ana Kopya': 'Main Clone', 'Temizlenebilir': 'Can Be Cleaned',
    'Commit bulunamadı.': 'No commits found.', 'Dal': 'Branch', 'Durum': 'Status', 'Yukarı Akış': 'Upstream',
    'Son Commit': 'Last Commit', 'Dizin Değişimi': 'Folder Changed', 'Panelden Açılış': 'Opened from Panel',
    'Hiç Açılmadı': 'Never Opened', 'Özet': 'Summary', 'Son Commit’ler': 'Recent Commits', "Son Commit'ler": 'Recent Commits',
    'Konum': 'Location', 'Proje': 'Projects', 'Yol kopyalandı': 'Path copied',
    "Bugün Açılan PR'lar": 'PRs Opened Today', "Bugünkü Commit'ler": "Today's Commits",
    'Commit': 'Commits', 'Bugün PR açılmadı.': 'No PRs opened today.', 'Bugün commit yok.': 'No commits today.',
    'İnceleme Bekleyen': 'Awaiting Review', 'Bekleyen inceleme yok.': 'No reviews waiting.',
    "Açık PR'larım": 'My Open PRs', 'Açık PR yok.': 'No open PRs.', 'Açan:': 'By:', 'Taslak': 'Draft',
    'Senin Hareketlerin': 'Your Activity', 'Açılan PR': 'PRs Opened', 'Eklenen Satır': 'Lines Added',
    'Silinen Satır': 'Lines Deleted', "GitHub'da Gör": 'View on GitHub',
    "PR'lar için GitHub CLI (gh) gerekiyor": 'PRs need the GitHub CLI (gh)',

    // Panestia (layouts.html, layouts.lua)
    'Düzen veya uygulama ara…': 'Search layouts or apps…', 'Diğerlerini Gizler': 'Hides Others', 'Özel Oran': 'Custom Ratio',
    'Sol daralsın': 'Narrow Left Side', 'Sol genişlesin': 'Widen Left Side', 'Sol Daralsın': 'Narrow Left Side', 'Sol Genişlesin': 'Widen Left Side',
    'Öndeki solda · önceki sağda': 'Front on the left · previous on the right', 'Bu Pencere': 'This Window',
    'Odakta Pencere Yok': 'No Focused Window', 'Eşleşen Düzen Yok': 'No Matching Layout', 'Uygula': 'Apply',
    'Hızlı Seç': 'Quick Pick', 'Oran': 'Ratio', 'Sıfırla': 'Reset',
    'İki Uygulama': 'Two Apps', 'Üç Uygulama': 'Three Apps', 'Odak': 'Focus',
    'Son İki Pencere Yan Yana': 'Last Two Windows Side by Side', 'Tarayıcı Ağırlıklı': 'Browser Focus',
    'Kod Ağırlıklı': 'Code Focus', 'Yarı Yarıya': 'Half and Half', 'Claude Yanında': 'Claude Alongside',
    'Terminal Yanında': 'Terminal Alongside', 'Toplantı': 'Meeting', 'Teams Yanında': 'Teams Alongside',
    'Geliştirme': 'Development', 'Kod': 'Code', 'Tarayıcı': 'Browser', 'İletişim': 'Communication',
    'Sol Yarı': 'Left Half', 'Sağ Yarı': 'Right Half', 'Üst Yarı': 'Top Half', 'Alt Yarı': 'Bottom Half',
    'Tam Ekran': 'Full Screen', 'Ortala': 'Center', 'Sol Üçte Bir': 'Left Third', 'Orta Üçte Bir': 'Center Third',
    'Sağ Üçte Bir': 'Right Third', 'Sol Üçte İki': 'Left Two Thirds', 'Sağ Üçte İki': 'Right Two Thirds',
    'Sol Üst': 'Top Left', 'Sağ Üst': 'Top Right', 'Sol Alt': 'Bottom Left', 'Sağ Alt': 'Bottom Right',
    'Diğer Ekrana': 'Next Screen',

    // Clipstia (shot.html)
    'Alan seçmek için sürükle': 'Drag to select an area', 'Kalem': 'Pen', 'Çizgi': 'Line', 'Dikdörtgen': 'Rectangle',
    'Elips': 'Ellipse', 'İşaretleyici': 'Highlighter', 'Bulanıklaştır': 'Blur', 'Numara': 'Number',
    'Küçük': 'Small', 'Orta': 'Medium', 'Büyük': 'Large',

    // Pulstia hub (pulstia.html, status.lua, claude.lua)
    'Günlük Durum Paneli': 'Daily Status Panel', 'Her Zaman Uyanık': 'Always Awake', 'Daralt': 'Collapse', 'Genişlet': 'Expand', 'Geliştirme Sunucuları': 'Dev Servers', 'Durdur': 'Stop',
    'Koyu Görünüm': 'Dark Mode', 'Ekran Koruyucu': 'Screen Saver', 'Açık Görünüm': 'Light Mode', 'Sıfırlanma': 'Resets', 'Son kontrol': 'Checked', 'Son Kontrol': 'Checked', 'Çevrimiçi': 'Online', 'Her Şey Yolunda': 'All Good',
    'Bağlantı Yok': 'No Connection', 'Dikkat': 'Attention', 'Bağlı': 'Online', 'Bağlı Değil': 'Offline',
    'Yanıt Vermiyor': 'Not Responding', 'Kontrol Ediliyor…': 'Checking…', 'Bağlantıyı Kes': 'Disconnect', 'Bağlantı Süresi': 'Connected For', 'sa': 'h', 'dk': 'min',
    'Bağlan': 'Connect', 'Bağlanıyor…': 'Connecting…', 'Bağlantı Kesiliyor…': 'Disconnecting…',
    'Yeniden Kontrol Et': 'Check Again', 'VPN Bağlantısı': 'VPN Connection', 'VPN Kapalı': 'VPN Off',
    'Mikrofon Kapalı': 'Microphone Off', 'Kullanım': 'Usage', 'Haftalık': 'Weekly', 'Oturum': 'Session',
    'Haftalık Limit': 'Weekly Limit', 'Oturum Limiti': 'Session Limit', '5 Saatlik': '5-Hour', '5 Saatlik Limit': '5-Hour Limit',
    'aktif': 'active', 'oturum': 'session', 'boşta': 'idle', 'Başlat': 'Start', 'Başlatıcıyı Çalıştır': 'Run Launcher',
    'Araçlar': 'Tools', 'Pano': 'Clipboard', 'Ekran Al': 'Screenshot', 'Düzen': 'Layouts', 'Projeler': 'Projects',
    'Metin Oku': 'Read Text', 'Hızlı Ayarlar': 'Quick Settings', 'Uyanık Tut': 'Keep Awake', 'Mikrofon': 'Microphone',
    'Toplantılar': 'Meetings', 'Açık': 'On', 'Kapalı': 'Off', 'Sessiz': 'Muted', 'Sistem': 'System',
    'Pil': 'Battery', 'Şarj': 'Charging', 'Şarjda': 'Charging', 'Bellek': 'Memory', 'Boş Disk': 'Free Disk',
    'Pil Ayarları': 'Battery Settings', 'Depolama Ayarları': 'Storage Settings',
    'Neyin ne kadar kullandığını gör': 'See what uses how much', 'Uygulamalar okunuyor…': 'Reading apps…',
    'Okunamadı.': 'Could not read.', 'Bellek Kullanımı': 'Memory Usage', 'Diğer': 'Other', 'Uzak Dal': 'Remote Branch', 'Uzak Dal Yok': 'No Remote Branch', 'Son Değişiklik': 'Last Change', 'Son Açılış': 'Last Opened', 'Ana Depo': 'Main Repo', 'Ana Depolar': 'Main Repos', 'Çalışma Kopyaları': 'Work Copies', 'Bugün Yaptıkların': 'Your Day', 'Solu Daralt': 'Narrow Left Side', 'Solu Genişlet': 'Widen Left Side', 'Seçili Pencere Yok': 'No Focused Window', 'Kullanım verisi yok': 'No usage data yet', 'Claude Code açıkken güncellenir': 'Updates while Claude Code runs',
    // Repostia: today / week / month and the commit history
    'Bu Hafta Yaptıkların': 'Your Week', 'Bu Ay Yaptıkların': 'Your Month', 'Hafta': 'Week', 'Ay': 'Month', 'Bu Ay': 'This Month', "Bu Hafta Açılan PR'lar": 'PRs Opened This Week', "Bu Ay Açılan PR'lar": 'PRs Opened This Month', "Bu Haftaki Commit'ler": "This Week's Commits", "Bu Ayki Commit'ler": "This Month's Commits", 'Bu hafta PR açılmadı.': 'No PRs opened this week.', 'Bu ay PR açılmadı.': 'No PRs opened this month.', 'Bu hafta commit yok.': 'No commits this week.', 'Bu ay commit yok.': 'No commits this month.', 'Günlük Commit': 'Daily Commits', 'Commit Geçmişi': 'Commit History', 'Gün gün geçmiş': 'Day-by-day history', 'Geçen Ay': 'Last Month', 'Son 90 Gün': 'Last 90 Days', 'Tüm Repolar': 'All Repos', 'Repo': 'Repo', 'Commit ara…': 'Search commits…', 'Aktif Gün': 'Active Days', 'Günlük Ortalama': 'Daily Average', 'En Çok Commit': 'Most Commits', 'Geçen ay commit yok.': 'No commits last month.', 'Son 90 günde commit yok.': 'No commits in the last 90 days.', 'Bu filtrelerle commit yok.': 'No commits match these filters.', 'Aramayı ya da repoyu değiştirmeyi dene.': 'Try another search or repo.', 'Geri · Esc': 'Back · Esc',
    // Repostia: filters and the Claude action
    'Claude': 'Claude',
    'Push Edilmemiş': 'Unpushed', 'Güncelleme Var': 'Updates Available', 'Ara: repo, dal, son commit…': 'Search: repo, branch, last commit…',
    'Commit’lenmemiş değişikliği olan repolar': 'Repos with uncommitted changes', 'Commit’i var ama GitHub’a gönderilmemiş repolar': 'Repos with commits not pushed to GitHub yet',
    'GitHub’da yeni commit’i olan repolar (son uzaktan kontrole göre)': 'Repos with new commits on GitHub (as of the last remote check)',
    // Repostia: pull / remote check, status card, commit authors
    'Tümünü Çek': 'Pull All', 'Çekiliyor…': 'Pulling…', 'Pull': 'Pull', 'Bütün güncellemeleri çeker': 'Pulls every update',
    'Uzaktan Kontrol Et': 'Check Remotes', 'Uzaktan Kontrol Ediliyor…': 'Checking Remotes…', 'Uzak Kontrol': 'Remote Check', 'Uzaktan kontrol tamamlandı': 'Remote check finished',
    'Güncel, temiz': 'Up to date, clean', 'Uzak dal yok': 'No remote branch', 'Durum hesaplanıyor…': 'Calculating status…', 'Detached HEAD': 'Detached HEAD',
    'dallar ayrıştı': 'branches diverged', 'Bir dalda değil': 'Not on a branch', 'Ana klonun ek çalışma dizini': 'Extra working directory of the main clone',
    'Sen': 'You', 'Senin commit’in': 'Your commit', 'Commit’lenmemiş dosya sayısı': 'Uncommitted file count',
    'Güncellenecek repo yok': 'No repos to update',
    'commit’lenmemiş değişiklik var': 'uncommitted changes', 'push edilmemiş commit var': 'unpushed commits', 'durumu henüz bilinmiyor': 'status not known yet',
    'ileri sarma mümkün değil (dallar ayrışmış)': 'cannot fast-forward (branches diverged)', 'yerel değişiklik çakışıyor': 'local changes conflict',
    'uzak dal tanımlı değil': 'no upstream branch', 'zaman aşımı': 'timed out', 'git başlatılamadı': 'could not start git',
    // hub: CPU gauge and its detail
    'İşlemci': 'CPU', 'İşlemci Kullanımı': 'CPU Usage', 'Neyin ne kadar işlemci kullandığını gör': 'See what uses the CPU',
    // hub: VPN card
    'Gecikme': 'Latency', 'Çok İyi': 'Excellent', 'İyi': 'Good', 'Yavaş': 'Slow',
    "Etkinlik İzleyicisi'nde Aç": 'Open in Activity Monitor', 'Çalışıyor': 'Running', 'Boşta': 'Idle',
    "claude.ai'de aç": 'Open on claude.ai', 'Claude Oturumları': 'Claude Sessions', 'Açık oturum yok.': 'No open sessions.',
    "Bir oturuma tıklayınca claude.ai'de açılır.": 'Click a session to open it on claude.ai.',
    'Kısayollar': 'Shortcuts', 'Henüz kısayol yok.': 'No shortcuts yet.', 'Konsol': 'Console', 'Yeniden Yükle': 'Reload',
    'modül yüklenemedi': 'module failed to load',
    'Takvim izni yok · Sistem Ayarları › Gizlilik › Takvimler': 'No calendar access · System Settings › Privacy › Calendars',
    // shortcut labels (init.lua HELP, tools.lua bind), shown in the hub's shortcuts view
    'Pano Geçmişi': 'Clipboard History', 'Pencere Düzenleri': 'Window Layouts',
    'Ekran Görüntüsü (⌘S Kaydet, ⌃C Kopyala)': 'Screenshot (⌘S Save, ⌃C Copy)',
    'Sola / Sağa Yasla (Tekrar Bas: ⅓ · ⅔)': 'Snap Left / Right (Press Again: ⅓ · ⅔)',
    'Üst Yarı / Alt Yarı / Tam Ekran': 'Top Half / Bottom Half / Full Screen',
    'Son Yerleşimi Geri Al': 'Undo Last Layout', 'Diğer Ekrana Taşı': 'Move to Other Screen',
    "Mac'i Uyanık Tut": 'Keep Mac Awake', 'Mikrofonu Kapat / Aç': 'Mute / Unmute Microphone',
    'Ekranı Kilitle': 'Lock Screen', '@ Yazar (Basılı Tut: Uygulamayı Kapatır)': 'Types @ (Hold: Quits the App)',
    'Ekrandan Metin Oku': 'Read Text from Screen', 'Metni Dönüştür (JSON, Base64, Tarih…)': 'Transform Text (JSON, Base64, Date…)',
    'Şablon Seç (ya da ;anahtar)': 'Pick Snippet (or ;key)', 'Jira Anahtarını Aç': 'Open Jira Key',
  };
  // Same Turkish word, different meaning per panel.
  var PAGE_EN = {
    clip: { 'Bağlantı': 'Link' },
    projects: { 'Son Kullanılan': 'Recent' },
    shot: { 'Ok': 'Arrow' },
  };
  // Extra strings (e.g. new hub copy): add them here, or call window.NB_I18N.add({ 'Türkçe': 'English' }).
  var EXTRA = {
  };

  var DAYS = { 'Pazar': 'Sunday', 'Pazartesi': 'Monday', 'Salı': 'Tuesday', 'Çarşamba': 'Wednesday', 'Perşembe': 'Thursday', 'Cuma': 'Friday', 'Cumartesi': 'Saturday', 'Bugün': 'Today', 'Yarın': 'Tomorrow', 'Dün': 'Yesterday' };
  var MONTHS = { 'Ocak': 'January', 'Şubat': 'February', 'Mart': 'March', 'Nisan': 'April', 'Mayıs': 'May', 'Haziran': 'June', 'Temmuz': 'July', 'Ağustos': 'August', 'Eylül': 'September', 'Ekim': 'October', 'Kasım': 'November', 'Aralık': 'December',
    'Oca': 'Jan', 'Şub': 'Feb', 'Mar': 'Mar', 'Nis': 'Apr', 'May': 'May', 'Haz': 'Jun', 'Tem': 'Jul', 'Ağu': 'Aug', 'Eyl': 'Sep', 'Eki': 'Oct', 'Kas': 'Nov', 'Ara': 'Dec' };
  for (var dk in DAYS) if (!EN[dk]) EN[dk] = DAYS[dk];

  var N = function (s) { return parseFloat(String(s).replace(/,/g, '')); }; // "1,234" (en-GB) -> 1234
  var pl = function (n, one, many) { return n + ' ' + (N(n) === 1 ? one : many); };
  var tr = function (s) { var t = T(s); return t == null ? s : t; };
  var NUM = '(\\d[\\d,.]*)';
  var R = function (src, fn) { return [new RegExp(src), fn]; };
  // Dynamic strings: [pattern, replacement(match) -> string]. Tried after the exact table.
  var RULES = [
    R('^(\\d+) sn önce$', function (m) { return m[1] + ' s ago'; }),
    R('^(\\d+) dk önce$', function (m) { return m[1] + ' min ago'; }),
    R('^(\\d+) sa önce$', function (m) { return m[1] + ' h ago'; }),
    R('^(\\d+) gün önce$', function (m) { return pl(m[1], 'day ago', 'days ago'); }),
    R('^(\\d+) hf önce$', function (m) { return m[1] + ' wk ago'; }),
    R('^(\\d+) ay önce$', function (m) { return m[1] + ' mo ago'; }),
    R('^(\\d+) yıl önce$', function (m) { return m[1] + ' yr ago'; }),
    R('^%(\\d+)$', function (m) { return m[1] + '%'; }),
    R('^%(\\d+) CPU$', function (m) { return m[1] + '% CPU'; }),
    R('^Claude %(\\d+)$', function (m) { return 'Claude ' + m[1] + '%'; }),
    R('^Bugün \\+%(\\d+)$', function (m) { return 'Today +' + m[1] + '%'; }),
    R('^(Bugün|Yarın|Dün|Pazartesi|Pazar|Salı|Çarşamba|Perşembe|Cumartesi|Cuma),? (\\d{1,2}[:.]\\d{2})$', function (m) { return DAYS[m[1]] + ' ' + m[2]; }),
    R('^(\\d{1,2}) (\\S+)( \\d{4})?$', function (m) { return MONTHS[m[2]] ? m[1] + ' ' + MONTHS[m[2]] + (m[3] || '') : null; }),
    R('^Sıfırlanma:? ([^·]+)$', function (m) { return 'Resets ' + tr(m[1]); }),
    R('^↻ ([^·]+)$', function (m) { return '↻ ' + tr(m[1]); }),
    R('^' + NUM + ' [Öö]ğe$', function (m) { return pl(m[1], 'Item', 'Items'); }),
    R('^' + NUM + ' Proje$', function (m) { return pl(m[1], 'Project', 'Projects'); }),
    R('^' + NUM + ' çekirdeğin toplamı$', function (m) { return 'across all ' + m[1] + ' cores'; }),
    R('^' + NUM + ' oturum$', function (m) { return pl(m[1], 'session', 'sessions'); }),
    R('^' + NUM + ' oturum çalışıyor$', function (m) { return pl(m[1], 'session', 'sessions') + ' running'; }),
    R('^' + NUM + ' aktif$', function (m) { return m[1] + ' active'; }),
    R('^' + NUM + ' açık$', function (m) { return m[1] + ' open'; }),
    R('^' + NUM + ' çalışıyor$', function (m) { return m[1] + ' running'; }),
    R('^' + NUM + ' araç$', function (m) { return pl(m[1], 'tool', 'tools'); }),
    R('^' + NUM + ' kısayol$', function (m) { return pl(m[1], 'shortcut', 'shortcuts'); }),
    R('^' + NUM + ' modül yüklenemedi$', function (m) { return pl(m[1], 'module', 'modules') + ' failed to load'; }),
    R('^' + NUM + ' Modül Yüklenemedi$', function (m) { return pl(m[1], 'Module', 'Modules') + ' Failed to Load'; }),
    R('^' + NUM + ' dosya$', function (m) { return pl(m[1], 'file', 'files'); }),
    R('^' + NUM + ' satır$', function (m) { return pl(m[1], 'line', 'lines'); }),
    R('^' + NUM + ' karakter$', function (m) { return pl(m[1], 'character', 'characters'); }),
    R('^' + NUM + ' kelime$', function (m) { return pl(m[1], 'word', 'words'); }),
    R('^… ve ' + NUM + ' karakter daha$', function (m) { return '… and ' + pl(m[1], 'more character', 'more characters'); }),
    R('^' + NUM + ' × ' + NUM + ' piksel$', function (m) { return m[1] + ' × ' + m[2] + ' pixels'; }),
    R('^' + NUM + ' Değişiklik$', function (m) { return pl(m[1], 'Change', 'Changes'); }),
    R('^' + NUM + ' ileride$', function (m) { return m[1] + ' ahead'; }),
    R('^' + NUM + ' geride$', function (m) { return m[1] + ' behind'; }),
    R('^' + NUM + ' tane daha$', function (m) { return m[1] + ' more'; }),
    R('^' + NUM + ' Push Bekliyor$', function (m) { return m[1] + ' to Push'; }),
    R('^' + NUM + ' yeni commit var$', function (m) { return pl(m[1], 'new commit', 'new commits') + ' to pull'; }),
    R('^' + NUM + ' commit push edilmedi$', function (m) { return pl(m[1], 'commit', 'commits') + ' not pushed'; }),
    R('^' + NUM + ' dosya commit’lenmedi$', function (m) { return pl(m[1], 'file', 'files') + ' not committed'; }),
    R('^son: (.+)$', function (m) { return 'last: ' + tr(m[1]); }),
    R('^' + NUM + ' repo çekilebilir; commit’lenmemiş ya da push edilmemiş değişikliği olanlar atlanır$', function (m) { return m[1] + ' can be pulled; repos with uncommitted or unpushed work are skipped'; }),
    R('^' + NUM + ' repo güncellendi(, .+)?$', function (m) { return m[1] + ' ' + (N(m[1]) === 1 ? 'repo' : 'repos') + ' updated' + (m[2] ? ', ' + tr(m[2].slice(2)) : ''); }),
    R('^' + NUM + ' atlandı: (.+?)(, .+)?$', function (m) { return m[1] + ' skipped: ' + m[2].split('; ').map(tr).join('; ') + (m[3] ? ', ' + tr(m[3].slice(2)) : ''); }),
    R('^' + NUM + ' çekilemedi(?: \\((.+)\\))?$', function (m) { return m[1] + ' failed' + (m[2] ? ' (' + tr(m[2]) + ')' : ''); }),
    R('^Çekilecek temiz repo yok, (.+)$', function (m) { return 'No clean repos to pull, ' + tr(m[1]); }),
    R('^Kontrol tamamlandı, ' + NUM + ' repo kontrol edilemedi$', function (m) { return 'Check finished, ' + m[1] + ' ' + (N(m[1]) === 1 ? 'repo' : 'repos') + ' could not be checked'; }),
    R('^(.+) zaten güncel$', function (m) { return m[1] + ' is already up to date'; }),
    R('^(.+) güncellendi$', function (m) { return m[1] + ' updated'; }),
    R('^' + NUM + ' commit$', function (m) { return pl(m[1], 'commit', 'commits'); }),
    R('^Filtreler kaldırılınca ' + NUM + ' öğe var\\.$', function (m) { return pl(m[1], 'item', 'items') + ' without filters.'; }),
    R('^Filtre kaldırılınca ' + NUM + ' proje var\\.$', function (m) { return pl(m[1], 'project', 'projects') + ' without the filter.'; }),
    // Empty-state headings (Title Case); the old sentence-case wording is still matched.
    R('^((?:“[^”]*”(?: \\+ )?)+) [Ff]iltresinde ([Ee]şleşen )?([Öö]ğe|[Pp]roje) [Yy]ok$', function (m) {
      var labels = m[1].replace(/“([^”]*)”/g, function (_, x) { return '“' + tr(x) + '”'; });
      return 'No ' + (m[2] ? 'Matching ' : '') + (/^[Öö]/.test(m[3]) ? 'Items' : 'Projects') + ' in ' + labels;
    }),
    R('^“([\\s\\S]*)” için [Ss]onuç [Yy]ok$', function (m) { return 'No Results for “' + m[1] + '”'; }),
    R('^Odak: ([^·]+)$', function (m) { return 'Focus: ' + m[1]; }),
    R('^Öndeki ([^·]+) solda$', function (m) { return m[1] + ' (front) on the left'; }),
    R('^önceki ([^·]+) sağda$', function (m) { return m[1] + ' (previous) on the right'; }),
    R('^([^·]+) tam ekran$', function (m) { return m[1] + ' full screen'; }),
    R('^([^·]+) ortada$', function (m) { return m[1] + ' centered'; }),
    R('^sağda ([^·]+)$', function (m) { return 'right: ' + m[1]; }),
    R('^([^·]+) %(\\d+)$', function (m) { return m[1] + ' ' + m[2] + '%'; }),
    R('^Kalınlık: ([^·]+)$', function (m) { return 'Size: ' + tr(m[1]); }),
    R('^([^·]+) bağlı değil$', function (m) { return m[1] + ' not connected'; }),
    R('^([^·]+) bağlı$', function (m) { return m[1] + ' connected'; }),
    R('^([^·]+) yanıt vermiyor$', function (m) { return m[1] + ' not responding'; }),
    R('^([^·]+) Yanıt Vermiyor$', function (m) { return m[1] + ' Not Responding'; }),
    R('^/ ([^·]+) kullanımda$', function (m) { return '/ ' + m[1] + ' in use'; }),
    R('^([^A-Za-zÀ-ɏ\\d]*)(\\d+),(\\d+) (B|KB|MB|GB|TB)$', function (m) { return m[1] + m[2] + '.' + m[3] + ' ' + m[4]; }), // "1,5 MB", "/ 16,0 GB"
    R('^(\\d+),(\\d)$', function (m) { return m[1] + '.' + m[2]; }), // decimal comma (free disk "0,4 TB")
    R('^([^:·\\s]+): (.+)$', function (m) { var t = T(m[2]); return t == null ? null : m[1] + ': ' + t; }), // "repo: reason" (pull errors)
  ];

  // ---------------------------------------------------------------- lookup
  var page = null, dict = EN, cache = new Map(), outs = new Set();
  function setPage(p) {
    page = p; dict = Object.assign({}, EN, PAGE_EN[p] || {}, EXTRA);
    cache.clear();
  }
  setPage(null);
  W.NB_I18N = {
    lang: 'en',
    add: function (map) { for (var k in map) EXTRA[k] = map[k]; setPage(page); if (D.body) walk(D.body, 0); },
    t: function (s) { return tr(String(s)); },
  };

  var trUpper = function (s) { return upLoc.call(s, 'tr'); };
  var titleCase = function (s) { return s.split(' ').map(function (w) { return w ? trUpper(w.charAt(0)) + w.slice(1) : w; }).join(' '); };
  // "All Good" -> "All good"; acronyms (VPN, DEV) and names in the first word stay as they are.
  var sentenceCase = function (s) { return s.split(' ').map(function (w, i) { return i && w !== w.toUpperCase() ? w.toLowerCase() : w; }).join(' '); };

  // Split "a · b · c" at the top level only (never inside parentheses); separators are kept.
  function splitDots(s) {
    var parts = [], depth = 0, last = 0;
    for (var i = 0; i < s.length; i++) {
      var c = s[i];
      if (c === '(') depth++;
      else if (c === ')') depth = Math.max(0, depth - 1);
      else if (c === '·' && !depth) {
        var a = i, b = i + 1;
        while (a > last && s[a - 1] === ' ') a--;
        while (b < s.length && s[b] === ' ') b++;
        parts.push(s.slice(last, a), s.slice(a, b)); last = b; i = b - 1;
      }
    }
    if (!parts.length) return null;
    parts.push(s.slice(last));
    return parts;
  }

  var depth = 0;
  function T(s) {
    if (!s) return null;
    if (cache.has(s)) return cache.get(s);
    if (outs.has(s) || depth > 6) return null;
    depth++;
    var r = null;
    try { r = lookup(s); } finally { depth--; }
    if (r === s) r = null;
    if (cache.size > 4000) cache.clear();
    cache.set(s, r);
    if (r != null) outs.add(r);
    return r;
  }
  function lookup(s) {
    if (Object.prototype.hasOwnProperty.call(dict, s)) return dict[s];
    if (!/[A-Za-zÀ-ɏ%]/.test(s) && !/^\d+,\d/.test(s)) return null;
    for (var i = 0; i < RULES.length; i++) {
      var m = RULES[i][0].exec(s);
      if (m) { var v = RULES[i][1](m); if (v != null) return v; }
    }
    var parts = splitDots(s);
    if (parts) {
      var changed = false;
      for (var j = 0; j < parts.length; j += 2) {
        if (!parts[j]) continue;
        var t = T(parts[j]);
        if (t != null) { parts[j] = t; changed = true; }
      }
      return changed ? parts.join('') : null;
    }
    var pm = /^(.+?) \(([^()]+)\)$/.exec(s); // "Kopyala (⌘C)"
    if (pm) { var pt = T(pm[1]); if (pt != null) return pt + ' (' + pm[2] + ')'; }
    var em = /^([\s\S]+?)([.:])$/.exec(s); // trailing full stop / colon
    if (em) { var et = T(em[1]); if (et != null) return et + em[2]; }
    if (/ \S/.test(s)) { // sentence case ("Her şey yolunda") -> look up the title case form
      var tc = titleCase(s);
      if (tc !== s) { var tt = T(tc); if (tt != null) return sentenceCase(tt); }
    }
    return null;
  }

  // ---------------------------------------------------------------- where not to translate
  // 1 = skip the subtree (user data), 2 = exact table entries only (mixed UI + user data).
  var BASE_SKIP = 'script,style,textarea,input,select,code,pre,kbd,svg,mark,[contenteditable]';
  var FIELDS = 'input,textarea,select'; // their values are user data, their placeholders are not
  var dtIs = function (el, names) { var dt = el.previousElementSibling; return dt && names.indexOf(dt.textContent.trim()) >= 0; };
  var PAGES = {
    // Pastia: item titles and the preview text are clipboard contents. Image/screenshot rows show a
    // UI fallback title ("Görsel"), so those titles allow exact entries.
    clip: { sel: '.ti,.pv-text,.pv-url,.pv-big,dd', mode: function (el) {
      if (el.matches('dd')) return dtIs(el, ['Ad', 'Kaynak', 'Name', 'Source']) ? 1 : 0;
      if (el.matches('.ti')) { var row = el.closest('.row'); return row && row.querySelector('[data-tid]') ? 2 : 1; }
      return 1;
    } },
    // Repostia: names, paths, commit subjects, PR titles, repos, authors, branch.
    projects: { sel: '.ti,.pv-name,.pv-path,.commit .s,.pt,.rp,.av,.a b,dd,.br,.who', mode: function (el) {
      if (el.matches('dd')) return dtIs(el, ['Dal', 'Branch']) ? 1 : 0;
      return 1;
    } },
    // Panestia: the focused window (app + title) and app names in the previews.
    layouts: { sel: '#target,#target b,.win b,.app-ic,.eyebrow em', mode: function (el) { return el.id === 'target' || el.tagName === 'EM' ? 2 : 1; } },
    // Hub: launcher title, host, meeting titles, process names, session names, dev server commands.
    hub: { sel: '.lt,.hostin,.mrow,.pn,.ss-tx b,.pp small', mode: function () { return 1; } },
    shot: { sel: '#editor,#pill', mode: function () { return 1; } },
  };
  function detect() {
    if (!D.body) return;
    var p = D.getElementById('stage') ? 'shot' : D.getElementById('scroll') ? 'hub' : D.getElementById('sorts') ? 'projects'
      : D.getElementById('times') ? 'clip' : D.getElementById('target') ? 'layouts' : null;
    if (p) setPage(p);
  }
  function localMode(el) {
    if (el.matches(BASE_SKIP)) return 1;
    var P = page && PAGES[page];
    return P && el.matches(P.sel) ? P.mode(el) : 0;
  }
  function modeOf(el) {
    var m = 0;
    for (var e = el; e && e.nodeType === 1; e = e.parentElement) { var x = localMode(e); if (x > m) m = x; if (m === 1) break; }
    return m;
  }

  // ---------------------------------------------------------------- DOM
  var ATTRS = ['placeholder', 'title', 'aria-label', 'data-tip', 'data-label', 'alt'];
  var changedAny = false;
  function exactOnly(s) { return Object.prototype.hasOwnProperty.call(dict, s) ? dict[s] : null; }
  function text(node, mode) {
    var v = node.data, s = v.trim();
    if (!s || s.length > 400) return;
    var t = mode === 2 ? exactOnly(s) : T(s);
    if (t == null || t === s) return;
    var lead = v.slice(0, v.indexOf(s)), trail = v.slice(v.indexOf(s) + s.length);
    node.data = lead + t + trail; changedAny = true;
  }
  function attr(el, name, mode) {
    var v = el.getAttribute(name);
    if (!v) return;
    var s = v.trim(), t = mode === 2 ? exactOnly(s) : T(s);
    if (t != null && t !== s) { el.setAttribute(name, t); changedAny = true; }
  }
  function attrs(el, mode) {
    if (!el.hasAttributes()) return;
    for (var i = 0; i < ATTRS.length; i++) if (el.hasAttribute(ATTRS[i])) attr(el, ATTRS[i], mode);
  }
  // Attributes are translated even inside user-data containers (tooltips on rows are UI), except on
  // the skipped elements' own data; text only where the mode allows it.
  function walk(node, mode) {
    if (node.nodeType === 3) { if (mode !== 1) text(node, mode); return; }
    if (node.nodeType !== 1) return;
    var lm = localMode(node), m = lm > mode ? lm : mode;
    if (lm === 1 && node.matches(BASE_SKIP)) { if (node.matches(FIELDS)) attrs(node, mode); return; }
    attrs(node, m === 1 ? 2 : m);
    for (var c = node.firstChild; c; c = c.nextSibling) walk(c, m);
  }
  function process(records) {
    if (!page) detect();
    changedAny = false;
    for (var i = 0; i < records.length; i++) {
      var r = records[i], tg = r.target;
      if (r.type === 'childList') {
        if (!r.addedNodes.length) continue;
        var pm = modeOf(tg.nodeType === 1 ? tg : tg.parentElement);
        for (var j = 0; j < r.addedNodes.length; j++) { var n = r.addedNodes[j]; if (n.parentNode === tg) walk(n, pm); }
      } else if (r.type === 'characterData') {
        var pe = tg.parentElement;
        if (pe) { var cm = modeOf(pe); if (cm !== 1) text(tg, cm); }
      } else if (r.type === 'attributes' && tg.nodeType === 1) {
        var am = modeOf(tg); attr(tg, r.attributeName, am === 1 ? 2 : am);
      }
    }
    // Hub: the panel reports its height right after rendering; English text can wrap differently.
    if (changedAny && typeof W.postSize === 'function') { try { W.postSize(); } catch (e) {} }
  }
  var mo = new MutationObserver(function (recs) {
    process(recs);
    mo.takeRecords(); // drop the records our own edits just produced
  });
  mo.observe(D.documentElement, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ATTRS });
  D.addEventListener('DOMContentLoaded', function () {
    detect();
    if (D.body) walk(D.body, 0);
    mo.takeRecords();
  });

  // CSS-generated text (::before content) cannot be reached through the DOM.
  var st = D.createElement('style');
  st.textContent = 'html #preview:empty::before{content:"Nothing selected"}';
  (D.head || D.documentElement).appendChild(st);
})();
