// حوالہ سازی — native Dialogs.formatCitation کی حرف بہ حرف Dart صورت
import '../model/model.dart';

const Map<String, String> citationTypeLabels = {
  'quran': 'قرآن مجید',
  'hadith': 'حدیث',
  'book': 'کتاب',
  'fiqh': 'فقہ حنفی',
  'tafsir': 'تفسیر',
  'biography': 'سیرت و تراجم',
  'manuscript': 'مخطوطہ',
  'thesis': 'مقالہ/تحقیق',
  'journal': 'مجلس/جرنل',
  'website': 'ویب سائٹ',
};

String formatCitation(Citation c) {
  final sb = StringBuffer();
  switch (c.type) {
    case 'quran':
      sb.write('قرآن مجید');
      if (c.title.isNotEmpty) sb.write('، سورۃ ${c.title}');
      if (c.page.isNotEmpty) sb.write('، آیت ${c.page}');
      break;
    case 'hadith':
      if (c.author.isNotEmpty) sb.write('${c.author}، ');
      if (c.title.isNotEmpty) sb.write(c.title);
      if (c.page.isNotEmpty) sb.write('، حدیث نمبر ${c.page}');
      if (c.volume.isNotEmpty) sb.write('، جلد ${c.volume}');
      if (c.notes.isNotEmpty) sb.write(' (${c.notes})');
      break;
    case 'website':
      if (c.title.isNotEmpty) sb.write(c.title);
      if (c.url.isNotEmpty) sb.write('، ${c.url}');
      if (c.notes.isNotEmpty) sb.write(' (${c.notes})');
      break;
    case 'manuscript':
      if (c.title.isNotEmpty) sb.write('«${c.title}»');
      sb.write('، مخطوطہ');
      if (c.place.isNotEmpty) sb.write('، ${c.place}');
      if (c.notes.isNotEmpty) sb.write('، ${c.notes}');
      break;
    default:
      if (c.author.isNotEmpty) sb.write('${c.author}، ');
      if (c.title.isNotEmpty) sb.write('«${c.title}»');
      if (c.editor.isNotEmpty) sb.write('، تحقیق: ${c.editor}');
      if (c.edition.isNotEmpty) sb.write('، طبع ${c.edition}');
      if (c.place.isNotEmpty || c.publisher.isNotEmpty) {
        sb.write('، ');
        if (c.place.isNotEmpty) sb.write('${c.place}: ');
        if (c.publisher.isNotEmpty) sb.write(c.publisher);
      }
      if (c.year.isNotEmpty) sb.write('، ${c.year}ء');
      if (c.volume.isNotEmpty) sb.write('، جلد ${c.volume}');
      if (c.page.isNotEmpty) sb.write('، ص ${c.page}');
  }
  return sb.toString();
}
