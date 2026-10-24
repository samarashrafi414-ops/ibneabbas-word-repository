// مرکزی ایڈیٹر — ورچوئلائزڈ بلاک لسٹ، ربن ٹول بارز (ہوم/انسرٹ/لے آؤٹ/
// حوالہ جات/منظر)، اسٹائل گیلری، خودکار محفوظ + Crash بحالی۔
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide TableCell;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../core/theme.dart';
import '../data/citation_format.dart';
import '../data/store.dart';
import '../docx/delta_convert.dart';
import '../docx/docx_writer.dart';
import '../model/model.dart';
import '../model/styles.dart';
import '../pdf/pdf_exporter.dart';
import '../screens/quran_screen.dart';
import 'block_widgets.dart';
import 'dialogs.dart';
import 'fnote_attribute.dart';
import 'style_manager.dart';

class EditorScreen extends StatefulWidget {
  final KDoc doc;
  const EditorScreen({super.key, required this.doc});
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  late KDoc _doc;
  QuillController? _activeController;
  ParaBlock? _activeBlock;
  int _activeIndex = 0;
  int _tab = 0;
  bool _dirty = false;
  bool _saving = false;
  Timer? _autosaveTimer;
  Timer? _debounce;
  final _paraKeys = <ParaBlock, GlobalKey<ParaBlockWidgetState>>{};
  String _docDir = '';
  // کیش — ہر build پر دوبارہ JSON پارز / پوری دستاویز کی گنتی نہیں ہوتی
  List<KStyle>? _stylesCache;
  int _cachedWords = 0;
  int _cachedChars = 0;
  // جدول سیل کی آخری پوزیشن
  int _lastRow = 0, _lastCol = 0;

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
    WidgetsBinding.instance.addObserver(this);
    _initDir();
    _refreshCounts();
    _autosaveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_dirty) DocStore.saveRecovery(_doc);
    });
  }

  Future<void> _initDir() async {
    await DocStore.root();
    setState(() => _docDir = DocStore.docDir(_doc.id).path);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_dirty) DocStore.saveRecovery(_doc);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _dirty) {
      DocStore.saveRecovery(_doc);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      if (_dirty) DocStore.saveRecovery(_doc);
      _refreshCounts();
    });
  }

  /// الفاظ/حروف کی گنتی — صرف اس وقت جب بدلی ہو (ہر build پر پورا اسکین نہیں)
  void _refreshCounts() {
    final w = _doc.wordCount();
    var c = 0;
    for (final b in _doc.blocks.whereType<ParaBlock>()) {
      c += b.plainText.length;
    }
    if (w != _cachedWords || c != _cachedChars) {
      _cachedWords = w;
      _cachedChars = c;
      if (mounted) setState(() {});
    }
  }

  /// تمام پیراگراف وِجٹس سے تازہ delta بلاکس میں لائیں (محفوظ/تلاش سے پہلے)
  void _syncAllDeltas() {
    for (final e in _paraKeys.entries) {
      e.value.currentState?.syncDeltaToBlock();
    }
    _paraKeys.removeWhere((k, _) => !_doc.blocks.contains(k));
  }

  GlobalKey<ParaBlockWidgetState> _keyFor(ParaBlock b) =>
      _paraKeys.putIfAbsent(b, () => GlobalKey<ParaBlockWidgetState>());

  void _reloadPara(ParaBlock b) =>
      _paraKeys[b]?.currentState?.reloadFromBlock();
  void _reloadAllParas() {
    for (final b in _doc.blocks.whereType<ParaBlock>()) {
      _reloadPara(b);
    }
  }

  int get _insertIndex => (_activeIndex + 1).clamp(0, _doc.blocks.length);

  void _insertBlocks(int at, List<KBlock> blocks) {
    setState(() {
      _doc.blocks.insertAll(at, blocks);
      _markDirty();
    });
  }

  Future<void> _save({bool silent = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    // تمام فعال پیراگرافوں کا تازہ delta حاصل کریں
    _syncAllDeltas();
    await DocStore.save(_doc);
    if (mounted) {
      setState(() {
        _dirty = false;
        _saving = false;
      });
      _refreshCounts();
      if (!silent) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('محفوظ ہو گیا')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _renameDoc,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/logo_hd.jpg', width: 30, height: 30),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _doc.title + (_dirty ? ' •' : ''),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'واپس (Undo)',
            onPressed: () => _activeController?.undo(),
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'دوبارہ (Redo)',
            onPressed: () => _activeController?.redo(),
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            tooltip: 'محفوظ کریں',
            onPressed: () => _save(),
          ),
        ],
      ),
      body: Column(
        children: [
          _tabBar(),
          if (_tab == 0) _styleGallery(),
          _toolbar(),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: const Color(0xFFE9EFEA),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 860),
                  margin:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: _doc.pageSetup.marginLeftMm * 1.2,
                    vertical: 24,
                  ),
                  child: ListView.builder(
                    itemCount: _doc.blocks.length,
                    itemBuilder: (ctx, i) {
                      final b = _doc.blocks[i];
                      if (b is ParaBlock) {
                        return ParaBlockWidget(
                          key: _keyFor(b),
                          block: b,
                          styles: _stylesList(),
                          onActivate: (c, blk, refresh) {
                            _activeController = c;
                            _activeBlock = blk;
                            _activeIndex = i;
                          },
                          onChanged: _markDirty,
                          onBlockMenu: () => _blockMenu(i),
                        );
                      } else if (b is TableBlock) {
                        return TableBlockWidget(
                          block: b,
                          onChanged: _markDirty,
                          onCellTap: (cell, r, c) {
                            _lastRow = r;
                            _lastCol = c;
                            _activeIndex = i;
                            _editCell(cell);
                          },
                          onTableMenu: () {
                            _activeIndex = i;
                            _tableMenu(b);
                          },
                        );
                      } else if (b is ImageBlock) {
                        return ImageBlockWidget(
                          block: b,
                          docDirPath: _docDir,
                          onTap: () => _imageMenu(b, i),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ),
          ),
          _statusBar(),
        ],
      ),
    );
  }

  List<KStyle> _stylesList() =>
      _stylesCache ??= _doc.styles.map((s) => KStyle.fromJson(s)).toList();

  void _invalidateStyles() => _stylesCache = null;

  Widget _tabBar() {
    const tabs = ['ہوم', 'انسرٹ', 'لے آؤٹ', 'حوالہ جات', 'منظر'];
    return Container(
      color: AppColors.navy,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == i ? AppColors.green : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _tab == i ? Colors.white : Colors.white70,
                      fontWeight: _tab == i ? FontWeight.bold : null,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _styleGallery() {
    final styles = _stylesList();
    final gallery = styles
        .where((s) =>
            s.type != 'character' &&
                [
                  'Normal',
                  'Title',
                  'Subtitle',
                  'Heading1',
                  'Heading2',
                  'Heading3',
                  'Quote',
                  'IntenseQuote',
                  'QuranAyah',
                  'Caption'
                ].contains(s.id) ||
            !s.builtIn)
        .toList();
    return Container(
      height: 58,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        itemCount: gallery.length + 1,
        itemBuilder: (ctx, i) {
          if (i == gallery.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ActionChip(
                avatar: const Icon(Icons.style, size: 16),
                label: const Text('اسٹائل مینیجر'),
                onPressed: _openStyleManager,
              ),
            );
          }
          final s = resolveStyle(styles, gallery[i].id);
          final active = _activeBlock?.styleId == gallery[i].id;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                s.name.replaceAll(RegExp(r'\s*\([^)]*\)'), ''),
                style: TextStyle(
                  fontFamily: s.fontFamily,
                  fontSize: s.fontSize.clamp(11, 15),
                  fontWeight: s.bold ? FontWeight.bold : null,
                  color: Color(s.color),
                ),
              ),
              selected: active,
              selectedColor: AppColors.green.withOpacity(0.25),
              onSelected: (_) => _applyStyle(gallery[i].id),
            ),
          );
        },
      ),
    );
  }

  Widget _statusBar() {
    return Container(
      color: AppColors.navyDeep,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        children: [
          Text('الفاظ: $_cachedWords',
              style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          const SizedBox(width: 14),
          Text('حروف: $_cachedChars',
              style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          const SizedBox(width: 14),
          Text('حواشی: ${_doc.footnotes.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          const Spacer(),
          Text(_dirty ? 'غیر محفوظ تبدیلیاں' : 'محفوظ',
              style: TextStyle(
                  color: _dirty ? AppColors.gold : AppColors.greenBright,
                  fontSize: 11.5)),
        ],
      ),
    );
  }

  // ---------- ٹول بار ----------
  Widget _toolbar() {
    switch (_tab) {
      case 1:
        return _insertToolbar();
      case 2:
        return _layoutToolbar();
      case 3:
        return _refsToolbar();
      case 4:
        return _viewToolbar();
      default:
        return _homeToolbar();
    }
  }

  Widget _bar(List<Widget> children) {
    return Container(
      height: 52,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        children: children
            .map((w) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Center(child: w)))
            .toList(),
      ),
    );
  }

  Widget _tbtn(IconData icon, String tip, VoidCallback? fn) => IconButton(
        icon: Icon(icon, size: 21),
        tooltip: tip,
        onPressed: fn,
        visualDensity: VisualDensity.compact,
        color: AppColors.navy,
      );

  Widget _homeToolbar() {
    final c = _activeController;
    return _bar([
      // فونٹ
      InkWell(
        onTap: () async {
          final v = await showFontPickerSheet(context);
          if (v != null) c?.formatSelection(FontAttribute(v));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Text(_currentFontName(), style: const TextStyle(fontSize: 12.5)),
            const Icon(Icons.arrow_drop_down, size: 18),
          ]),
        ),
      ),
      const SizedBox(width: 4),
      PopupMenuButton<String>(
        tooltip: 'فونٹ سائز',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Text('سائز', style: TextStyle(fontSize: 12.5)),
            Icon(Icons.arrow_drop_down, size: 18),
          ]),
        ),
        itemBuilder: (ctx) => [
          for (final s in [
            '8',
            '9',
            '10',
            '11',
            '12',
            '14',
            '16',
            '18',
            '20',
            '24',
            '28',
            '36',
            '48',
            '72'
          ])
            PopupMenuItem(value: s, child: Text(s)),
        ],
        onSelected: (v) => c?.formatSelection(SizeAttribute(v)),
      ),
      _tbtn(
          Icons.format_bold, 'بولڈ', () => c?.formatSelection(Attribute.bold)),
      _tbtn(Icons.format_italic, 'ترچھا',
          () => c?.formatSelection(Attribute.italic)),
      _tbtn(Icons.format_underlined, 'خط کشیدہ',
          () => c?.formatSelection(Attribute.underline)),
      _tbtn(Icons.format_strikethrough, 'کٹا ہوا',
          () => c?.formatSelection(Attribute.strikeThrough)),
      _tbtn(Icons.format_color_text, 'متن رنگ', () async {
        final v = await showColorSheet(context, title: 'متن کا رنگ');
        if (v != null && c != null) {
          c.formatSelection(ColorAttribute(argbToHex(v)));
        }
      }),
      _tbtn(Icons.format_color_fill, 'ہائی لائٹ', () async {
        final v = await showColorSheet(context, title: 'ہائی لائٹ رنگ');
        if (c != null) {
          c.formatSelection(
              BackgroundAttribute(v == null ? null : argbToHex(v)));
        }
      }),
      _tbtn(Icons.format_clear, 'فارمیٹنگ صاف', _clearFormat),
      const VerticalDivider(width: 14),
      // پیراگراف گروپ — صارف کی بھیجی ربن تصویر کے مطابق
      _tbtn(Icons.format_list_bulleted, 'نقطہ فہرست (Bullets)',
          () => _toggleList('bullet')),
      _tbtn(Icons.format_list_numbered, 'نمبر فہرست (Numbering)',
          () => _toggleList('ordered')),
      _tbtn(Icons.format_indent_decrease, 'انڈینٹ کم (Decrease Indent)',
          () => _changeIndent(-1)),
      _tbtn(Icons.format_indent_increase, 'انڈینٹ زیادہ (Increase Indent)',
          () => _changeIndent(1)),
      _tbtn(Icons.format_align_right, 'سیدھ — شروع', () => _setAlign(null)),
      _tbtn(Icons.format_align_center, 'درمیان (Center)',
          () => _setAlign('center')),
      _tbtn(Icons.format_align_left, 'سیدھ — آخر', () => _setAlign('right')),
      _tbtn(Icons.format_align_justify, 'برابر (Justify)',
          () => _setAlign('justify')),
      PopupMenuButton<double>(
        tooltip: 'سطر فاصلہ (Line Spacing)',
        icon: const Icon(Icons.format_line_spacing,
            size: 21, color: AppColors.navy),
        itemBuilder: (ctx) => [
          for (final v in [1.0, 1.15, 1.3, 1.5, 1.8, 2.0, 2.5, 3.0])
            PopupMenuItem(value: v, child: Text('سطر فاصلہ $v')),
        ],
        onSelected: _setLineSpacing,
      ),
      _tbtn(Icons.border_all, 'بارڈرز (Borders)', _paragraphBorders),
      _tbtn(Icons.format_color_fill_outlined, 'شیڈنگ (Shading)', () async {
        if (_activeBlock == null) return;
        final v = await showColorSheet(context, title: 'پیراگراف شیڈنگ');
        setState(() {
          _activeBlock!.shading = v;
          _markDirty();
        });
        _reloadPara(_activeBlock!);
      }),
      const VerticalDivider(width: 14),
      _tbtn(Icons.clear_all, 'خالی لائنیں ختم کریں', _removeEmptyLines),
      _tbtn(Icons.keyboard_tab, 'پہلی سطر کا فاصلہ', _firstLineIndentDialog),
      const VerticalDivider(width: 14),
      _tbtn(Icons.swap_horiz, 'سمت RTL/LTR', _toggleDirection),
      _tbtn(Icons.find_replace, 'تلاش و تبدیل', _findReplace),
    ]);
  }

  Widget _insertToolbar() {
    return _bar([
      _tbtn(Icons.grid_on, 'جدول شامل کریں', _insertTable),
      _tbtn(Icons.auto_stories, 'شعر جدول (صدر | فاصل | عجز)',
          _insertPoetryTable),
      _tbtn(Icons.image, 'تصویر — گیلری',
          () => _insertImage(ImageSource.gallery)),
      _tbtn(Icons.camera_alt, 'تصویر — کیمرہ',
          () => _insertImage(ImageSource.camera)),
      _tbtn(Icons.note_add, 'حاشیہ (Footnote)', _insertFootnote),
      _tbtn(Icons.menu_book, 'آیتِ قرآنی شامل کریں', _insertQuran),
      _tbtn(Icons.emoji_symbols, 'رموز و علامات', _insertSymbol),
      _tbtn(Icons.format_quote, 'حوالہ (Citation)', _insertCitation),
      _tbtn(Icons.insert_page_break, 'صفحہ وقفہ', () {
        _insertBlocks(_insertIndex, [
          ParaBlock([
            {'insert': '\n'}
          ])
            ..pageBreakBefore = true,
        ]);
      }),
      _tbtn(Icons.today, 'آج کی تاریخ', () {
        final now = DateTime.now();
        final s =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        _insertTextAtCursor(s);
      }),
      _tbtn(Icons.add_box, 'نیا پیراگراف بلاک', () {
        _insertBlocks(_insertIndex, [
          ParaBlock([
            {'insert': '\n'}
          ]),
        ]);
      }),
    ]);
  }

  Widget _layoutToolbar() {
    return _bar([
      _tbtn(Icons.description, 'صفحہ ترتیبات', _pageSetup),
      _tbtn(Icons.border_outer, 'صفحہ بارڈر', _pageBorder),
      _tbtn(Icons.space_bar, 'پیراگراف فاصلے', _paragraphSpacing),
      PopupMenuButton<String>(
        tooltip: 'صفحہ سائز',
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Icon(Icons.fit_screen, size: 20, color: AppColors.navy),
            Text(' سائز', style: TextStyle(fontSize: 12.5)),
          ]),
        ),
        itemBuilder: (ctx) => const [
          PopupMenuItem(value: 'A4', child: Text('A4 — 210×297')),
          PopupMenuItem(value: 'A5', child: Text('A5 — 148×210')),
          PopupMenuItem(value: 'Letter', child: Text('Letter — 216×279')),
          PopupMenuItem(value: 'Legal', child: Text('Legal — 216×356')),
        ],
        onSelected: (v) => setState(() {
          switch (v) {
            case 'A5':
              _doc.pageSetup.pageWidthMm = 148;
              _doc.pageSetup.pageHeightMm = 210;
              break;
            case 'Letter':
              _doc.pageSetup.pageWidthMm = 216;
              _doc.pageSetup.pageHeightMm = 279;
              break;
            case 'Legal':
              _doc.pageSetup.pageWidthMm = 216;
              _doc.pageSetup.pageHeightMm = 356;
              break;
            default:
              _doc.pageSetup.pageWidthMm = 210;
              _doc.pageSetup.pageHeightMm = 297;
          }
          _markDirty();
        }),
      ),
      _tbtn(
          Icons.screen_rotation,
          'رخ (Portrait/Landscape)',
          () => setState(() {
                _doc.pageSetup.landscape = !_doc.pageSetup.landscape;
                _markDirty();
              })),
    ]);
  }

  Widget _refsToolbar() {
    return _bar([
      _tbtn(Icons.list_alt, 'حواشی کی فہرست', _footnoteList),
      _tbtn(Icons.note_add, 'نیا حاشیہ', _insertFootnote),
      _tbtn(Icons.format_quote, 'حوالہ شامل کریں', _insertCitation),
      _tbtn(Icons.library_books, 'میرے مصادر', _mySources),
      _tbtn(Icons.collections_bookmark, 'مآخذ و مراجع شامل کریں',
          _insertBibliography),
      _tbtn(Icons.menu_book, 'قرآن سے آیت', _insertQuran),
    ]);
  }

  Widget _viewToolbar() {
    return _bar([
      _tbtn(Icons.picture_as_pdf, 'PDF برآمد', _exportPdf),
      _tbtn(Icons.file_present, 'DOCX برآمد', _exportDocx),
      _tbtn(Icons.share, 'شیئر (DOCX)', () => _exportDocx(share: true)),
      _tbtn(Icons.info_outline, 'دستاویز معلومات', _docInfo),
      _tbtn(Icons.style, 'اسٹائل مینیجر', _openStyleManager),
      _tbtn(Icons.text_fields, 'موجودہ پیراگراف سے اسٹائل اپڈیٹ',
          _updateStyleFromPara),
    ]);
  }

  // ================= اعمال =================
  String _currentFontName() {
    final c = _activeController;
    if (c == null) return 'فونٹ';
    final style = c.getSelectionStyle();
    final f = style.attributes['font']?.value;
    return f is String && f.isNotEmpty ? f : 'فونٹ';
  }

  void _renameDoc() async {
    final ctrl = TextEditingController(text: _doc.title);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('دستاویز کا نام'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('منسوخ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('محفوظ')),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty) {
      setState(() {
        _doc.title = v.trim();
        _markDirty();
      });
    }
  }

  void _clearFormat() {
    final c = _activeController;
    if (c == null) return;
    for (final a in <Attribute>[
      Attribute.bold,
      Attribute.italic,
      Attribute.underline,
      Attribute.strikeThrough,
      const ColorAttribute(null),
      const BackgroundAttribute(null),
      const FontAttribute(null),
      const SizeAttribute(null),
      const ScriptAttributeRaw(null),
    ]) {
      c.formatSelection(a);
    }
  }

  void _toggleList(String type) {
    final c = _activeController;
    if (c == null) return;
    final cur = c.getSelectionStyle().attributes['list']?.value;
    final target = cur == type ? null : type;
    c.formatText(0, c.document.length, ListAttribute(target));
  }

  void _changeIndent(int delta) {
    final c = _activeController;
    if (c == null || _activeBlock == null) return;
    final lines = deltaToLines(_activeBlock!.delta);
    final cur = lines.isEmpty ? 0 : lines.first.indent;
    final next = (cur + delta).clamp(0, 8);
    c.formatText(
        0, c.document.length, IndentAttribute(level: next == 0 ? null : next));
  }

  void _setAlign(String? align) {
    final c = _activeController;
    if (c == null) return;
    c.formatText(0, c.document.length, AlignAttribute(align));
  }

  void _setLineSpacing(double v) {
    final c = _activeController;
    if (c == null) return;
    c.formatText(0, c.document.length, LineHeightAttribute(lineHeight: v));
  }

  void _toggleDirection() {
    final c = _activeController;
    final b = _activeBlock;
    if (c == null || b == null) return;
    setState(() {
      b.rtl = !b.rtl;
      _markDirty();
    });
    c.formatText(
        0, c.document.length, DirectionAttribute(b.rtl ? 'rtl' : 'ltr'));
    _reloadPara(b);
  }

  Future<void> _paragraphBorders() async {
    final b = _activeBlock;
    if (b == null) return;
    final v = await showBordersDialog(context, b.borders);
    if (v != null) {
      setState(() {
        b.borders = v.isEmpty ? null : v;
        _markDirty();
      });
      _reloadPara(b);
    }
  }

  Future<void> _paragraphSpacing() async {
    final b = _activeBlock;
    if (b == null) return;
    var sb = b.spaceBeforePt, sa = b.spaceAfterPt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('پیراگراف فاصلے'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Expanded(child: Text('قبل (pt)')),
                IconButton(
                    onPressed: () => setS(() => sb = (sb - 2).clamp(0, 72)),
                    icon: const Icon(Icons.remove_circle_outline)),
                Text('$sb'),
                IconButton(
                    onPressed: () => setS(() => sb = (sb + 2).clamp(0, 72)),
                    icon: const Icon(Icons.add_circle_outline)),
              ]),
              Row(children: [
                const Expanded(child: Text('بعد (pt)')),
                IconButton(
                    onPressed: () => setS(() => sa = (sa - 2).clamp(0, 72)),
                    icon: const Icon(Icons.remove_circle_outline)),
                Text('$sa'),
                IconButton(
                    onPressed: () => setS(() => sa = (sa + 2).clamp(0, 72)),
                    icon: const Icon(Icons.add_circle_outline)),
              ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('منسوخ')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('لاگو')),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() {
        b.spaceBeforePt = sb;
        b.spaceAfterPt = sa;
        _markDirty();
      });
      _reloadPara(b);
    }
  }

  void _applyStyle(String styleId) {
    final b = _activeBlock;
    final c = _activeController;
    if (b == null || c == null) return;
    final styles = _stylesList();
    final st = resolveStyle(styles, styleId);
    setState(() {
      b.styleId = styleId;
      b.rtl = st.rtl;
      b.spaceBeforePt = st.spaceBeforePt;
      b.spaceAfterPt = st.spaceAfterPt;
      b.shading = st.shading ?? b.shading;
      if (st.borders != null) b.borders = st.borders;
      _markDirty();
    });
    final len = c.document.length;
    c.formatText(
        0,
        len,
        AlignAttribute(st.align == 'start'
            ? null
            : (st.align == 'end' ? 'right' : st.align)));
    c.formatText(0, len, LineHeightAttribute(lineHeight: st.lineSpacing));
    c.formatText(0, len, DirectionAttribute(st.rtl ? 'rtl' : 'ltr'));
    final headerLevel = switch (styleId) {
      'Heading1' || 'Title' => 1,
      'Heading2' || 'Subtitle' => 2,
      'Heading3' => 3,
      _ => null,
    };
    c.formatText(0, len, HeaderAttribute(level: headerLevel));
    _reloadPara(b);
  }

  void _updateStyleFromPara() {
    final b = _activeBlock;
    final c = _activeController;
    if (b == null || c == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پہلے کوئی پیراگراف منتخب کریں')));
      return;
    }
    final styles = _stylesList();
    final idx = styles.indexWhere((s) => s.id == b.styleId);
    if (idx < 0) return;
    final st = styles[idx];
    final selStyle = c.getSelectionStyle();
    final lines = deltaToLines(b.delta);
    final firstAttrs =
        lines.isEmpty ? const <String, dynamic>{} : lines.first.lineAttrs;
    st
      ..rtl = b.rtl
      ..spaceBeforePt = b.spaceBeforePt
      ..spaceAfterPt = b.spaceAfterPt
      ..shading = b.shading
      ..borders = b.borders
      ..align = (firstAttrs['align'] as String?) ?? 'start'
      ..lineSpacing =
          (firstAttrs['lineHeight'] as num?)?.toDouble() ?? st.lineSpacing;
    final f = selStyle.attributes['font']?.value;
    if (f is String && f.isNotEmpty) st.fontFamily = f;
    final sz = selStyle.attributes['size']?.value;
    if (sz != null) st.fontSize = double.tryParse(sz.toString()) ?? st.fontSize;
    st.bold = selStyle.attributes['bold']?.value == true;
    st.italic = selStyle.attributes['italic']?.value == true;
    _doc.styles = styles.map((s) => s.toJson()).toList();
    _invalidateStyles();
    if (st.inTemplate) {
      TemplateStyles.save(styles);
    }
    setState(_markDirty);
    // اس اسٹائل کے تمام پیراگراف تازہ کریں
    for (final blk in _doc.blocks.whereType<ParaBlock>()) {
      if (blk.styleId == st.id) _reloadPara(blk);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'اسٹائل «${st.name}» اپڈیٹ ہو گیا — تمام متعلقہ پیراگراف تازہ')));
  }

  Future<void> _openStyleManager() async {
    final styles = _stylesList();
    final usage = <String, int>{};
    for (final b in _doc.blocks.whereType<ParaBlock>()) {
      usage[b.styleId] = (usage[b.styleId] ?? 0) + 1;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StyleManagerScreen(
          styles: styles,
          usage: usage,
          onChanged: (updated) {
            // حذف شدہ اسٹائل کے پیراگراف Normal میں
            final ids = updated.map((s) => s.id).toSet();
            for (final b in _doc.blocks.whereType<ParaBlock>()) {
              if (!ids.contains(b.styleId)) b.styleId = 'Normal';
            }
            _doc.styles = updated.map((s) => s.toJson()).toList();
            _invalidateStyles();
            TemplateStyles.save(updated);
            setState(_markDirty);
            _reloadAllParas();
          },
        ),
      ),
    );
  }

  // ---------- انسرٹ اعمال ----------
  void _insertTextAtCursor(String text) {
    final c = _activeController;
    if (c == null) return;
    final sel = c.selection;
    c.replaceText(sel.start, sel.end - sel.start, text, null);
  }

  Future<void> _insertSymbol() async {
    final item = await showSymbolsSheet(context);
    if (item == null || _activeController == null) return;
    final c = _activeController!;
    final sel = c.selection;
    c.replaceText(sel.start, sel.end - sel.start, item.insert, null);
    if (item.fontFamily != null) {
      c.formatText(
          sel.start, item.insert.length, FontAttribute(item.fontFamily));
    }
    if (item.cursorBetween && item.insert.length >= 2) {
      c.updateSelection(
          TextSelection.collapsed(offset: sel.start + item.insert.length - 1),
          ChangeSource.local);
    }
  }

  Future<void> _insertTable() async {
    final v = await showInsertTableDialog(context);
    if (v == null) return;
    final rows =
        List.generate(v.$1, (_) => List.generate(v.$2, (_) => TableCell()));
    _insertBlocks(_insertIndex, [TableBlock(rows)]);
  }

  void _insertPoetryTable() {
    TableCell cell(String t, {bool bold = false, String align = 'center'}) =>
        TableCell()
          ..text = t
          ..bold = bold
          ..align = align;
    final rows = <List<TableCell>>[
      [
        cell('صدر', bold: true),
        cell('فاصل', bold: true),
        cell('عجز', bold: true)
      ],
      for (var i = 0; i < 4; i++) [cell(''), cell(''), cell('')],
    ];
    final t = TableBlock(rows)
      ..headerRow = true
      ..borderPreset = 'internal';
    _insertBlocks(_insertIndex, [t]);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('شعر جدول شامل — صدر | فاصل | عجز (إثراء المتون طرز)')));
  }

  Future<void> _insertImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? xf = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (xf == null) return;
    final mediaDir = Directory(p.join(_docDir, 'media'));
    await mediaDir.create(recursive: true);
    final ext = p.extension(xf.path).isEmpty ? '.jpg' : p.extension(xf.path);
    final name = 'img${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(xf.path).copy(p.join(mediaDir.path, name));
    _insertBlocks(_insertIndex, [ImageBlock('media/$name')]);
  }

  Future<void> _insertFootnote() async {
    if (_activeController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پہلے کسی پیراگراف میں کرسر رکھیں')));
      return;
    }
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نیا حاشیہ'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'حاشیے کا متن…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('منسوخ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('شامل کریں')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final fn = KFootnote(_doc.nextFootnoteId++, text.trim());
    setState(() {
      _doc.footnotes.add(fn);
      _markDirty();
    });
    final c = _activeController!;
    final sel = c.selection;
    // عارضی marker — renumber درست نمبر لگائے گا
    c.replaceText(sel.start, sel.end - sel.start, '¹', null);
    c.formatText(sel.start, 1, FootnoteAttribute(fn.id));
    _renumberFootnoteMarkers();
  }

  void _renumberFootnoteMarkers() {
    var n = 0;
    for (final b in _doc.blocks.whereType<ParaBlock>()) {
      var changed = false;
      for (final op in b.delta) {
        if (op is Map) {
          final attrs = op['attributes'] as Map<String, dynamic>?;
          if (attrs != null && attrs.containsKey('fnote')) {
            n++;
            final correct = superscriptNum(n);
            if (op['insert'] != correct) {
              op['insert'] = correct;
              changed = true;
            }
          }
        }
      }
      if (changed) _reloadPara(b);
    }
  }

  Future<void> _footnoteList() async {
    await showFootnoteListSheet(
      context,
      footnotes: _doc.footnotes,
      onEdit: (i, text) async {
        setState(() {
          _doc.footnotes[i].text = text;
          _markDirty();
        });
      },
      onDelete: (i) async {
        final id = _doc.footnotes[i].id;
        setState(() {
          _doc.footnotes.removeAt(i);
          // marker runs حذف
          for (final b in _doc.blocks.whereType<ParaBlock>()) {
            b.delta.removeWhere((op) =>
                op is Map &&
                (op['attributes'] as Map<String, dynamic>?)?['fnote'] == id);
            if (b.delta.isEmpty) {
              b.delta = [
                {'insert': '\n'}
              ];
            }
            _reloadPara(b);
          }
          _markDirty();
        });
        _renumberFootnoteMarkers();
      },
    );
  }

  Future<void> _insertQuran() async {
    final blocks = await Navigator.push<List<ParaBlock>>(
      context,
      MaterialPageRoute(builder: (_) => const QuranScreen(pickMode: true)),
    );
    if (blocks != null && blocks.isNotEmpty) {
      _insertBlocks(_insertIndex, blocks);
    }
  }

  Future<void> _insertCitation() async {
    final result = await showCitationForm(context);
    if (result == null) return;
    final (cit, saveToLib) = result;
    if (saveToLib) await CitationStore.add(cit);
    setState(() {
      _doc.usedCitations.add(cit);
      _markDirty();
    });
    // حوالہ فٹ نوٹ کے طور پر داخل (native روایت)
    if (_activeController != null) {
      final fn = KFootnote(_doc.nextFootnoteId++, formatCitation(cit));
      setState(() => _doc.footnotes.add(fn));
      final c = _activeController!;
      final sel = c.selection;
      c.replaceText(sel.start, sel.end - sel.start, '¹', null);
      c.formatText(sel.start, 1, FootnoteAttribute(fn.id));
      _renumberFootnoteMarkers();
    }
  }

  Future<void> _mySources() async {
    final sources = await CitationStore.all();
    if (!mounted) return;
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('کوئی محفوظ مصدر نہیں')));
      return;
    }
    final picked = await showModalBottomSheet<Citation>(
      context: context,
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        itemCount: sources.length,
        itemBuilder: (ctx, i) => ListTile(
          title: Text(formatCitation(sources[i])),
          onTap: () => Navigator.pop(ctx, sources[i]),
        ),
      ),
    );
    if (picked != null && _activeController != null) {
      setState(() => _doc.usedCitations.add(picked));
      final fn = KFootnote(_doc.nextFootnoteId++, formatCitation(picked));
      setState(() => _doc.footnotes.add(fn));
      final c = _activeController!;
      final sel = c.selection;
      c.replaceText(sel.start, sel.end - sel.start, '¹', null);
      c.formatText(sel.start, 1, FootnoteAttribute(fn.id));
      _renumberFootnoteMarkers();
    }
  }

  void _insertBibliography() {
    final entries =
        _doc.usedCitations.isNotEmpty ? _doc.usedCitations : <Citation>[];
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('اس دستاویز میں ابھی کوئی حوالہ استعمال نہیں ہوا')));
      return;
    }
    ParaBlock para(String text,
        {String style = 'Bibliography', bool rtl = true}) {
      return ParaBlock([
        {'insert': text},
        {'insert': '\n'}
      ])
        ..styleId = style
        ..rtl = rtl;
    }

    final blocks = <KBlock>[
      para('مآخذ و مراجع', style: 'Heading1'),
      for (final e in entries) para(formatCitation(e)),
    ];
    _insertBlocks(_doc.blocks.length, blocks);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مآخذ و مراجع آخر میں شامل کر دیے گئے')));
  }

  // ---------- خالی لائنیں ختم + پہلی سطر کا فاصلہ (ہوم ٹیب) ----------

  /// Delta کو سطروں میں توڑیں — ہر سطر کے ساتھ اس کے '\n' والے op کے attrs
  static (List<List<(String, Map<String, dynamic>?)>>,
      List<Map<String, dynamic>?>) _splitLines(List<dynamic> delta) {
    final lines = <List<(String, Map<String, dynamic>?)>>[];
    final lineAttrs = <Map<String, dynamic>?>[];
    var cur = <(String, Map<String, dynamic>?)>[];
    for (final op in delta) {
      if (op is! Map || op['insert'] is! String) continue;
      final attrs = op['attributes'] as Map<String, dynamic>?;
      final text = op['insert'] as String;
      var rest = text;
      while (true) {
        final idx = rest.indexOf('\n');
        if (idx < 0) {
          if (rest.isNotEmpty) cur.add((rest, attrs));
          break;
        }
        if (idx > 0) cur.add((rest.substring(0, idx), attrs));
        lines.add(cur);
        lineAttrs.add(attrs);
        cur = <(String, Map<String, dynamic>?)>[];
        rest = rest.substring(idx + 1);
        if (rest.isEmpty) break;
      }
    }
    if (cur.isNotEmpty) {
      lines.add(cur);
      lineAttrs.add(null);
    }
    return (lines, lineAttrs);
  }

  /// خالی سطریں حذف کر کے نیا delta — سطر attrs محفوظ رکھ کر
  List<dynamic> _stripEmptyLines(List<dynamic> delta) {
    final (lines, lineAttrs) = _splitLines(delta);
    final out = <dynamic>[];
    var kept = 0;
    for (var i = 0; i < lines.length; i++) {
      final text = lines[i].map((r) => r.$1).join();
      if (text.trim().isEmpty) continue; // خالی سطر — حذف
      kept++;
      StringBuffer? buf;
      Map<String, dynamic>? bufAttrs;
      void flush() {
        final b = buf;
        final a = bufAttrs;
        if (b != null && b.isNotEmpty) {
          out.add({
            'insert': b.toString(),
            if (a != null && a.isNotEmpty) 'attributes': a,
          });
        }
        buf = null;
      }

      for (final (run, attrs) in lines[i]) {
        if (buf != null && _attrsEqual(bufAttrs, attrs)) {
          buf!.write(run);
        } else {
          flush();
          buf = StringBuffer(run);
          bufAttrs = attrs;
        }
      }
      flush();
      final la = lineAttrs[i];
      out.add({
        'insert': '\n',
        if (la != null && la.isNotEmpty) 'attributes': la,
      });
    }
    if (kept == 0) return [
      {'insert': '\n'}
    ];
    return out;
  }

  Future<void> _removeEmptyLines() async {
    _syncAllDeltas();
    final paras = _doc.blocks.whereType<ParaBlock>().toList();
    var emptyBlocks = 0;
    var emptyLines = 0;
    for (final b in paras) {
      if (b.plainText.trim().isEmpty) {
        emptyBlocks++;
      } else {
        final (lines, _) = _splitLines(b.delta);
        for (final ln in lines) {
          if (ln.map((r) => r.$1).join().trim().isEmpty) emptyLines++;
        }
      }
    }
    final total = emptyBlocks + emptyLines;
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کوئی خالی لائن نہیں ملی')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('خالی لائنیں ختم کریں'),
        content: Text(
            'پوری دستاویز میں $total خالی لائنیں ملیں (خالی پیراگراف: $emptyBlocks، پیراگرافوں کے اندر خالی سطریں: $emptyLines)۔ انہیں حذف کر دیا جائے؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('منسوخ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ختم کریں')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      // خالی پیراگراف بلاکس حذف — کم از کم ایک بلاک ضرور رہے
      final empties =
          paras.where((b) => b.plainText.trim().isEmpty).toList();
      final keepOne = empties.length >= _doc.blocks.length;
      for (var i = 0; i < empties.length; i++) {
        if (keepOne && i == 0) continue;
        _doc.blocks.remove(empties[i]);
      }
      for (final b in _doc.blocks.whereType<ParaBlock>()) {
        b.delta = _stripEmptyLines(b.delta);
      }
      _markDirty();
    });
    _paraKeys.removeWhere((k, _) => !_doc.blocks.contains(k));
    _reloadAllParas();
    _refreshCounts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$total خالی لائنیں ختم ہو گئیں')));
    }
  }

  Future<void> _firstLineIndentDialog() async {
    final b = _activeBlock;
    if (b == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پہلے کوئی پیراگراف منتخب کریں')));
      return;
    }
    var value = b.firstLineIndentPt;
    var applyAll = false;
    const presets = [0.0, 12.0, 18.0, 24.0, 36.0, 48.0];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('پہلی سطر کا فاصلہ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'پیراگراف کی پہلی سطر شروع میں اتنا اندر سے شروع ہوگی (جیسے اردو کتب میں ہوتا ہے)۔'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in presets)
                    ChoiceChip(
                      label: Text(p == 0 ? 'بغیر' : '${p.toInt()} pt'),
                      selected: value == p,
                      onSelected: (_) => setS(() => value = p),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(child: Text('تمام پیراگرافوں پر لاگو کریں')),
                Switch(
                    value: applyAll,
                    onChanged: (v) => setS(() => applyAll = v)),
              ]),
              const Text(
                'نوٹ: Word (DOCX) فائل میں یہ اصل first-line indent کے طور پر محفوظ ہوگا۔',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('منسوخ')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('لاگو')),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() {
        if (applyAll) {
          for (final blk in _doc.blocks.whereType<ParaBlock>()) {
            blk.firstLineIndentPt = value;
          }
        } else {
          b.firstLineIndentPt = value;
        }
        _markDirty();
      });
      _reloadAllParas();
    }
  }

  // ---------- تلاش و تبدیل ----------
  Future<void> _findReplace() async {
    _syncAllDeltas();
    // گنتی کے لیے دستاویز کا متن ایک بار جوڑیں — ہر حرف پر پورا اسکین نہیں
    final allText = _doc.blocks
        .whereType<ParaBlock>()
        .map((b) => b.plainText)
        .join('\n');
    final qCtrl = TextEditingController();
    final rCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final count = qCtrl.text.isEmpty
              ? 0
              : qCtrl.text.allMatches(allText).length;
          return AlertDialog(
            title: const Text('تلاش و تبدیل'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qCtrl,
                  decoration: const InputDecoration(labelText: 'تلاش کریں'),
                  onChanged: (_) => setS(() {}),
                ),
                TextField(
                  controller: rCtrl,
                  decoration: const InputDecoration(labelText: 'تبدیل کر کے'),
                ),
                const SizedBox(height: 10),
                Text('موجودگیاں: $count',
                    style: const TextStyle(color: AppColors.inkSoft)),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('بند کریں')),
              FilledButton(
                onPressed: qCtrl.text.isEmpty
                    ? null
                    : () {
                        var total = 0;
                        for (final b in _doc.blocks.whereType<ParaBlock>()) {
                          final (nd, n) =
                              _replaceInDelta(b.delta, qCtrl.text, rCtrl.text);
                          if (n > 0) {
                            b.delta = nd;
                            total += n;
                            _reloadPara(b);
                          }
                        }
                        setState(_markDirty);
                        _refreshCounts();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$total جگہ تبدیل ہو گیا')));
                        Navigator.pop(ctx);
                      },
                child: const Text('تمام تبدیل کریں'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Delta کے اندر متن تبدیل — حرف بہ حرف attrs محفوظ رکھ کر (ایک قدم میں،
  /// تاکہ formatting ضائع نہ ہو)
  (List<dynamic>, int) _replaceInDelta(
      List<dynamic> delta, String query, String replacement) {
    // حروف کی فہرست (متن + attrs)
    final chars = <(String, Map<String, dynamic>?)>[];
    for (final op in delta) {
      if (op is Map && op['insert'] is String) {
        final attrs = op['attributes'] as Map<String, dynamic>?;
        final text = op['insert'] as String;
        for (final ch in text.split('')) {
          chars.add((ch, attrs));
        }
      }
    }
    final plain = chars.map((c) => c.$1).join();
    var count = 0;
    var from = 0;
    final out = <(String, Map<String, dynamic>?)>[];
    while (true) {
      final idx = plain.indexOf(query, from);
      if (idx < 0) {
        out.addAll(chars.sublist(from));
        break;
      }
      out.addAll(chars.sublist(from, idx));
      final repAttrs = idx < chars.length ? chars[idx].$2 : null;
      for (final ch in replacement.split('')) {
        out.add((ch, repAttrs));
      }
      count++;
      from = idx + query.length;
      if (from >= chars.length) break;
    }
    if (count == 0) return (delta, 0);
    // دوبارہ ops بنائیں — یکساں attrs والے حروف یکجا
    final ops = <dynamic>[];
    StringBuffer? buf;
    Map<String, dynamic>? bufAttrs;
    void flush() {
      final bb = buf;
      if (bb != null && bb.isNotEmpty) {
        ops.add({
          'insert': bb.toString(),
          if (bufAttrs != null && bufAttrs.isNotEmpty) 'attributes': bufAttrs,
        });
      }
      buf = null;
    }

    for (final (ch, attrs) in out) {
      if (buf != null && _attrsEqual(bufAttrs, attrs)) {
        buf!.write(ch);
      } else {
        flush();
        buf = StringBuffer(ch);
        bufAttrs = attrs;
      }
    }
    flush();
    // سطر attrs (آخری '\n' والا op) محفوظ رکھیں: اصل delta کے ہر newline op کی
    // جگہ — سادہ صورت: اگر نتیجے میں '\n' موجود نہیں تو اصل کا آخری op شامل کریں
    final hasNl = ops.any((o) => (o['insert'] as String).contains('\n'));
    if (!hasNl) ops.add({'insert': '\n'});
    return (ops, count);
  }

  bool _attrsEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }

  // ---------- جدول/تصویر/بلاک مینو ----------
  void _editCell(TableCell cell) async {
    final ctrl = TextEditingController(text: cell.text);
    var bold = cell.bold;
    var align = cell.align;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('سیل ترمیم'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: ctrl, maxLines: 4, autofocus: true),
              Row(
                children: [
                  const Text('بولڈ'),
                  Switch(value: bold, onChanged: (v) => setS(() => bold = v)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: align,
                    items: const [
                      DropdownMenuItem(value: 'start', child: Text('شروع')),
                      DropdownMenuItem(value: 'center', child: Text('درمیان')),
                      DropdownMenuItem(value: 'end', child: Text('آخر')),
                    ],
                    onChanged: (v) => setS(() => align = v!),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.format_color_fill),
                      label: const Text('سیل شیڈنگ'),
                      onPressed: () async {
                        final v =
                            await showColorSheet(context, title: 'سیل شیڈنگ');
                        setState(() => cell.shading = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.border_all),
                      label: Text(cell.borderAll == null
                          ? 'سیل بارڈر: جدول جیسا'
                          : 'سیل بارڈر: فعال'),
                      onPressed: () async {
                        final v = await showBordersDialog(
                            context,
                            cell.borderAll == null
                                ? null
                                : EdgeBorders.box(cell.borderAll!));
                        setState(() {
                          cell.borderAll = (v == null || v.isEmpty)
                              ? null
                              : (v.top ?? BorderSpec());
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('منسوخ')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('محفوظ')),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() {
        cell.text = ctrl.text;
        cell.bold = bold;
        cell.align = align;
        _markDirty();
      });
    }
  }

  void _tableMenu(TableBlock t) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.post_add),
            title: const Text('سطر نیچے شامل'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                t.rows.insert(
                    _lastRow + 1, List.generate(t.cols, (_) => TableCell()));
                _markDirty();
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.view_column),
            title: const Text('کالم شامل'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                for (final r in t.rows) {
                  r.insert((_lastCol + 1).clamp(0, r.length), TableCell());
                }
                _markDirty();
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('موجودہ سطر حذف'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                if (t.rows.length > 1)
                  t.rows.removeAt(_lastRow.clamp(0, t.rows.length - 1));
                _markDirty();
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('موجودہ کالم حذف'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                if (t.cols > 1) {
                  for (final r in t.rows) {
                    r.removeAt(_lastCol.clamp(0, r.length - 1));
                  }
                }
                _markDirty();
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.view_headline),
            title:
                Text(t.headerRow ? 'ہیڈر سطر بند کریں' : 'ہیڈر سطر فعال کریں'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                t.headerRow = !t.headerRow;
                _markDirty();
              });
            },
          ),
          for (final (key, label) in [
            ('grid', 'بارڈر: مکمل گرڈ'),
            ('box', 'بارڈر: صرف بیرونی باکس'),
            ('internal', 'بارڈر: صرف اندرونی'),
            ('none', 'بارڈر: کوئی نہیں'),
          ])
            ListTile(
              leading: const Icon(Icons.border_all),
              title: Text(label),
              trailing: t.borderPreset == key ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  t.borderPreset = key;
                  _markDirty();
                });
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('پورا جدول حذف',
                style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _doc.blocks.remove(t);
                _markDirty();
              });
            },
          ),
        ],
      ),
    );
  }

  void _imageMenu(ImageBlock b, int index) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تصویر',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('چوڑائی: ${(b.widthFrac * 100).round()}%'),
              Slider(
                value: b.widthFrac,
                min: 0.25,
                max: 1.0,
                divisions: 15,
                onChanged: (v) => setS(() {
                  b.widthFrac = v;
                  setState(_markDirty);
                }),
              ),
              TextField(
                controller: TextEditingController(text: b.caption),
                decoration: const InputDecoration(labelText: 'کیپشن'),
                onChanged: (v) {
                  b.caption = v;
                  setState(_markDirty);
                },
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('تصویر حذف',
                    style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _doc.blocks.removeAt(index);
                    _markDirty();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _blockMenu(int index) {
    final b = _doc.blocks[index];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.vertical_align_top),
            title: const Text('اوپر پیراگراف شامل'),
            onTap: () {
              Navigator.pop(ctx);
              _insertBlocks(index, [
                ParaBlock([
                  {'insert': '\n'}
                ])
              ]);
            },
          ),
          ListTile(
            leading: const Icon(Icons.vertical_align_bottom),
            title: const Text('نیچے پیراگراف شامل'),
            onTap: () {
              Navigator.pop(ctx);
              _insertBlocks(index + 1, [
                ParaBlock([
                  {'insert': '\n'}
                ])
              ]);
            },
          ),
          ListTile(
            leading: const Icon(Icons.arrow_upward),
            title: const Text('بلاک اوپر لے جائیں'),
            onTap: () {
              Navigator.pop(ctx);
              if (index > 0) {
                setState(() {
                  final it = _doc.blocks.removeAt(index);
                  _doc.blocks.insert(index - 1, it);
                  _markDirty();
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.arrow_downward),
            title: const Text('بلاک نیچے لے جائیں'),
            onTap: () {
              Navigator.pop(ctx);
              if (index < _doc.blocks.length - 1) {
                setState(() {
                  final it = _doc.blocks.removeAt(index);
                  _doc.blocks.insert(index + 1, it);
                  _markDirty();
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('بلاک حذف کریں',
                style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                if (_doc.blocks.length > 1) _doc.blocks.remove(b);
                _markDirty();
              });
            },
          ),
        ],
      ),
    );
  }

  // ---------- لے آؤٹ ----------
  Future<void> _pageBorder() async {
    final v = await showPageBorderDialog(context, _doc.pageSetup.pageBorder,
        _doc.pageSetup.pageBorderOffsetFrom);
    if (v != null) {
      setState(() {
        _doc.pageSetup.pageBorder = v.$1;
        _doc.pageSetup.pageBorderOffsetFrom = v.$2;
        _markDirty();
      });
    }
  }

  Future<void> _pageSetup() async {
    final ps = _doc.pageSetup;
    final hCtrl = TextEditingController(text: ps.headerText);
    final fCtrl = TextEditingController(text: ps.footerText);
    final mT = TextEditingController(text: ps.marginTopMm.toString());
    final mB = TextEditingController(text: ps.marginBottomMm.toString());
    final mL = TextEditingController(text: ps.marginLeftMm.toString());
    final mR = TextEditingController(text: ps.marginRightMm.toString());
    var pageNumbers = ps.pageNumbers;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('صفحہ ترتیبات'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: hCtrl,
                    decoration:
                        const InputDecoration(labelText: 'سرورق متن (Header)')),
                TextField(
                    controller: fCtrl,
                    decoration:
                        const InputDecoration(labelText: 'پاورق متن (Footer)')),
                SwitchListTile(
                  title: const Text('صفحہ نمبر'),
                  value: pageNumbers,
                  onChanged: (v) => setS(() => pageNumbers = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                Wrap(spacing: 8, children: [
                  ActionChip(
                    label: const Text('حاشیے: عام'),
                    onPressed: () => setS(() {
                      mT.text = mB.text = mL.text = mR.text = '25.4';
                    }),
                  ),
                  ActionChip(
                    label: const Text('تنگ'),
                    onPressed: () => setS(() {
                      mT.text = mB.text = mL.text = mR.text = '12.7';
                    }),
                  ),
                  ActionChip(
                    label: const Text('وسیع'),
                    onPressed: () => setS(() {
                      mT.text = mB.text = '25.4';
                      mL.text = mR.text = '50.8';
                    }),
                  ),
                ]),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: mT,
                          decoration:
                              const InputDecoration(labelText: 'اوپر mm'),
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: mB,
                          decoration:
                              const InputDecoration(labelText: 'نیچے mm'),
                          keyboardType: TextInputType.number)),
                ]),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: mL,
                          decoration:
                              const InputDecoration(labelText: 'بائیں mm'),
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: mR,
                          decoration:
                              const InputDecoration(labelText: 'دائیں mm'),
                          keyboardType: TextInputType.number)),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('منسوخ')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('محفوظ')),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() {
        ps.headerText = hCtrl.text;
        ps.footerText = fCtrl.text;
        ps.pageNumbers = pageNumbers;
        ps.marginTopMm = double.tryParse(mT.text) ?? ps.marginTopMm;
        ps.marginBottomMm = double.tryParse(mB.text) ?? ps.marginBottomMm;
        ps.marginLeftMm = double.tryParse(mL.text) ?? ps.marginLeftMm;
        ps.marginRightMm = double.tryParse(mR.text) ?? ps.marginRightMm;
        _markDirty();
      });
    }
  }

  void _docInfo() {
    var chars = 0, paras = 0, tables = 0, images = 0;
    for (final b in _doc.blocks) {
      if (b is ParaBlock) {
        paras++;
        chars += b.plainText.length;
      } else if (b is TableBlock) {
        tables++;
      } else if (b is ImageBlock) {
        images++;
      }
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('دستاویز معلومات'),
        content: Text(
            'عنوان: ${_doc.title}\nالفاظ: ${_doc.wordCount()}\nحروف: $chars\n'
            'پیراگراف بلاک: $paras\nجداول: $tables\nتصاویر: $images\n'
            'حواشی: ${_doc.footnotes.length}\nحوالہ جات: ${_doc.usedCitations.length}\n'
            'آخری تبدیلی: ${_doc.modified}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('بند کریں')),
        ],
      ),
    );
  }

  // ---------- برآمد ----------
  Future<Map<String, List<int>>> _collectMedia() async {
    final media = <String, List<int>>{};
    final dir = DocStore.docDir(_doc.id);
    for (final b in _doc.blocks.whereType<ImageBlock>()) {
      final f = File(p.join(dir.path, b.relPath));
      if (await f.exists()) media[b.relPath] = await f.readAsBytes();
    }
    return media;
  }

  Future<File> _exportDocxFile() async {
    await _save(silent: true);
    final media = await _collectMedia();
    final result = await compute(
      (Map<String, dynamic> input) => buildDocx(
        input['doc'] as Map<String, dynamic>,
        (input['media'] as Map<String, List<int>>),
      ),
      {'doc': _doc.toJson(), 'media': media},
    );
    final dir = await Directory.systemTemp.createTemp('kanz_export');
    final safe = _doc.title.replaceAll(RegExp(r'[^\w\u0600-\u06FF -]'), '_');
    final f = File(p.join(dir.path, '$safe.docx'));
    await f.writeAsBytes(result.bytes, flush: true);
    if (result.warnings.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.warnings.join('؛ '))));
    }
    return f;
  }

  Future<void> _exportDocx({bool share = false}) async {
    try {
      final f = await _exportDocxFile();
      if (share) {
        await Share.shareXFiles([XFile(f.path)], text: _doc.title);
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('DOCX تیار: ${f.path}')));
        await Share.shareXFiles([XFile(f.path)], text: _doc.title);
      }
    } catch (e) {
      await CrashLog.log(e, StackTrace.current);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('برآمد ناکام: $e')));
      }
    }
  }

  Future<void> _exportPdf() async {
    BuildContext? dialogCtx;
    try {
      await _save(silent: true);
      // پیش رفت ڈائیلاگ — لمبی دستاویز پر ایپ ہینگ ہوئی نہیں لگے گی
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            dialogCtx = ctx;
            return const AlertDialog(
              content: Row(children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('PDF تیار ہو رہی ہے…')),
              ]),
            );
          },
        );
      }
      final bytes = await buildPdf(_doc, DocStore.docDir(_doc.id).path);
      if (dialogCtx != null && dialogCtx!.mounted) {
        Navigator.pop(dialogCtx!);
      }
      final dir = await Directory.systemTemp.createTemp('kanz_pdf');
      final safe = _doc.title.replaceAll(RegExp(r'[^\w\u0600-\u06FF -]'), '_');
      final f = File(p.join(dir.path, '$safe.pdf'));
      await f.writeAsBytes(bytes, flush: true);
      if (mounted) {
        await Share.shareXFiles([XFile(f.path)], text: _doc.title);
      }
    } catch (e) {
      if (dialogCtx != null && dialogCtx!.mounted) {
        Navigator.pop(dialogCtx!);
      }
      await CrashLog.log(e, StackTrace.current);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF ناکام: $e')));
      }
    }
  }
}

