// حقیقی OOXML (DOCX) مصنف — native DocxWriter کی ساخت کی عکاسی + جداول،
// تصاویر، بارڈرز (pBdr/pgBorders/tblBorders/tcBorders) اور genuine styles.xml۔
// خالص Dart (dart:io صرف امیج سائز/بائٹس کے لیے map کے ذریعے وصول کرتا ہے) —
// compute() isolate میں چلنے کے قابل۔
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../model/model.dart';
import '../model/styles.dart';
import 'delta_convert.dart';

String xmlEsc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

const double _mmTwips = 56.6929;
int _ptHalf(double pt) => (pt * 2).round();
int _ptTwips(double pt) => (pt * 20).round();
int _borderSz(double pt) => (pt * 8).round().clamp(2, 48);

String _borderEl(String name, BorderSpec b) {
  if (b.isNone)
    return '<w:$name w:val="none" w:sz="0" w:space="0" w:color="auto"/>';
  return '<w:$name w:val="${b.style == 'thick' ? 'single' : b.style}" '
      'w:sz="${b.style == 'thick' ? _borderSz(b.widthPt < 1.5 ? 1.5 : b.widthPt) : _borderSz(b.widthPt)}" '
      'w:space="${b.spacePt.round()}" w:color="${argbToHexNoHash(b.color)}"/>';
}

String _edgesXml(String wrapper, EdgeBorders e, {bool includeBetween = false}) {
  final sb = StringBuffer('<w:$wrapper>');
  if (e.top != null) sb.write(_borderEl('top', e.top!));
  if (e.left != null) sb.write(_borderEl('left', e.left!));
  if (e.bottom != null) sb.write(_borderEl('bottom', e.bottom!));
  if (e.right != null) sb.write(_borderEl('right', e.right!));
  if (includeBetween && e.between != null)
    sb.write(_borderEl('between', e.between!));
  sb.write('</w:$wrapper>');
  return sb.toString();
}

class DocxBuildResult {
  final Uint8List bytes;
  final List<String> warnings;
  DocxBuildResult(this.bytes, this.warnings);
}

