// مکمل تحقیقی فونٹ رجسٹری — صارف کی منظور شدہ فہرست (46 فونٹس، 6 زمرے)
//
// ہر اندراج کا [name] ہی وہ نام ہے جو دستاویز میں محفوظ ہوتا ہے اور DOCX میں
// w:rFonts کے طور پر لکھا جاتا ہے (MS Word میں اصل فونٹ نظر آئے گا)۔
// ملکیتی (proprietary) فونٹس فائل کے طور پر شامل نہیں کیے جا سکتے — وہ
// «نام فقط» (nameOnly) ہیں: ایپ میں ان کی جگہ ہم شکل آزاد فونٹ ([display])
// سے رینڈرنگ ہوتی ہے اور ساتھ «PC» بیج دکھتا ہے۔

/// ایک فونٹ اندراج
class FontEntry {
  /// مستند نام (صارف کی فہرست والا) — یہی دستاویز/DOCX میں لکھا جاتا ہے
  final String name;

  /// زمرے جن میں یہ فونٹ چنندہ (picker) میں نظر آئے گا
  final List<String> groups;

  /// ایپ کے اندر رینڈرنگ کے لیے رجسٹرڈ Flutter family
  /// (بنڈل فونٹ کے لیے عموماً [name] ہی؛ نام فقط کے لیے ہم شکل متبادل)
  final String display;

  /// بنڈل فائل کا راستہ (PDF برآمد کے لیے)؛ نام فقط پر متبادل کی فائل
  final String? asset;

  /// true ہو تو اصل فونٹ proprietary ہے — فائل شامل نہیں، صرف نام
  final bool nameOnly;

  const FontEntry(this.name, this.groups, this.display,
      {this.asset, this.nameOnly = false});

  /// مطابقت (compatibility) — پرانا نام
  String get family => name;

  /// مطابقت — DOCX نام ہمیشہ مستند نام ہے
  String get docxName => name;

  /// مطابقت — بنیادی زمرہ
  String get group => groups.first;

  bool get bundled => !nameOnly;
}

class FontCatalog {
  static const String defaultUrdu = 'Noto Nastaliq Urdu';
  static const String amiriQuran = 'Amiri Quran';
  static const String amiri = 'Amiri';
  static const String symbols = 'KFGQPC Arabic Symbols 01';

  /// زمرے (صارف کی ترتیب)
  static const List<String> categories = [
    'urdu',
    'arabic',
    'quran',
    'english',
    'persian',
    'translit',
  ];

  static String categoryLabel(String c) => switch (c) {
        'urdu' => 'اردو',
        'arabic' => 'عربی',
        'quran' => 'قرآن',
        'english' => 'انگریزی',
        'persian' => 'فارسی',
        'translit' => 'نقلِ صوت / علمی',
        _ => c,
      };

