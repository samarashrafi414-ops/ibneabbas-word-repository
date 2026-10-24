// رموز و علامات — native ایپ کی 44 علامات + نئی قسم «رموزِ دینیہ»
//
// «رموزِ دینیہ» کی خطاطی اشکال صارف کے اپنے فونٹ KFGQPC Arabic Symbols 01
// (Symbols1_Ver02.otf) سے لی گئی ہیں۔ فونٹ اصلاً MS-Symbol (3,0) cmap رکھتا
// تھا؛ بنڈل شدہ نقل میں fontTools سے معیاری Unicode (3,1) cmap شامل کیا گیا
// ہے تاکہ Android/iOS/Flutter اسے رینڈر کر سکے — glyph اشکال عین اصل ہیں۔
// ہر کوڈ پوائنٹ کی شناخت فونٹ کو render کر کے بصری طور پر کی گئی (اندازہ نہیں)۔

import 'font_catalog.dart';

class SymbolItem {
  /// دکھایا جانے والا لیبل
  final String label;

  /// داخل کیا جانے والا متن (ایک یا دو حروف)
  final String insert;

  /// جس فونٹ میں رینڈر ہو (null = موجودہ فونٹ)
  final String? fontFamily;

  /// ﴿﴾ جیسی جوڑی: کرسر درمیان میں رکھا جائے
  final bool cursorBetween;
  const SymbolItem(this.label, this.insert,
      {this.fontFamily, this.cursorBetween = false});
}

class SymbolCategory {
  final String name;
  final List<SymbolItem> items;
  const SymbolCategory(this.name, this.items);
}

const String _sym = FontCatalog.symbols;
const String _amiri = FontCatalog.amiri;

String _pu(int cp) => String.fromCharCode(cp);

/// رموزِ دینیہ — إثراء المتون طرز کی مکمل فہرست
final List<SymbolItem> religiousSymbols = [
  // بسم الله — تین خطاطی اساليب (KFGQPC) + یونیکوڈ Ligature
  SymbolItem('بسم الله الرحمن الرحيم — اسلوب ١', _pu(0xF021), fontFamily: _sym),
  SymbolItem('بسم الله الرحمن الرحيم — اسلوب ٢', _pu(0xF022), fontFamily: _sym),
  SymbolItem('بسم الله الرحمن الرحيم — اسلوب ٣', _pu(0xF023), fontFamily: _sym),
  const SymbolItem('بسم الله الرحمن الرحيم — ﷽', '﷽', fontFamily: _amiri),
  // اللہ تعالیٰ کی تعظیم
  SymbolItem('عز وجل', _pu(0xF044), fontFamily: _sym),
  SymbolItem('سبحانه وتعالى', _pu(0xF045), fontFamily: _sym),
  SymbolItem('جل وعلا', _pu(0xF043), fontFamily: _sym),
  const SymbolItem('جل جلاله — ﷻ', 'ﷻ', fontFamily: _amiri),
  SymbolItem('جل جلاله', _pu(0xF042), fontFamily: _sym),
  SymbolItem('تبارك وتعالى', _pu(0xF046), fontFamily: _sym),
  SymbolItem('الله أكبر', _pu(0xF041), fontFamily: _sym),
  // درود و سلام
  const SymbolItem('صلى الله عليه وسلم — ﷺ', 'ﷺ', fontFamily: _amiri),
  SymbolItem('صلى الله عليه وسلم', _pu(0xF048), fontFamily: _sym),
  SymbolItem('صلى الله عليه وعلى آله وسلم', _pu(0xF047), fontFamily: _sym),
  SymbolItem('عليه الصلاة والسلام', _pu(0xF04F), fontFamily: _sym),
  SymbolItem('عليه السلام', _pu(0xF053), fontFamily: _sym),
  SymbolItem('عليها السلام', _pu(0xF050), fontFamily: _sym),
  SymbolItem('عليهما السلام', _pu(0xF052), fontFamily: _sym),
  SymbolItem('عليهم السلام', _pu(0xF051), fontFamily: _sym),
  // ترضّی
  SymbolItem('رضي الله عنه', _pu(0xF049), fontFamily: _sym),
  SymbolItem('رضي الله عنها', _pu(0xF04A), fontFamily: _sym),
  SymbolItem('رضي الله عنهما', _pu(0xF04C), fontFamily: _sym),
  SymbolItem('رضي الله عنهم', _pu(0xF04D), fontFamily: _sym),
  SymbolItem('رضي الله عنهن', _pu(0xF04B), fontFamily: _sym),
  // ترحّم
  SymbolItem('رحمه الله', _pu(0xF056), fontFamily: _sym),
  SymbolItem('رحمها الله', _pu(0xF054), fontFamily: _sym),
  SymbolItem('رحمهما الله', _pu(0xF057), fontFamily: _sym),
  SymbolItem('رحمهم الله', _pu(0xF058), fontFamily: _sym),
  SymbolItem('رحمهن الله', _pu(0xF055), fontFamily: _sym),
  // اضافی
  SymbolItem('صدق الله العظيم', _pu(0xF028), fontFamily: _sym),
  SymbolItem('قرآن كريم', _pu(0xF027), fontFamily: _sym),
  SymbolItem('محمد', _pu(0xF026), fontFamily: _sym),
  SymbolItem('الله', _pu(0xF025), fontFamily: _sym),
];

