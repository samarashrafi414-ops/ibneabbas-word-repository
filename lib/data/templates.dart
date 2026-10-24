// دستاویز ٹیمپلیٹس: خالی، تحقیقی مقالہ، فتویٰ، خط — RTL اسٹائلز کے ساتھ
import '../model/model.dart';
import '../model/styles.dart';
import 'store.dart';

ParaBlock _para(String text,
    {String style = 'Normal', String? align, double? size, String? font}) {
  final attrs = <String, dynamic>{};
  if (size != null) attrs['size'] = size.toString();
  if (font != null) attrs['font'] = font;
  final lineAttrs = <String, dynamic>{'direction': 'rtl'};
  if (align != null) lineAttrs['align'] = align;
  return ParaBlock([
    {
      'insert': text,
      if (attrs.isNotEmpty) 'attributes': attrs,
    },
    {
      'insert': '\n',
      'attributes': lineAttrs,
    }
  ])
    ..styleId = style;
}

Future<KDoc> newDocument({
  required String title,
  required String template,
  List<KStyle>? templateStyles,
}) async {
  final styles = builtinStyles();
  if (templateStyles != null) {
    for (final ts in templateStyles) {
      final i = styles.indexWhere((s) => s.id == ts.id);
      if (i >= 0) {
        styles[i] = ts;
      } else {
        styles.add(ts);
      }
    }
  }
  final blocks = <KBlock>[];
  switch (template) {
    case 'research':
      blocks.addAll([
        _para('بسم الله الرحمن الرحيم', style: 'Title', font: 'Amiri Quran'),
        _para('مقالے کا عنوان', style: 'Title'),
        _para('محقق کا نام — ادارہ', style: 'Subtitle'),
        _para('مقدمہ', style: 'Heading1'),
        _para('یہاں مقدمہ لکھیں…'),
        _para('متن / ابواب', style: 'Heading1'),
        _para('اصل متن یہاں…'),
        _para('خاتمہ و نتائج', style: 'Heading1'),
        _para('نتائج یہاں…'),
        _para('مآخذ و مراجع', style: 'Heading1'),
        _para('حوالہ یہاں درج کریں…', style: 'Bibliography'),
      ]);
      break;
    case 'fatwa':
      blocks.addAll([
        _para('بسم الله الرحمن الرحيم', style: 'Title', font: 'Amiri Quran'),
        _para('نحمدہ و نصلی علی رسولہ الکریم', align: 'center'),
        _para('الجواب حامداً و مصلیاً', style: 'Heading2'),
        _para('سوال:', style: 'Heading3'),
        _para('سوال یہاں لکھیں…'),
        _para('جواب:', style: 'Heading3'),
        _para('جواب یہاں لکھیں…'),
        _para('واللہ تعالیٰ اعلم بالصواب', align: 'center'),
      ]);
      break;
    case 'phd':
      // پی ایچ ڈی مقالہ — صارف کی منظور شدہ فونٹ میز کے مطابق اسٹائلز
      void setFont(String id, String f) {
        final i = styles.indexWhere((x) => x.id == id);
        if (i >= 0) styles[i].fontFamily = f;
      }

      setFont('Normal', 'Jameel Noori Nastaleeq');
      setFont('Title', 'Jameel Noori Nastaleeq');
      setFont('Subtitle', 'Jameel Noori Nastaleeq');
      setFont('Heading1', 'Jameel Noori Nastaleeq');
      setFont('Heading2', 'Jameel Noori Nastaleeq');
      setFont('Heading3', 'Jameel Noori Nastaleeq');
      setFont('QuranAyah', 'KFGQPC Uthmanic Script HAFS');
      setFont('Quote', 'Amiri');
      setFont('FootnoteText', 'Amiri');
      setFont('Bibliography', 'Jameel Noori Nastaleeq');
      styles.add(KStyle(
        id: 'EnglishText',
        name: 'English Text',
        fontFamily: 'Times New Roman',
        fontSize: 12,
        rtl: false,
        align: 'start',
      ));
      styles.add(KStyle(
        id: 'Transliteration',
        name: 'Transliteration',
        type: 'character',
        fontFamily: 'Gentium Plus',
        fontSize: 12,
        italic: true,
      ));
      blocks.addAll([
        _para('بسم الله الرحمن الرحيم',
            style: 'Title', font: 'KFGQPC Uthmanic Script HAFS'),
        _para('مقالے کا عنوان', style: 'Title'),
        _para('محقق کا نام — جامعہ / ادارہ', style: 'Subtitle'),
        _para('تمہید', style: 'Heading1'),
        _para('یہاں تمہید لکھیں… (اردو متن: Jameel Noori Nastaleeq)'),
        _para('باب اول', style: 'Heading1'),
        _para('فصل اول', style: 'Heading2'),
        _para(
            'اصل متن یہاں… عربی عبارات و احادیث کے لیے Amiri، آیات کے لیے «قرآن سے آیت» بٹن (KFGQPC Uthmanic Script HAFS)، انگریزی متن کے لیے English Text اسٹائل اور نقلِ صوت کے لیے Transliteration کرکٹر اسٹائل استعمال کریں۔'),
        _para('خاتمہ و نتائج', style: 'Heading1'),
        _para('نتائج یہاں…'),
        _para('مآخذ و مراجع', style: 'Heading1'),
        _para('حوالہ یہاں درج کریں…', style: 'Bibliography'),
      ]);
      break;
    case 'letter':
      blocks.addAll([
        _para('بخدمت جناب …', style: 'Normal'),
        _para('السلام علیکم ورحمۃ اللہ وبرکاتہ', align: 'center'),
        _para('مودبانہ گزارش ہے کہ…'),
        _para('والسلام', align: 'end'),
        _para('نام / دستخط', align: 'end'),
      ]);
      break;
    default:
      blocks.add(ParaBlock([
        {'insert': '\n'}
      ]));
  }
  return KDoc(
    id: DocStore.newId(),
    title: title,
    blocks: blocks,
    footnotes: [],
    pageSetup: PageSetup(),
    styles: styles.map((s) => s.toJson()).toList(),
    usedCitations: [],
    modified: DateTime.now(),
  );
}
