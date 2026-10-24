// ایڈیٹر ڈائیلاگ: رنگ، جدول اندراج، بارڈرز، صفحہ ترتیبات، رموز، حواشی، تلاش و تبدیل
import 'package:flutter/material.dart';
import '../core/font_catalog.dart';
import '../core/symbols_data.dart';
import '../core/theme.dart';
import '../model/model.dart';

const List<int> paletteColors = [
  0xFF000000,
  0xFF142238,
  0xFF0A5C36,
  0xFF19B58A,
  0xFF35C759,
  0xFFD9A441,
  0xFFFF0000,
  0xFFB71C1C,
  0xFF0000FF,
  0xFF0D47A1,
  0xFF6A1B9A,
  0xFFFF00FF,
  0xFFFFFF00,
  0xFFFF9800,
  0xFF795548,
  0xFF607D8B,
  0xFF9E9E9E,
  0xFFFFFFFF,
  0xFFFFF9C4,
  0xFFE8F5E9,
  0xFFE3F2FD,
  0xFFFCE4EC,
  0xFFF3E5F5,
  0xFFFFF3E0,
];

Future<int?> showColorSheet(BuildContext context,
    {required String title, bool allowNone = true}) {
  return showModalBottomSheet<int?>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (allowNone)
                InkWell(
                  onTap: () => Navigator.pop(ctx, -1),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.format_color_reset, size: 20),
                  ),
                ),
              for (final c in paletteColors)
                InkWell(
                  onTap: () => Navigator.pop(ctx, c),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(c),
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  ).then((v) => v == -1 ? null : v);
}

Future<(int, int)?> showInsertTableDialog(BuildContext context) async {
  var rows = 3, cols = 3;
  return showDialog<(int, int)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('جدول شامل کریں'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _numRow('سطریں', rows, (v) => setS(() => rows = v)),
            _numRow('کالم', cols, (v) => setS(() => cols = v)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('منسوخ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, (rows, cols)),
              child: const Text('شامل کریں')),
        ],
      ),
    ),
  );
}

Widget _numRow(String label, int value, void Function(int) onChange) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label),
      Row(
        children: [
          IconButton(
              onPressed: () => onChange((value - 1).clamp(1, 30)),
              icon: const Icon(Icons.remove_circle_outline)),
          Text('$value', style: const TextStyle(fontSize: 16)),
          IconButton(
              onPressed: () => onChange((value + 1).clamp(1, 30)),
              icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
    ],
  );
}

/// ایک بارڈر لکیر کی ترمیم — style/width/color
class BorderSpecEditor extends StatefulWidget {
  final String label;
  final BorderSpec? initial;
  final void Function(BorderSpec?) onChanged;
  const BorderSpecEditor(
      {super.key,
      required this.label,
      required this.initial,
      required this.onChanged});
  @override
  State<BorderSpecEditor> createState() => _BorderSpecEditorState();
}

class _BorderSpecEditorState extends State<BorderSpecEditor> {
  late BorderSpec _spec;
  late bool _enabled;
  @override
  void initState() {
    super.initState();
    _enabled = widget.initial != null && !widget.initial!.isNone;
    _spec = widget.initial?.copy() ?? BorderSpec();
  }

