# IBNEABBAS WORD — Flutter (v2.0.0)

اردو/عربی RTL-اوّل تحقیقی ورڈ پروسیسر کی **مکمل Flutter نئی تحریر** — native ایپ
«Kanz Word Pro» v1.7 (پیکیج: `com.ibneabbas.kanzword`) کا جانشین، تاکہ یہی ایپ
Android اور iPhone دونوں پر چلے۔ پیکیج آئی ڈی native والی ہی رکھی گئی ہے تاکہ
یہ اس کی جگہ انسٹال ہو سکے۔

A complete Flutter rewrite of the native research word processor **Kanz Word
Pro** (v1.7). Package id `com.ibneabbas.kanzword`, version `2.0.0+1`.

---

## فیچرز — native ایپ سے موازنہ / Feature map vs the native app

| فیچر | Native v1.7 | Flutter v2.0 |
|---|---|---|
| رچ ایڈیٹر (بولڈ/اٹالک/انڈرلائن/رنگ/ہائی لائٹ/سائز) | ✓ | ✓ (flutter_quill 10.8.5) |
| پیراگراف ٹولز: بلٹس، نمبرنگ، ملٹی لیول انڈنٹ، الائن، لائن سپیسنگ، RTL/LTR | جزوی | ✓ مکمل (MS Word Paragraph ربن کے مطابق) |
| **جدول (Tables)** | ✗ | ✓ نیا — قطار/کالم اضافہ و حذف، ہیڈر شیڈنگ، سیل الائن، بارڈرز |
| **تصاویر (Images)** | ✗ | ✓ نیا — گیلری/کیمرا، چوڑائی ایڈجسٹ، کیپشن |
| **بارڈرز مکمل** (پیراگراف + between، صفحہ pgBorders، جدول/سیل) | ✗ | ✓ نیا — تمام DOCX میں آتے جاتے ہیں (round-trip) |
| **اسٹائلز سسٹم مکمل** (منیجر، تخلیق/ترمیم/حذف، گیلری، ٹیمپلیٹ اسٹائلز) | جزوی | ✓ نیا — genuine `styles.xml` |
| حقیقی فوٹ نوٹس (footnotes.xml، سیپریٹرز سمیت) | ✓ | ✓ |
| DOCX برآمد (حقیقی OOXML انجن) | ✓ | ✓ Dart انجن (document/styles/footnotes/numbering/header/footer/media+rels) |
| DOCX درآمد (پیراگراف، رن فارمیٹنگ، ہیڈنگز، لسٹس، جدول، تصاویر، فوٹ نوٹس، اسٹائلز، پیج بارڈر) | ✓ | ✓ |
| PDF برآمد (A4) | ✓ | ✓ (pdf/printing) — حواشی آخر میں «حواشی» کے تحت (نیچے حدود دیکھیں) |
| آف لائن قرآن: آیت + ترجمۂ کنزالایمان + علمی حوالہ | ✓ | ✓ (bundled JSON، 114 سورتیں، 6,236 آیات) |
| حوالہ جات: 10 علمی ٹیمپلیٹس + مآخذ و مراجع | ✓ | ✓ |
| ٹیمپلیٹس (خالی، مقالہ، فتویٰ، خط) | ✓ | ✓ + **مقالہ (پی ایچ ڈی)** نیا |
| آٹو سیو + کریش ریکوری | ✓ | ✓ (20s آٹو سیو، 2s debounce ریکوری فائل) |
| رموزِ دینیہ (إثراء المتون جدول) | ✗ | ✓ نیا — KFGQPC سمبل فونٹ کے اصل گلفس |
| شعر جدول (صدر \| فاصل \| عجز) | ✗ | ✓ نیا پری سیٹ |
| تحقیقی فونٹس (46 فونٹس، 6 زمرے) + PhD پیش سیٹ | جزوی (15) | ✓ نیا — نیچے جدول دیکھیں |
| SAF کھولنا/محفوظ کرنا | ✓ | ✓ file_picker/share_plus (Android+iOS دونوں) |
| سپلیش + HD لوگو، پریمیم نیوی/سبز UI | جزوی | ✓ |

