// DOCX درآمد — native DocxReader کی وسعت کے ساتھ: پیراگراف، runs، عنوانات،
// لسٹیں، جداول (بارڈرز سمیت)، تصاویر، حواشی، styles.xml، صفحہ بارڈرز۔
// خراب part پوری فائل نہیں گراتا (partial recovery)؛ غیر معاون عناصر گنے جاتے ہیں۔
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../model/model.dart';
import '../model/styles.dart';
import 'delta_convert.dart';

class DocxImportResult {
  final Map<String, dynamic> docJson;
  final Map<String, List<int>> media; // نئی relPath → bytes
  final int unsupportedCount;
  final List<String> notes;
  DocxImportResult(this.docJson, this.media, this.unsupportedCount, this.notes);
}

XmlElement? _child(XmlElement e, String local) {
  for (final c in e.childElements) {
    if (c.name.local == local) return c;
  }
  return null;
}

List<XmlElement> _children(XmlElement e, String local) =>
    e.childElements.where((c) => c.name.local == local).toList();

String? _attr(XmlElement e, String local) {
  for (final a in e.attributes) {
    if (a.name.local == local) return a.value;
  }
  return null;
}

String _allText(XmlElement e) {
  final sb = StringBuffer();
  for (final n in e.descendants) {
    if (n is XmlElement && n.name.local == 't') sb.write(n.innerText);
  }
  return sb.toString();
}

BorderSpec? _parseBorder(XmlElement? el) {
  if (el == null) return null;
  final val = _attr(el, 'val') ?? 'single';
  if (val == 'none' || val == 'nil') {
    return BorderSpec(style: 'none', widthPt: 0, color: 0xFF000000);
  }
  final sz = double.tryParse(_attr(el, 'sz') ?? '8') ?? 8;
  final colorHex = _attr(el, 'color');
  return BorderSpec(
    style: val,
    widthPt: (sz / 8).clamp(0.5, 6),
    color: (colorHex == null || colorHex == 'auto')
        ? 0xFF000000
        : hexToArgb(colorHex),
    spacePt: double.tryParse(_attr(el, 'space') ?? '4') ?? 4,
  );
}

EdgeBorders? _parseEdges(XmlElement? pBdr, {bool between = false}) {
  if (pBdr == null) return null;
  final e = EdgeBorders(
    top: _parseBorder(_child(pBdr, 'top')),
    bottom: _parseBorder(_child(pBdr, 'bottom')),
    left: _parseBorder(_child(pBdr, 'left')),
    right: _parseBorder(_child(pBdr, 'right')),
    between: between ? _parseBorder(_child(pBdr, 'between')) : null,
  );
  return e.isEmpty ? null : e;
}

