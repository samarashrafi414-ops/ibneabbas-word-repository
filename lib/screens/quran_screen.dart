// قرآن اسکرین — سورت فہرست + تلاش؛ آیات کا انتخاب (حد/انفرادی) اور ایڈیٹر میں
// اندراج: ﴿عربی﴾ Amiri Quran میں + ترجمۂ کنزالایمان + علمی حوالہ (native طرز)
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/quran_repo.dart';
import '../data/store.dart';
import '../model/model.dart';

class QuranScreen extends StatefulWidget {
  final bool pickMode;
  const QuranScreen({super.key, required this.pickMode});
  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  List<Surah>? _surahs;
  String _query = '';
  // تلاش debounce — ہر حرف پر 6236 آیات کا اسکین ٹائپنگ روک دیتا تھا
  Timer? _searchTimer;
  bool _includeCitation = true;
  String _quranFont = 'Amiri Quran';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v);
    });
  }

  Future<void> _load() async {
    _includeCitation = await Settings.quranCitation();
    _quranFont = await Settings.quranFont();
    final s = await QuranRepo.load();
    if (mounted) setState(() => _surahs = s);
  }

  @override
  Widget build(BuildContext context) {
    final body = _surahs == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'سورت یا آیت تلاش کریں (عربی/اردو)…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _onQueryChanged,
                ),
              ),
              if (_query.trim().length >= 2)
                Expanded(child: _searchResults())
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _surahs!.length,
                    itemBuilder: (ctx, i) {
                      final s = _surahs![i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            child: Text('${s.id}'),
                          ),
                          title: Text(s.nameAr,
                              style: const TextStyle(
                                  fontFamily: 'Amiri Quran', fontSize: 17)),
                          subtitle: Text('${s.nameEn} • ${s.total} آیات'),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AyahPickScreen(
                                surah: s,
                                pickMode: widget.pickMode,
                                includeCitation: _includeCitation,
                              ),
                            ),
                          ).then((v) {
                            if (v is List<ParaBlock> && widget.pickMode) {
                              Navigator.pop(context, v);
                            }
                          }),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
    if (widget.pickMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('قرآن مجید — آیت منتخب کریں')),
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('قرآن مجید (آف لائن)'),
        actions: [
          Row(
            children: [
              const Text('علمی حوالہ', style: TextStyle(fontSize: 12)),
              Switch(
                value: _includeCitation,
                activeColor: AppColors.greenBright,
                onChanged: (v) async {
                  setState(() => _includeCitation = v);
                  await Settings.setQuranCitation(v);
                },
              ),
            ],
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _searchResults() {
    final results = QuranRepo.search(_query, _surahs!);
    if (results.isEmpty) {
      return const Center(child: Text('کوئی نتیجہ نہیں'));
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final s = results[i];
        // ایک سورت کی سینکڑوں آیات ایک دم بنانا ہینگ تھا — پہلی 40 + گنتی
        final shown = s.ayahs.take(40).toList();
        final rest = s.ayahs.length - shown.length;
        return ExpansionTile(
          title:
              Text(s.nameAr, style: const TextStyle(fontFamily: 'Amiri Quran')),
          subtitle: Text('${s.ayahs.length} آیات ملیں'),
          children: [
            for (final a in shown)
              ListTile(
                title: Text(a.arabic,
                    style: const TextStyle(
                        fontFamily: 'Amiri Quran', fontSize: 16)),
                subtitle: Text(a.urdu, maxLines: 2),
                trailing: widget.pickMode
                    ? IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: AppColors.greenDark),
                        onPressed: () async {
                          final full = (await QuranRepo.load())
                              .firstWhere((x) => x.id == s.id);
                          if (mounted) {
                            Navigator.pop(
                                context,
                                buildAyahBlocks(full, [a.no], _includeCitation,
                                    quranFont: _quranFont));
                          }
                        },
                      )
                    : null,
              ),
            if (rest > 0)
              ListTile(
                title: Text('…اور $rest مزید آیات (تلاش مزید مخصوص کریں)'),
              ),
          ],
        );
      },
    );
  }
}

/// منتخب آیات سے اندراج بلاک — native QuranActivity کی عین صورت:
/// ﴿عربی﴾ (Amiri Quran، وسط) + آخری آیت پر علمی حوالہ + ترجمہ سطر
List<ParaBlock> buildAyahBlocks(Surah s, List<int> ayahNos, bool withCitation,
    {String quranFont = 'Amiri Quran'}) {
  final sorted = ayahNos.toList()..sort();
  final arabic =
      sorted.map((n) => s.ayahs.firstWhere((a) => a.no == n).arabic).join(' ');
  final urdu = sorted
      .map((n) => s.ayahs.firstWhere((a) => a.no == n).urdu)
      .where((u) => u.isNotEmpty)
      .join(' ');
  String citation = '';
  if (withCitation && sorted.isNotEmpty) {
    citation = ' ${QuranRepo.citationFor(s, sorted.first, sorted.last)}';
  }
  ParaBlock mk(String text, Map<String, dynamic> attrs,
      Map<String, dynamic> lineAttrs, String style) {
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

  return [
    mk('﴿$arabic﴾$citation', {'font': quranFont, 'size': '19'},
        {'align': 'center', 'direction': 'rtl'}, 'QuranAyah'),
    if (urdu.isNotEmpty)
      mk('ترجمہ کنزالایمان: "$urdu"', {'size': '13.5'}, {'direction': 'rtl'},
          'Normal'),
  ];
}

class AyahPickScreen extends StatefulWidget {
  final Surah surah;
  final bool pickMode;
  final bool includeCitation;
  const AyahPickScreen({
    super.key,
    required this.surah,
    required this.pickMode,
    required this.includeCitation,
  });
  @override
  State<AyahPickScreen> createState() => _AyahPickScreenState();
}

class _AyahPickScreenState extends State<AyahPickScreen> {
  final Set<int> _selected = {};
  String _quranFont = 'Amiri Quran';

  @override
  void initState() {
    super.initState();
    Settings.quranFont().then((f) {
      if (mounted) setState(() => _quranFont = f);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.surah;
    return Scaffold(
      appBar: AppBar(
        title:
            Text(s.nameAr, style: const TextStyle(fontFamily: 'Amiri Quran')),
        actions: [
          TextButton(
            onPressed: () =>
                setState(() => _selected.addAll(s.ayahs.map((a) => a.no))),
            child: const Text('تمام', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: s.ayahs.length,
        itemBuilder: (ctx, i) {
          final a = s.ayahs[i];
          final sel = _selected.contains(a.no);
          return Card(
            color: sel ? AppColors.green.withOpacity(0.10) : null,
            child: CheckboxListTile(
              value: sel,
              onChanged: widget.pickMode
                  ? (v) => setState(() {
                        if (v == true) {
                          _selected.add(a.no);
                        } else {
                          _selected.remove(a.no);
                        }
                      })
                  : null,
              title: Text('﴿${a.arabic}﴾',
                  style:
                      const TextStyle(fontFamily: 'Amiri Quran', fontSize: 17)),
              subtitle: Text(a.urdu),
              secondary: CircleAvatar(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                child: Text('${a.no}', style: const TextStyle(fontSize: 12)),
              ),
            ),
          );
        },
      ),
      floatingActionButton: widget.pickMode && _selected.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pop(
                  context,
                  buildAyahBlocks(s, _selected.toList(), widget.includeCitation,
                      quranFont: _quranFont)),
              icon: const Icon(Icons.add),
              label: Text('${_selected.length} آیات شامل کریں'),
            )
          : null,
    );
  }
}
