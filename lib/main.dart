// IBNEABBAS WORD — داخلہ نقطہ۔ CrashGuard: کوئی بھی غلطی ایپ نہیں روکتی،
// صرف لاگ ہوتی ہے؛ autosave/recovery ڈیٹا بچاتے ہیں۔
import 'dart:async';
import 'package:flutter/material.dart';
import 'app.dart';
import 'data/store.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      CrashLog.log(details.exception, details.stack ?? StackTrace.current);
    };
    runApp(const IbneabbasWordApp());
  }, (error, stack) {
    CrashLog.log(error, stack);
  });
}