DocxImportResult importDocx(Uint8List bytes, String docId, String title) {
  final notes = <String>[];
  var unsupported = 0;
  final archive = ZipDecoder().decodeBytes(bytes);
  List<int>? partBytes(String name) {
    for (final f in archive) {
      if (f.name == name) return (f.content as List<int>);
    }
    return null;
  }

  String decodeXml(String name) {
    final b = partBytes(name);
    if (b == null) return '';
    return utf8.decode(b, allowMalformed: true);
  }

  // rels: id → target
  final rels = <String, String>{};
  final relsText = decodeXml('word/_rels/document.xml.rels');
  if (relsText.isNotEmpty) {
    final rd = XmlDocument.parse(relsText);
    for (final rel in rd.descendants.whereType<XmlElement>()) {
      final id = _attr(rel, 'Id');
      final target = _attr(rel, 'Target');
      if (id != null && target != null) rels[id] = target;
    }
  }

  // numbering: numId → numFmt
  final numFmt = <int, String>{};
  final numText = decodeXml('word/numbering.xml');
  if (numText.isNotEmpty) {
    try {
      final nd = XmlDocument.parse(numText);
      final abstractFmt = <int, String>{};
      for (final an in nd.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'abstractNum')) {
        final aid = int.tryParse(_attr(an, 'abstractNumId') ?? '');
        final lvl0 = an.childElements
            .where((e) => e.name.local == 'lvl')
            .cast<XmlElement?>()
            .firstWhere((_) => true, orElse: () => null);
        final fmt = lvl0 == null ? null : _child(lvl0, 'numFmt');
        if (aid != null) abstractFmt[aid] = _attr(fmt ?? an, 'val') ?? 'bullet';
      }
      for (final num in nd.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'num')) {
        final nid = int.tryParse(_attr(num, 'numId') ?? '');
        final abs = _child(num, 'abstractNumId');
        final aid = abs == null ? null : int.tryParse(_attr(abs, 'val') ?? '');
        if (nid != null && aid != null)
          numFmt[nid] = abstractFmt[aid] ?? 'bullet';
      }
    } catch (_) {
      notes.add('numbering.xml پڑھنے میں خرابی — لسٹیں سادہ متن میں');
    }
  }

  // styles.xml
  var styles = builtinStyles();
  final stylesText = decodeXml('word/styles.xml');
  if (stylesText.isNotEmpty) {
    try {
      styles = _parseStyles(stylesText);
    } catch (_) {
      notes.add('styles.xml پڑھنے میں خرابی — طے شدہ اسٹائلز استعمال');
    }
  }
  final styleIds = styles.map((s) => s.id).toSet();

  // footnotes
  final footnotes = <KFootnote>[];
  final fnText = decodeXml('word/footnotes.xml');
  if (fnText.isNotEmpty) {
    try {
      final fd = XmlDocument.parse(fnText);
      for (final fn in fd.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'footnote')) {
        final id = int.tryParse(_attr(fn, 'id') ?? '');
        final type = _attr(fn, 'type');
        if (id == null || id < 2 || type != null) continue;
        footnotes.add(KFootnote(id, _allText(fn)));
      }
    } catch (_) {
      notes.add('footnotes.xml پڑھنے میں خرابی');
    }
  }

  final docText = decodeXml('word/document.xml');
  if (docText.isEmpty)
    throw Exception('word/document.xml نہیں ملی — فائل خراب ہے');
  final xdoc = XmlDocument.parse(docText);
  final body = xdoc.descendants
      .whereType<XmlElement>()
      .firstWhere((e) => e.name.local == 'body');

  final pageSetup = PageSetup();
  final blocks = <KBlock>[];
  final media = <String, List<int>>{};
  var mediaCount = 0;
  var fnOrdinal = 0;

  KLine parsePara(XmlElement pEl) {
    final runs = <KRun>[];
    final lineAttrs = <String, dynamic>{};
    var rtl = false;
    final pPr = _child(pEl, 'pPr');
    if (pPr != null) {
      if (_child(pPr, 'bidi') != null) rtl = true;
      final jc = _child(pPr, 'jc');
      if (jc != null) {
        final v = _attr(jc, 'val');
        if (v == 'center') lineAttrs['align'] = 'center';
        if (v == 'right') lineAttrs['align'] = 'right';
        if (v == 'both' || v == 'distribute') lineAttrs['align'] = 'justify';
      }
      final numPr = _child(pPr, 'numPr');
      if (numPr != null) {
        final ilvl = _child(numPr, 'ilvl');
        final numIdEl = _child(numPr, 'numId');
        lineAttrs['indent'] =
            int.tryParse(ilvl == null ? '0' : _attr(ilvl, 'val') ?? '0') ?? 0;
        final nid =
            numIdEl == null ? null : int.tryParse(_attr(numIdEl, 'val') ?? '');
        final fmt = nid == null ? 'bullet' : (numFmt[nid] ?? 'bullet');
        lineAttrs['list'] = fmt == 'decimal' ? 'ordered' : 'bullet';
      }
    }
    for (final rEl in pEl.childElements) {
      if (rEl.name.local == 'hyperlink') {
        // hyperlink کے اندر کے runs بھی شامل
        for (final inner in rEl.childElements) {
          if (inner.name.local == 'r')
            _parseRun(inner, runs, () => ++fnOrdinal);
        }
        continue;
      }
      if (rEl.name.local != 'r') {
        if (rEl.name.local != 'pPr' &&
            rEl.name.local != 'bookmarkStart' &&
            rEl.name.local != 'bookmarkEnd') {
          unsupported++;
        }
        continue;
      }
      _parseRun(rEl, runs, () => ++fnOrdinal);
    }
    if (rtl) lineAttrs['direction'] = 'rtl';
    return KLine(runs, lineAttrs);
  }

  void handlePara(XmlElement pEl) {
    final pPr = _child(pEl, 'pPr');
    var styleId = 'Normal';
    var spaceBefore = 0.0, spaceAfter = 6.0;
    int? shading;
    EdgeBorders? borders;
    var pageBreakBefore = false;
    var rtlBlock = false;
    if (pPr != null) {
      final ps = _child(pPr, 'pStyle');
      if (ps != null) {
        final v = _attr(ps, 'val');
        if (v != null && styleIds.contains(v)) styleId = v;
      }
      if (_child(pPr, 'bidi') != null) rtlBlock = true;
      final sp = _child(pPr, 'spacing');
      if (sp != null) {
        spaceBefore = (double.tryParse(_attr(sp, 'before') ?? '0') ?? 0) / 20;
        spaceAfter = (double.tryParse(_attr(sp, 'after') ?? '120') ?? 120) / 20;
      }
      final shd = _child(pPr, 'shd');
      if (shd != null) {
        final fill = _attr(shd, 'fill');
        if (fill != null && fill != 'auto') shading = hexToArgb(fill);
      }
      borders = _parseEdges(_child(pPr, 'pBdr'), between: true);
      if (_child(pPr, 'pageBreakBefore') != null) pageBreakBefore = true;
    }
    // صفحہ وقفہ والا run ہو تو اگلا پیراگراف pageBreakBefore
    var hasPageBreak = false;
    for (final d in pEl.descendants.whereType<XmlElement>()) {
      if (d.name.local == 'br' && _attr(d, 'type') == 'page')
        hasPageBreak = true;
      if (d.name.local == 'lastRenderedPageBreak') hasPageBreak = false;
    }
    // تصویر والا پیراگراف؟
    XmlElement? blip;
    for (final d in pEl.descendants.whereType<XmlElement>()) {
      if (d.name.local == 'blip') blip = d;
    }
    if (blip != null) {
      final embed = _attr(blip, 'embed');
      final target = embed == null ? null : rels[embed];
      if (target != null) {
        final partName = target.startsWith('word/') ? target : 'word/$target';
        final bytes = partBytes(partName.replaceAll('word/word/', 'word/'));
        if (bytes != null) {
          mediaCount++;
          final ext = partName.split('.').last;
          final relPath = 'media/img$mediaCount.$ext';
          media[relPath] = bytes;
          // چوڑائی کا تناسب
          double frac = 0.7;
          for (final d in pEl.descendants.whereType<XmlElement>()) {
            if (d.name.local == 'extent') {
              final cx = double.tryParse(_attr(d, 'cx') ?? '');
              if (cx != null) {
                const emuPerMm = 36000.0;
                final contentMm = pageSetup.pageWidthMm -
                    pageSetup.marginLeftMm -
                    pageSetup.marginRightMm;
                frac = (cx / emuPerMm / contentMm).clamp(0.15, 1.0);
              }
            }
          }
          blocks.add(ImageBlock(relPath)..widthFrac = frac);
          return;
        }
      }
      unsupported++;
      return;
    }
    final line = parsePara(pEl);
    final delta = linesToDelta([line]);
    final pb = ParaBlock(delta)
      ..styleId = styleId
      ..rtl = rtlBlock
      ..spaceBeforePt = spaceBefore
      ..spaceAfterPt = spaceAfter
      ..shading = shading
      ..borders = borders
      ..pageBreakBefore = pageBreakBefore;
    blocks.add(pb);
    if (hasPageBreak) {
      blocks.add(ParaBlock([
        {'insert': '\n'}
      ])
        ..pageBreakBefore = true);
    }
  }

  TableBlock handleTable(XmlElement tbl) {
    var preset = 'grid';
    EdgeBorders? custom;
    final tblPr = _child(tbl, 'tblPr');
    if (tblPr != null) {
      final tb = _child(tblPr, 'tblBorders');
      if (tb != null) {
        custom = _parseEdges(tb);
        final insideH = _parseBorder(_child(tb, 'insideH'));
        final topNone = custom?.top?.isNone ?? false;
        if (topNone && insideH != null && !insideH.isNone) {
          preset = 'internal';
        } else if (custom != null && insideH == null) {
          preset = 'box';
        } else if (custom != null &&
            (custom.top?.isNone ?? false) &&
            (insideH?.isNone ?? false)) {
          preset = 'none';
        }
      }
    }
    final rows = <List<TableCell>>[];
    for (final tr in _children(tbl, 'tr')) {
      final row = <TableCell>[];
      for (final tc in _children(tr, 'tc')) {
        final cell = TableCell();
        final tcPr = _child(tc, 'tcPr');
        if (tcPr != null) {
          final shd = _child(tcPr, 'shd');
          if (shd != null) {
            final fill = _attr(shd, 'fill');
            if (fill != null && fill != 'auto') cell.shading = hexToArgb(fill);
          }
          final tcB = _parseEdges(_child(tcPr, 'tcBorders'));
          if (tcB?.top != null) cell.borderAll = tcB!.top;
        }
        final texts = <String>[];
        for (final pEl in _children(tc, 'p')) {
          final line = parsePara(pEl);
          final t = line.runs.map((r) => r.text).join();
          texts.add(t);
          if (line.runs.any((r) => r.bold)) cell.bold = true;
          if (line.align == 'center') cell.align = 'center';
          if (line.align == 'right') cell.align = 'end';
        }
        cell.text = texts.join('\n');
        row.add(cell);
      }
      rows.add(row);
    }
    final t = TableBlock(rows)
      ..borderPreset = preset
      ..customBorders = preset == 'custom' ? custom : null;
    return t;
  }

  for (final el in body.childElements) {
    switch (el.name.local) {
      case 'p':
        handlePara(el);
        break;
      case 'tbl':
        blocks.add(handleTable(el));
        break;
      case 'sectPr':
        _parseSectPr(el, pageSetup);
        break;
      default:
        unsupported++;
    }
  }

  // header/footer متن
  String partPlain(String name) {
    final t = decodeXml(name);
    if (t.isEmpty) return '';
    try {
      return _allText(XmlDocument.parse(t).rootElement);
    } catch (_) {
      return '';
    }
  }

  pageSetup.headerText = partPlain('word/header1.xml');
  final footerText = partPlain('word/footer1.xml');
  if (footerText.isNotEmpty) pageSetup.footerText = footerText;

  if (blocks.isEmpty) {
    blocks.add(ParaBlock([
      {'insert': '\n'}
    ]));
  }
  var maxFn = 1;
  for (final f in footnotes) {
    if (f.id > maxFn) maxFn = f.id;
  }
  final doc = KDoc(
    id: docId,
    title: title,
    blocks: blocks,
    footnotes: footnotes,
    pageSetup: pageSetup,
    styles: styles.map((s) => s.toJson()).toList(),
    usedCitations: [],
    modified: DateTime.now(),
  );
  doc.nextFootnoteId = maxFn + 1;
  return DocxImportResult(doc.toJson(), media, unsupported, notes);
}

