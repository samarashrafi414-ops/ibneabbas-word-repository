// اسٹائل مینیجر — built-in + صارف اسٹائلز؛ تخلیق/ترمیم/حذف/نام کی تبدیلی؛
// لائیو پیش منظر؛ استعمال کی گنتی کی وارننگ۔
import 'package:flutter/material.dart';
import '../core/font_catalog.dart';
import '../core/theme.dart';
import '../model/styles.dart';
import 'dialogs.dart';

class StyleManagerScreen extends StatefulWidget {
  final List<KStyle> styles;
  final Map<String, int> usage; // styleId → استعمال گنتی
  final void Function(List<KStyle>) onChanged;
  const StyleManagerScreen({
    super.key,
    required this.styles,
    required this.usage,
    required this.onChanged,
  });
  @override
  State<StyleManagerScreen> createState() => _StyleManagerScreenState();
}

class _StyleManagerScreenState extends State<StyleManagerScreen> {
  late List<KStyle> _styles;
  @override
  void initState() {
    super.initState();
    _styles = widget.styles.map((s) => s.copy()).toList();
  }

  void _notify() {
    widget.onChanged(_styles.map((s) => s.copy()).toList());
    setState(() {});
  }

  Future<void> _edit(KStyle? existing) async {
    final result = await Navigator.push<KStyle>(
      context,
      MaterialPageRoute(
        builder: (_) => StyleFormScreen(
          initial: existing?.copy() ??
              KStyle(
                id: 'Style${DateTime.now().millisecondsSinceEpoch % 100000}',
                name: 'نیا اسٹائل',
              ),
          isNew: existing == null,
          usedIds: _styles.map((s) => s.id).toSet(),
        ),
      ),
    );
    if (result == null) return;
    if (existing == null) {
      _styles.add(result);
    } else {
      final i = _styles.indexWhere((s) => s.id == existing.id);
      if (i >= 0) _styles[i] = result;
    }
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اسٹائل مینیجر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'نیا اسٹائل',
            onPressed: () => _edit(null),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: _styles.length,
        itemBuilder: (ctx, i) {
          final s = resolveStyle(_styles, _styles[i].id);
          final raw = _styles[i];
          final used = widget.usage[raw.id] ?? 0;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: TextStyle(
                            fontFamily: s.fontFamily,
                            fontSize: s.fontSize.clamp(12, 22),
                            fontWeight: s.bold ? FontWeight.bold : null,
                            fontStyle: s.italic ? FontStyle.italic : null,
                            color: Color(s.color),
                          ),
                        ),
                      ),
                      if (raw.builtIn)
                        const Chip(
                            label: Text('built-in',
                                style: TextStyle(fontSize: 10))),
                      if (raw.inTemplate)
                        const Chip(
                            label: Text('ٹیمپلیٹ',
                                style: TextStyle(fontSize: 10))),
                    ],
                  ),
                  Text(
                    'پیش منظر: العلم نور والجهل ظلمة — ${s.fontFamily} ${s.fontSize}pt'
                    '${used > 0 ? ' • استعمال: $used پیراگراف' : ''}'
                    '${raw.type == 'character' ? ' • کرداری اسٹائل' : ''}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.inkSoft),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 17),
                        label: const Text('ترمیم'),
                        onPressed: () => _edit(raw),
                      ),
                      if (raw.builtIn)
                        TextButton.icon(
                          icon: const Icon(Icons.restart_alt, size: 17),
                          label: const Text('ری سیٹ'),
                          onPressed: () {
                            final orig = builtinStyles()
                                .where((b) => b.id == raw.id)
                                .firstOrNull;
                            if (orig != null) {
                              final idx =
                                  _styles.indexWhere((x) => x.id == raw.id);
                              _styles[idx] = orig.copy()
                                ..inTemplate = raw.inTemplate;
                              _notify();
                            }
                          },
                        ),
                      if (!raw.builtIn)
                        TextButton.icon(
                          icon: const Icon(Icons.delete, size: 17),
                          label: const Text('حذف'),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (d) => AlertDialog(
                                title: const Text('اسٹائل حذف کریں؟'),
                                content: Text(used > 0
                                    ? 'وارننگ: یہ اسٹائل $used پیراگرافوں میں استعمال ہو رہا ہے۔ حذف کرنے پر وہ عام متن ہو جائیں گے۔'
                                    : '«${raw.name}» حذف کر دیا جائے گا۔'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(d, false),
                                      child: const Text('منسوخ')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(d, true),
                                      child: const Text('حذف')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              _styles.removeWhere((x) => x.id == raw.id);
                              _notify();
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add),
        label: const Text('نیا اسٹائل'),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

/// اسٹائل تخلیق/ترمیم کا مکمل فارم
class StyleFormScreen extends StatefulWidget {
  final KStyle initial;
  final bool isNew;
  final Set<String> usedIds;
  const StyleFormScreen(
      {super.key,
      required this.initial,
      required this.isNew,
      required this.usedIds});
  @override
  State<StyleFormScreen> createState() => _StyleFormScreenState();
}

class _StyleFormScreenState extends State<StyleFormScreen> {
  late KStyle _s;
  late final TextEditingController _nameCtrl;
  @override
  void initState() {
    super.initState();
    _s = widget.initial;
    _nameCtrl = TextEditingController(text: _s.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'نیا اسٹائل' : 'اسٹائل ترمیم'),
        actions: [
          TextButton(
            onPressed: () {
              _s.name =
                  _nameCtrl.text.trim().isEmpty ? _s.id : _nameCtrl.text.trim();
              if (widget.isNew) {
                // منفرد ID بنائیں
                var base = _s.name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
                if (base.isEmpty || widget.usedIds.contains(base)) {
                  base =
                      'Style${DateTime.now().millisecondsSinceEpoch % 1000000}';
                }
                _s.id = base;
              }
              Navigator.pop(context, _s);
            },
            child: const Text('محفوظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'اسٹائل کا نام'),
          ),
          const SizedBox(height: 14),
          // پیش منظر
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _s.shading == null ? Colors.white : Color(_s.shading!),
              borderRadius: BorderRadius.circular(16),
              border: _s.borders == null
                  ? Border.all(color: Colors.grey.shade300)
                  : null,
            ),
            child: Text(
              'بسم الله الرحمن الرحيم — العلم نور',
              textAlign: _s.align == 'center'
                  ? TextAlign.center
                  : _s.align == 'justify'
                      ? TextAlign.justify
                      : TextAlign.start,
              style: TextStyle(
                fontFamily: _s.fontFamily,
                fontSize: _s.fontSize,
                fontWeight: _s.bold ? FontWeight.bold : null,
                fontStyle: _s.italic ? FontStyle.italic : null,
                decoration: _s.underline ? TextDecoration.underline : null,
                color: Color(_s.color),
                backgroundColor:
                    _s.highlight == null ? null : Color(_s.highlight!),
                height: _s.lineSpacing,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _row(
              'قسم',
              DropdownButton<String>(
                value: _s.type,
                items: const [
                  DropdownMenuItem(value: 'paragraph', child: Text('پیراگراف')),
                  DropdownMenuItem(value: 'character', child: Text('کرداری')),
                  DropdownMenuItem(
                      value: 'linked', child: Text('مشترکہ (Linked)')),
                ],
                onChanged: (v) => setState(() => _s.type = v!),
              )),
          _row(
              'فونٹ',
              DropdownButton<String>(
                value: _s.fontFamily,
                items: [
                  for (final f in FontCatalog.all)
                    DropdownMenuItem(
                        value: f.family,
                        child: Text(f.family,
                            style: TextStyle(fontFamily: f.display))),
                ],
                onChanged: (v) => setState(() => _s.fontFamily = v!),
              )),
          _row(
              'سائز (pt)',
              Row(children: [
                Expanded(
                  child: Slider(
                    value: _s.fontSize,
                    min: 8,
                    max: 48,
                    divisions: 40,
                    onChanged: (v) => setState(() => _s.fontSize = v),
                  ),
                ),
                Text('${_s.fontSize.toStringAsFixed(0)}'),
              ])),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                  label: const Text('بولڈ B'),
                  selected: _s.bold,
                  onSelected: (v) => setState(() => _s.bold = v)),
              FilterChip(
                  label: const Text('ترچھا I'),
                  selected: _s.italic,
                  onSelected: (v) => setState(() => _s.italic = v)),
              FilterChip(
                  label: const Text('خط کشیدہ U'),
                  selected: _s.underline,
                  onSelected: (v) => setState(() => _s.underline = v)),
              FilterChip(
                  label: const Text('RTL سمت'),
                  selected: _s.rtl,
                  onSelected: (v) => setState(() => _s.rtl = v)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.format_color_text),
                  label: Text('متن رنگ: ${_hex(_s.color)}'),
                  onPressed: () async {
                    final v =
                        await showColorSheet(context, title: 'متن کا رنگ');
                    if (v != null) setState(() => _s.color = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.format_color_fill),
                  label: const Text('ہائی لائٹ'),
                  onPressed: () async {
                    final v =
                        await showColorSheet(context, title: 'ہائی لائٹ رنگ');
                    setState(() => _s.highlight = v);
                  },
                ),
              ),
            ],
          ),
          _row(
              'سیدھ',
              DropdownButton<String>(
                value: _s.align,
                items: const [
                  DropdownMenuItem(value: 'start', child: Text('شروع')),
                  DropdownMenuItem(value: 'center', child: Text('درمیان')),
                  DropdownMenuItem(value: 'end', child: Text('آخر')),
                  DropdownMenuItem(
                      value: 'justify', child: Text('برابر (Justify)')),
                ],
                onChanged: (v) => setState(() => _s.align = v!),
              )),
          _row(
              'سطر فاصلہ',
              Row(children: [
                Expanded(
                  child: Slider(
                    value: _s.lineSpacing,
                    min: 1.0,
                    max: 3.0,
                    divisions: 20,
                    onChanged: (v) => setState(() => _s.lineSpacing = v),
                  ),
                ),
                Text(_s.lineSpacing.toStringAsFixed(1)),
              ])),
          _row('قبل فاصلہ (pt)',
              _ptField(_s.spaceBeforePt, (v) => _s.spaceBeforePt = v)),
          _row('بعد فاصلہ (pt)',
              _ptField(_s.spaceAfterPt, (v) => _s.spaceAfterPt = v)),
          _row('انڈینٹ سطح',
              _numStepper(_s.indentLevel, (v) => _s.indentLevel = v)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.border_all),
            label: const Text('پیراگراف بارڈرز'),
            onPressed: () async {
              final v = await showBordersDialog(context, _s.borders);
              if (v != null) setState(() => _s.borders = v.isEmpty ? null : v);
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.format_color_fill_outlined),
            label: const Text('پیراگراف شیڈنگ'),
            onPressed: () async {
              final v = await showColorSheet(context, title: 'شیڈنگ رنگ');
              setState(() => _s.shading = v);
            },
          ),
          SwitchListTile(
            title:
                const Text('ٹیمپلیٹ میں شامل — تمام نئی دستاویزات میں دستیاب'),
            value: _s.inTemplate,
            onChanged: (v) => setState(() => _s.inTemplate = v),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _hex(int c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  Widget _row(String label, Widget child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(label)),
            Expanded(child: child),
          ],
        ),
      );

  Widget _ptField(double v, void Function(double) set) => SizedBox(
        width: 90,
        child: TextFormField(
          initialValue: v.toString(),
          keyboardType: TextInputType.number,
          onChanged: (t) => set(double.tryParse(t) ?? 0),
          decoration: const InputDecoration(isDense: true),
        ),
      );

  Widget _numStepper(int v, void Function(int) set) => Row(
        children: [
          IconButton(
              onPressed: () => setState(() => set((v - 1).clamp(0, 8))),
              icon: const Icon(Icons.remove_circle_outline)),
          Text('$v'),
          IconButton(
              onPressed: () => setState(() => set((v + 1).clamp(0, 8))),
              icon: const Icon(Icons.add_circle_outline)),
        ],
      );
}