  void _emit() => widget.onChanged(_enabled ? _spec : null);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(widget.label),
          value: _enabled,
          onChanged: (v) => setState(() {
            _enabled = v;
            _emit();
          }),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (_enabled) ...[
          Row(
            children: [
              const Text('اسلوب: '),
              DropdownButton<String>(
                value: _spec.style == 'none' ? 'single' : _spec.style,
                items: const [
                  DropdownMenuItem(value: 'single', child: Text('اکیلی لکیر')),
                  DropdownMenuItem(value: 'double', child: Text('دوہری')),
                  DropdownMenuItem(value: 'dotted', child: Text('نقطہ دار')),
                  DropdownMenuItem(value: 'dashed', child: Text('خط دار')),
                  DropdownMenuItem(value: 'thick', child: Text('موٹی')),
                  DropdownMenuItem(value: 'wave', child: Text('لہر دار')),
                ],
                onChanged: (v) => setState(() {
                  _spec.style = v!;
                  _emit();
                }),
              ),
            ],
          ),
          Row(
            children: [
              const Text('چوڑائی: '),
              Expanded(
                child: Slider(
                  value: _spec.widthPt,
                  min: 0.5,
                  max: 6,
                  divisions: 11,
                  label: '${_spec.widthPt} pt',
                  onChanged: (v) => setState(() {
                    _spec.widthPt = v;
                    _emit();
                  }),
                ),
              ),
              Text('${_spec.widthPt.toStringAsFixed(1)}pt'),
            ],
          ),
          Row(
            children: [
              const Text('رنگ: '),
              Wrap(
                spacing: 6,
                children: [
                  for (final c in [
                    0xFF000000,
                    0xFF0A5C36,
                    0xFF19B58A,
                    0xFFB71C1C,
                    0xFF0D47A1,
                    0xFFD9A441,
                    0xFF607D8B
                  ])
                    InkWell(
                      onTap: () => setState(() {
                        _spec.color = c;
                        _emit();
                      }),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Color(c),
                          border: Border.all(
                              color: _spec.color == c
                                  ? AppColors.green
                                  : Colors.grey,
                              width: _spec.color == c ? 3 : 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// پیراگراف بارڈرز مکمل ڈائیلاگ — presets سمیت
Future<EdgeBorders?> showBordersDialog(
    BuildContext context, EdgeBorders? initial) async {
  final result = await showDialog<EdgeBorders>(
    context: context,
    builder: (ctx) {
      var cur = initial?.copy() ?? EdgeBorders();
      return StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('پیراگراف بارڈرز'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('کوئی نہیں'),
                        selected: cur.isEmpty,
                        onSelected: (_) => setS(() => cur = EdgeBorders()),
                      ),
                      ChoiceChip(
                        label: const Text('باکس'),
                        selected: false,
                        onSelected: (_) =>
                            setS(() => cur = EdgeBorders.box(BorderSpec())),
                      ),
                      ChoiceChip(
                        label: const Text('سایہ دار باکس'),
                        selected: false,
                        onSelected: (_) => setS(() => cur = EdgeBorders(
                              top: BorderSpec(),
                              left: BorderSpec(),
                              bottom: BorderSpec(widthPt: 2.25),
                              right: BorderSpec(widthPt: 2.25),
                            )),
                      ),
                      ChoiceChip(
                        label: const Text('تمام اطراف + درمیان'),
                        selected: false,
                        onSelected: (_) => setS(() {
                          cur = EdgeBorders.box(BorderSpec());
                          cur.between = BorderSpec();
                        }),
                      ),
                    ],
                  ),
                  const Divider(),
                  BorderSpecEditor(
                      label: 'اوپر',
                      initial: cur.top,
                      onChanged: (v) => cur.top = v),
                  BorderSpecEditor(
                      label: 'نیچے',
                      initial: cur.bottom,
                      onChanged: (v) => cur.bottom = v),
                  BorderSpecEditor(
                      label: 'دائیں',
                      initial: cur.right,
                      onChanged: (v) => cur.right = v),
                  BorderSpecEditor(
                      label: 'بائیں',
                      initial: cur.left,
                      onChanged: (v) => cur.left = v),
                  BorderSpecEditor(
                      label: 'درمیان (مسلسل پیراگرافوں کے بیچ)',
                      initial: cur.between,
                      onChanged: (v) => cur.between = v),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('منسوخ')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, cur),
                child: const Text('لاگو کریں')),
          ],
        ),
      );
    },
  );
  return result;
}

/// صفحہ بارڈر ڈائیلاگ
Future<(BorderSpec?, String)?> showPageBorderDialog(
    BuildContext context, BorderSpec? initial, String offsetFrom) async {
  return showDialog<(BorderSpec?, String)>(
    context: context,
    builder: (ctx) {
      BorderSpec? cur = initial?.copy();
      var off = offsetFrom;
      return StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('صفحہ بارڈر'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BorderSpecEditor(
                    label: 'صفحہ بارڈر فعال',
                    initial: cur,
                    onChanged: (v) => cur = v,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('فاصلہ اس سے: '),
                      DropdownButton<String>(
                        value: off,
                        items: const [
                          DropdownMenuItem(
                              value: 'page', child: Text('صفحے کے کنارے')),
                          DropdownMenuItem(
                              value: 'text', child: Text('متن کے کنارے')),
                        ],
                        onChanged: (v) => setS(() => off = v!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('منسوخ')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, (cur, off)),
                child: const Text('لاگو کریں')),
          ],
        ),
      );
    },
  );
}

