<p align="center">
  <img src="assets/logo.svg" width="112" height="112" alt="Nimbstia logosu">
</p>

<h1 align="center">Nimbstia</h1>

<p align="center">
  <b>macOS için sakin, klavye öncelikli bir çalışma tezgâhı.</b><br>
  Pano geçmişi, Lightshot tarzı ekran görüntüsü, pencere düzenleri, proje açıcı ve bir durum panosu —<br>
  tek bir Hammerspoon yapılandırması, Apple Silicon'da yerel, varsayılan olarak gizli.
</p>

<p align="center">
  <a href="README.md">English</a>
</p>

<p align="center">
  <img src="assets/hero-dark.png" width="960" alt="Nimbstia: durum panosu ve paneller">
</p>

<p align="center">
  <a href="#kurulum">Kurulum</a> ·
  <a href="#araçlar">Araçlar</a> ·
  <a href="#tüm-kısayollar">Kısayollar</a> ·
  <a href="#ayarlar">Ayarlar</a> ·
  <a href="#gizlilik">Gizlilik</a>
</p>

---

**Neden.** macOS'ta bazı gündelik işler gereğinden fazla tıklama istiyor: bir saat önce kopyaladığın şeyi bulmak, iki pencereyi yan yana koymak, üstüne not düşülmüş bir ekran görüntüsü almak, doğru depoyu açmak. Nimbstia bunların her birini tek bir kısayola ve yolunu kesmeyen bir panele indiriyor.