void _parseRun(XmlElement rEl, List<KRun> runs, int Function() nextOrdinal) {
  final attrs = <String, dynamic>{};
  final rPr = _child(rEl, 'rPr');
  if (rPr != null) {
    if (_child(rPr, 'b') != null) attrs['bold'] = true;
    if (_child(rPr, 'i') != null) attrs['italic'] = true;
    if (_child(rPr, 'u') != null) attrs['underline'] = true;
    if (_child(rPr, 'strike') != null) attrs['strike'] = true;
    final fonts = _child(rPr, 'rFonts');
    if (fonts != null) {
      final name =
          _attr(fonts, 'cs') ?? _attr(fonts, 'ascii') ?? _attr(fonts, 'hAnsi');
      if (name != null) attrs['font'] = _docxToFamily(name);
    }
    final sz = _child(rPr, 'sz');
    if (sz != null) {
      final v = double.tryParse(_attr(sz, 'val') ?? '');
      if (v != null) attrs['size'] = (v / 2).toString();
    }
    final color = _child(rPr, 'color');
    if (color != null) {
      final v = _attr(color, 'val');
      if (v != null && v != 'auto') attrs['color'] = '#$v';
    }
    final hl = _child(rPr, 'highlight');
    if (hl != null) {
      final v = _attr(hl, 'val');
      final argb = v == null ? null : highlightArgb(v);
      if (argb != null) attrs['background'] = argbToHex(argb);
    }
    final va = _child(rPr, 'vertAlign');
    if (va != null) {
      final v = _attr(va, 'val');
      if (v == 'superscript') attrs['script'] = 'super';
      if (v == 'subscript') attrs['script'] = 'sub';
    }
    final rStyle = _child(rPr, 'rStyle');
    if (rStyle != null) {
      final v = _attr(rStyle, 'val');
      if (v != null) attrs['cstyle'] = v;
    }
  }
  for (final node in rEl.childElements) {
    switch (node.name.local) {
      case 't':
        if (node.innerText.isNotEmpty)
          runs.add(KRun(node.innerText, Map.of(attrs)));
        break;
      case 'tab':
        runs.add(KRun('\t', Map.of(attrs)));
        break;
      case 'br':
        if (_attr(node, 'type') != 'page') runs.add(KRun('\n', Map.of(attrs)));
        break;
      case 'footnoteReference':
        final id = int.tryParse(_attr(node, 'id') ?? '');
        if (id != null) {
          final ord = nextOrdinal();
          final a = Map<String, dynamic>.of(attrs);
          a['fnote'] = id;
          runs.add(KRun(superscriptNum(ord), a));
        }
        break;
    }
  }
}

