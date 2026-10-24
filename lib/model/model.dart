// دستاویز ماڈل — native ایپ کے model/ پیکج کی Flutter صورت + جداول، تصاویر،
// بارڈرز اور اسٹائلز کی توسیع۔ تمام کلاسز خالص Dart ڈیٹا ہیں تاکہ compute()
// isolate میں بھیجی جا سکیں۔

/// بارڈر کی ایک لکیر
class BorderSpec {
  String style; // none|single|double|dotted|dashed|thick|wave
  double widthPt; // 0.5 – 6
  int color; // ARGB
  double spacePt; // متن سے فاصلہ (pt) — پیراگراف/پیج کے لیے
  BorderSpec({
    this.style = 'single',
    this.widthPt = 1.0,
    this.color = 0xFF000000,
    this.spacePt = 4,
  });
  bool get isNone => style == 'none';
  BorderSpec copy() => BorderSpec(
      style: style, widthPt: widthPt, color: color, spacePt: spacePt);
  Map<String, dynamic> toJson() => {
        's': style,
        'w': widthPt,
        'c': color,
        'sp': spacePt,
      };
  factory BorderSpec.fromJson(Map<String, dynamic> j) => BorderSpec(
        style: j['s'] as String? ?? 'single',
        widthPt: (j['w'] as num?)?.toDouble() ?? 1.0,
        color: j['c'] as int? ?? 0xFF000000,
        spacePt: (j['sp'] as num?)?.toDouble() ?? 4,
      );
}

/// چاروں اطراف کے بارڈر (+ پیراگراف کے لیے between)
class EdgeBorders {
  BorderSpec? top;
  BorderSpec? bottom;
  BorderSpec? left;
  BorderSpec? right;
  BorderSpec? between; // صرف پیراگراف: مسلسل پیراگرافوں کے درمیان
  EdgeBorders({this.top, this.bottom, this.left, this.right, this.between});
  bool get isEmpty =>
      top == null &&
      bottom == null &&
      left == null &&
      right == null &&
      between == null;
  EdgeBorders copy() => EdgeBorders(
        top: top?.copy(),
        bottom: bottom?.copy(),
        left: left?.copy(),
        right: right?.copy(),
        between: between?.copy(),
      );
  Map<String, dynamic> toJson() => {
        if (top != null) 'top': top!.toJson(),
        if (bottom != null) 'bottom': bottom!.toJson(),
        if (left != null) 'left': left!.toJson(),
        if (right != null) 'right': right!.toJson(),
        if (between != null) 'between': between!.toJson(),
      };
  factory EdgeBorders.fromJson(Map<String, dynamic> j) => EdgeBorders(
        top: j['top'] == null
            ? null
            : BorderSpec.fromJson(j['top'] as Map<String, dynamic>),
        bottom: j['bottom'] == null
            ? null
            : BorderSpec.fromJson(j['bottom'] as Map<String, dynamic>),
        left: j['left'] == null
            ? null
            : BorderSpec.fromJson(j['left'] as Map<String, dynamic>),
        right: j['right'] == null
            ? null
            : BorderSpec.fromJson(j['right'] as Map<String, dynamic>),
        between: j['between'] == null
            ? null
            : BorderSpec.fromJson(j['between'] as Map<String, dynamic>),
      );
  static EdgeBorders box(BorderSpec s) => EdgeBorders(
      top: s.copy(), bottom: s.copy(), left: s.copy(), right: s.copy());
}