- **Yerel ve hafif** — [Hammerspoon](https://www.hammerspoon.org) içinde çalışan Lua ve küçük HTML panelleri. Electron yok, boştayken işlemci ~%0, bellek sabit (on ekran görüntüsünden sonra ≈ 140 MB).
- **Varsayılan olarak gizli** — her şey Mac'inde kalır. Parola yöneticisinden kopyalananlar hiç kaydedilmez.
- **Sakin tasarım** — tek bir ortak tasarım sistemi (`theme.css`): kâğıt-mürekkep nötrleri, tek vurgu mavisi, çevrimdışı gömülü Geist ve Geist Mono, tek tıkla geçilen gerçek açık ve koyu tema, yalnız gereken ipuçları.

## Nimbstia — merkez

Menü çubuğundaki işarete tıkla. Günün her şeyi tek bir panoda: VPN ve geliştirme sunucusuna erişim, Claude planından ne kadar kaldığı ve hangi Claude Code oturumlarının çalıştığı, tek tıkla her araç ve en sık kullandığın anahtarlar.

<p align="center">
  <img src="assets/screens/popover-dark.png" width="360" alt="Nimbstia durum panosu">
</p>

- **Bağlantı** — sunucuna her 30 sn'de ve uyanma ya da ağ değişikliğinden hemen sonra VPN + TCP denetimi; her şey yolundaysa tek bir yeşil nokta.
- **Claude kullanımı** — sıfırlanma zamanlarıyla plan limitleri ve açık oturumlar (oturumu claude.ai'de açar); Claude Code'un yerelde tuttuğu dosyalardan okunur.
- **Hızlı ayarlar** — Mac'i uyanık tut <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>K</kbd>, mikrofonu kapat <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>M</kbd>, macOS Takvim'den isteğe bağlı toplantı uyarısı.

## Araçlar

### Pastia · pano geçmişi — <kbd>Ctrl</kbd> <kbd>V</kbd>

<img src="assets/screens/clipboard-dark.png" width="880" alt="Pastia pano geçmişi">

Metin, bağlantı, renk, kopyalanan görseller ve ekran görüntüleri klasörü — her zaman en yeni üstte, günlere göre gruplu. Tür ve zamana göre filtrele, ara, sabitle, yerinde düzenle; paneli kapatmadan kopyala (<kbd>Cmd</kbd> <kbd>C</kbd>) ya da yapıştır (<kbd>↩</kbd>).

### Clipstia · ekran görüntüsü — <kbd>Ctrl</kbd> <kbd>.</kbd>

<img src="assets/screens/screenshot-dark.png" width="720" alt="Clipstia ekran görüntüsü düzenleyicisi">

Ekranı dondurur — açık bir menü varken bile — sonra alanı sürükleyip işaretlersin: kalem, çizgi, ok, kutu, elips, işaretleyici, metin, bulanıklaştırma, numaralı adımlar. <kbd>Ctrl</kbd> <kbd>C</kbd> kaydeder **ve** kopyalar, <kbd>Cmd</kbd> <kbd>S</kbd> yalnız kaydeder.

### Panestia · pencere düzenleri — <kbd>Ctrl</kbd> <kbd>Space</kbd>

<img src="assets/screens/layouts-dark.png" width="880" alt="Panestia pencere düzenleri">

Tek tuşla çok uygulamalı düzenler, "son iki pencere yan yana", ayarlanabilir oran ve geri alma. Odaktaki pencereyi <kbd>Ctrl</kbd> <kbd>Opt</kbd> + oklarla yasla — tekrar basınca ⅓ → ⅔.

### Repostia · projeler — <kbd>Ctrl</kbd> <kbd>Shift</kbd> <kbd>P</kbd>

<img src="assets/screens/projects-dark.png" width="880" alt="Repostia proje açıcı">

`~/Projects` altındaki her depo: dal, değişiklikler, ileride/geride ve son commit'ler. VS Code, Terminal, GitHub Desktop ya da Finder'da açar.

### Küçük yardımcılar

| Araç | Kısayol | Ne yapar |
|---|---|---|
| **Lexstia** · ekrandan metin | <kbd>Ctrl</kbd> <kbd>Shift</kbd> <kbd>O</kbd> | Bir alan seç; içindeki yazı (Türkçe + İngilizce) panoya gelir. |
| **Twistia** · metin dönüştür | <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>T</kbd> | JSON biçimlendir/sıkıştır, JWT çöz, Base64, URL, zaman damgası ↔ tarih, harf dönüşümü, satır sırala/tekilleştir, SQL `IN` listesi, UUID — seçimin yerine yazar. |
| **Snipstia** · şablonlar | `;anahtar` · <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>S</kbd> | `;tarih`, `;daily`, `;pr` yaz, metne dönüşsün. `snippets.lua` içinden düzenlenir. |
| **Hopstia** · uygulama tuşları | <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>Cmd</kbd> + harf | V VS Code · C Chrome · A Claude · T Teams · X Terminal · O Outlook · W WhatsApp · G GitHub Desktop · F Finder. Tekrar basınca pencereleri arasında gezer. |
| **Jira** | <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>J</kbd> | Seçimdeki ya da panodaki iş anahtarını (`ABC-123`) açar. |

<div align="center">
<details>
<summary><b>Açık tema</b>: her panel açık temada da gelir, güneş/ay butonuyla tek tıkla geçilir</summary>
<br>
<img src="assets/hero-light.png" width="880" alt="Nimbstia, light theme"><br><br>
<img src="assets/screens/popover-light.png" width="420" alt="Hub, light theme"><br><br>
<img src="assets/screens/clipboard-light.png" width="880" alt="Pastia, light theme"><br><br>
<img src="assets/screens/screenshot-light.png" width="720" alt="Clipstia, light theme"><br><br>
<img src="assets/screens/layouts-light.png" width="880" alt="Panestia, light theme"><br><br>
<img src="assets/screens/projects-light.png" width="880" alt="Repostia, light theme"><br><br>
</details>
</div>

## Tüm kısayollar

| Tuşlar | Eylem | Tuşlar | Eylem |
|---|---|---|---|
| <kbd>Ctrl</kbd> <kbd>V</kbd> | Pastia | <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>←</kbd> <kbd>→</kbd> | Sola / sağa yasla (tekrar: ⅓ · ⅔) |
| <kbd>Ctrl</kbd> <kbd>.</kbd> | Clipstia | <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>↑</kbd> <kbd>↓</kbd> <kbd>↩</kbd> | Üst / alt / tam ekran |
| <kbd>Ctrl</kbd> <kbd>Space</kbd> | Panestia | <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>C</kbd> · <kbd>Z</kbd> | Ortala · yerleşimi geri al |
| <kbd>Ctrl</kbd> <kbd>Shift</kbd> <kbd>P</kbd> | Repostia | <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>Cmd</kbd> <kbd>←</kbd> <kbd>→</kbd> | Diğer ekrana taşı |
| <kbd>Ctrl</kbd> <kbd>Shift</kbd> <kbd>O</kbd> | Lexstia | <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>K</kbd> | Uyanık tut |
| <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>T</kbd> | Twistia | <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>M</kbd> | Mikrofonu kapat |
| <kbd>Ctrl</kbd> <kbd>Opt</kbd> <kbd>S</kbd> | Snipstia | <kbd>Ctrl</kbd> <kbd>Cmd</kbd> <kbd>L</kbd> | Ekranı kilitle |

## Kurulum

### Yapay zekâ ajanıyla (en kolayı)

Aşağıdaki metni Claude Code, Codex, Cursor ya da terminal komutu çalıştırabilen herhangi bir kodlama ajanına yapıştır:

```text
Install Nimbstia on this Mac by following https://github.com/ahmetakyapi/Nimbstia/blob/main/AGENTS.md
step by step. Ask me before backing up my current Hammerspoon config and before filling in any
personal settings, then walk me through the macOS permissions and verify that everything loaded.
Talk to me in Turkish.
```

[`AGENTS.md`](AGENTS.md) ajanlar için yazılmış kısa bir kurulum kılavuzudur: ön koşul denetimi, kurulum betiği, sana sorulacak isteğe bağlı ayarlar, senin açacağın iki macOS izni, doğrulama adımı ve sık görülen sorunların çözümü.

### Tek komutla

```bash
curl -fsSL https://raw.githubusercontent.com/ahmetakyapi/Nimbstia/main/install.sh | bash
```

Betik, Hammerspoon yoksa Homebrew ile kurar, mevcut `~/.hammerspoon` klasörünü `~/.hammerspoon.backup-<tarih>` olarak yedekler, Nimbstia'yı oraya klonlar ve başlatır. Önce kendin bakmak istersen:

```bash
git clone https://github.com/ahmetakyapi/Nimbstia.git ~/.hammerspoon
cp ~/.hammerspoon/config.example.lua ~/.hammerspoon/config.local.lua
open -a Hammerspoon
```

Kurulum Applications klasörüne **Nimbstia.app** de ekler; Dock'ta tutarsan tek tıkla merkezi açar (`scripts/build-app.sh` yeniden üretir).

Ardından **Sistem Ayarları › Gizlilik ve Güvenlik** altında Hammerspoon'a iki izin ver: **Erişilebilirlik** (kısayollar, pencereler, şablonlar) ve **Ekran Kaydı** (ekran görüntüsü, metin tanıma). Nimbstia Mac açılınca kendiliğinden başlar.

## Ayarlar

Kişisel değerler `config.local.lua` dosyasında durur (git'e girmez). Hepsi isteğe bağlıdır; değeri olmayan özellik kendini gizler.

```lua
return {
  jiraBase = "https://sirketin.atlassian.net/browse/",              -- Ctrl Opt J
  jiraProjects = { "ABC", "OPS" },                                    -- yalnız bu önekler
  devCheck = { name = "DEV", host = "10.0.0.10", port = 22 },          -- bağlantı kartı
  launcher = { title = "Geliştirme ortamını başlat", path = os.getenv("HOME") .. "/Desktop/start.command" },
  screenshotDir = os.getenv("HOME") .. "/Documents/Screenshots",
}
```

- **Şablonlar:** `snippets.lua`, düz bir `{ key, label, text }` listesi; `text` bir fonksiyon da olabilir (tarihler için).
- **Düzenler ve uygulama tuşları:** `layouts.lua` ve `tools.lua` dosyalarının başındaki tablolar.
- **Tema:** her panelin ve merkezin başlığındaki güneş/ay butonu.
- **Kısayol çakışmaları:** <kbd>Ctrl</kbd> <kbd>V</kbd> Vim'in blok seçim tuşunun, <kbd>Ctrl</kbd> <kbd>Space</kbd> macOS'un "önceki giriş kaynağı" kısayolunun yerini alır. Bunlara ihtiyacın varsa `init.lua` içindeki atamaları değiştir.

## Gizlilik

- Pano geçmişi Hammerspoon ayarlarında, kopyalanan görseller ve küçük resimler `clipdata/` klasöründe yerel olarak durur (git'e girmez).
- Parola yöneticilerinin işaretlediği kopyalar (`org.nspasteboard.ConcealedType`, 1Password, Bitwarden, KeePassXC…) hiç kaydedilmez; panoyu kısa süre ödünç alan araçlar da sırları yeniden yayınlamadan geri yükler.
- Claude kullanımı ve oturumlar, Claude Code'un Mac'inde tuttuğu dosyalardan okunur (`~/.claude.json`, `~/.claude/sessions`); hiçbir yere gönderilmez.
- Tek ağ trafiği, ayarladığın sunucuya yapılan isteğe bağlı TCP denetimidir. Toplantı uyarısı macOS Takvim'i yerelde ve yalnız sen açtıktan sonra okur.

## Tasarım ve önizleme

Tüm paneller tek bir stil dosyasını kullanır: [`theme.css`](theme.css). Açık/koyu renk değişkenleri, metin için Geist,
etiket, sayı ve tuşlar için Geist Mono (`assets/fonts` içinde gömülü, internetten indirilmez), tuş kapakları ve
hareket eğrileri burada. `panel.lua` dosyayı fontlarıyla birlikte panele gömer; paneller tamamen çevrimdışı kalır.

Arayüz üzerinde Mac olmadan çalışmak için panelleri demo veriyle tarayıcıda açabilirsin:

```bash
npm i -D playwright && npx playwright install chromium   # bir kez
node scripts/preview/shoot.js out clipboard pulstia      # out/<panel>-light.png ve -dark.png
node scripts/preview/shoot.js --readme                   # README görsellerini yeniden üret
```

## Kaldırma

Hammerspoon'dan çık, `~/.hammerspoon` klasörünü sil (ya da yedeğini geri koy) ve istersen Hammerspoon'u da kaldır.

## Lisans

[MIT](LICENSE) © Ahmet Akyapı
