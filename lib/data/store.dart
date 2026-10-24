// مقامی ذخیرہ: دستاویز لائبریری (JSON فائلیں)، autosave/recovery، ترتیبات،
// حوالہ جات کی لائبریری، ٹیمپلیٹ اسٹائلز۔ سب کچھ آف لائن۔
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/model.dart';
import '../model/styles.dart';

/// بھاری JSON انکوڈنگ isolate میں — بڑی دستاویز پر بھی UI کبھی نہیں رکتی۔
String _encodeDocJson(Map<String, dynamic> m) => jsonEncode(m);

class DocMeta {
  final String id;
  String title;
  DateTime modified;
  int words;
  DocMeta(this.id, this.title, this.modified, this.words);
}

class DocStore {
  static Directory? _root;
  static Future<Directory> root() async {
    if (_root != null) return _root!;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'ibneabbas_word'));
    await d.create(recursive: true);
    await Directory(p.join(d.path, 'docs')).create(recursive: true);
    await Directory(p.join(d.path, 'recovery')).create(recursive: true);
    _root = d;
    return d;
  }

  static Directory docDir(String id) =>
      Directory(p.join(_root!.path, 'docs', id));
  static File docFile(String id) => File(p.join(docDir(id).path, 'doc.json'));
  static File metaFile(String id) => File(p.join(docDir(id).path, 'meta.json'));
  static File recoveryFile(String id) =>
      File(p.join(_root!.path, 'recovery', '$id.json'));

  static Future<List<DocMeta>> listDocs() async {
    await root();
    final docsDir = Directory(p.join(_root!.path, 'docs'));
    final out = <DocMeta>[];
    await for (final e in docsDir.list()) {
      if (e is Directory) {
        // پہلے چھوٹی meta فائل — پوری دستاویز پڑھے بغیر فہرست کھلتی ہے
        final meta = metaFile(p.basename(e.path));
        if (await meta.exists()) {
          try {
            final j =
                jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
            out.add(DocMeta(
              j['id'] as String,
              j['title'] as String? ?? 'بے عنوان',
              DateTime.tryParse(j['modified'] as String? ?? '') ??
                  DateTime.now(),
              (j['words'] as num?)?.toInt() ?? 0,
            ));
            continue;
          } catch (_) {/* خراب meta — مکمل فائل سے فال بیک */}
        }
        final f = File(p.join(e.path, 'doc.json'));
        if (await f.exists()) {
          try {
            final j =
                jsonDecode(await f.readAsString()) as Map<String, dynamic>;
            out.add(DocMeta(
              j['id'] as String,
              j['title'] as String? ?? 'بے عنوان',
              DateTime.tryParse(j['modified'] as String? ?? '') ??
                  DateTime.now(),
              0,
            ));
          } catch (_) {/* خراب فائل نظر انداز — کبھی hang نہیں */}
        }
      }
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  static Future<KDoc?> load(String id) async {
    await root();
    final f = docFile(id);
    if (!await f.exists()) return null;
    return KDoc.fromJson(
        jsonDecode(await f.readAsString()) as Map<String, dynamic>);
  }

  static Future<void> save(KDoc doc) async {
    await root();
    await docDir(doc.id).create(recursive: true);
    doc.modified = DateTime.now();
    final tmp = File(p.join(docDir(doc.id).path, 'doc.json.tmp'));
    // بھاری انکوڈنگ isolate میں، پھر لکھائی
    final jsonStr = await compute(_encodeDocJson, doc.toJson());
    await tmp.writeAsString(jsonStr, flush: true);
    await tmp.rename(docFile(doc.id).path);
    // چھوٹی meta فائل — لائبریری فہرست تیز کھلے
    try {
      await metaFile(doc.id).writeAsString(jsonEncode({
        'id': doc.id,
        'title': doc.title,
        'modified': doc.modified.toIso8601String(),
        'words': doc.wordCount(),
      }));
    } catch (_) {}
    // کامیاب save کے بعد recovery صاف
    final r = recoveryFile(doc.id);
    if (await r.exists()) await r.delete();
  }

  static Future<void> saveRecovery(KDoc doc) async {
    await root();
    try {
      final jsonStr = await compute(_encodeDocJson, doc.toJson());
      await recoveryFile(doc.id).writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  static Future<bool> hasRecovery(String id) async {
    await root();
    final r = recoveryFile(id);
    if (!await r.exists()) return false;
    final saved = docFile(id);
    if (!await saved.exists()) return true;
    return (await r.lastModified()).isAfter(await saved.lastModified());
  }

  static Future<KDoc?> loadRecovery(String id) async {
    await root();
    final r = recoveryFile(id);
    if (!await r.exists()) return null;
    return KDoc.fromJson(
        jsonDecode(await r.readAsString()) as Map<String, dynamic>);
  }

  static Future<void> delete(String id) async {
    await root();
    final d = docDir(id);
    if (await d.exists()) await d.delete(recursive: true);
    final r = recoveryFile(id);
    if (await r.exists()) await r.delete();
  }

  static Future<void> duplicate(KDoc doc, String newId) async {
    final copy = KDoc.fromJson(doc.toJson());
    copy.id = newId;
    copy.title = '${doc.title} — نقل';
    // میڈیا بھی نقل کریں
    final srcMedia = Directory(p.join(docDir(doc.id).path, 'media'));
    if (await srcMedia.exists()) {
      final dstMedia = Directory(p.join(docDir(newId).path, 'media'));
      await dstMedia.create(recursive: true);
      await for (final e in srcMedia.list()) {
        if (e is File) await e.copy(p.join(dstMedia.path, p.basename(e.path)));
      }
    }
    await save(copy);
  }

  static String newId() =>
      'd${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
}

/// ترتیبات (SharedPreferences)
class Settings {
  static SharedPreferences? _sp;
  static Future<SharedPreferences> _p() async =>
      _sp ??= await SharedPreferences.getInstance();
  static Future<String> uiLang() async =>
      (await _p()).getString('ui_lang') ?? 'ur';
  static Future<void> setUiLang(String v) async =>
      (await _p()).setString('ui_lang', v);
  static Future<bool> quranCitation() async =>
      (await _p()).getBool('quran_citation') ?? true;
  static Future<void> setQuranCitation(bool v) async =>
      (await _p()).setBool('quran_citation', v);
  static Future<String> defaultFont() async =>
      (await _p()).getString('default_font') ?? 'Noto Nastaliq Urdu';
  static Future<void> setDefaultFont(String v) async =>
      (await _p()).setString('default_font', v);

  // ── تحقیقی (PhD) کرداری فونٹس ──
  static Future<String> _roleFont(String key, String dflt) async =>
      (await _p()).getString(key) ?? dflt;
  static Future<void> _setRoleFont(String key, String v) async =>
      (await _p()).setString(key, v);
  static Future<String> urduFont() =>
      _roleFont('font_urdu', 'Jameel Noori Nastaleeq');
  static Future<void> setUrduFont(String v) => _setRoleFont('font_urdu', v);
  static Future<String> arabicFont() => _roleFont('font_arabic', 'Amiri');
  static Future<void> setArabicFont(String v) => _setRoleFont('font_arabic', v);
  static Future<String> quranFont() => _roleFont('font_quran', 'Amiri Quran');
  static Future<void> setQuranFont(String v) => _setRoleFont('font_quran', v);
  static Future<String> englishFont() =>
      _roleFont('font_english', 'Times New Roman');
  static Future<void> setEnglishFont(String v) =>
      _setRoleFont('font_english', v);
  static Future<String> footnoteFont() => _roleFont('font_footnote', 'Amiri');
  static Future<void> setFootnoteFont(String v) =>
      _setRoleFont('font_footnote', v);
  static Future<String> translitFont() =>
      _roleFont('font_translit', 'Gentium Plus');
  static Future<void> setTranslitFont(String v) =>
      _setRoleFont('font_translit', v);

  /// پی ایچ ڈی پیش سیٹ: صارف کی منظور شدہ فونٹ میز ایک ٹیپ میں لاگو
  static Future<void> applyPhdPreset() async {
    await setUrduFont('Jameel Noori Nastaleeq');
    await setArabicFont('Amiri');
    await setQuranFont('KFGQPC Uthmanic Script HAFS');
    await setEnglishFont('Times New Roman');
    await setFootnoteFont('Amiri');
    await setTranslitFont('Gentium Plus');
    await setDefaultFont('Jameel Noori Nastaleeq');
  }
}

/// حوالہ جات کی ذاتی لائبریری (native کے sources DB کی صورت)
class CitationStore {
  static Future<List<Citation>> all() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('citations');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((c) => Citation.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveAll(List<Citation> list) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        'citations', jsonEncode(list.map((c) => c.toJson()).toList()));
  }

  static Future<Citation> add(Citation c) async {
    final list = await all();
    c.id = (list.isEmpty
            ? 0
            : list.map((e) => e.id).reduce((a, b) => a > b ? a : b)) +
        1;
    list.add(c);
    await saveAll(list);
    return c;
  }
}

/// ایپ سطح کے ٹیمپلیٹ اسٹائلز — ہر نئی دستاویز میں شامل
class TemplateStyles {
  static Future<List<KStyle>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('template_styles');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((s) => KStyle.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<KStyle> styles) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        'template_styles',
        jsonEncode(
            styles.where((s) => s.inTemplate).map((s) => s.toJson()).toList()));
  }
}

/// CrashGuard کی Flutter صورت: خاموشی سے غلطی لاگ فائل میں، ایپ کبھی رکے نہیں
class CrashLog {
  static Future<void> log(Object error, StackTrace st) async {
    try {
      final dir = await DocStore.root();
      final f = File(p.join(dir.path, 'crash_log.txt'));
      await f.writeAsString(
          '${DateTime.now().toIso8601String()}\n$error\n$st\n---\n',
          mode: FileMode.append);
    } catch (_) {}
  }
}
