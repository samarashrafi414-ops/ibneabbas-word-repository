// DOCX انجن کی جانچ: فارمیٹ شدہ پیراگراف + footnote + 3×3 جدول + تصویر والا
// نمونہ بنا کر unzip کر کے XML parts کی تصدیق — بشمول styles.xml اسٹائل
// round-trip اور بارڈرز (pBdr/pgBorders/tblBorders)۔
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibneabbas_word/docx/docx_reader.dart';
import 'package:ibneabbas_word/docx/docx_writer.dart';
import 'package:ibneabbas_word/model/model.dart';
import 'package:ibneabbas_word/model/styles.dart';

KDoc sampleDoc() {
  final styles = builtinStyles();
  // کسٹم اسٹائل — round-trip کے لیے
  styles.add(KStyle(
    id: 'MyResearch',
    name: 'میری تحقیقی طرز',
    basedOnId: 'Normal',
    fontFamily: 'Noto Naskh Arabic',
    fontSize: 15.5,
    bold: true,
    color: 0xFF7B1FA2,
    align: 'justify',
    lineSpacing: 1.9,
    borders: EdgeBorders(
        bottom: BorderSpec(style: 'double', widthPt: 1.5, color: 0xFF0A5C36)),
    inTemplate: true,
  ));
  final para = ParaBlock([
    {
      'insert': 'بسم الله الرحمن الرحيم ',
      'attributes': {'bold': true, 'font': 'Amiri Quran', 'size': '18'},
    },
    {
      'insert': 'حوالہ',
      'attributes': {'fnote': 2},
    },
    {
      'insert': '\n',
      'attributes': {'direction': 'rtl', 'align': 'center'},
    },
  ])
    ..styleId = 'MyResearch'
    ..borders = EdgeBorders(
      top: BorderSpec(style: 'single', widthPt: 1.0, color: 0xFF000000),
      between: BorderSpec(style: 'dotted', widthPt: 0.5, color: 0xFF808080),
    );
  final table = TableBlock([
    for (var r = 0; r < 3; r++)
      [
        for (var c = 0; c < 3; c++) TableCell()..text = 'خانہ ${r + 1}-$c',
      ],
  ]);
  final doc = KDoc(
    id: 'test1',
    title: 'نمونہ دستاویز',
    blocks: [
      para,
      table,
      ImageBlock('media/image1.png')
        ..widthFrac = 0.5
        ..caption = 'نمونہ تصویر',
    ],
    footnotes: [KFootnote(2, 'یہ نمونہ حاشیہ ہے — بخاری، کتاب العلم')],
    pageSetup: PageSetup()
      ..pageBorder =
          BorderSpec(style: 'single', widthPt: 2.25, color: 0xFF0A5C36)
      ..pageBorderOffsetFrom = 'page',
    styles: styles.map((s) => s.toJson()).toList(),
    usedCitations: [],
    modified: DateTime.now(),
  );
  return doc;
}

void main() {
  // 1×1 PNG
  final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

  test('DOCX بنائیں: parts + w:tbl + footnotes + media + borders', () {
    final doc = sampleDoc();
    final result = buildDocx(doc.toJson(), {'media/image1.png': png});
    expect(result.bytes.length, greaterThan(1000));
    final zip = ZipDecoder().decodeBytes(result.bytes);
    final names = zip.files.map((f) => f.name).toSet();
    expect(names, contains('[Content_Types].xml'));
    expect(names, contains('word/document.xml'));
    expect(names, contains('word/footnotes.xml'));
    expect(names, contains('word/styles.xml'));
    expect(names, contains('word/numbering.xml'));
    expect(names, contains('word/media/image1.png'));
    String textOf(String name) => utf8.decode(
        zip.files.firstWhere((f) => f.name == name).content as List<int>);
    final docXml = textOf('word/document.xml');
    expect(docXml, contains('<w:tbl>'));
    expect(docXml, contains('footnoteReference'));
    expect(docXml, contains('<w:pBdr>'));
    expect(docXml, contains('w:between'));
    expect(docXml, contains('<w:pgBorders'));
    expect(docXml, contains('offsetFrom="page"'));
    expect(docXml, contains('<w:tblBorders>'));
    final fnXml = textOf('word/footnotes.xml');
    expect(fnXml, contains('نمونہ حاشیہ'));
    final stXml = textOf('word/styles.xml');
    expect(stXml, contains('w:styleId="MyResearch"'));
    expect(stXml, contains('w:styleId="Heading1"'));
    expect(stXml, contains('<w:basedOn'));
    expect(stXml, contains('<w:qFormat/>'));
  });

  test('round-trip: درآمد پر اسٹائل + جدول + حاشیہ برقرار', () {
    final doc = sampleDoc();
    final result = buildDocx(doc.toJson(), {'media/image1.png': png});
    final imported = importDocx(result.bytes, 'test2', 'درآمد شدہ');
    final back = KDoc.fromJson(imported.docJson);
    final styles = back.styles.map((s) => KStyle.fromJson(s)).toList();
    final mine = styles.where((s) => s.id == 'MyResearch');
    expect(mine, isNotEmpty, reason: 'کسٹم اسٹائل درآمد پر موجود ہو');
    expect(mine.first.fontSize, 15.5);
    expect(mine.first.bold, isTrue);
    expect(back.footnotes.length, 1);
    expect(back.footnotes.first.text, contains('نمونہ حاشیہ'));
    expect(back.blocks.whereType<TableBlock>(), hasLength(1));
    expect(back.blocks.whereType<TableBlock>().first.rows.length, 3);
    expect(back.blocks.whereType<ImageBlock>(), hasLength(1));
    expect(back.pageSetup.pageBorder, isNotNull);
    expect(back.pageSetup.pageBorder!.widthPt, closeTo(2.25, 0.2));
  });

  test('امیج سائز شناخت', () {
    expect(imageSize(png), [1, 1]);
  });
}