/// [docJson] KDoc.toJson()؛ [media] relPath → bytes (تصاویر)
DocxBuildResult buildDocx(
    Map<String, dynamic> docJson, Map<String, List<int>> media) {
  final doc = KDoc.fromJson(docJson);
  final warnings = <String>[];
  final styles = doc.styles.map((s) => KStyle.fromJson(s)).toList();
  if (styles.isEmpty) styles.addAll(builtinStyles());
  final styleById = <String, KStyle>{for (final s in styles) s.id: s};

  // فٹ نوٹ renumber (ظہور کی ترتیب سے، 2 سے آغاز)
  final fnOrder = <int, int>{};
  var fnNext = 2;
  int mapFn(int oldId) {
    if (!fnOrder.containsKey(oldId)) fnOrder[oldId] = fnNext++;
    return fnOrder[oldId]!;
  }

  // نمبرنگ: ہر مسلسل لسٹ کے لیے الگ numId (Word میں ہر لسٹ 1 سے)
  final nums = <Map<String, dynamic>>[]; // {abstract: 0 bullet|1 decimal}
  var inList = false;
  int currentNumId = 0;

  final rels = StringBuffer();
  var relId = 1;
  final relIds = <String, int>{};
  int nextRel() => relId++;
  final stylesRel = nextRel();
  final numberingRel = nextRel();
  int? footnotesRel;
  final hasFootnotes = doc.footnotes.isNotEmpty;
  if (hasFootnotes) footnotesRel = nextRel();
  int? headerRel, footerRel;
  if (doc.pageSetup.headerText.isNotEmpty) headerRel = nextRel();
  if (doc.pageSetup.footerText.isNotEmpty || doc.pageSetup.pageNumbers) {
    footerRel = nextRel();
  }
  // تصاویر کے rels بلاک لوپ میں شامل ہوں گے
  final mediaParts = <String, List<int>>{};
  var mediaCount = 0;

  String runXml(KRun r) {
    if (r.fnote != null) {
      final newId = mapFn(r.fnote!);
      return '<w:r><w:rPr><w:vertAlign w:val="superscript"/></w:rPr>'
          '<w:footnoteReference w:id="$newId"/></w:r>';
    }
    final rp = StringBuffer('<w:rPr>');
    if (r.cstyle != null) rp.write('<w:rStyle w:val="${xmlEsc(r.cstyle!)}"/>');
    final font = docxFont(r.font);
    rp.write(
        '<w:rFonts w:ascii="${xmlEsc(font)}" w:hAnsi="${xmlEsc(font)}" w:cs="${xmlEsc(font)}"/>');
    if (r.bold) rp.write('<w:b/><w:bCs/>');
    if (r.italic) rp.write('<w:i/><w:iCs/>');
    if (r.underline) rp.write('<w:u w:val="single"/>');
    if (r.strike) rp.write('<w:strike/>');
    final sz = r.size;
    if (sz != null) {
      rp.write(
          '<w:sz w:val="${_ptHalf(sz)}"/><w:szCs w:val="${_ptHalf(sz)}"/>');
    }
    if (r.color != null) {
      rp.write('<w:color w:val="${argbToHexNoHash(hexToArgb(r.color!))}"/>');
    }
    if (r.background != null) {
      final hl = nearestHighlightName(hexToArgb(r.background!));
      if (hl != null) rp.write('<w:highlight w:val="$hl"/>');
    }
    if (r.script == 'super') rp.write('<w:vertAlign w:val="superscript"/>');
    if (r.script == 'sub') rp.write('<w:vertAlign w:val="subscript"/>');
    rp.write('</w:rPr>');
    // متن: \n → w:br، \t → w:tab
    final parts = r.text.split('\n');
    final sb = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) sb.write('<w:r>$rp<w:br/></w:r>');
      final seg = parts[i];
      if (seg.isEmpty) continue;
      final segs = seg.split('\t');
      for (var k = 0; k < segs.length; k++) {
        if (k > 0) sb.write('<w:r>$rp<w:tab/></w:r>');
        if (segs[k].isNotEmpty) {
          sb.write(
              '<w:r>$rp<w:t xml:space="preserve">${xmlEsc(segs[k])}</w:t></w:r>');
        }
      }
    }
    return sb.toString();
  }

  String paraXml(ParaBlock block, {bool inCell = false}) {
    final lines = deltaToLines(block.delta);
    final out = StringBuffer();
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      final isFirst = li == 0;
      final ppr = StringBuffer('<w:pPr>');
      final style = styleById[block.styleId];
      if (isFirst) {
        if (block.styleId != 'Normal' || style != null) {
          ppr.write('<w:pStyle w:val="${xmlEsc(block.styleId)}"/>');
        }
        if (block.pageBreakBefore) ppr.write('<w:pageBreakBefore/>');
        if (block.borders != null && !block.borders!.isEmpty) {
          ppr.write(_edgesXml('pBdr', block.borders!, includeBetween: true));
        }
        if (block.shading != null) {
          ppr.write(
              '<w:shd w:val="clear" w:color="auto" w:fill="${argbToHexNoHash(block.shading!)}"/>');
        }
      }
      // نمبرنگ
      if (line.list != null) {
        if (!inList) {
          currentNumId = nums.length + 1;
          nums.add({'abstract': line.list == 'ordered' ? 1 : 0});
          inList = true;
        }
        ppr.write('<w:numPr><w:ilvl w:val="${line.indent}"/>'
            '<w:numId w:val="$currentNumId"/></w:numPr>');
      } else if (!inCell) {
        inList = false;
      }
      if (block.rtl || line.rtlLine) ppr.write('<w:bidi/>');
      // سیدھ
      final align = line.align;
      String? jc;
      if (align == 'center') jc = 'center';
      if (align == 'right') jc = 'right';
      if (align == 'justify') jc = 'both';
      if (jc != null) ppr.write('<w:jc w:val="$jc"/>');
      // فاصلے
      final lh = line.lineHeight ?? style?.lineSpacing;
      final sb_ = isFirst ? block.spaceBeforePt : 0.0;
      final sa_ = isFirst ? block.spaceAfterPt : 0.0;
      ppr.write(
          '<w:spacing w:before="${_ptTwips(sb_)}" w:after="${_ptTwips(sa_)}"'
          '${lh != null ? ' w:line="${(lh * 240).round()}" w:lineRule="auto"' : ''}/>');
      final indAttrs = <String>[];
      if (line.indent > 0 && line.list == null) {
        indAttrs.add(block.rtl
            ? 'w:right="${line.indent * 720}"'
            : 'w:left="${line.indent * 720}"');
      }
      if (isFirst && block.firstLineIndentPt > 0) {
        // پہلی سطر کا فاصلہ — Word کا اصل first-line indent
        indAttrs.add(
            'w:firstLine="${(block.firstLineIndentPt * 20).round()}"');
      }
      if (indAttrs.isNotEmpty) {
        ppr.write('<w:ind ${indAttrs.join(' ')}/>');
      }
      ppr.write('</w:pPr>');
      out.write('<w:p>$ppr');
      for (final r in line.runs) {
        out.write(runXml(r));
      }
      out.write('</w:p>');
    }
    return out.toString();
  }

  // ---- body ----
  final body = StringBuffer();
  for (final block in doc.blocks) {
    if (block is ParaBlock) {
      body.write(paraXml(block));
    } else if (block is TableBlock) {
      inList = false;
      body.write(_tableXml(block, paraXml));
    } else if (block is ImageBlock) {
      inList = false;
      final bytes = media[block.relPath];
      if (bytes == null) {
        warnings.add('تصویر نہیں ملی: ${block.relPath}');
        continue;
      }
      mediaCount++;
      final ext = block.relPath.split('.').last.toLowerCase();
      final partName = 'media/image$mediaCount.$ext';
      mediaParts[partName] = bytes;
      final rid = nextRel();
      relIds[partName] = rid;
      final size = imageSize(bytes);
      const emuPerMm = 36000;
      final contentMm = doc.pageSetup.pageWidthMm -
          doc.pageSetup.marginLeftMm -
          doc.pageSetup.marginRightMm;
      final wEmu = (contentMm * emuPerMm * block.widthFrac).round();
      final hEmu = size != null && size[0] > 0
          ? (wEmu * size[1] / size[0]).round()
          : (wEmu * 0.75).round();
      body.write('<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:drawing>'
          '<wp:inline distT="0" distB="0" distL="0" distR="0">'
          '<wp:extent cx="$wEmu" cy="$hEmu"/>'
          '<wp:docPr id="$mediaCount" name="Image $mediaCount"/>'
          '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
          '<pic:pic><pic:nvPicPr><pic:cNvPr id="$mediaCount" name="image$mediaCount.$ext"/><pic:cNvPicPr/></pic:nvPicPr>'
          '<pic:blipFill><a:blip r:embed="rId$rid"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
          '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$wEmu" cy="$hEmu"/></a:xfrm>'
          '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'
          '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>');
      if (block.caption.isNotEmpty) {
        final cap = ParaBlock([
          {'insert': block.caption},
          {
            'insert': '\n',
            'attributes': {'align': 'center'}
          }
        ])
          ..styleId = 'Caption'
          ..rtl = true;
        body.write(paraXml(cap));
      }
    }
  }

  // ---- sectPr ----
  final ps = doc.pageSetup;
  final pw = (ps.landscape ? ps.pageHeightMm : ps.pageWidthMm) * _mmTwips;
  final ph = (ps.landscape ? ps.pageWidthMm : ps.pageHeightMm) * _mmTwips;
  final sect = StringBuffer('<w:sectPr>');
  if (headerRel != null)
    sect.write('<w:headerReference w:type="default" r:id="rId$headerRel"/>');
  if (footerRel != null)
    sect.write('<w:footerReference w:type="default" r:id="rId$footerRel"/>');
  sect.write(
      '<w:pgSz w:w="${pw.round()}" w:h="${ph.round()}" w:orient="${ps.landscape ? 'landscape' : 'portrait'}"/>');
  sect.write('<w:pgMar w:top="${(ps.marginTopMm * _mmTwips).round()}" '
      'w:right="${(ps.marginRightMm * _mmTwips).round()}" '
      'w:bottom="${(ps.marginBottomMm * _mmTwips).round()}" '
      'w:left="${(ps.marginLeftMm * _mmTwips).round()}" w:header="720" w:footer="720" w:gutter="0"/>');
  if (ps.pageBorder != null && !ps.pageBorder!.isNone) {
    sect.write('<w:pgBorders w:offsetFrom="${ps.pageBorderOffsetFrom}">');
    sect.write(_borderEl('top', ps.pageBorder!));
    sect.write(_borderEl('left', ps.pageBorder!));
    sect.write(_borderEl('bottom', ps.pageBorder!));
    sect.write(_borderEl('right', ps.pageBorder!));
    sect.write('</w:pgBorders>');
  }
  sect.write('</w:sectPr>');

  final documentXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<w:body>$body$sect</w:body></w:document>';

  // ---- footnotes.xml ----
  String? footnotesXml;
  if (hasFootnotes) {
    final sb = StringBuffer(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:footnote w:type="separator" w:id="0"><w:p><w:r><w:separator/></w:r></w:p></w:footnote>'
        '<w:footnote w:type="continuationSeparator" w:id="1"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:footnote>');
    // ترتیب: نئے ids کے مطابق
    final byNew = <int, KFootnote>{};
    fnOrder.forEach((oldId, newId) {
      final fn = doc.footnotes
          .where((f) => f.id == oldId)
          .cast<KFootnote?>()
          .firstWhere((_) => true, orElse: () => null);
      if (fn != null) byNew[newId] = fn;
    });
    // حوالہ نہ پائے گئے حواشی بھی آخر میں شامل (نقصان نہیں)
    for (final fn in doc.footnotes) {
      if (!fnOrder.containsKey(fn.id)) {
        final nid = fnNext++;
        byNew[nid] = fn;
      }
    }
    final keys = byNew.keys.toList()..sort();
    for (final nid in keys) {
      final fn = byNew[nid]!;
      sb.write(
          '<w:footnote w:id="$nid"><w:p><w:pPr><w:pStyle w:val="FootnoteText"/>'
          '<w:bidi/></w:pPr>'
          '<w:r><w:rPr><w:vertAlign w:val="superscript"/></w:rPr><w:t xml:space="preserve"> </w:t></w:r>'
          '<w:r><w:t xml:space="preserve">${xmlEsc(fn.text)}</w:t></w:r></w:p></w:footnote>');
    }
    sb.write('</w:footnotes>');
    footnotesXml = sb.toString();
  }

  // ---- numbering.xml ----
  final numberingXml = _numberingXml(nums);

  // ---- styles.xml ----
  final stylesXml = _stylesXml(styles);

  // ---- header/footer ----
  String? headerXml, footerXml;
  if (headerRel != null) {
    headerXml = _hdrFtrXml('hdr', ps.headerText, rtl: true);
  }
  if (footerRel != null) {
    footerXml =
        _hdrFtrXml('ftr', ps.footerText, rtl: true, pageNumber: ps.pageNumbers);
  }

  // ---- rels ----
  rels.write(
      '<Relationship Id="rId$stylesRel" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>');
  rels.write(
      '<Relationship Id="rId$numberingRel" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>');
  if (footnotesRel != null) {
    rels.write(
        '<Relationship Id="rId$footnotesRel" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes" Target="footnotes.xml"/>');
  }
  if (headerRel != null) {
    rels.write(
        '<Relationship Id="rId$headerRel" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>');
  }
  if (footerRel != null) {
    rels.write(
        '<Relationship Id="rId$footerRel" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>');
  }
  relIds.forEach((part, rid) {
    rels.write(
        '<Relationship Id="rId$rid" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="$part"/>');
  });

  var contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Default Extension="png" ContentType="image/png"/>'
      '<Default Extension="jpeg" ContentType="image/jpeg"/>'
      '<Default Extension="jpg" ContentType="image/jpeg"/>'
      '<Default Extension="gif" ContentType="image/gif"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>';
  if (footnotesXml != null) {
    contentTypes +=
        '<Override PartName="/word/footnotes.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml"/>';
  }
  if (headerXml != null) {
    contentTypes +=
        '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>';
  }
  if (footerXml != null) {
    contentTypes +=
        '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>';
  }
  contentTypes += '</Types>';

  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml', contentTypes);
  add(
      '_rels/.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
          '</Relationships>');
  add('word/document.xml', documentXml);
  add(
      'word/_rels/document.xml.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">$rels</Relationships>');
  add('word/styles.xml', stylesXml);
  add('word/numbering.xml', numberingXml);
  if (footnotesXml != null) add('word/footnotes.xml', footnotesXml);
  if (headerXml != null) add('word/header1.xml', headerXml);
  if (footerXml != null) add('word/footer1.xml', footerXml);
  mediaParts.forEach((name, bytes) {
    archive.addFile(ArchiveFile('word/$name', bytes.length, bytes));
  });

  final zipBytes = ZipEncoder().encode(archive);
  return DocxBuildResult(Uint8List.fromList(zipBytes!), warnings);
}

