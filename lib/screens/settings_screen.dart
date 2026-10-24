// ترتیبات + تعارف (About) — لوگو، ورژن، فیچرز کا خلاصہ
import 'package:flutter/material.dart';
import '../core/font_catalog.dart';
import '../core/theme.dart';
import '../data/store.dart';
import '../editor/style_manager.dart';
import '../model/styles.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _lang = 'ur';
  String _font = FontCatalog.defaultUrdu;
  bool _quranCit = true;
  String _urduFont = 'Jameel Noori Nastaleeq';
  String _arabicFont = 'Amiri';
  String _quranFont = 'Amiri Quran';
  String _englishFont = 'Times New Roman';
  String _footnoteFont = 'Amiri';
  String _translitFont = 'Gentium Plus';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await Settings.uiLang();
    final f = await Settings.defaultFont();
    final q = await Settings.quranCitation();
    final uf = await Settings.urduFont();
    final af = await Settings.arabicFont();
    final qf = await Settings.quranFont();
    final ef = await Settings.englishFont();
    final ff = await Settings.footnoteFont();
    final tf = await Settings.translitFont();
    if (mounted) {
      setState(() {
        _lang = l;
        _font = f;
        _quranCit = q;
        _urduFont = uf;
        _arabicFont = af;
        _quranFont = qf;
        _englishFont = ef;
        _footnoteFont = ff;
        _translitFont = tf;
      });
    }
  }

  Widget _roleFontTile(String label, String value, String group,
      Future<void> Function(String) save, void Function(String) apply) {
    final names = FontCatalog.byGroup(group).map((f) => f.name).toList();
    if (!names.contains(value)) names.insert(0, value);
    return ListTile(
      leading: const Icon(Icons.text_fields),
      title: Text(label),
      trailing: DropdownButton<String>(
        value: value,
        items: [
          for (final n in names) DropdownMenuItem(value: n, child: Text(n)),
        ],
        onChanged: (v) async {
          if (v == null) return;
          setState(() => apply(v));
          await save(v);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ترتیبات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 110),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/logo_hd.jpg',
                        width: 64, height: 64),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IBNEABBAS WORD',
                            style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tinos')),
                        Text(
                            'ورژن 2.0.0 (Flutter) — Kanz Word Pro کا ایڈوانس جانشین',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('ایپ کی زبان'),
                  subtitle: Text(_lang == 'ur'
                      ? 'اردو'
                      : _lang == 'ar'
                          ? 'العربية'
                          : 'English'),
                  trailing: DropdownButton<String>(
                    value: _lang,
                    items: const [
                      DropdownMenuItem(value: 'ur', child: Text('اردو')),
                      DropdownMenuItem(value: 'ar', child: Text('العربية')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) async {
                      setState(() => _lang = v!);
                      await Settings.setUiLang(v!);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.font_download),
                  title: const Text('طے شدہ فونٹ'),
                  trailing: DropdownButton<String>(
                    value: _font,
                    items: [
                      for (final f in FontCatalog.all)
                        DropdownMenuItem(
                            value: f.family, child: Text(f.family)),
                    ],
                    onChanged: (v) async {
                      setState(() => _font = v!);
                      await Settings.setDefaultFont(v!);
                    },
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.menu_book),
                  title: const Text('آیت داخل کرتے وقت علمی حوالہ شامل کریں'),
                  subtitle: const Text('مثلاً (سورۃ البقرة 2:255)'),
                  value: _quranCit,
                  onChanged: (v) async {
                    setState(() => _quranCit = v);
                    await Settings.setQuranCitation(v);
                  },
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.school),
                  title: Text('تحقیقی فونٹس (PhD)'),
                  subtitle:
                      Text('ہر کردار کے لیے الگ فونٹ — مقالہ و تھیسس کی ترتیب'),
                ),
                _roleFontTile('اردو متن', _urduFont, 'urdu',
                    Settings.setUrduFont, (v) => _urduFont = v),
                _roleFontTile('عربی متن و احادیث', _arabicFont, 'arabic',
                    Settings.setArabicFont, (v) => _arabicFont = v),
                _roleFontTile('قرآنی آیات', _quranFont, 'quran',
                    Settings.setQuranFont, (v) => _quranFont = v),
                _roleFontTile(
                    'انگریزی متن و حوالہ جات',
                    _englishFont,
                    'english',
                    Settings.setEnglishFont,
                    (v) => _englishFont = v),
                _roleFontTile('حواشی', _footnoteFont, 'arabic',
                    Settings.setFootnoteFont, (v) => _footnoteFont = v),
                _roleFontTile(
                    'نقلِ صوت (Transliteration)',
                    _translitFont,
                    'translit',
                    Settings.setTranslitFont,
                    (v) => _translitFont = v),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Settings.applyPhdPreset();
                      await _load();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('پی ایچ ڈی پیش سیٹ لاگو ہو گیا')));
                      }
                    },
                    icon: const Icon(Icons.workspace_premium),
                    label: const Text('پی ایچ ڈی پیش سیٹ لاگو کریں'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.style),
                  title: const Text('ٹیمپلیٹ اسٹائلز'),
                  subtitle:
                      const Text('وہ اسٹائلز جو ہر نئی دستاویز میں آئیں گے'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () async {
                    final tpl = await TemplateStyles.load();
                    final merged = builtinStyles();
                    for (final t in tpl) {
                      final i = merged.indexWhere((s) => s.id == t.id);
                      if (i >= 0) {
                        merged[i] = t;
                      } else {
                        merged.add(t);
                      }
                    }
                    if (!mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StyleManagerScreen(
                          styles: merged,
                          usage: const {},
                          onChanged: (updated) => TemplateStyles.save(updated),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('خصوصیات',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 8),
                  Text(
                    '• حقیقی DOCX انجن — genuine footnotes (footnotes.xml)، styles.xml، numbering\n'
                    '• جداول (بارڈرز سمیت) اور تصاویر — تخلیق، ترمیم، درآمد و برآمد\n'
                    '• مکمل بارڈرز: پیراگراف، صفحہ (pgBorders)، جدول و سیل\n'
                    '• MS Word درجے کا اسٹائل سسٹم — gallery، مینیجر، template styles\n'
                    '• آف لائن قرآن: 6236 آیات + ترجمۂ کنزالایمان + علمی حوالہ\n'
                    '• رموزِ دینیہ: KFGQPC خطاطی علامات (إثراء المتون طرز)\n'
                    '• 10 علمی حوالہ ٹیمپلیٹس + مآخذ و مراجع خودکار\n'
                    '• خودکار محفوظ (autosave) + crash بحالی — دستاویز کبھی ضائع نہیں\n'
                    '• A4 PDF برآمد و اشتراک — مکمل آف لائن',
                    style: TextStyle(fontSize: 13, height: 1.9),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
