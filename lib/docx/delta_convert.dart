// Delta (flutter_quill) ⇄ ساختہ runs تبدیلی — DOCX/PDF انجن کی مشترکہ بنیاد
import '../core/font_catalog.dart';

class KRun {
  String text;
  Map<String, dynamic> attrs;
  KRun(this.text, this.attrs);
  bool get bold => attrs['bold'] == true;
  bool get italic => attrs['italic'] == true;
  bool get underline => attrs['underline'] == true;
  bool get strike => attrs['strike'] == true;
  String? get font => attrs['font'] as String?;
  double? get size {
    final v = attrs['size'];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String? get color => attrs['color'] as String?;
  String? get background => attrs['background'] as String?;
  String? get script => attrs['script'] as String?;
  int? get fnote => attrs['fnote'] is int ? attrs['fnote'] as int : null;
  String? get cstyle => attrs['cstyle'] as String?;
}

class KLine {
  List<KRun> runs;
  Map<String, dynamic> lineAttrs;
  KLine(this.runs, this.lineAttrs);
  String? get align => lineAttrs['align'] as String?;
  String? get list => lineAttrs['list'] as String?;
  int get indent => (lineAttrs['indent'] as num?)?.toInt() ?? 0;
  int? get header => (lineAttrs['header'] as num?)?.toInt();
  bool get rtlLine => lineAttrs['direction'] == 'rtl';
  double? get lineHeight => (lineAttrs['lineHeight'] as num?)?.toDouble();
}

/// ایک پیراگراف کے Delta کو سطور میں توڑیں (ہر '\n' ایک سطر ختم کرتی ہے)
List<KLine> deltaToLines(List<dynamic> delta) {
  final lines = <KLine>[];
  var runs = <KRun>[];
  for (final raw in delta) {
    if (raw is! Map) continue;
    final insert = raw['insert'];
    final attrs = raw['attributes'] as Map<String, dynamic>? ?? const {};
    if (insert is String) {
      var rest = insert;
      while (true) {
        final idx = rest.indexOf('\n');
        if (idx < 0) {
          if (rest.isNotEmpty) runs.add(KRun(rest, Map.of(attrs)));
          break;
        }
        if (idx > 0) runs.add(KRun(rest.substring(0, idx), Map.of(attrs)));
        lines.add(KLine(runs, Map.of(attrs)));
        runs = <KRun>[];
        rest = rest.substring(idx + 1);
        if (rest.isEmpty) break;
      }
    }
  }
  if (runs.isNotEmpty) lines.add(KLine(runs, const {}));
  if (lines.isEmpty) lines.add(KLine([], const {}));
  return lines;
}

/// runs + سطر attrs سے quill Delta JSON بنائیں
List<dynamic> linesToDelta(List<KLine> lines) {
  final ops = <dynamic>[];
  for (final line in lines) {
    for (final r in line.runs) {
      ops.add({
        'insert': r.text,
        if (r.attrs.isNotEmpty) 'attributes': r.attrs,
      });
    }
    ops.add({
      'insert': '\n',
      if (line.lineAttrs.isNotEmpty) 'attributes': line.lineAttrs,
    });
  }
  if (ops.isEmpty) ops.add({'insert': '\n'});
  return ops;
}

String deltaPlainText(List<dynamic> delta) {
  final sb = StringBuffer();
  for (final op in delta) {
    if (op is Map && op['insert'] is String) sb.write(op['insert']);
  }
  return sb.toString();
}

/// '#RRGGBB' یا 'RRGGBB' → ARGB int
int hexToArgb(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return int.parse(h, radix: 16);
}

String argbToHex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String argbToHexNoHash(int argb) =>
    (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

/// Word کے 15 highlight رنگ — قریب ترین نام (native روایت)
const Map<String, int> wordHighlights = {
  'black': 0xFF000000,
  'blue': 0xFF0000FF,
  'cyan': 0xFF00FFFF,
  'green': 0xFF00FF00,
  'magenta': 0xFFFF00FF,
  'red': 0xFFFF0000,
  'yellow': 0xFFFFFF00,
  'white': 0xFFFFFFFF,
  'darkBlue': 0xFF000080,
  'darkCyan': 0xFF008080,
  'darkGray': 0xFF808080,
  'darkGreen': 0xFF008000,
  'darkMagenta': 0xFF800080,
  'darkRed': 0xFF800000,
  'darkYellow': 0xFF808000,
  'lightGray': 0xFFC0C0C0,
};

String? nearestHighlightName(int argb) {
  if (argb == 0) return null;
  var best = 'yellow';
  var bestD = 1 << 62;
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  wordHighlights.forEach((name, v) {
    final dr = r - ((v >> 16) & 0xFF);
    final dg = g - ((v >> 8) & 0xFF);
    final db = b - (v & 0xFF);
    final d = dr * dr + dg * dg + db * db;
    if (d < bestD) {
      bestD = d;
      best = name;
    }
  });
  return best;
}

int? highlightArgb(String name) => wordHighlights[name];

/// فونٹ کا DOCX نام
String docxFont(String? family) =>
    FontCatalog.docxNameFor(family ?? FontCatalog.defaultUrdu);

/// اعشاریہ ہندسے (¹²³…) — فٹ نوٹ marker کے لیے
const _sup = ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹'];
String superscriptNum(int n) =>
    n.toString().split('').map((d) => _sup[int.parse(d)]).join();