/// تصویر کے ابعاد (PNG/JPEG/GIF) — [width, height] یا null
List<int>? imageSize(List<int> b) {
  if (b.length > 24 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47) {
    final w = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
    final h = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
    return [w, h];
  }
  if (b.length > 10 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) {
    return [b[6] | (b[7] << 8), b[8] | (b[9] << 8)];
  }
  if (b.length > 2 && b[0] == 0xFF && b[1] == 0xD8) {
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = b[i + 1];
      if (marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC) {
        final h = (b[i + 5] << 8) | b[i + 6];
        final w = (b[i + 7] << 8) | b[i + 8];
        return [w, h];
      }
      final len = (b[i + 2] << 8) | b[i + 3];
      i += 2 + len;
    }
  }
  return null;
}

String _tableXml(
    TableBlock t, String Function(ParaBlock, {bool inCell}) paraXml) {
  final sb = StringBuffer('<w:tbl><w:tblPr>');
  sb.write('<w:tblW w:w="5000" w:type="pct"/>');
  // بارڈرز
  EdgeBorders borders;
  switch (t.borderPreset) {
    case 'none':
      borders = EdgeBorders(
        top: BorderSpec(style: 'none'),
        bottom: BorderSpec(style: 'none'),
        left: BorderSpec(style: 'none'),
        right: BorderSpec(style: 'none'),
      );
      sb.write(_tblBordersXml(borders, inside: BorderSpec(style: 'none')));
      break;
    case 'box':
      sb.write(_tblBordersXml(EdgeBorders.box(BorderSpec()), inside: null));
      break;
    case 'internal':
      sb.write(_tblBordersXml(
          EdgeBorders(
              top: BorderSpec(style: 'none'),
              bottom: BorderSpec(style: 'none'),
              left: BorderSpec(style: 'none'),
              right: BorderSpec(style: 'none')),
          inside: BorderSpec()));
      break;
    case 'custom':
      sb.write(_tblBordersXml(t.customBorders ?? EdgeBorders.box(BorderSpec()),
          inside: BorderSpec()));
      break;
    default: // grid
      sb.write(
          _tblBordersXml(EdgeBorders.box(BorderSpec()), inside: BorderSpec()));
  }
  sb.write('<w:tblLayout w:type="fixed"/></w:tblPr>');
  final cols = t.cols;
  if (cols > 0) {
    sb.write('<w:tblGrid>');
    for (var i = 0; i < cols; i++) {
      sb.write('<w:gridCol w:w="${(9360 / cols).round()}"/>');
    }
    sb.write('</w:tblGrid>');
  }
  for (var r = 0; r < t.rows.length; r++) {
    final isHeader = t.headerRow && r == 0;
    sb.write('<w:tr>');
    if (isHeader) sb.write('<w:trPr><w:tblHeader/></w:trPr>');
    for (final cell in t.rows[r]) {
      sb.write('<w:tc><w:tcPr>');
      sb.write(
          '<w:tcW w:w="${cols > 0 ? (9360 / cols).round() : 3000}" w:type="dxa"/>');
      final shd = cell.shading ?? (isHeader ? t.headerShading : null);
      if (shd != null) {
        sb.write(
            '<w:shd w:val="clear" w:color="auto" w:fill="${argbToHexNoHash(shd)}"/>');
      }
      if (cell.borderAll != null) {
        sb.write(_edgesXml('tcBorders', EdgeBorders.box(cell.borderAll!)));
      }
      sb.write('</w:tcPr>');
      // سیل متن — ہر سطر الگ پیراگراف
      final lines = cell.text.split('\n');
      if (lines.isEmpty) lines.add('');
      for (final ln in lines) {
        final attrs = <String, dynamic>{};
        if (cell.align == 'center') attrs['align'] = 'center';
        if (cell.align == 'end') attrs['align'] = 'right';
        final pb = ParaBlock([
          {
            'insert': ln,
            if (cell.bold) 'attributes': {'bold': true},
          },
          {
            'insert': '\n',
            if (attrs.isNotEmpty) 'attributes': attrs,
          }
        ])
          ..spaceAfterPt = 2
          ..spaceBeforePt = 2;
        sb.write(paraXml(pb, inCell: true));
      }
      sb.write('</w:tc>');
    }
    sb.write('</w:tr>');
  }
  sb.write('</w:tbl>');
  return sb.toString();
}