String _docxToFamily(String docxName) {
  const known = {
    'Times New Roman': 'Tinos',
    'Georgia': 'Gelasio',
    'Garamond': 'EB Garamond',
    'Cambria': 'Caladea',
    'Calibri': 'Carlito',
    'Jameel Noori Nastaleeq': 'Jameel Noori Nastaleeq',
    'Noto Nastaliq Urdu': 'Noto Nastaliq Urdu',
    'Amiri': 'Amiri',
    'Amiri Quran': 'Amiri Quran',
    'Noto Naskh Arabic': 'Noto Naskh Arabic',
    'KFGQPC Arabic Symbols 01': 'KFGQPC Arabic Symbols 01',
  };
  return known[docxName] ?? docxName;
}

void _parseSectPr(XmlElement sect, PageSetup ps) {
  final pgSz = _child(sect, 'pgSz');
  if (pgSz != null) {
    final w = double.tryParse(_attr(pgSz, 'w') ?? '');
    final h = double.tryParse(_attr(pgSz, 'h') ?? '');
    if (w != null && h != null) {
      ps.pageWidthMm = w / 56.6929;
      ps.pageHeightMm = h / 56.6929;
      ps.landscape = _attr(pgSz, 'orient') == 'landscape' ||
          ps.pageWidthMm > ps.pageHeightMm;
      if (ps.landscape && ps.pageWidthMm < ps.pageHeightMm) {
        final t = ps.pageWidthMm;
        ps.pageWidthMm = ps.pageHeightMm;
        ps.pageHeightMm = t;
      }
    }
  }
  final mar = _child(sect, 'pgMar');
  if (mar != null) {
    double m(String a, double d) =>
        (double.tryParse(_attr(mar, a) ?? '') ?? d * 56.6929) / 56.6929;
    ps.marginTopMm = m('top', 25.4);
    ps.marginBottomMm = m('bottom', 25.4);
    ps.marginLeftMm = m('left', 25.4);
    ps.marginRightMm = m('right', 25.4);
  }
  final pgB = _child(sect, 'pgBorders');
  if (pgB != null) {
    ps.pageBorderOffsetFrom = _attr(pgB, 'offsetFrom') ?? 'page';
    ps.pageBorder = _parseBorder(_child(pgB, 'top'));
  }
}