/// صفحہ ترتیبات + صفحہ بارڈر (DOCX sectPr)
class PageSetup {
  bool landscape = false;
  double marginTopMm = 25.4, marginBottomMm = 25.4;
  double marginLeftMm = 25.4, marginRightMm = 25.4;
  double pageWidthMm = 210, pageHeightMm = 297; // A4
  String headerText = '';
  String footerText = '';
  bool pageNumbers = false;
  BorderSpec? pageBorder;
  String pageBorderOffsetFrom = 'page'; // page | text
  PageSetup();
  Map<String, dynamic> toJson() => {
        'landscape': landscape,
        'mt': marginTopMm,
        'mb': marginBottomMm,
        'ml': marginLeftMm,
        'mr': marginRightMm,
        'pw': pageWidthMm,
        'ph': pageHeightMm,
        'header': headerText,
        'footer': footerText,
        'pn': pageNumbers,
        'pb': pageBorder?.toJson(),
        'pbo': pageBorderOffsetFrom,
      };
  factory PageSetup.fromJson(Map<String, dynamic> j) {
    final p = PageSetup();
    p.landscape = j['landscape'] as bool? ?? false;
    p.marginTopMm = (j['mt'] as num?)?.toDouble() ?? 25.4;
    p.marginBottomMm = (j['mb'] as num?)?.toDouble() ?? 25.4;
    p.marginLeftMm = (j['ml'] as num?)?.toDouble() ?? 25.4;
    p.marginRightMm = (j['mr'] as num?)?.toDouble() ?? 25.4;
    p.pageWidthMm = (j['pw'] as num?)?.toDouble() ?? 210;
    p.pageHeightMm = (j['ph'] as num?)?.toDouble() ?? 297;
    p.headerText = j['header'] as String? ?? '';
    p.footerText = j['footer'] as String? ?? '';
    p.pageNumbers = j['pn'] as bool? ?? false;
    p.pageBorder = j['pb'] == null
        ? null
        : BorderSpec.fromJson(j['pb'] as Map<String, dynamic>);
    p.pageBorderOffsetFrom = j['pbo'] as String? ?? 'page';
    return p;
  }
}

class KFootnote {
  int id;
  String text;
  KFootnote(this.id, this.text);
  Map<String, dynamic> toJson() => {'id': id, 'text': text};
  factory KFootnote.fromJson(Map<String, dynamic> j) =>
      KFootnote(j['id'] as int, j['text'] as String? ?? '');
}

abstract class KBlock {
  String kind; // para | table | image
  KBlock(this.kind);
  Map<String, dynamic> toJson();
}

/// پیراگراف بلاک — متن flutter_quill Delta JSON کی صورت میں؛
/// بلاک سطح کی فارمیٹنگ (اسٹائل، فاصلے، شیڈنگ، بارڈر، سمت) یہاں محفوظ ہے،
/// جبکہ inline + سطر فارمیٹنگ (align/list/indent/header/lineHeight/direction)
/// Delta کے اندر رہتی ہے تاکہ quill خود رینڈر کرے۔
class ParaBlock extends KBlock {
  List<dynamic> delta;
  String styleId = 'Normal';
  bool rtl = true;
  double spaceBeforePt = 0;
  double spaceAfterPt = 6;
  double firstLineIndentPt = 0; // پہلی سطر کا فاصلہ (pt) — Word first-line indent
  int? shading; // ARGB یا null
  EdgeBorders? borders;
  bool pageBreakBefore = false;
  ParaBlock(this.delta) : super('para');
  String get plainText {
    final sb = StringBuffer();
    for (final op in delta) {
      if (op is Map && op['insert'] is String) sb.write(op['insert']);
    }
    return sb.toString().replaceAll('\n', '');
  }

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'para',
        'delta': delta,
        'styleId': styleId,
        'rtl': rtl,
        'sb': spaceBeforePt,
        'sa': spaceAfterPt,
        'fli': firstLineIndentPt,
        'shading': shading,
        'borders': borders?.toJson(),
        'pbb': pageBreakBefore,
      };
  factory ParaBlock.fromJson(Map<String, dynamic> j) {
    final p = ParaBlock(List<dynamic>.from(j['delta'] as List? ??
        const [
          {'insert': '\n'}
        ]));
    p.styleId = j['styleId'] as String? ?? 'Normal';
    p.rtl = j['rtl'] as bool? ?? true;
    p.spaceBeforePt = (j['sb'] as num?)?.toDouble() ?? 0;
    p.spaceAfterPt = (j['sa'] as num?)?.toDouble() ?? 6;
    p.firstLineIndentPt = (j['fli'] as num?)?.toDouble() ?? 0;
    p.shading = j['shading'] as int?;
    p.borders = j['borders'] == null
        ? null
        : EdgeBorders.fromJson(j['borders'] as Map<String, dynamic>);
    p.pageBreakBefore = j['pbb'] as bool? ?? false;
    return p;
  }
}

