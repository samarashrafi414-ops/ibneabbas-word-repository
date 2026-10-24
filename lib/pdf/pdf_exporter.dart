// PDF برآمد (A4) — pdf/printing پیکجز؛ بنڈل فونٹس کے ساتھ آف لائن رینڈرنگ۔
// حواشی دستاویز کے آخر میں «حواشی» عنوان کے تحت نمبر وار آتے ہیں
// (native کا صفحہ بہ صفحہ نظام اس انجن میں ممکن نہیں — README میں درج)۔
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import '../model/model.dart';
import '../model/styles.dart';
import '../core/font_catalog.dart';
import '../docx/delta_convert.dart';

/// PDF فونٹ کیش — ہر برآمد پر فونٹ دوبارہ parse نہ ہوں
final _pdfFontCache = <String, pw.Font>{};

Future<Uint8List> buildPdf(KDoc doc, String docDirPath) async {
  final fonts = _pdfFontCache;
  Future<pw.Font> loadFont(String assetPath, String key) async {
    if (fonts.containsKey(key)) return fonts[key]!;
    final data = await rootBundle.load(assetPath);
    final f = pw.Font.ttf(data);
    fonts[key] = f;
    return f;
  }

  final nastaliq =
      await loadFont('assets/fonts/NotoNastaliqUrdu.ttf', 'nastaliq');
  final naskh = await loadFont('assets/fonts/NotoNaskhArabic.ttf', 'naskh');
  final amiri = await loadFont('assets/fonts/AmiriQuran-Regular.ttf', 'amiri');
  final tinos = await loadFont('assets/fonts/Tinos-Regular.ttf', 'tinos');

  // دستاویز میں استعمال شدہ فونٹس رجسٹری سے لوڈ (نام فقط پر متبادل فائل)
  final byStored = <String, pw.Font>{};
  final usedNames = <String>{
    for (final st in doc.styles)
      (st['fontFamily'] as String?) ?? FontCatalog.defaultUrdu,
  };
  for (final b in doc.blocks) {
    if (b is ParaBlock) {
      for (final op in b.delta) {
        if (op is Map && op['attributes'] is Map) {
          final f = (op['attributes'] as Map)['font'];
          if (f is String) usedNames.add(f);
        }
      }
    }
  }
  for (final name in usedNames) {
    final asset = FontCatalog.assetFor(name);
    if (asset != null) {
      try {
        byStored[name] = await loadFont(asset, 'u:$name');
      } catch (_) {
        // فائل نہ ملے تو نیچے والا fallback چلے گا
      }
    }
  }

  pw.Font fontFor(String? family) {
    if (family != null && byStored.containsKey(family)) {
      return byStored[family]!;
    }
    switch (family) {
      case 'Amiri Quran':
      case 'Amiri':
        return amiri;
      case 'Noto Naskh Arabic':
      case 'Scheherazade New':
      case 'Lateef':
        return naskh;
      case 'Tinos':
      case 'Gelasio':
      case 'EB Garamond':
      case 'Caladea':
      case 'Carlito':
        return tinos;
      default:
        return nastaliq;
    }
  }

  final styles = doc.styles.map((s) => KStyle.fromJson(s)).toList();
  final ps = doc.pageSetup;
  final pageFormat = PdfPageFormat(
    (ps.landscape ? ps.pageHeightMm : ps.pageWidthMm) * PdfPageFormat.mm,
    (ps.landscape ? ps.pageWidthMm : ps.pageHeightMm) * PdfPageFormat.mm,
    marginTop: ps.marginTopMm * PdfPageFormat.mm,
    marginBottom: ps.marginBottomMm * PdfPageFormat.mm,
    marginLeft: ps.marginLeftMm * PdfPageFormat.mm,
    marginRight: ps.marginRightMm * PdfPageFormat.mm,
  );

  final fnNumbers = <int, int>{};
  var fnCounter = 0;
  int fnNum(int id) => fnNumbers.putIfAbsent(id, () => ++fnCounter);

  final widgets = <pw.Widget>[];

  pw.TextAlign alignOf(String? a, bool rtl) {
    if (a == 'center') return pw.TextAlign.center;
    if (a == 'right') return pw.TextAlign.right;
    if (a == 'justify') return pw.TextAlign.justify;
    return rtl ? pw.TextAlign.right : pw.TextAlign.left;
  }

  for (final block in doc.blocks) {
    if (block is ParaBlock) {
      final style = resolveStyle(styles, block.styleId);
      for (final line in deltaToLines(block.delta)) {
        final spans = <pw.TextSpan>[];
        for (final r in line.runs) {
          if (r.fnote != null) {
            spans.add(pw.TextSpan(
              text: ' ${fnNum(r.fnote!)}',
              style: pw.TextStyle(
                  font: fontFor(style.fontFamily),
                  fontSize: style.fontSize * 0.7,
                  color: PdfColors.green900),
            ));
            continue;
          }
          spans.add(pw.TextSpan(
            text: r.text,
            style: pw.TextStyle(
              font: fontFor(r.font ?? style.fontFamily),
              fontSize: r.size ?? style.fontSize,
              fontWeight: (r.bold || style.bold) ? pw.FontWeight.bold : null,
              fontStyle:
                  (r.italic || style.italic) ? pw.FontStyle.italic : null,
              color: r.color != null
                  ? PdfColor.fromInt(hexToArgb(r.color!))
                  : PdfColor.fromInt(style.color),
              decoration: (r.underline || style.underline)
                  ? pw.TextDecoration.underline
                  : (r.strike ? pw.TextDecoration.lineThrough : null),
            ),
          ));
        }
        final rtl = block.rtl;
        widgets.add(pw.Padding(
          padding: pw.EdgeInsets.only(
            top: block.spaceBeforePt,
            bottom: block.spaceAfterPt,
            right: rtl ? line.indent * 24.0 : 0,
            left: rtl ? 0 : line.indent * 24.0,
          ),
          child: pw.RichText(
            textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            textAlign: alignOf(line.align, rtl),
            text: pw.TextSpan(
                children: spans,
                style: pw.TextStyle(
                    font: fontFor(style.fontFamily),
                    fontSize: style.fontSize,
                    lineSpacing: style.lineSpacing)),
          ),
        ));
      }
    } else if (block is TableBlock) {
      final rows = <List<String>>[];
      for (final row in block.rows) {
        rows.add(row.map((c) => c.text).toList());
      }
      widgets.add(pw.TableHelper.fromTextArray(
        data: rows,
        headerStyle: pw.TextStyle(
            font: nastaliq, fontWeight: pw.FontWeight.bold, fontSize: 11),
        cellStyle: pw.TextStyle(font: nastaliq, fontSize: 11),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellAlignment: pw.Alignment.centerRight,
      ));
      widgets.add(pw.SizedBox(height: 8));
    } else if (block is ImageBlock) {
      final f = File(p.join(docDirPath, block.relPath));
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        widgets.add(pw.Center(
          child: pw.Image(pw.MemoryImage(bytes),
              width: pageFormat.availableWidth * block.widthFrac),
        ));
        if (block.caption.isNotEmpty) {
          widgets.add(pw.Center(
            child: pw.Text(block.caption,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(font: naskh, fontSize: 10)),
          ));
        }
        widgets.add(pw.SizedBox(height: 6));
      }
    }
  }

  if (fnNumbers.isNotEmpty) {
    widgets.add(pw.Divider());
    widgets.add(pw.Text('حواشی',
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
            font: nastaliq, fontSize: 14, fontWeight: pw.FontWeight.bold)));
    final sorted = fnNumbers.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final e in sorted) {
      final fn = doc.footnotes.where((f) => f.id == e.key).firstOrNull;
      if (fn == null) continue;
      widgets.add(pw.Text('${e.value}. ${fn.text}',
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(font: naskh, fontSize: 10.5)));
    }
  }

  final pdf = pw.Document(title: doc.title, author: 'IBNEABBAS WORD');
  pdf.addPage(pw.MultiPage(
    pageFormat: pageFormat,
    header: ps.headerText.isEmpty
        ? null
        : (ctx) => pw.Center(
            child: pw.Text(ps.headerText,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(font: naskh, fontSize: 10))),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(ps.footerText,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(font: naskh, fontSize: 10)),
        if (ps.pageNumbers)
          pw.Text('${ctx.pageNumber}',
              style: pw.TextStyle(font: tinos, fontSize: 10)),
      ],
    ),
    build: (ctx) => widgets,
  ));
  return pdf.save();
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
