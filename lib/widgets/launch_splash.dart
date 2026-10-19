import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Layar pembuka GroU, ditumpuk di atas [child] saat aplikasi baru dibuka.
///
/// Frame pertamanya sengaja identik dengan splash native (warna latar, logo
/// 250 dp di tengah, terang/gelap mengikuti sistem seperti splash native),
/// jadi peralihannya tidak terlihat. Setelah itu logonya melambung kecil lalu
/// lapisan ini memudar, memperlihatkan aplikasi yang sudah dimuat di
/// belakangnya.
class LaunchSplash extends StatefulWidget {
  final Widget child;
  const LaunchSplash({super.key, required this.child});

  /// Ukuran logo, sama dengan logo.png (1000 px) yang dianggap @4x oleh
  /// flutter_native_splash.
  static const logoSize = 250.0;

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _done = false;

  // Fase sebagai pecahan durasi: diam sejenak, melambung, lalu memudar.
  static const _lift = Interval(0.1, 0.5);
  static const _exit = Interval(0.62, 1, curve: Curves.easeInCubic);

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pengguna yang mematikan animasi sistem langsung masuk ke aplikasi.
    if (MediaQuery.of(context).disableAnimations) _controller.duration = const Duration(milliseconds: 300);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;

    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final colors = dark ? AppColors.dark : AppColors.light;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, logo) {
            final v = _controller.value;
            final lift = Curves.easeOutBack.transform(_lift.transform(v));
            final exit = _exit.transform(v);
            return IgnorePointer(
              ignoring: exit > 0,
              child: Opacity(
                opacity: 1 - exit,
                child: ColoredBox(
                  color: colors.bg,
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(0, -10 * lift),
                      child: Transform.scale(scale: 1 + 0.04 * lift + 0.08 * exit, child: logo),
                    ),
                  ),
                ),
              ),
            );
          },
          child: Image.asset(
            dark ? 'assets/branding/logo_dark.png' : 'assets/branding/logo.png',
            width: LaunchSplash.logoSize,
            height: LaunchSplash.logoSize,
            semanticLabel: 'GroU',
          ),
        ),
      ],
    );
  }
}