class TableCell {
  String text = '';
  bool bold = false;
  String align = 'start'; // start|center|end
  int? shading;
  BorderSpec? borderAll; // سیل کے چاروں طرف (null = جدول کا طے شدہ)
  TableCell();
  Map<String, dynamic> toJson() => {
        'text': text,
        'bold': bold,
        'align': align,
        'shading': shading,
        'borderAll': borderAll?.toJson(),
      };
  factory TableCell.fromJson(Map<String, dynamic> j) {
    final c = TableCell();
    c.text = j['text'] as String? ?? '';
    c.bold = j['bold'] as bool? ?? false;
    c.align = j['align'] as String? ?? 'start';
    c.shading = j['shading'] as int?;
    c.borderAll = j['borderAll'] == null
        ? null
        : BorderSpec.fromJson(j['borderAll'] as Map<String, dynamic>);
    return c;
  }
}

class TableBlock extends KBlock {
  List<List<TableCell>> rows;
  bool headerRow = true;
  int headerShading = 0xFFD9EAD3;
  String borderPreset = 'grid'; // none|grid|box|internal|external
  EdgeBorders? customBorders; // preset=custom پر
  TableBlock(this.rows) : super('table');
  int get cols => rows.isEmpty ? 0 : rows.first.length;
  @override
  Map<String, dynamic> toJson() => {
        'kind': 'table',
        'rows': rows.map((r) => r.map((c) => c.toJson()).toList()).toList(),
        'headerRow': headerRow,
        'headerShading': headerShading,
        'borderPreset': borderPreset,
        'customBorders': customBorders?.toJson(),
      };
  factory TableBlock.fromJson(Map<String, dynamic> j) {
    final t = TableBlock(
      (j['rows'] as List? ?? [])
          .map((r) => (r as List)
              .map((c) => TableCell.fromJson(c as Map<String, dynamic>))
              .toList())
          .toList(),
    );
    t.headerRow = j['headerRow'] as bool? ?? true;
    t.headerShading = j['headerShading'] as int? ?? 0xFFD9EAD3;
    t.borderPreset = j['borderPreset'] as String? ?? 'grid';
    t.customBorders = j['customBorders'] == null
        ? null
        : EdgeBorders.fromJson(j['customBorders'] as Map<String, dynamic>);
    return t;
  }
}

class ImageBlock extends KBlock {
  String relPath; // دستاویز فولڈر کے اندر نسبتی راستہ (media/xxx.jpg)
  double widthFrac = 0.7; // صفحہ چوڑائی کا حصہ
  String caption = '';
  ImageBlock(this.relPath) : super('image');
  @override
  Map<String, dynamic> toJson() => {
        'kind': 'image',
        'relPath': relPath,
        'widthFrac': widthFrac,
        'caption': caption
      };
  factory ImageBlock.fromJson(Map<String, dynamic> j) {
    final b = ImageBlock(j['relPath'] as String);
    b.widthFrac = (j['widthFrac'] as num?)?.toDouble() ?? 0.7;
    b.caption = j['caption'] as String? ?? '';
    return b;
  }
}

