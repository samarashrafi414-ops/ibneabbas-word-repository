// اسٹائلز سسٹم — MS Word درجے کا: built-in + صارف اسٹائلز، based-on وراثت،
// DOCX styles.xml میں حقیقی Word styles کے طور پر محفوظ۔
import 'model.dart';

class KStyle {
  String id; // Word styleId (حروف/اعداد، خالی جگہ نہیں)
  String name;
  String type; // paragraph | character | linked
  String basedOnId;
  String fontFamily;
  double fontSize;
  bool bold, italic, underline;
  int color; // ARGB
  int? highlight;
  String align; // start|center|end|justify
  double lineSpacing;
  double spaceBeforePt, spaceAfterPt;
  int indentLevel;
  bool rtl;
  EdgeBorders? borders;
  int? shading;
  bool builtIn;
  bool inTemplate; // تمام نئی دستاویزات میں دستیاب
  KStyle({
    required this.id,
    required this.name,
    this.type = 'paragraph',
    this.basedOnId = 'Normal',
    this.fontFamily = 'Noto Nastaliq Urdu',
    this.fontSize = 14,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color = 0xFF142238,
    this.highlight,
    this.align = 'start',
    this.lineSpacing = 1.6,
    this.spaceBeforePt = 0,
    this.spaceAfterPt = 6,
    this.indentLevel = 0,
    this.rtl = true,
    this.borders,
    this.shading,
    this.builtIn = false,
    this.inTemplate = false,
  });

  KStyle copy() => KStyle.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'basedOnId': basedOnId,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'color': color,
        'highlight': highlight,
        'align': align,
        'lineSpacing': lineSpacing,
        'sb': spaceBeforePt,
        'sa': spaceAfterPt,
        'indentLevel': indentLevel,
        'rtl': rtl,
        'borders': borders?.toJson(),
        'shading': shading,
        'builtIn': builtIn,
        'inTemplate': inTemplate,
      };
  factory KStyle.fromJson(Map<String, dynamic> j) => KStyle(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? 'paragraph',
        basedOnId: j['basedOnId'] as String? ?? 'Normal',
        fontFamily: j['fontFamily'] as String? ?? 'Noto Nastaliq Urdu',
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 14,
        bold: j['bold'] as bool? ?? false,
        italic: j['italic'] as bool? ?? false,
        underline: j['underline'] as bool? ?? false,
        color: j['color'] as int? ?? 0xFF142238,
        highlight: j['highlight'] as int?,
        align: j['align'] as String? ?? 'start',
        lineSpacing: (j['lineSpacing'] as num?)?.toDouble() ?? 1.6,
        spaceBeforePt: (j['sb'] as num?)?.toDouble() ?? 0,
        spaceAfterPt: (j['sa'] as num?)?.toDouble() ?? 6,
        indentLevel: j['indentLevel'] as int? ?? 0,
        rtl: j['rtl'] as bool? ?? true,
        borders: j['borders'] == null
            ? null
            : EdgeBorders.fromJson(j['borders'] as Map<String, dynamic>),
        shading: j['shading'] as int?,
        builtIn: j['builtIn'] as bool? ?? false,
        inTemplate: j['inTemplate'] as bool? ?? false,
      );
}