## معماری / Architecture

- **بلاک ماڈل:** دستاویز = ترتیب وار بلاکس (پیراگراف / جدول / تصویر)۔
  ہر پیراگراف کا اپنا `QuillController` ہے؛ پیراگراف بلاک-مقامی (block-local)
  حالت رکھتا ہے، اس لیے ایک حرف لکھنے سے پوری دستاویز دوبارہ نہیں بنتی۔
  فہرست `ListView.builder` سے **virtualized** ہے — صرف نظر آنے والے بلاکس
  بنتے ہیں؛ 200 صفحات کی دستاویز بھی کھلتی اور قابلِ تدوین رہتی ہے۔
- **فوٹ نوٹ اینکر:** پیراگراف کے اندر `fnote` کسٹم attribute؛ نمبر خودکار
  دوبارہ گنے جاتے ہیں؛ DOCX میں حقیقی `w:footnoteReference`۔
- **DOCX انجن (Dart):** `archive` + `xml` پر مبنی — `document.xml`,
  `styles.xml` (genuine Word styles: styleId/basedOn/next/qFormat/مکمل rPr/pPr),
  `footnotes.xml` (آئی ڈیز 2 سے؛ 0/1 سیپریٹرز)، `numbering.xml`,
  ہیڈر/فوٹر، `word/media/` + rels، `[Content_Types].xml`۔
  درآمد و برآمد دونوں `compute()` isolate میں چلتے ہیں (UI کبھی نہیں اٹکتی)۔
- **اسٹائلز:** built-in (Normal, Title, Subtitle, Heading 1–3, Quote,
  Intense Quote, Caption, Footnote Text, Bibliography, QuranAyah) + صارف کے
  اسٹائلز؛ «ٹیمپلیٹ میں شامل» والے ہر نئی دستاویز میں؛ «Update style to match
  current paragraph» سے سب پیراگراف بیک وقت بدلتے ہیں۔
- **بارڈرز:** پیراگراف (چاروں اطراف + `between`)، صفحہ (`sectPr/pgBorders`,
  offset page/text)، جدول (presets: none/grid/box/internal/custom + فی سیل)۔
  اسٹائلز: single, double, dotted, dashed, thick, wave؛ چوڑائی 0.5–6pt؛ رنگ؛
  متن سے فاصلہ۔ سب DOCX round-trip ہوتے ہیں۔
- **قرآن:** ڈیٹا پہلے استعمال پر lazy لوڈ (`compute` میں parse)، کیش شدہ؛
  تلاش debounced۔ آیت بطور: ﴿عربی﴾ (قرآنی فونٹ — طے شدہ Amiri Quran، PhD
  پیش سیٹ کے بعد KFGQPC HAFS) + `ترجمہ کنزالایمان: "…"` + علمی حوالہ
  `(سورۃ البقرة 2:255)` (چیک باکس، طے شدہ ON)۔
- **تصاویر:** داخل کرتے وقت زیادہ سے زیادہ 1600px تک downscale؛ دستاویز کے
  فولڈر میں `media/` کے اندر محفوظ۔

## تحقیقی فونٹس / Research fonts (46)

چنندہ (picker) 6 زمروں میں ہے: اردو / عربی / قرآن / انگریزی / فارسی /
نقلِ صوت۔ **بنڈل** = اصل فائل ایپ میں شامل (سب fontTools سے جانچی ہوئی)؛
**نام فقط (PC)** = ملکیتی فونٹ — فائل لائسنس کی وجہ سے شامل نہیں؛ ایپ میں
ہم شکل آزاد متبادل سے نظر آتا ہے، مگر دستاویز/DOCX میں اصل نام ہی لکھا جاتا
ہے تاکہ PC کے MS Word میں حقیقی فونٹ لگے۔ کل فونٹ فائلیں ≈ **38 MB**
(جس میں Jameel Noori 13.8MB اور Alvi 9.6MB نستعلیق شامل ہیں — صارف کی ہدایت
پر سائز کے باوجود شامل کیے گئے)۔

