// flutter_quill کے لیے مخصوص attributes: فٹ نوٹ anchor + کرداری اسٹائل ربط
import 'package:flutter_quill/flutter_quill.dart';

class FootnoteAttribute extends Attribute<int?> {
  const FootnoteAttribute([int? value])
      : super('fnote', AttributeScope.inline, value);
}

class CharStyleAttribute extends Attribute<String?> {
  const CharStyleAttribute([String? value])
      : super('cstyle', AttributeScope.inline, value);
}
