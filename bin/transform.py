#!/usr/bin/env python3
"""Text transforms for the ⌃⌥T chooser.

Usage: transform.py <input-file>
Prints a JSON array of {"id", "label", "result"} for every transform that applies to the input,
most relevant first. Results are full strings; the chooser shows a preview.
"""
import base64
import binascii
import datetime as dt
import json
import re
import sys
import urllib.parse
import uuid
import zoneinfo

TZ = zoneinfo.ZoneInfo("Europe/Istanbul")
TR_UPPER = str.maketrans({"i": "İ", "ı": "I"})
TR_LOWER = str.maketrans({"I": "ı", "İ": "i"})


def tr_upper(s):
    return s.translate(TR_UPPER).upper()


def tr_lower(s):
    return s.translate(TR_LOWER).lower()


def tr_title(s):
    return " ".join(tr_upper(w[:1]) + tr_lower(w[1:]) for w in s.split(" "))


def fmt_time(t):
    return dt.datetime.fromtimestamp(t, TZ).strftime("%d.%m.%Y %H:%M:%S")


def b64_decode(s):
    s2 = re.sub(r"\s+", "", s)
    pad = "=" * (-len(s2) % 4)
    raw = base64.b64decode(s2 + pad, altchars=b"-_" if ("-" in s2 or "_" in s2) else None, validate=True)
    return raw.decode("utf-8")


def jwt_decode(s):
    parts = s.strip().split(".")
    if len(parts) != 3:
        raise ValueError
    out = {}
    for name, p in zip(("header", "payload"), parts[:2]):
        out[name] = json.loads(b64_decode(p))
    pl = out["payload"]
    for k in ("iat", "exp", "nbf"):
        if isinstance(pl.get(k), (int, float)):
            pl[k + "_readable"] = fmt_time(pl[k])
    return json.dumps(out, indent=2, ensure_ascii=False)


def main():
    text = open(sys.argv[1], encoding="utf-8", errors="replace").read() if len(sys.argv) > 1 else ""
    s = text.strip()
    out = []

    def add(id_, label, fn):
        try:
            r = fn()
        except Exception:
            return
        if r is None or r == text:
            return
        out.append({"id": id_, "label": label, "result": r})

    if s:
        # JSON first when the input is JSON.
        def pretty():
            return json.dumps(json.loads(s), indent=2, ensure_ascii=False)

        def minify():
            return json.dumps(json.loads(s), separators=(",", ":"), ensure_ascii=False)

        add("json", "JSON biçimlendir", pretty)
        add("jsonmin", "JSON sıkıştır (tek satır)", minify)
        add("jwt", "JWT çöz (header + payload)", lambda: jwt_decode(s))

        # Timestamps (seconds or milliseconds) → readable date.
        if re.fullmatch(r"\d{10}(\d{3})?(\.\d+)?", s):
            v = float(s)
            add("ts", "Zaman damgası → tarih (İstanbul)", lambda: fmt_time(v / 1000 if v > 1e11 else v))

        # ISO date → epoch.
        def iso_to_ts():
            d = dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
            if d.tzinfo is None:
                d = d.replace(tzinfo=TZ)
            return str(int(d.timestamp()))

        add("iso", "Tarih → zaman damgası (sn)", iso_to_ts)

        add("b64d", "Base64 çöz", lambda: b64_decode(s) if len(s) >= 4 and re.fullmatch(r"[A-Za-z0-9+/=_\-\s]+", s) else None)
        add("urld", "URL çöz", lambda: urllib.parse.unquote_plus(s) if "%" in s or "+" in s else None)
        if "=" in s and ("?" in s or "&" in s) and "\n" not in s:
            add("query", "URL parametrelerini aç", lambda: "\n".join(
                f"{k} = {v}" for k, v in urllib.parse.parse_qsl(urllib.parse.urlsplit(s).query or s, keep_blank_values=True)) or None)
        add("hexd", "Hex çöz", lambda: binascii.unhexlify(re.sub(r"\s|0x", "", s)).decode("utf-8")
            if re.fullmatch(r"(0x)?[0-9a-fA-F\s]+", s) and len(re.sub(r"\s", "", s)) % 2 == 0 else None)

        add("b64e", "Base64 kodla", lambda: base64.b64encode(text.encode()).decode())
        add("urle", "URL kodla", lambda: urllib.parse.quote(text, safe=""))
        add("upper", "BÜYÜK HARF", lambda: tr_upper(text))
        add("lower", "küçük harf", lambda: tr_lower(text))
        add("title", "Baş Harfler Büyük", lambda: tr_title(text))
        add("trim", "Boşlukları temizle", lambda: re.sub(r"[ \t]+", " ", "\n".join(l.strip() for l in text.strip().splitlines())))
        if "\n" in s:
            add("oneline", "Tek satıra indir", lambda: " ".join(l.strip() for l in s.splitlines() if l.strip()))
            add("sort", "Satırları sırala", lambda: "\n".join(sorted(s.splitlines(), key=tr_lower)))
            add("uniq", "Tekrarlanan satırları sil", lambda: "\n".join(dict.fromkeys(s.splitlines())))
            add("csv", "Satırları virgülle birleştir", lambda: ", ".join(l.strip() for l in s.splitlines() if l.strip()))
            add("sqlin", "SQL IN listesi", lambda: "(" + ", ".join("'" + l.strip().replace("'", "''") + "'" for l in s.splitlines() if l.strip()) + ")")
        add("camel", "camelCase", lambda: (lambda w: w[0].lower() + "".join(x.capitalize() for x in w[1:]))(re.findall(r"[A-Za-z0-9]+", s)))
        add("snake", "snake_case", lambda: "_".join(x.lower() for x in re.findall(r"[A-Z]?[a-z0-9]+|[A-Z]+(?![a-z])", s)))
        add("kebab", "kebab-case", lambda: "-".join(x.lower() for x in re.findall(r"[A-Z]?[a-z0-9]+|[A-Z]+(?![a-z])", s)))
        add("count", "Say: karakter / kelime / satır",
            lambda: f"{len(text)} karakter · {len(text.split())} kelime · {len(text.splitlines()) or 1} satır")

    # Generators that need no input.
    now = dt.datetime.now(TZ)
    out.append({"id": "uuid", "label": "Yeni UUID", "result": str(uuid.uuid4())})
    out.append({"id": "now", "label": "Şimdiki zaman damgası (sn)", "result": str(int(now.timestamp()))})
    out.append({"id": "nowiso", "label": "Şimdi (ISO 8601)", "result": now.isoformat(timespec="seconds")})
    out.append({"id": "today", "label": "Bugünün tarihi", "result": now.strftime("%d.%m.%Y")})

    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