/// ScriptAttribute کا null-قدر والا متبادل (clear format کے لیے)
class ScriptAttributeRaw extends Attribute<String?> {
  const ScriptAttributeRaw(String? v)
      : super('script', AttributeScope.inline, v);
}

/// حوالہ فارم — native کے 10 ٹیمپلیٹس؛ نتیجہ: (Citation, لائبریری میں محفوظ؟)
Future<(Citation, bool)?> showCitationForm(BuildContext context,
    {String initialType = 'book'}) async {
  var type = initialType;
  var save = true;
  final ctrls = <String, TextEditingController>{
    'author': TextEditingController(),
    'title': TextEditingController(),
    'editor': TextEditingController(),
    'publisher': TextEditingController(),
    'place': TextEditingController(),
    'year': TextEditingController(),
    'volume': TextEditingController(),
    'page': TextEditingController(),
    'edition': TextEditingController(),
    'url': TextEditingController(),
    'notes': TextEditingController(),
  };
  final labels = {
    'author': 'مصنف',
    'title': 'کتاب/عنوان (قرآن: سورۃ)',
    'editor': 'محقق/مدیر',
    'publisher': 'ناشر',
    'place': 'مقامِ طبع',
    'year': 'سنِ طبع',
    'volume': 'جلد',
    'page': 'صفحہ (حدیث: نمبر؛ قرآن: آیت)',
    'edition': 'طبع',
    'url': 'لنک (URL)',
    'notes': 'نوٹ',
  };
  return showDialog<(Citation, bool)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('حوالہ شامل کریں'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'حوالے کی قسم'),
                  items: [
                    for (final e in citationTypeLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setS(() => type = v!),
                ),
                for (final k in ctrls.keys)
                  TextField(
                    controller: ctrls[k],
                    decoration: InputDecoration(labelText: labels[k]),
                  ),
                SwitchListTile(
                  title: const Text('میرے مصادر میں محفوظ کریں'),
                  value: save,
                  onChanged: (v) => setS(() => save = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('منسوخ')),
          FilledButton(
            onPressed: () {
              final c = Citation()
                ..type = type
                ..author = ctrls['author']!.text
                ..title = ctrls['title']!.text
                ..editor = ctrls['editor']!.text
                ..publisher = ctrls['publisher']!.text
                ..place = ctrls['place']!.text
                ..year = ctrls['year']!.text
                ..volume = ctrls['volume']!.text
                ..page = ctrls['page']!.text
                ..edition = ctrls['edition']!.text
                ..url = ctrls['url']!.text
                ..notes = ctrls['notes']!.text;
              Navigator.pop(ctx, (c, save));
            },
            child: const Text('فٹ نوٹ میں داخل کریں'),
          ),
        ],
      ),
    ),
  );
}