List<KStyle> _parseStyles(String xmlText) {
  final doc = XmlDocument.parse(xmlText);
  final out = <KStyle>[];
  final builtinIds = builtinStyles().map((s) => s.id).toSet();
  for (final st in doc.descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == 'style')) {
    final id = _attr(st, 'styleId');
    if (id == null) continue;
    final type = _attr(st, 'type') ?? 'paragraph';
    final nameEl = _child(st, 'name');
    final name = nameEl == null ? id : (_attr(nameEl, 'val') ?? id);
    final s = KStyle(
      id: id,
      name: name,
      type: type == 'character' ? 'character' : 'paragraph',
      builtIn: builtinIds.contains(id),
    );
    final based = _child(st, 'basedOn');
    if (based != null) s.basedOnId = _attr(based, 'val') ?? 'Normal';
    final pPr = _child(st, 'pPr');
    if (pPr != null) {
      s.rtl = _child(pPr, 'bidi') != null;
      final jc = _child(pPr, 'jc');
      if (jc != null) {
        final v = _attr(jc, 'val');
        s.align = v == 'center'
            ? 'center'
            : v == 'right'
                ? 'end'
                : v == 'both'
                    ? 'justify'
                    : 'start';
      }
      final sp = _child(pPr, 'spacing');
      if (sp != null) {
        s.spaceBeforePt =
            (double.tryParse(_attr(sp, 'before') ?? '0') ?? 0) / 20;
        s.spaceAfterPt =
            (double.tryParse(_attr(sp, 'after') ?? '120') ?? 120) / 20;
        final line = double.tryParse(_attr(sp, 'line') ?? '');
        if (line != null) s.lineSpacing = line / 240;
      }
      s.borders = _parseEdges(_child(pPr, 'pBdr'), between: true);
      final shd = _child(pPr, 'shd');
      if (shd != null) {
        final fill = _attr(shd, 'fill');
        if (fill != null && fill != 'auto') s.shading = hexToArgb(fill);
      }
    }
    final rPr = _child(st, 'rPr');
    if (rPr != null) {
      if (_child(rPr, 'b') != null) s.bold = true;
      if (_child(rPr, 'i') != null) s.italic = true;
      if (_child(rPr, 'u') != null) s.underline = true;
      final fonts = _child(rPr, 'rFonts');
      if (fonts != null) {
        final n = _attr(fonts, 'cs') ?? _attr(fonts, 'ascii');
        if (n != null) s.fontFamily = _docxToFamily(n);
      }
      final sz = _child(rPr, 'sz');
      if (sz != null) {
        final v = double.tryParse(_attr(sz, 'val') ?? '');
        if (v != null) s.fontSize = v / 2;
      }
      final color = _child(rPr, 'color');
      if (color != null) {
        final v = _attr(color, 'val');
        if (v != null && v != 'auto') s.color = hexToArgb(v);
      }
      final hl = _child(rPr, 'highlight');
      if (hl != null) {
        final v = _attr(hl, 'val');
        if (v != null) s.highlight = highlightArgb(v);
      }
    }
    out.add(s);
  }
  // غائب built-ins شامل کریں تاکہ ایڈیٹر ہمیشہ مکمل فہرست دکھائے
  final ids = out.map((s) => s.id).toSet();
  for (final b in builtinStyles()) {
    if (!ids.contains(b.id)) out.add(b);
  }
  return out;
}