| # | فونٹ | حیثیت | ماخذ / متبادل |
|---|---|---|---|
| 1 | Jameel Noori Nastaleeq | بنڈل | native اثاثے (Noori) |
| 2 | Noto Nastaliq Urdu | بنڈل | native اثاثے (Google) |
| 3 | Alvi Nastaleeq | بنڈل (9.6MB) | inshapardaz/urdu-web-fonts — داخلی نام «Alvi Lahori Nastaleeq» |
| 4 | Faiz Lahori Nastaleeq | نام فقط | تصدیق شدہ مفت ماخذ نہ ملا → متبادل: Noto Nastaliq Urdu |
| 5 | Nafees Nastaleeq | بنڈل | GitHub mirror (CRULP) — داخلی خاندانی نام «Nafees» |
| 6 | Mehr Nastaliq Web | بنڈل | native اثاثے (PakType) |
| 7 | Urdu Typesetting | نام فقط (Microsoft) | متبادل: Noto Nastaliq Urdu |
| 8 | Nafees Web Naskh | بنڈل | inshapardaz/urdu-web-fonts (CRULP) — داخلی نام «Nafees» |
| 9 | Amiri | بنڈل | google/fonts |
| 10 | Traditional Arabic | نام فقط (Microsoft) | متبادل: Noto Naskh Arabic |
| 11 | Arabic Typesetting | نام فقط (Microsoft) | متبادل: Noto Naskh Arabic |
| 12 | Simplified Arabic | نام فقط (Microsoft) | متبادل: Noto Naskh Arabic |
| 13 | Scheherazade New | بنڈل | native اثاثے (SIL) |
| 14 | Noto Naskh Arabic | بنڈل | native اثاثے (Google) |
| 15 | Noto Sans Arabic | بنڈل | google/fonts |
| 16 | Sakkal Majalla | نام فقط (Microsoft) | متبادل: Noto Naskh Arabic |
| 17 | Adobe Arabic | نام فقط (Adobe) | متبادل: Noto Naskh Arabic |
| 18 | Lateef | بنڈل | native اثاثے (SIL) |
| 19 | KFGQPC Uthmanic Script HAFS | بنڈل | archive.org پر KFGQPC تقسیم کا آئینہ (Ver13) — داخلی نام «KFGQPC HAFS Uthmanic Script» |
| 20 | Amiri Quran | بنڈل | native اثاثے |
| 21 | Uthman Taha Naskh | بنڈل | archive.org (Ver10) — داخلی نام «KFGQPC Uthman Taha Naskh» |
| 22 | IndoPak Quranic Script | بنڈل | GitHub (DigitalKhatt IndoPak build) — داخلی نام «DigitalKhatt IndoPak» |
| 23 | KFGQPC Uthmanic Script | نام فقط | سادہ (غیر HAFS) بنڈل کا تصدیق شدہ ماخذ نہ ملا → متبادل: Amiri Quran |
| 24 | Times New Roman | نام فقط (Microsoft) | متبادل: Tinos (بنڈل) |
| 25 | Arial | نام فقط (Microsoft) | متبادل: Arimo (بنڈل، google/fonts) |
| 26 | Calibri | نام فقط (Microsoft) | متبادل: Carlito (بنڈل) |
| 27 | Cambria | نام فقط (Microsoft) | متبادل: Caladea (بنڈل) |
| 28 | Garamond | نام فقط (Monotype) | متبادل: EB Garamond (بنڈل) |
| 29 | Georgia | نام فقط (Microsoft) | متبادل: Gelasio (بنڈل) |
| 30 | Palatino Linotype | نام فقط (Monotype) | متبادل: Gelasio (بنڈل) |
| 31 | Book Antiqua | نام فقط (Monotype) | متبادل: Gelasio (بنڈل) |
| 32 | Aptos | نام فقط (Microsoft) | متبادل: Carlito (بنڈل) |
| 33 | Helvetica | نام فقط (Linotype) | متبادل: Arimo (بنڈل) |
| 34 | B Nazanin | بنڈل | GitHub (intuxicated/css-persian) — داخلی نام عین «B Nazanin» |
| 35 | B Mitra | بنڈل | اسی ماخذ سے — «B Mitra» |
| 36 | B Lotus | بنڈل | اسی ماخذ سے — «B Lotus» |
| 37 | B Zar | بنڈل | اسی ماخذ سے — «B Zar» |
| 38 | Vazirmatn | بنڈل | google/fonts |
| 39 | IranNastaliq | بنڈل | font-store/font-IranNastaliq — داخلی نام «IranNastaliq-Web» |
| 40 | Gentium Plus | بنڈل (Regular+Italic) | google/fonts (SIL) |
| 41 | Charis SIL | بنڈل | software.sil.org سرکاری تقسیم |
| 42 | Doulos SIL | بنڈل | software.sil.org سرکاری تقسیم |
| 43 | Brill | نام فقط (Brill) | متبادل: Gentium Plus |
| 44 | Cambria Math | نام فقط (Microsoft) | متبادل: STIX Two Math |
| 45 | STIX Two Math | بنڈل | google/fonts |
| 46 | (Noto Naskh Arabic فارسی زمرے میں بھی) | بنڈل | اوپر #14 |

