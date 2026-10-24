// فونٹ رجسٹری جانچ: ہر بنڈل اندراج کی فائل موجود ہو، نام فقط اندراجات کا
// متبادل رجسٹرڈ ہو، اور DOCX نام کی دونوں طرف تبدیلی درست ہو۔
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibneabbas_word/core/font_catalog.dart';

void main() {
  test('bundled font files exist on disk', () {
    final seenAssets = <String>{};
    for (final f in FontCatalog.all) {
      if (f.asset != null) seenAssets.add(f.asset!);
      if (!f.nameOnly) {
        expect(f.asset, isNotNull, reason: '${f.name} bundled but no asset');
        expect(File(f.asset!).existsSync(), isTrue,
            reason: '${f.name} -> ${f.asset} missing');
      }
      // display family must be registered in pubspec.yaml
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('family: ${f.display}'), isTrue,
          reason: '${f.name} display ${f.display} not registered in pubspec');
    }
    expect(seenAssets.length, greaterThan(20));
  });

  test('46 user-list names are all registered', () {
    const userList = [
      // اردو
      'Jameel Noori Nastaleeq', 'Noto Nastaliq Urdu', 'Alvi Nastaleeq',
      'Faiz Lahori Nastaleeq', 'Nafees Nastaleeq', 'Mehr Nastaliq Web',
      'Urdu Typesetting', 'Nafees Web Naskh',
      // عربی
      'Amiri', 'Traditional Arabic', 'Arabic Typesetting', 'Simplified Arabic',
      'Scheherazade New', 'Noto Naskh Arabic', 'Noto Sans Arabic',
      'Sakkal Majalla', 'Adobe Arabic', 'Lateef',
      // قرآن
      'KFGQPC Uthmanic Script HAFS', 'Amiri Quran', 'Uthman Taha Naskh',
      'IndoPak Quranic Script', 'KFGQPC Uthmanic Script',
      // انگریزی
      'Times New Roman', 'Arial', 'Calibri', 'Cambria', 'Garamond', 'Georgia',
      'Palatino Linotype', 'Book Antiqua', 'Aptos', 'Helvetica',
      // فارسی
      'B Nazanin', 'B Mitra', 'B Lotus', 'B Zar', 'Vazirmatn', 'IranNastaliq',
      // نقلِ صوت
      'Gentium Plus', 'Charis SIL', 'Doulos SIL', 'Brill', 'Cambria Math',
      'STIX Two Math',
    ];
    // صارف کی فہرست میں 46 اندراجات ہیں؛ Noto Naskh Arabic دو زمروں میں
    // دہرایا گیا ہے، اس لیے منفرد نام 45 ہیں
    expect(userList.length, 45);
    expect(FontCatalog.byGroup('persian').map((f) => f.name),
        contains('Noto Naskh Arabic'));
    for (final n in userList) {
      expect(FontCatalog.entryFor(n), isNotNull, reason: '$n not registered');
      expect(FontCatalog.docxNameFor(n), n);
      expect(FontCatalog.familyForDocx(n), n);
    }
    // ہر زمرہ خالی نہ ہو
    for (final c in FontCatalog.categories) {
      expect(FontCatalog.byGroup(c), isNotEmpty, reason: 'category $c empty');
    }
    // legacy فائل family → مستند نام
    expect(FontCatalog.docxNameFor('Tinos'), 'Times New Roman');
    expect(FontCatalog.docxNameFor('Mehr Nastaliq'), 'Mehr Nastaliq Web');
    expect(FontCatalog.displayFamilyFor('Times New Roman'), 'Tinos');
    expect(FontCatalog.displayFamilyFor('KFGQPC Uthmanic Script HAFS'),
        'KFGQPC Uthmanic Script HAFS');
  });
}