/// طے شدہ built-in اسٹائلز (Word کے ناموں/IDs کے مطابق)
List<KStyle> builtinStyles() => [
      KStyle(id: 'Normal', name: 'عام متن (Normal)', builtIn: true),
      KStyle(
          id: 'Title',
          name: 'عنوانِ اعظم (Title)',
          basedOnId: 'Normal',
          fontSize: 30,
          bold: true,
          align: 'center',
          color: 0xFF0A1F33,
          spaceAfterPt: 12,
          lineSpacing: 1.8,
          builtIn: true),
      KStyle(
          id: 'Subtitle',
          name: 'ذیلی عنوان (Subtitle)',
          basedOnId: 'Normal',
          fontSize: 17,
          italic: true,
          align: 'center',
          color: 0xFF44546A,
          spaceAfterPt: 10,
          builtIn: true),
      KStyle(
          id: 'Heading1',
          name: 'عنوان 1',
          basedOnId: 'Normal',
          fontSize: 22,
          bold: true,
          color: 0xFF0A5C36,
          spaceBeforePt: 14,
          spaceAfterPt: 6,
          lineSpacing: 1.7,
          builtIn: true),
      KStyle(
          id: 'Heading2',
          name: 'عنوان 2',
          basedOnId: 'Normal',
          fontSize: 18,
          bold: true,
          color: 0xFF0A5C36,
          spaceBeforePt: 12,
          spaceAfterPt: 5,
          lineSpacing: 1.7,
          builtIn: true),
      KStyle(
          id: 'Heading3',
          name: 'عنوان 3',
          basedOnId: 'Normal',
          fontSize: 16,
          bold: true,
          italic: true,
          color: 0xFF1B5E20,
          spaceBeforePt: 10,
          spaceAfterPt: 4,
          builtIn: true),
      KStyle(
          id: 'Quote',
          name: 'اقتباس (Quote)',
          basedOnId: 'Normal',
          fontFamily: 'Noto Naskh Arabic',
          fontSize: 15,
          italic: true,
          color: 0xFF37474F,
          indentLevel: 1,
          spaceBeforePt: 6,
          spaceAfterPt: 6,
          builtIn: true),
      KStyle(
          id: 'IntenseQuote',
          name: 'نمایاں اقتباس',
          basedOnId: 'Quote',
          bold: true,
          color: 0xFF0A5C36,
          shading: 0xFFE8F5E9,
          borders: EdgeBorders(
              right: BorderSpec(
                  style: 'single',
                  widthPt: 2.25,
                  color: 0xFF19B58A,
                  spacePt: 8)),
          builtIn: true),
      KStyle(
          id: 'Caption',
          name: 'کیپشن (Caption)',
          basedOnId: 'Normal',
          fontSize: 11,
          italic: true,
          color: 0xFF607D8B,
          align: 'center',
          builtIn: true),
      KStyle(
          id: 'FootnoteText',
          name: 'حاشیہ متن',
          basedOnId: 'Normal',
          fontFamily: 'Noto Naskh Arabic',
          fontSize: 11,
          lineSpacing: 1.3,
          spaceAfterPt: 2,
          builtIn: true),
      KStyle(
          id: 'Bibliography',
          name: 'مآخذ و مراجع',
          basedOnId: 'Normal',
          fontSize: 13,
          spaceAfterPt: 4,
          indentLevel: 1,
          builtIn: true),
      KStyle(
          id: 'QuranAyah',
          name: 'آیتِ قرآنی',
          basedOnId: 'Normal',
          fontFamily: 'Amiri Quran',
          fontSize: 18,
          align: 'center',
          lineSpacing: 2.0,
          spaceBeforePt: 8,
          spaceAfterPt: 8,
          builtIn: true),
    ];

/// based-on سلسلہ حل کر کے مؤثر اسٹائل (بچہ والد پر فوقیت رکھتا ہے — فیلڈ بہ فیلڈ
/// سادہ ضم: بچے کی تمام قدریں، سوائے اس کے کہ والد کی borders/shading صرف اسی
/// صورت میں جب بچے کی خالی ہو)۔
KStyle resolveStyle(List<KStyle> styles, String id) {
  final byId = <String, KStyle>{for (final s in styles) s.id: s};
  final chain = <KStyle>[];
  var cur = byId[id] ?? byId['Normal'] ?? builtinStyles().first;
  final seen = <String>{};
  while (true) {
    chain.add(cur);
    if (!seen.add(cur.id)) break;
    final parent = byId[cur.basedOnId];
    if (parent == null || parent.id == cur.id) break;
    cur = parent;
  }
  var result = chain.last.copy();
  for (final s in chain.reversed.skip(1)) {
    final j = s.toJson();
    // والد کی بنیاد پر بچے کی قدریں لگائیں — borders/shading بچے کی غیر موجودگی میں والد سے
    final merged = KStyle.fromJson(j);
    merged.borders = s.borders ?? result.borders;
    merged.shading = s.shading ?? result.shading;
    merged.highlight = s.highlight ?? result.highlight;
    result = merged;
  }
  return result;
}

KStyle? findStyle(List<KStyle> styles, String id) {
  for (final s in styles) {
    if (s.id == id) return s;
  }
  return null;
}
