// میرے مصادر — محفوظ حوالہ جات کی لائبریری
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/citation_format.dart';
import '../data/store.dart';
import '../editor/editor_screen.dart' show showCitationForm;
import '../model/model.dart';

class CitationsScreen extends StatefulWidget {
  const CitationsScreen({super.key});
  @override
  State<CitationsScreen> createState() => _CitationsScreenState();
}

class _CitationsScreenState extends State<CitationsScreen> {
  List<Citation> _list = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await CitationStore.all();
    if (mounted) setState(() => _list = l);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('میرے مصادر و حوالہ جات')),
      body: _list.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 80),
                child: Text(
                    'ابھی کوئی مصدر محفوظ نہیں\nحوالہ شامل کر کے محفوظ کریں',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkSoft)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 110),
              itemCount: _list.length,
              itemBuilder: (ctx, i) {
                final c = _list[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.format_quote,
                        color: AppColors.greenDark),
                    title: Text(formatCitation(c)),
                    subtitle: Text(citationTypeLabels[c.type] ?? c.type),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        _list.removeAt(i);
                        await CitationStore.saveAll(_list);
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 74),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final r = await showCitationForm(context);
            if (r != null) {
              await CitationStore.add(r.$1);
              _load();
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('نیا حوالہ'),
        ),
      ),
    );
  }
}