  static const List<FontEntry> all = [
    // ── اردو ──────────────────────────────────────────────
    FontEntry('Jameel Noori Nastaleeq', ['urdu'], 'Jameel Noori Nastaleeq',
        asset: 'assets/fonts/Noori_Regular.ttf'),
    FontEntry('Noto Nastaliq Urdu', ['urdu'], 'Noto Nastaliq Urdu',
        asset: 'assets/fonts/NotoNastaliqUrdu.ttf'),
    FontEntry('Alvi Nastaleeq', ['urdu'], 'Alvi Nastaleeq',
        asset: 'assets/fonts/AlviNastaleeq.ttf'),
    FontEntry('Faiz Lahori Nastaleeq', ['urdu'], 'Noto Nastaliq Urdu',
        asset: 'assets/fonts/NotoNastaliqUrdu.ttf', nameOnly: true),
    FontEntry('Nafees Nastaleeq', ['urdu'], 'Nafees Nastaleeq',
        asset: 'assets/fonts/NafeesNastaleeq.otf'),
    FontEntry('Mehr Nastaliq Web', ['urdu'], 'Mehr Nastaliq Web',
        asset: 'assets/fonts/MehrNastaliqWeb.ttf'),
    FontEntry('Urdu Typesetting', ['urdu'], 'Noto Nastaliq Urdu',
        asset: 'assets/fonts/NotoNastaliqUrdu.ttf', nameOnly: true),
    FontEntry('Nafees Web Naskh', ['urdu'], 'Nafees Web Naskh',
        asset: 'assets/fonts/NafeesWebNaskh.otf'),
    FontEntry('Gulzar', ['urdu'], 'Gulzar',
        asset: 'assets/fonts/Gulzar-Regular.ttf'),
    // ── عربی ──────────────────────────────────────────────
    FontEntry('Amiri', ['arabic'], 'Amiri',
        asset: 'assets/fonts/Amiri-Regular.ttf'),
    FontEntry('Traditional Arabic', ['arabic'], 'Noto Naskh Arabic',
        asset: 'assets/fonts/NotoNaskhArabic.ttf', nameOnly: true),
    FontEntry('Arabic Typesetting', ['arabic'], 'Noto Naskh Arabic',
        asset: 'assets/fonts/NotoNaskhArabic.ttf', nameOnly: true),
    FontEntry('Simplified Arabic', ['arabic'], 'Noto Naskh Arabic',
        asset: 'assets/fonts/NotoNaskhArabic.ttf', nameOnly: true),
    FontEntry('Scheherazade New', ['arabic'], 'Scheherazade New',
        asset: 'assets/fonts/ScheherazadeNew-Regular.ttf'),
    FontEntry('Noto Naskh Arabic', ['arabic', 'persian'], 'Noto Naskh Arabic',
        asset: 'assets/fonts/NotoNaskhArabic.ttf'),
    FontEntry('Noto Sans Arabic', ['arabic'], 'Noto Sans Arabic',
        asset: 'assets/fonts/NotoSansArabic.ttf'),
    FontEntry('Sakkal Majalla', ['arabic'], 'Noto Naskh Arabic',
        asset: 'assets/fonts/NotoNaskhArabic.ttf', nameOnly: true),
    FontEntry('Adobe Arabic', ['arabic'], 'Noto Naskh Arabic',
        asset: 'assets/fonts/NotoNaskhArabic.ttf', nameOnly: true),
    FontEntry('Lateef', ['arabic'], 'Lateef',
        asset: 'assets/fonts/Lateef-Regular.ttf'),
    FontEntry('Mirza', ['arabic'], 'Mirza',
        asset: 'assets/fonts/Mirza-Regular.ttf'),
    FontEntry(
        'KFGQPC Arabic Symbols 01', ['arabic'], 'KFGQPC Arabic Symbols 01',
        asset: 'assets/fonts/KFGQPCSymbols.otf'),
    // ── قرآن ──────────────────────────────────────────────
    FontEntry(
        'KFGQPC Uthmanic Script HAFS', ['quran'], 'KFGQPC Uthmanic Script HAFS',
        asset: 'assets/fonts/UthmanicHafs.otf'),
    FontEntry('Amiri Quran', ['quran', 'arabic'], 'Amiri Quran',
        asset: 'assets/fonts/AmiriQuran-Regular.ttf'),
    FontEntry('Uthman Taha Naskh', ['quran'], 'Uthman Taha Naskh',
        asset: 'assets/fonts/UthmanTaha.otf'),
    FontEntry('IndoPak Quranic Script', ['quran'], 'IndoPak Quranic Script',
        asset: 'assets/fonts/IndoPak.otf'),
    FontEntry('KFGQPC Uthmanic Script', ['quran'], 'Amiri Quran',
        asset: 'assets/fonts/AmiriQuran-Regular.ttf', nameOnly: true),
    // ── انگریزی (تمام ملکیتی — نام فقط، ہم شکل آزاد متبادل سے رینڈرنگ) ──
    FontEntry('Times New Roman', ['english'], 'Tinos',
        asset: 'assets/fonts/Tinos-Regular.ttf', nameOnly: true),
    FontEntry('Arial', ['english'], 'Arimo',
        asset: 'assets/fonts/Arimo.ttf', nameOnly: true),
    FontEntry('Calibri', ['english'], 'Carlito',
        asset: 'assets/fonts/Carlito-Regular.ttf', nameOnly: true),
    FontEntry('Cambria', ['english'], 'Caladea',
        asset: 'assets/fonts/Caladea-Regular.ttf', nameOnly: true),
    FontEntry('Garamond', ['english'], 'EB Garamond',
        asset: 'assets/fonts/EBGaramond.ttf', nameOnly: true),
    FontEntry('Georgia', ['english'], 'Gelasio',
        asset: 'assets/fonts/Gelasio-Regular.ttf', nameOnly: true),
    FontEntry('Palatino Linotype', ['english'], 'Gelasio',
        asset: 'assets/fonts/Gelasio-Regular.ttf', nameOnly: true),
    FontEntry('Book Antiqua', ['english'], 'Gelasio',
        asset: 'assets/fonts/Gelasio-Regular.ttf', nameOnly: true),
    FontEntry('Aptos', ['english'], 'Carlito',
        asset: 'assets/fonts/Carlito-Regular.ttf', nameOnly: true),
    FontEntry('Helvetica', ['english'], 'Arimo',
        asset: 'assets/fonts/Arimo.ttf', nameOnly: true),
    // ── فارسی ─────────────────────────────────────────────
    FontEntry('B Nazanin', ['persian'], 'B Nazanin',
        asset: 'assets/fonts/BNazanin.ttf'),
    FontEntry('B Mitra', ['persian'], 'B Mitra',
        asset: 'assets/fonts/BMitra.ttf'),
    FontEntry('B Lotus', ['persian'], 'B Lotus',
        asset: 'assets/fonts/BLotus.ttf'),
    FontEntry('B Zar', ['persian'], 'B Zar', asset: 'assets/fonts/BZar.ttf'),
    FontEntry('Vazirmatn', ['persian'], 'Vazirmatn',
        asset: 'assets/fonts/Vazirmatn.ttf'),
    FontEntry('IranNastaliq', ['persian'], 'IranNastaliq',
        asset: 'assets/fonts/IranNastaliq.ttf'),
    // ── نقلِ صوت / علمی ────────────────────────────────────
    FontEntry('Gentium Plus', ['translit'], 'Gentium Plus',
        asset: 'assets/fonts/GentiumPlus-Regular.ttf'),
    FontEntry('Charis SIL', ['translit'], 'Charis SIL',
        asset: 'assets/fonts/CharisSIL-Regular.ttf'),
    FontEntry('Doulos SIL', ['translit'], 'Doulos SIL',
        asset: 'assets/fonts/DoulosSIL-Regular.ttf'),
    FontEntry('Brill', ['translit'], 'Gentium Plus',
        asset: 'assets/fonts/GentiumPlus-Regular.ttf', nameOnly: true),
    FontEntry('Cambria Math', ['translit'], 'STIX Two Math',
        asset: 'assets/fonts/STIXTwoMath-Regular.ttf', nameOnly: true),
    FontEntry('STIX Two Math', ['translit'], 'STIX Two Math',
        asset: 'assets/fonts/STIXTwoMath-Regular.ttf'),
  ];