/// حوالہ (Citation) — native DbHelper.Citation کی عکاسی
class Citation {
  int id = 0;
  String type = 'book';
  String author = '', title = '', editor = '', publisher = '', place = '';
  String year = '', volume = '', page = '', edition = '', url = '', notes = '';
  Citation();
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'author': author,
        'title': title,
        'editor': editor,
        'publisher': publisher,
        'place': place,
        'year': year,
        'volume': volume,
        'page': page,
        'edition': edition,
        'url': url,
        'notes': notes,
      };
  factory Citation.fromJson(Map<String, dynamic> j) {
    final c = Citation();
    c.id = j['id'] as int? ?? 0;
    c.type = j['type'] as String? ?? 'book';
    c.author = j['author'] as String? ?? '';
    c.title = j['title'] as String? ?? '';
    c.editor = j['editor'] as String? ?? '';
    c.publisher = j['publisher'] as String? ?? '';
    c.place = j['place'] as String? ?? '';
    c.year = j['year'] as String? ?? '';
    c.volume = j['volume'] as String? ?? '';
    c.page = j['page'] as String? ?? '';
    c.edition = j['edition'] as String? ?? '';
    c.url = j['url'] as String? ?? '';
    c.notes = j['notes'] as String? ?? '';
    return c;
  }
}

/// مکمل دستاویز
class KDoc {
  String id;
  String title;
  List<KBlock> blocks;
  List<KFootnote> footnotes;
  PageSetup pageSetup;
  List<Map<String, dynamic>>
      styles; // KStyle.toJson() کی فہرست (model/styles.dart)
  List<Citation> usedCitations;
  int nextFootnoteId = 2; // 0/1 Word کے separators کے لیے محفوظ (native روایت)
  DateTime modified;

  KDoc({
    required this.id,
    required this.title,
    required this.blocks,
    required this.footnotes,
    required this.pageSetup,
    required this.styles,
    required this.usedCitations,
    required this.modified,
  });

  int wordCount() {
    var n = 0;
    final ws = RegExp(r'\s+');
    for (final b in blocks) {
      if (b is ParaBlock) {
        final t = b.plainText.trim();
        if (t.isNotEmpty) n += t.split(ws).length;
      } else if (b is TableBlock) {
        for (final r in b.rows) {
          for (final c in r) {
            final t = c.text.trim();
            if (t.isNotEmpty) n += t.split(ws).length;
          }
        }
      }
    }
    return n;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'footnotes': footnotes.map((f) => f.toJson()).toList(),
        'pageSetup': pageSetup.toJson(),
        'styles': styles,
        'usedCitations': usedCitations.map((c) => c.toJson()).toList(),
        'nextFootnoteId': nextFootnoteId,
        'modified': modified.toIso8601String(),
      };

  factory KDoc.fromJson(Map<String, dynamic> j) {
    final d = KDoc(
      id: j['id'] as String,
      title: j['title'] as String? ?? 'بے عنوان',
      blocks: (j['blocks'] as List? ?? []).map((b) {
        final m = b as Map<String, dynamic>;
        switch (m['kind']) {
          case 'table':
            return TableBlock.fromJson(m);
          case 'image':
            return ImageBlock.fromJson(m);
          default:
            return ParaBlock.fromJson(m);
        }
      }).toList(),
      footnotes: (j['footnotes'] as List? ?? [])
          .map((f) => KFootnote.fromJson(f as Map<String, dynamic>))
          .toList(),
      pageSetup: PageSetup.fromJson(
          j['pageSetup'] as Map<String, dynamic>? ?? const {}),
      styles: (j['styles'] as List? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList(),
      usedCitations: (j['usedCitations'] as List? ?? [])
          .map((c) => Citation.fromJson(c as Map<String, dynamic>))
          .toList(),
      modified:
          DateTime.tryParse(j['modified'] as String? ?? '') ?? DateTime.now(),
    );
    d.nextFootnoteId = j['nextFootnoteId'] as int? ?? 2;
    return d;
  }
}