/// رموز پینل — اقسام کے ساتھ
Future<SymbolItem?> showSymbolsSheet(BuildContext context) {
  return showModalBottomSheet<SymbolItem>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (ctx, scroll) => DefaultTabController(
        length: symbolCategories.length,
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text('رموز و علامات',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            TabBar(
              isScrollable: true,
              tabs: [
                for (final c in symbolCategories) Tab(text: c.name),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final cat in symbolCategories)
                    GridView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(14),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: cat.items.length,
                      itemBuilder: (ctx, i) {
                        final item = cat.items[i];
                        return InkWell(
                          onTap: () => Navigator.pop(ctx, item),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.insert,
                                  style: TextStyle(
                                    fontFamily:
                                        item.fontFamily ?? 'Noto Naskh Arabic',
                                    fontSize: 19,
                                    color: AppColors.navy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.label,
                                  style: const TextStyle(
                                      fontSize: 10, color: AppColors.inkSoft),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// حواشی کی فہرست — ترمیم/حذف
Future<void> showFootnoteListSheet(
  BuildContext context, {
  required List<KFootnote> footnotes,
  required Future<void> Function(int index, String text) onEdit,
  required Future<void> Function(int index) onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('حواشی (Footnotes)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (footnotes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('کوئی حاشیہ نہیں'),
              ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: footnotes.length,
                itemBuilder: (ctx, i) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    child: Text('${i + 1}'),
                  ),
                  title: Text(footnotes[i].text,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 19),
                        onPressed: () async {
                          final ctrl =
                              TextEditingController(text: footnotes[i].text);
                          final v = await showDialog<String>(
                            context: ctx,
                            builder: (dctx) => AlertDialog(
                              title: const Text('حاشیہ ترمیم'),
                              content: TextField(
                                controller: ctrl,
                                maxLines: 4,
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(dctx),
                                    child: const Text('منسوخ')),
                                FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dctx, ctrl.text),
                                    child: const Text('محفوظ')),
                              ],
                            ),
                          );
                          if (v != null) {
                            await onEdit(i, v);
                            setS(() {});
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 19),
                        onPressed: () async {
                          await onDelete(i);
                          setS(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// مکمل فونٹ چنندہ: صارف کے 6 زمروں کے ساتھ، ہر فونٹ کی لائیو پیش نظارہ سطر،
/// نام فقط (proprietary) فونٹس پر «PC» بیج۔ منتخب مستند نام لوٹاتا ہے۔
Future<String?> showFontPickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navyPanel,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => DefaultTabController(
      length: FontCatalog.categories.length,
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.72,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('فونٹ منتخب کریں',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
            ),
            TabBar(
              isScrollable: true,
              labelColor: AppColors.green,
              unselectedLabelColor: Colors.white60,
              indicatorColor: AppColors.green,
              tabs: [
                for (final c in FontCatalog.categories)
                  Tab(text: FontCatalog.categoryLabel(c)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final c in FontCatalog.categories)
                    Builder(
                      builder: (ctx) {
                        // lazy فہرست — سارے فونٹ ایک ساتھ لوڈ نہیں ہوتے
                        // (پہلے ListView(children:) ہر ٹائل بنا کر 35 فونٹ
                        // ایک دم لوڈ کر دیتا تھا — یہی پکر کھولتے ہی ہینگ تھا)
                        final fonts = FontCatalog.byGroup(c);
                        return ListView.builder(
                          itemCount: fonts.length,
                          itemBuilder: (ctx, i) {
                            final f = fonts[i];
                            return ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(f.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14)),
                                  ),
                                  if (f.nameOnly)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: AppColors.greenDark,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: const Text('PC',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              subtitle: Text('ابجد ہوّز — ABC abc 123',
                                  style: TextStyle(
                                      fontFamily: f.display,
                                      color: Colors.white70,
                                      fontSize: 16)),
                              onTap: () => Navigator.pop(ctx, f.name),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
