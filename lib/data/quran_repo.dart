// قرآن ڈیٹا — سست لوڈ (lazy): ایپ شروع ہونے پر کچھ نہیں؛ پہلی بار قرآن فیچر
// کھلنے پر assets/data/quran.json پڑھ کر cache۔ ماخذ: dawateislami.net/quran
// ترجمۂ کنزالایمان (native ایپ کا عین ڈیٹا: 114 سورتیں، 6236 آیات)۔
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Ayah {
  final int no;
  final String arabic;
  final String urdu;
  const Ayah(this.no, this.arabic, this.urdu);
}

class Surah {
  final int id;
  final String nameAr;
  final String nameEn;
  final int total;
  final List<Ayah> ayahs;
  const Surah(this.id, this.nameAr, this.nameEn, this.total, this.ayahs);
}

class QuranRepo {
  static List<Surah>? _cache;
  static Future<List<Surah>>? _loading;

  static Future<List<Surah>> load() {
    if (_cache != null) return Future.value(_cache);
    return _loading ??= _doLoad();
  }

  static Future<List<Surah>> _doLoad() async {
    final raw = await rootBundle.loadString('assets/data/quran.json');
    // بڑی JSON UI thread پر parse نہ کریں
    final parsed = await compute(_parse, raw);
    _cache = parsed;
    return parsed;
  }

  static List<Surah> _parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final out = <Surah>[];
    for (final s in j['surahs'] as List) {
      final m = s as Map<String, dynamic>;
      out.add(Surah(
        m['id'] as int,
        m['name_ar'] as String,
        m['name_en'] as String? ?? '',
        m['total'] as int,
        (m['ayahs'] as List).map((a) {
          final am = a as Map<String, dynamic>;
          return Ayah(am['ayah'] as int, am['arabic'] as String,
              am['urdu'] as String? ?? '');
        }).toList(),
      ));
    }
    return out;
  }

  static List<Surah> search(String query, List<Surah> all) {
    final q = query.trim();
    if (q.isEmpty) return [];
    final out = <Surah>[];
    for (final s in all) {
      final hits = s.ayahs
          .where((a) => a.arabic.contains(q) || a.urdu.contains(q))
          .toList();
      if (hits.isNotEmpty) {
        out.add(Surah(s.id, s.nameAr, s.nameEn, hits.length, hits));
      }
    }
    return out;
  }

  /// علمی (PhD طرز) حوالہ: (سورۃ البقرة 2:255) — native QuranInsert کی عکاسی
  static String citationFor(Surah s, int firstAyah, int lastAyah) {
    var name = s.nameAr;
    if (name.startsWith('سورة ')) name = name.substring(5);
    if (firstAyah == lastAyah) return '(سورۃ $name ${s.id}:$firstAyah)';
    return '(سورۃ $name ${s.id}:$firstAyah-$lastAyah)';
  }
}
