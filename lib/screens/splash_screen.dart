import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/store.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onReady;
  const SplashScreen({super.key, required this.onReady});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // پہلے فریم کے بعد ہی ہلکا کام — startup پر بھاری لوڈ نہیں
    await Future.delayed(const Duration(milliseconds: 650));
    try {
      await DocStore.root();
    } catch (_) {}
    if (mounted) widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: Image.asset('assets/logo_hd.jpg', width: 170, height: 170),
            ),
            const SizedBox(height: 26),
            const Text(
              'IBNEABBAS WORD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontFamily: 'Tinos',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'اردو و عربی تحقیقی تحریر کا مکمل ورڈ پروسیسر',
              style: TextStyle(color: Colors.white70, fontSize: 14.5),
            ),
            const SizedBox(height: 34),
            const CircularProgressIndicator(color: AppColors.green),
          ],
        ),
      ),
    );
  }
}
