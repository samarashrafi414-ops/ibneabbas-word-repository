// بلاک وِجٹس — ہر پیراگراف کا اپنا QuillEditor (block-local state تاکہ ایک
// حرف کی تبدیلی پر پوری دستاویز rebuild نہ ہو)، جدول و تصویر کے وِجٹس۔
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart' hide TableCell;
import 'package:flutter_quill/flutter_quill.dart';
import '../core/font_catalog.dart';
import '../core/theme.dart';
import '../model/model.dart';
import '../model/styles.dart';

typedef ParaActivate = void Function(
    QuillController controller, ParaBlock block, VoidCallback refresh);

class ParaBlockWidget extends StatefulWidget {
  final ParaBlock block;
  final List<KStyle> styles;
  final ParaActivate onActivate;
  final VoidCallback onChanged;
  final VoidCallback onBlockMenu;
  const ParaBlockWidget({
    super.key,
    required this.block,
    required this.styles,
    required this.onActivate,
    required this.onChanged,
    required this.onBlockMenu,
  });
  @override
  State<ParaBlockWidget> createState() => ParaBlockWidgetState();
}

class ParaBlockWidgetState extends State<ParaBlockWidget> {
  late final QuillController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  bool _suppress = false;
  Timer? _syncTimer;
  List<KStyle>? _resolvedFor;
  final _resolvedCache = <String, KStyle>{};

  QuillController get controller => _controller;

  /// اسٹائل حل کرنے کا کیش — ہر build پر byId نقشہ + JSON کاپیاں نہیں بنتیں
  KStyle _resolve(String id) {
    if (!identical(widget.styles, _resolvedFor)) {
      _resolvedFor = widget.styles;
      _resolvedCache.clear();
    }
    return _resolvedCache.putIfAbsent(id, () => resolveStyle(widget.styles, id));
  }

  /// باہر سے delta ہم آہنگ کرنا (محفوظ کرنے / تلاش سے پہلے)
  void syncDeltaToBlock() {
    _syncTimer?.cancel();
    widget.block.delta = _controller.document.toDelta().toJson();
  }