String _tblBordersXml(EdgeBorders e, {BorderSpec? inside}) {
  final sb = StringBuffer('<w:tblBorders>');
  BorderSpec d = BorderSpec();
  sb.write(_borderEl('top', e.top ?? d));
  sb.write(_borderEl('left', e.left ?? d));
  sb.write(_borderEl('bottom', e.bottom ?? d));
  sb.write(_borderEl('right', e.right ?? d));
  if (inside != null) {
    sb.write(_borderEl('insideH', inside));
    sb.write(_borderEl('insideV', inside));
  }
  sb.write('</w:tblBorders>');
  return sb.toString();
}

String _numberingXml(List<Map<String, dynamic>> nums) {
  final sb = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
  // abstract 0 = bullet, 1 = decimal
  for (var a = 0; a < 2; a++) {
    sb.write('<w:abstractNum w:abstractNumId="$a">');
    for (var lvl = 0; lvl < 3; lvl++) {
      sb.write('<w:lvl w:ilvl="$lvl">'
          '<w:start w:val="1"/>'
          '<w:numFmt w:val="${a == 0 ? 'bullet' : 'decimal'}"/>'
          '<w:lvlText w:val="${a == 0 ? '•' : '%1.'}"/>'
          '<w:lvlPicBulletId w:val="0"/>'
          '<w:pPr><w:ind w:left="${720 + lvl * 360}" w:hanging="360"/></w:pPr>'
          '</w:lvl>');
    }
    sb.write('</w:abstractNum>');
  }
  for (var i = 0; i < nums.length; i++) {
    sb.write(
        '<w:num w:numId="${i + 1}"><w:abstractNumId w:val="${nums[i]['abstract']}"/></w:num>');
  }
  sb.write('</w:numbering>');
  return sb.toString();
}

