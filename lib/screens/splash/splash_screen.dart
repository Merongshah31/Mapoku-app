import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// First screen on launch: the logo and the tagline, then the app fades in.
/// The logo settles in and the tagline follows; with Reduce Motion on,
/// both simply appear.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  late final _logoFade = CurvedAnimation(parent: _c, curve: const Interval(0, 0.5, curve: Curves.easeOut));
  late final _logoScale = Tween(begin: 0.92, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: const Interval(0, 0.6, curve: Curves.easeOutCubic)));
  late final _taglineFade = CurvedAnimation(parent: _c, curve: const Interval(0.5, 1, curve: Curves.easeOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.page,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Container(
                    width: 168,
                    height: 168,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: const [BoxShadow(color: Color(0x241E2B22), blurRadius: 24, offset: Offset(0, 8))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Image.asset('assets/images/mapoku_logo_large.png', semanticLabel: 'mapOKU'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _taglineFade,
                // One line; shrinks rather than wrapping on narrow phones.
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Freedom to move, for everyone.',
                    maxLines: 1,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Palette.ink, letterSpacing: -0.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