اضافی بنڈل: Gulzar, Mirza (native اثاثوں سے) اور رموز کا فونٹ
**KFGQPC Arabic Symbols 01** (صارف کی اپنی فائل `Symbols1_Ver02.otf` —
اصل فائل صرف MS-Symbol cmap رکھتی تھی، اس لیے اسی کے گلفس پر معیاری
Unicode cmap شامل کر کے `KFGQPCSymbols.otf` بنائی گئی؛ گلفس عین وہی ہیں)۔

### پی ایچ ڈی پیش سیٹ / PhD preset

ترتیبات میں «پی ایچ ڈی پیش سیٹ لاگو کریں» ایک ٹیپ میں یہ کرداری فونٹس لگا
دیتا ہے — اردو متن: Jameel Noori Nastaleeq؛ عربی و احادیث: Amiri؛ قرآنی
آیات: KFGQPC Uthmanic Script HAFS (آیت داخل کرنے کا فونٹ بھی یہی ہو جاتا
ہے)؛ انگریزی متن و حوالہ جات: Times New Roman (نام فقط/Tinos)؛ حواشی:
متعلقہ زبان کا فونٹ (طے شدہ Amiri)؛ نقلِ صوت: Gentium Plus۔ ہر کردار کا
فونٹ الگ سے بھی بدلا جا سکتا ہے۔ **«مقالہ (پی ایچ ڈی)» ٹیمپلیٹ** انہی
فونٹس والے اسٹائلز (بشمول `English Text` پیراگراف اسٹائل اور
`Transliteration` کرکٹر اسٹائل) کے ساتھ نئی دستاویز بناتا ہے۔

## رموزِ دینیہ / Religious symbols (Ithraa AlMotoon)

تمام عبارات کے اصل خطاطی گلفس **KFGQPC Arabic Symbols 01** فونٹ میں موجود
پائے گئے (ہر گلاف کو رینڈر کر کے بصری طور پر شناخت کیا گیا) — کسی عبارت کو
متن-فال بیک کی ضرورت نہیں پڑی۔ پورا سائز = بنیادی کوڈ پوائنٹ؛ چھوٹی
(compact) صورتیں بریکٹ میں — پینل میں «رموزِ دینیہ — صغیر» زمرے میں الگ بھی
موجود ہیں۔