  @override
  void initState() {
    super.initState();
    _controller = QuillController(
      document: Document.fromJson(widget.block.delta),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) _activate();
    });
    _controller.addListener(_onDocChange);
  }

  void _activate() =>
      widget.onActivate(_controller, widget.block, () => setState(() {}));

  void _onDocChange() {
    if (_suppress) return;
    // ہر حرف پر پورا پیراگراف سیریلائز کرنا ٹائپنگ روک دیتا تھا —
    // اب 250ms رکنے پر ایک بار ہم آہنگ ہوتا ہے (محفوظ کرنے پر فوری sync بھی ہے)
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 250), () {
      widget.block.delta = _controller.document.toDelta().toJson();
      widget.onChanged();
    });
  }

  /// باہر سے delta بدلنا (تلاش و تبدیل، اسٹائل اطلاق وغیرہ)
  void reloadFromBlock() {
    _suppress = true;
    final sel = _controller.selection;
    _controller.document = Document.fromJson(widget.block.delta);
    if (sel.isValid && sel.end <= _controller.document.length) {
      _controller.updateSelection(sel, ChangeSource.local);
    }
    _suppress = false;
    setState(() {});
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    // آخری حالت ضائع نہ ہو — dispose سے پہلے فوری sync
    try {
      widget.block.delta = _controller.document.toDelta().toJson();
    } catch (_) {}
    _controller.removeListener(_onDocChange);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  DefaultStyles _stylesFor(KStyle st) {
    TextStyle base = TextStyle(
      fontFamily: FontCatalog.displayFamilyFor(st.fontFamily),
      fontSize: st.fontSize,
      color: Color(st.color),
      fontWeight: st.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: st.italic ? FontStyle.italic : FontStyle.normal,
      decoration: st.underline ? TextDecoration.underline : null,
      height: st.lineSpacing,
    );
    DefaultTextBlockStyle blockStyle(
            TextStyle s, double before, double after) =>
        DefaultTextBlockStyle(
          s,
          const HorizontalSpacing(0, 0),
          VerticalSpacing(before, after),
          const VerticalSpacing(0, 0),
          st.shading == null ? null : BoxDecoration(color: Color(st.shading!)),
        );
    KStyle hs(String id, double fs) {
      return _resolve(id);
    }

    return DefaultStyles(
      paragraph: blockStyle(
          base, widget.block.spaceBeforePt, widget.block.spaceAfterPt),
      placeHolder: DefaultTextBlockStyle(
        base.copyWith(color: const Color(0xFF9AA7B8)),
        const HorizontalSpacing(0, 0),
        VerticalSpacing(widget.block.spaceBeforePt, widget.block.spaceAfterPt),
        const VerticalSpacing(0, 0),
        null,
      ),
      h1: blockStyle(
          base.copyWith(
              fontFamily:
                  FontCatalog.displayFamilyFor(hs('Heading1', 22).fontFamily),
              fontSize: hs('Heading1', 22).fontSize,
              fontWeight: FontWeight.bold),
          10,
          6),
      h2: blockStyle(
          base.copyWith(
              fontFamily:
                  FontCatalog.displayFamilyFor(hs('Heading2', 18).fontFamily),
              fontSize: hs('Heading2', 18).fontSize,
              fontWeight: FontWeight.bold),
          8,
          5),
      h3: blockStyle(
          base.copyWith(
              fontFamily:
                  FontCatalog.displayFamilyFor(hs('Heading3', 16).fontFamily),
              fontSize: hs('Heading3', 16).fontSize,
              fontWeight: FontWeight.bold),
          6,
          4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = _resolve(widget.block.styleId);
    final b = widget.block.borders;
    BorderSide side(BorderSpec? s) {
      if (s == null || s.isNone) return BorderSide.none;
      return BorderSide(
        color: Color(s.color),
        width: s.style == 'double' ? s.widthPt * 2 : s.widthPt,
      );
    }

    Widget editor = Directionality(
      textDirection: widget.block.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: QuillEditor(
        focusNode: _focusNode,
        scrollController: _scrollController,
        controller: _controller,
        configurations: QuillEditorConfigurations(
          scrollable: false,
          expands: false,
          autoFocus: false,
          placeholder: 'یہاں لکھیں…',
          customStyles: _stylesFor(st),
          customStyleBuilder: (attr) {
            if (attr.key == 'fnote') {
              return const TextStyle(
                color: AppColors.greenDark,
                fontWeight: FontWeight.bold,
              );
            }
            if (attr.key == 'font') {
              return TextStyle(
                  fontFamily:
                      FontCatalog.displayFamilyFor(attr.value as String));
            }
            if (attr.key == 'cstyle') {
              return const TextStyle(color: AppColors.navy);
            }
            return const TextStyle();
          },
          // پہلی سطر کا فاصلہ — ایپ میں بلاک کی شروع میں دکھایا جاتا ہے،
          // Word (DOCX) میں یہ اصل first-line indent بن کر محفوظ ہوتا ہے
          padding: widget.block.rtl
              ? EdgeInsets.only(
                  right: 6 + widget.block.firstLineIndentPt,
                  left: 6,
                  top: 2,
                  bottom: 2)
              : EdgeInsets.only(
                  left: 6 + widget.block.firstLineIndentPt,
                  right: 6,
                  top: 2,
                  bottom: 2),
        ),
      ),
    );
    if (widget.block.shading != null || (b != null && !b.isEmpty)) {
      editor = Container(
        decoration: BoxDecoration(
          color: widget.block.shading == null
              ? null
              : Color(widget.block.shading!),
          border: b == null
              ? null
              : Border(
                  top: side(b.top),
                  bottom: side(b.bottom),
                  left: side(b.left),
                  right: side(b.right),
                ),
        ),
        child: editor,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: widget.onBlockMenu,
          onTap: () {
            _activate();
            _focusNode.requestFocus();
          },
          child: Container(
            width: 22,
            padding: const EdgeInsets.only(top: 10),
            alignment: Alignment.topCenter,
            child: Icon(Icons.drag_indicator,
                size: 16, color: Colors.grey.withOpacity(0.5)),
          ),
        ),
        Expanded(child: editor),
      ],
    );
  }
}

/// جدول وِجٹ — سیل پر tap سے ترمیم؛ اوپر چھوٹی ٹول بار
class TableBlockWidget extends StatelessWidget {
  final TableBlock block;
  final VoidCallback onChanged;
  final void Function(TableCell cell, int r, int c) onCellTap;
  final VoidCallback onTableMenu;
  const TableBlockWidget({
    super.key,
    required this.block,
    required this.onChanged,
    required this.onCellTap,
    required this.onTableMenu,
  });

  TableBorder _border() {
    const thin = BorderSide(color: Color(0xFF9AA7B8), width: 0.8);
    switch (block.borderPreset) {
      case 'none':
        return const TableBorder();
      case 'box':
        return const TableBorder(
            top: thin, bottom: thin, left: thin, right: thin);
      case 'internal':
        return const TableBorder(horizontalInside: thin, verticalInside: thin);
      default:
        return const TableBorder(
            top: thin,
            bottom: thin,
            left: thin,
            right: thin,
            horizontalInside: thin,
            verticalInside: thin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cols = block.cols;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.grid_on, size: 16, color: AppColors.greenDark),
            const SizedBox(width: 4),
            Text('جدول ${block.rows.length}×$cols',
                style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 18),
              tooltip: 'جدول اعمال',
              onPressed: onTableMenu,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        Table(
          border: _border(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (var r = 0; r < block.rows.length; r++)
              TableRow(
                decoration: BoxDecoration(
                  color: (block.headerRow && r == 0)
                      ? Color(block.headerShading)
                      : null,
                ),
                children: [
                  for (var c = 0; c < block.rows[r].length; c++)
                    InkWell(
                      onTap: () => onCellTap(block.rows[r][c], r, c),
                      child: Container(
                        color: block.rows[r][c].shading == null
                            ? null
                            : Color(block.rows[r][c].shading!),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Text(
                          block.rows[r][c].text.isEmpty
                              ? '···'
                              : block.rows[r][c].text,
                          textAlign: block.rows[r][c].align == 'center'
                              ? TextAlign.center
                              : block.rows[r][c].align == 'end'
                                  ? TextAlign.left
                                  : TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'Noto Nastaliq Urdu',
                            fontSize: 13,
                            fontWeight: block.rows[r][c].bold
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: block.rows[r][c].text.isEmpty
                                ? Colors.grey
                                : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class ImageBlockWidget extends StatelessWidget {
  final ImageBlock block;
  final String docDirPath;
  final VoidCallback onTap;
  const ImageBlockWidget({
    super.key,
    required this.block,
    required this.docDirPath,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final f = File('$docDirPath/${block.relPath}');
    return LayoutBuilder(builder: (context, cons) {
      return Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: cons.maxWidth * block.widthFrac,
              child: f.existsSync()
                  ? Image.file(f, fit: BoxFit.contain)
                  : Container(
                      height: 120,
                      color: Colors.grey.shade200,
                      child: const Center(child: Text('تصویر نہیں ملی')),
                    ),
            ),
          ),
          if (block.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(block.caption,
                  style: const TextStyle(
                      fontFamily: 'Noto Naskh Arabic',
                      fontSize: 12,
                      color: AppColors.inkSoft)),
            ),
        ],
      );
    });
  }
}