  static FontEntry? entryFor(String name) {
    for (final f in all) {
      if (f.name == name) return f;
    }
    return null;
  }

  /// محفوظ شدہ/درآمد شدہ نام سے ایپ میں رینڈرنگ والا family
  static String displayFamilyFor(String stored) {
    final e = entryFor(stored);
    if (e != null) return e.display;
    final legacy = _legacyToCanonical[stored];
    if (legacy != null) return entryFor(legacy)?.display ?? stored;
    return stored;
  }

  /// PDF برآمد کے لیے فائل کا راستہ (نہ ملے تو null)
  static String? assetFor(String stored) {
    final e = entryFor(stored) ?? entryFor(_legacyToCanonical[stored] ?? '');
    return e?.asset;
  }

  /// پرانے محفوظ نام (فائل family) → مستند نام
  static const Map<String, String> _legacyToCanonical = {
    'Tinos': 'Times New Roman',
    'Arimo': 'Arial',
    'Carlito': 'Calibri',
    'Caladea': 'Cambria',
    'Gelasio': 'Georgia',
    'EB Garamond': 'Garamond',
    'Mehr Nastaliq': 'Mehr Nastaliq Web',
  };

  /// دستاویز میں محفوظ family سے DOCX (Word) نام
  static String docxNameFor(String family) {
    if (entryFor(family) != null) return family;
    return _legacyToCanonical[family] ?? family;
  }

  /// DOCX سے درآمد شدہ نام → دستاویز میں محفوظ ہونے والا نام
  static String familyForDocx(String docxName) {
    if (entryFor(docxName) != null) return docxName;
    return _legacyToCanonical[docxName] ?? docxName;
  }

  static List<FontEntry> byGroup(String g) =>
      all.where((f) => f.groups.contains(g)).toList();
}