| عبارت | کوڈ پوائنٹ / فونٹ |
|---|---|
| بسم الله الرحمن الرحيم — اسلوب ١/٢/٣ | U+F021 / U+F022 / U+F023 — KFGQPC Symbols |
| بسم الله الرحمن الرحيم — ﷽ | U+FDFD — Amiri (Unicode ligature) |
| الله أكبر | U+F041 |
| جل جلاله | U+F042 (U+F064)؛ نیز U+FDFB ﷻ — Amiri |
| جل وعلا | U+F043 (U+F065) |
| عز وجل | U+F044 (U+F062) |
| سبحانه وتعالى | U+F045 (U+F063) |
| تبارك وتعالى | U+F046 (U+F066) |
| صلى الله عليه وعلى آله وسلم | U+F047 |
| صلى الله عليه وسلم | U+F048 (U+F067)؛ نیز U+FDFA ﷺ — Amiri |
| رضي الله عنه | U+F049 (U+F068) |
| رضي الله عنها | U+F04A (U+F069) |
| رضي الله عنهن | U+F04B (U+F06C) |
| رضي الله عنهما | U+F04C (U+F06B) |
| رضي الله عنهم | U+F04D (U+F06A) |
| عليه الصلاة والسلام | U+F04F (U+F06D) |
| عليها السلام | U+F050 (U+F06F) |
| عليهم السلام | U+F051 (U+F070) |
| عليهما السلام | U+F052 (U+F071) |
| عليه السلام | U+F053 (U+F06E) |
| رحمها الله | U+F054 (U+F075) |
| رحمهن الله | U+F055 (U+F076) |
| رحمه الله | U+F056 (U+F072) |
| رحمهما الله | U+F057 (U+F074) |
| رحمهم الله | U+F058 (U+F073) |

مزید زمرے پینل میں: دعائیہ کلمات (صدق الله العظيم وغیرہ)، قرآنی علامات
(﴿ ﴾ ۞ ﷺ وغیرہ)، اوقاف و رموز (۔ ، ؛ : ؟ ! ﴾ ﴿ « » – — …)، آرائشی
(❁ ✦ ﷽ ﷺ ❀ وغیرہ)۔ نوٹ: PUA رموز والے DOCX کو MS Word میں درست دیکھنے کے
لیے PC پر KFGQPC سمبل فونٹ انسٹال ہونا چاہیے؛ یونیکوڈ ligatures
(﷽ ﷺ ﷻ) ہر جگہ چلتے ہیں۔

**شعر جدول:** «جدول» کے ساتھ «شعر جدول» بٹن إثراء طرز کا 3-کالمی جدول
(صدر | فاصل | عجز، ہیڈر قطار + 4 قطاریں، درمیانی فاصل کالُم تنگ) داخل کرتا ہے۔

## حروفِ مقطعات — تصدیق / Muqatta'at verification

صارف کے حکم کے مطابق: جن آیات میں حروفِ مقطعات ہیں، ان کے ترجمے کے خانے میں
کنزالایمان مطبوعہ کے عین مطابق **حروف ہی** درج ہیں (ویب سائٹ کے خانے کی طرح
خالی نہیں)۔ بنڈل ڈیٹا کی جانچ (2026-10-22): ایسی آیات **19** ہیں —
(2:1) (3:1) (19:1) (20:1) (26:1) (28:1) (29:1) (30:1) (31:1) (32:1) (36:1)
(40:1) (41:1) (42:1) (42:2) (43:1) (44:1) (45:1) (46:1) — انیسوں میں ترجمہ
حروف پر مشتمل اور غیر خالی ہے؛ پوری 6,236 آیات میں ترجمے کا **کوئی خانہ
خالی نہیں**۔ (تصدیقی رپورٹ: `~/workspace/quran-verification/REPORT.md` —
عربی متن dawateislami.net سے 100%، ترجمہ 99.71% یکساں پایا گیا تھا۔)

## بلڈ / Build

**Android (PC پر):**
```bash
flutter pub get
flutter build apk --release      # یا: flutter build appbundle
```

