// لائبریری/ہوم — پریمیم navy ہیڈر، حالیہ دستاویزات کے کارڈز، ٹیمپلیٹس،
// floating bottom navigation (reference تصویر کا انداز)
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../core/theme.dart';
import '../data/store.dart';
import '../data/templates.dart';
import '../docx/docx_reader.dart';
import '../editor/editor_screen.dart';
import '../model/model.dart';
import 'citations_screen.dart';
import 'quran_screen.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<DocMeta> _docs = [];
  List<DocMeta> _filtered = [];
  bool _loading = true;
  int _nav = 0;
  // پہلے سے کھلے ٹیبز ہی بنتے ہیں — ایپ شروع میں قرآن (3MB) سمیت
  // چاروں اسکرینیں ایک ساتھ بنانا اسٹارٹ اپ ہینگ تھا
  final _builtTabs = <int>{0};
  Timer? _debounce;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final docs = await DocStore.listDocs();
    // recovery کی پیشکش
    for (final d in docs) {
      if (await DocStore.hasRecovery(d.id)) {
        d.title = '${d.title} (غیر محفوظ مسودہ موجود)';
      }
    }
    if (mounted) {
      setState(() {
        _docs = docs;
        _filtered = docs;
        _loading = false;
      });
    }
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _filtered = q.trim().isEmpty
            ? _docs
            : _docs.where((d) => d.title.contains(q.trim())).toList();
      });
    });
  }

  Future<void> _newDoc(String template, String defaultTitle) async {
    final ctrl = TextEditingController(text: defaultTitle);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نئی دستاویز'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('منسوخ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('بنائیں')),
        ],
      ),
    );
    if (title == null) return;
    final tplStyles = await TemplateStyles.load();
    final doc = await newDocument(
        title: title.trim().isEmpty ? defaultTitle : title.trim(),
        template: template,
        templateStyles: tplStyles);
    await DocStore.save(doc);
    await _refresh();
    if (mounted) _open(doc.id);
  }

  Future<void> _open(String id) async {
    KDoc? doc;
    if (await DocStore.hasRecovery(id)) {
      final useRec = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('غیر محفوظ مسودہ ملا'),
          content: const Text(
              'اس دستاویز کا ایک غیر محفوظ مسودہ (autosave) موجود ہے۔ بحال کریں یا محفوظ شدہ صورت کھولیں؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('محفوظ شدہ')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('مسودہ بحال کریں')),
          ],
        ),
      );
      doc = useRec == true
          ? await DocStore.loadRecovery(id)
          : await DocStore.load(id);
    } else {
      doc = await DocStore.load(id);
    }
    if (doc == null || !mounted) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => EditorScreen(doc: doc!)));
    _refresh();
  }

  Future<void> _importDocx() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return;
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('DOCX درآمد ہو رہی ہے…')));
    }
    try {
      final id = DocStore.newId();
      final result = await compute(
        (Map<String, dynamic> input) => importDocx(
          input['bytes'] as Uint8List,
          input['id'] as String,
          input['title'] as String,
        ),
        {
          'bytes': bytes,
          'id': id,
          'title': file.name
              .replaceAll(RegExp(r'\.docx$', caseSensitive: false), ''),
        },
      );
      final doc = KDoc.fromJson(result.docJson);
      // میڈیا لکھیں
      final mediaDir = Directory(p.join(DocStore.docDir(id).path, 'media'));
      await mediaDir.create(recursive: true);
      for (final e in result.media.entries) {
        await File(p.join(DocStore.docDir(id).path, e.key))
            .writeAsBytes(e.value, flush: true);
      }
      await DocStore.save(doc);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'درآمد مکمل${result.unsupportedCount > 0 ? ' — ${result.unsupportedCount} غیر معاون عناصر چھوڑے گئے' : ''}')));
        _open(id);
      }
    } catch (e) {
      await CrashLog.log(e, StackTrace.current);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('درآمد ناکام: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _nav,
            children: [
              _libraryBody(),
              _builtTabs.contains(1)
                  ? const QuranScreen(pickMode: false)
                  : const SizedBox.shrink(),
              _builtTabs.contains(2)
                  ? const CitationsScreen()
                  : const SizedBox.shrink(),
              _builtTabs.contains(3)
                  ? const SettingsScreen()
                  : const SizedBox.shrink(),
            ],
          ),
          // Floating bottom navigation
          Positioned(
            left: 18,
            right: 18,
            bottom: 14,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 8)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navBtn(0, Icons.library_books, 'لائبریری'),
                  _navBtn(1, Icons.menu_book, 'قرآن'),
                  _navBtn(2, Icons.format_quote, 'مصادر'),
                  _navBtn(3, Icons.settings, 'ترتیبات'),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _nav == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 74),
              child: FloatingActionButton.extended(
                onPressed: () => _newDoc('blank', 'نئی دستاویز'),
                icon: const Icon(Icons.add),
                label: const Text('نئی دستاویز'),
              ),
            )
          : null,
    );
  }

  Widget _navBtn(int i, IconData icon, String label) {
    final active = _nav == i;
    return InkWell(
      onTap: () => setState(() {
        _nav = i;
        _builtTabs.add(i);
      }),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            if (active) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _libraryBody() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 46, 16, 4),
            child: NavyPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset('assets/logo_hd.jpg',
                            width: 56, height: 56),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('IBNEABBAS WORD',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tinos')),
                            Text(
                                'محقق کا ورڈ پروسیسر — اردو • عربی • حوالہ جات',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'دستاویز تلاش کریں…',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
            child: Row(
              children: [
                const Text('ٹیمپلیٹس',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _importDocx,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('DOCX درآمد'),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 108,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _tplCard(Icons.article, 'خالی دستاویز', 'blank', 'نئی دستاویز'),
                _tplCard(Icons.school, 'تحقیقی مقالہ', 'research', 'مقالہ'),
                _tplCard(Icons.workspace_premium, 'مقالہ (پی ایچ ڈی)', 'phd',
                    'پی ایچ ڈی مقالہ'),
                _tplCard(Icons.gavel, 'فتویٰ', 'fatwa', 'فتویٰ'),
                _tplCard(Icons.mail, 'خط', 'letter', 'خط'),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text('حالیہ دستاویزات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        if (_loading)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
        else if (_filtered.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text('کوئی دستاویز نہیں — نئی بنائیں یا DOCX درآمد کریں',
                  style: TextStyle(color: AppColors.inkSoft)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 110),
            sliver: SliverList.builder(
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final d = _filtered[i];
                return Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    leading: Container(
                      width: 46,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.description,
                          color: AppColors.greenDark),
                    ),
                    title: Text(d.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'آخری تبدیلی: ${d.modified.toString().substring(0, 16)}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        switch (v) {
                          case 'open':
                            _open(d.id);
                            break;
                          case 'duplicate':
                            final doc = await DocStore.load(d.id);
                            if (doc != null) {
                              await DocStore.duplicate(doc, DocStore.newId());
                              _refresh();
                            }
                            break;
                          case 'delete':
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('دستاویز حذف کریں؟'),
                                content:
                                    Text('«${d.title}» مستقل حذف ہو جائے گی۔'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('منسوخ')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('حذف')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await DocStore.delete(d.id);
                              _refresh();
                            }
                            break;
                        }
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'open', child: Text('کھولیں')),
                        PopupMenuItem(
                            value: 'duplicate', child: Text('نقل بنائیں')),
                        PopupMenuItem(value: 'delete', child: Text('حذف کریں')),
                      ],
                    ),
                    onTap: () => _open(d.id),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _tplCard(IconData icon, String label, String tpl, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: InkWell(
        onTap: () => _newDoc(tpl, title),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 108,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: AppColors.navy.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: AppColors.greenDark),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}
