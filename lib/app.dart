import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'screens/library_screen.dart';
import 'screens/splash_screen.dart';

class IbneabbasWordApp extends StatefulWidget {
  const IbneabbasWordApp({super.key});
  @override
  State<IbneabbasWordApp> createState() => _IbneabbasWordAppState();
}

class _IbneabbasWordAppState extends State<IbneabbasWordApp> {
  bool _ready = false;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IBNEABBAS WORD',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('ur'),
      supportedLocales: const [Locale('ur'), Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _ready
          ? const LibraryScreen()
          : SplashScreen(onReady: () => setState(() => _ready = true)),
    );
  }
}