**iPhone (صرف Mac + Xcode پر ممکن ہے):**
```bash
flutter build ipa
```
پروجیکٹ iOS-تیار ہے: `ios/` مکمل Runner پروجیکٹ، Bundle ID
`com.ibneabbas.kanzword`، deployment target iOS 13.0، مکمل AppIcon سیٹ
(HD لوگو سے تیار)، LaunchImage، Info.plist میں فوٹو/کیمرا اجازت کی تفصیل،
`UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` اور DOCX کھولنے
کے لیے UTI رجسٹرڈ ہے (Files/WhatsApp سے براہِ راست کھل سکتی ہے)۔
**ایماندارانہ نوٹ:** اس ماحول میں نہ Android APK بن سکا (Gradle/Java نیٹ
ورک رکاوٹ) نہ iOS بائنری (macOS/Xcode درکار) — ڈیلیوری **سورس پروجیکٹ**
ہے؛ دونوں بلڈز PC/Mac پر اوپر والے کمانڈز سے بنتے ہیں۔

## کارکردگی / Performance design

- ایڈیٹر: virtualized بلاک لسٹ (`ListView.builder`) + بلاک-مقامی کنٹرولرز
  — آف اسکرین پیراگراف کے ایڈیٹر نہیں بنتے؛ سنگل کریکٹر تبدیلی پر پوری
  اسکرین rebuild نہیں ہوتی۔
- DOCX درآمد/برآمد: `compute()` isolates + progress اشارہ۔
- قرآن: lazy لوڈ + `compute` parse + کیش؛ تلاش debounce کے ساتھ۔
- تصاویر: داخلے پر 1600px downscale؛ لائبریری تلاش debounced۔
- آغاز: پہلے فریم سے پہلے کوئی بھاری کام نہیں؛ دستاویزات lazy لسٹ۔

## ٹیسٹ / Tests

- `flutter analyze` — **0 errors, 0 warnings** (صرف چند info lints)۔
- `flutter test` — **5/5 پاس**: DOCX انجن (parts، `w:tbl`، footnotes،
  media، `w:pBdr` + `w:between`، `w:pgBorders`، styles.xml کسٹم اسٹائل)،
  درآمد round-trip (اسٹائل/جدول/حاشیہ/تصویر/پیج بارڈر)، امیج سائز شناخت،
  فونٹ رجسٹری (46 نام، بنڈل فائلوں کی موجودگی، pubspec رجسٹریشن،
  DOCX-نام تبدیلی)۔
- انحصار (pubspec): flutter_quill 10.8.5, image_picker 1.1.2, archive 3.6.1,
  xml 6.5.0, file_picker 8.1.7, share_plus 10.1.4, path_provider 2.1.4,
  path 1.9.0, shared_preferences 2.3.2, pdf 3.11.1, printing 5.13.4,
  intl 0.19.0 — تمام Flutter 3.24.5 / Dart 3.5.4 پر resolve شدہ۔

## حدود / Honest limitations

- اس ماحول میں APK/IPA **بلڈ نہیں** ہوا (اوپر دیکھیں)؛ ڈیوائس ٹیسٹ بھی نہیں
  ہوا — دعویٰ صرف analyze + VM ٹیسٹوں تک ہے۔
- PDF میں حواشی صفحہ بہ صفحہ کے بجائے دستاویز کے آخر میں آتے ہیں؛ pdf
  پیکج کی عربی شیپنگ محدود ہے (DOCX ہی اصل مکمل صورت ہے)۔
- Show/Hide (¶) نشانات flutter_quill میں دستیاب نہیں — شامل نہیں کیے گئے۔
- فی-پیراگراف undo تاریخ (ہر بلاک کی اپنی)؛ دستاویز-گیر undo نہیں۔
- PUA سمبلز کے لیے Word میں KFGQPC فونٹ درکار (اوپر نوٹ دیکھیں)۔
- نام فقط فونٹس (Times New Roman وغیرہ) ایپ میں متبادل شکل میں نظر آتے
  ہیں؛ اصل شکل صرف PC کے Word میں، جہاں وہ فونٹ انسٹال ہو۔
- UI زبان کی ترتیب محفوظ ہوتی ہے، مگر انٹرفیس فی الحال اردو-اوّل ہے۔
- درآمد میں نامعلوم DOCX حصے (مثلاً چارٹس، ایمبیڈڈ آبجیکٹس) آگے نہیں لے
  جائے جاتے؛ درآمد کنندہ اپنی رپورٹ میں ان کی تعداد بتاتا ہے۔