/// صغیر (inline مختصر) اشکال — سطر کے اندر چھوٹی صورت میں استعمال کے لیے
final List<SymbolItem> religiousSymbolsSmall = [
  SymbolItem('عز وجل — صغیر', _pu(0xF062), fontFamily: _sym),
  SymbolItem('سبحانه وتعالى — صغیر', _pu(0xF063), fontFamily: _sym),
  SymbolItem('جل جلاله — صغیر', _pu(0xF064), fontFamily: _sym),
  SymbolItem('جل وعلا — صغیر', _pu(0xF065), fontFamily: _sym),
  SymbolItem('صلى الله عليه وسلم — صغیر', _pu(0xF067), fontFamily: _sym),
  SymbolItem('عليه السلام — صغیر', _pu(0xF06E), fontFamily: _sym),
  SymbolItem('عليها السلام — صغیر', _pu(0xF06F), fontFamily: _sym),
  SymbolItem('عليهما السلام — صغیر', _pu(0xF071), fontFamily: _sym),
  SymbolItem('عليهم السلام — صغیر', _pu(0xF070), fontFamily: _sym),
  SymbolItem('رضي الله عنه — صغیر', _pu(0xF068), fontFamily: _sym),
  SymbolItem('رضي الله عنها — صغیر', _pu(0xF069), fontFamily: _sym),
  SymbolItem('رضي الله عنهما — صغیر', _pu(0xF06B), fontFamily: _sym),
  SymbolItem('رضي الله عنهم — صغیر', _pu(0xF06A), fontFamily: _sym),
  SymbolItem('رضي الله عنهن — صغیر', _pu(0xF06C), fontFamily: _sym),
  SymbolItem('رحمه الله — صغیر', _pu(0xF072), fontFamily: _sym),
  SymbolItem('رحمها الله — صغیر', _pu(0xF075), fontFamily: _sym),
  SymbolItem('رحمهما الله — صغیر', _pu(0xF074), fontFamily: _sym),
  SymbolItem('رحمهم الله — صغیر', _pu(0xF073), fontFamily: _sym),
  SymbolItem('رحمهن الله — صغیر', _pu(0xF076), fontFamily: _sym),
];

final List<SymbolCategory> symbolCategories = [
  SymbolCategory('رموزِ دینیہ', religiousSymbols),
  SymbolCategory('رموزِ دینیہ — صغیر', religiousSymbolsSmall),
  const SymbolCategory('دعائیہ کلمات', [
    SymbolItem('ﷺ', 'ﷺ'),
    SymbolItem('ﷻ', 'ﷻ'),
    SymbolItem('﷽', '﷽'),
    SymbolItem('رضي الله عنه (متن)', 'رضی اللہ عنہ'),
    SymbolItem('رحمه الله (متن)', 'رحمہ اللہ'),
    SymbolItem('عليه السلام (متن)', 'علیہ السلام'),
    SymbolItem('صلى الله عليه وسلم (متن)', 'صلی اللہ علیہ وسلم'),
  ]),
  const SymbolCategory('قرآنی علامات', [
    SymbolItem('﴿', '﴿﴾', cursorBetween: true),
    SymbolItem('۞', '۞'),
    SymbolItem('۩', '۩'),
    SymbolItem('۝', '۝'),
    SymbolItem('ۖ', 'ۖ'),
    SymbolItem('ۗ', 'ۗ'),
    SymbolItem('ۘ', 'ۘ'),
    SymbolItem('ۙ', 'ۙ'),
    SymbolItem('ۚ', 'ۚ'),
    SymbolItem('ۛ', 'ۛ'),
    SymbolItem('ۜ', 'ۜ'),
  ]),
  const SymbolCategory('اوقاف و رموز', [
    SymbolItem('،', '،'),
    SymbolItem('۔', '۔'),
    SymbolItem('؟', '؟'),
    SymbolItem(':', ':'),
    SymbolItem('؛', '؛'),
    SymbolItem('…', '…'),
    SymbolItem('–', '–'),
    SymbolItem('—', '—'),
    SymbolItem('(', '('),
    SymbolItem(')', ')'),
    SymbolItem('" "', '"'),
    SymbolItem('« »', '«»', cursorBetween: true),
    SymbolItem('[ ]', '[]', cursorBetween: true),
    SymbolItem('{ }', '{}', cursorBetween: true),
  ]),
  const SymbolCategory('آرائشی', [
    SymbolItem('❀', '❀'),
    SymbolItem('❁', '❁'),
    SymbolItem('✿', '✿'),
    SymbolItem('✦', '✦'),
    SymbolItem('★', '★'),
    SymbolItem('ﷲ', 'ﷲ'),
  ]),
];