String _hdrFtrXml(String kind, String text,
    {required bool rtl, bool pageNumber = false}) {
  final sb = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:$kind xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:p><w:pPr>${rtl ? '<w:bidi/>' : ''}<w:jc w:val="center"/></w:pPr>');
  if (text.isNotEmpty) {
    sb.write('<w:r><w:t xml:space="preserve">${xmlEsc(text)}</w:t></w:r>');
  }
  if (pageNumber) {
    if (text.isNotEmpty)
      sb.write('<w:r><w:t xml:space="preserve"> — </w:t></w:r>');
    sb.write('<w:fldSimple w:instr=" PAGE "/>');
  }
  sb.write('</w:p></w:$kind>');
  return sb.toString();
}

String _stylesXml(List<KStyle> styles) {
  final sb = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
  sb.write('<w:docDefaults><w:rPrDefault><w:rPr>'
      '<w:rFonts w:ascii="Noto Nastaliq Urdu" w:hAnsi="Noto Nastaliq Urdu" w:cs="Noto Nastaliq Urdu"/>'
      '<w:sz w:val="28"/><w:szCs w:val="28"/>'
      '</w:rPr></w:rPrDefault>'
      '<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="384" w:lineRule="auto"/></w:pPr></w:pPrDefault>'
      '</w:docDefaults>');
  for (final s in styles) {
    final type = s.type == 'character' ? 'character' : 'paragraph';
    sb.write('<w:style w:type="$type" w:styleId="${xmlEsc(s.id)}">');
    sb.write(
        '<w:name w:val="${xmlEsc(s.name.replaceAll(RegExp(r'\s*\([^)]*\)'), ''))}"/>');
    if (s.basedOnId != s.id && s.id != 'Normal') {
      sb.write('<w:basedOn w:val="${xmlEsc(s.basedOnId)}"/>');
    }
    sb.write('<w:next w:val="Normal"/>');
    if (s.builtIn) sb.write('<w:qFormat/>');
    sb.write('<w:uiPriority w:val="${s.builtIn ? 1 : 10}"/>');
    if (s.type != 'character') {
      sb.write('<w:pPr>');
      if (s.rtl) sb.write('<w:bidi/>');
      final jc =
          {'center': 'center', 'end': 'right', 'justify': 'both'}[s.align];
      if (jc != null) sb.write('<w:jc w:val="$jc"/>');
      sb.write(
          '<w:spacing w:before="${_ptTwips(s.spaceBeforePt)}" w:after="${_ptTwips(s.spaceAfterPt)}" '
          'w:line="${(s.lineSpacing * 240).round()}" w:lineRule="auto"/>');
      if (s.indentLevel > 0) {
        sb.write(s.rtl
            ? '<w:ind w:right="${s.indentLevel * 720}"/>'
            : '<w:ind w:left="${s.indentLevel * 720}"/>');
      }
      if (s.borders != null && !s.borders!.isEmpty) {
        sb.write(_edgesXml('pBdr', s.borders!, includeBetween: true));
      }
      if (s.shading != null) {
        sb.write(
            '<w:shd w:val="clear" w:color="auto" w:fill="${argbToHexNoHash(s.shading!)}"/>');
      }
      sb.write('</w:pPr>');
    }
    sb.write('<w:rPr>');
    final font = docxFont(s.fontFamily);
    sb.write(
        '<w:rFonts w:ascii="${xmlEsc(font)}" w:hAnsi="${xmlEsc(font)}" w:cs="${xmlEsc(font)}"/>');
    if (s.bold) sb.write('<w:b/><w:bCs/>');
    if (s.italic) sb.write('<w:i/><w:iCs/>');
    if (s.underline) sb.write('<w:u w:val="single"/>');
    sb.write('<w:color w:val="${argbToHexNoHash(s.color)}"/>');
    sb.write(
        '<w:sz w:val="${_ptHalf(s.fontSize)}"/><w:szCs w:val="${_ptHalf(s.fontSize)}"/>');
    if (s.highlight != null) {
      final hl = nearestHighlightName(s.highlight!);
      if (hl != null) sb.write('<w:highlight w:val="$hl"/>');
    }
    sb.write('</w:rPr></w:style>');
  }
  sb.write('</w:styles>');
  return sb.toString();
}
