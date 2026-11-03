-- Metin şablonları: bir yere ";anahtar" yazınca metne dönüşür. ⌃⌥S ile listeden de seçilir.
-- Yeni şablon eklemek için bu listeye bir satır ekle; Hammerspoon menüsünden "Yeniden yükle" yeter.
-- text: sabit metin ya da function() ... end (her seferinde hesaplanır).
return {
  { key = ";tarih", label = "Bugünün tarihi",        text = function() return os.date("%d.%m.%Y") end },
  { key = ";saat",  label = "Şu anki saat",          text = function() return os.date("%H:%M") end },
  { key = ";simdi", label = "Tarih + saat",          text = function() return os.date("%d.%m.%Y %H:%M") end },
  { key = ";iso",   label = "ISO tarih",             text = function() return os.date("%Y-%m-%d") end },
  { key = ";intest", label = "IN TEST devir yorumu", text = [[Geliştirme tamamlandı ve yerelde doğrulandı.

Doğrulama:
-

IN TEST'e alındı, kontrolünüze sunuyorum.]] },
  { key = ";daily", label = "Daily notu", text = [[Dün:
-
Bugün:
-
Engel:
- Yok]] },
  { key = ";pr",    label = "PR açıklaması iskeleti", text = [[## Özet
-

## Neden
-

## Test
-

Refs: ]] },
  { key = ";bug",   label = "Hata kaydı iskeleti", text = [[Adımlar:
1.

Beklenen:
-

Gerçekleşen:
-

Ortam: DEV]] },
  { key = ";tsk",   label = "Teşekkür",              text = "Teşekkürler, elinize sağlık 🙏" },
  { key = ";bakiyorum", label = "İnceliyorum",        text = "Bakıyorum, kısa süre içinde dönüş yapacağım." },
}
