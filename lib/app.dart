import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_screen.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';

/// Root of the mapOKU app.
class MapokuApp extends StatefulWidget {
  const MapokuApp({super.key});

  @override
  State<MapokuApp> createState() => _MapokuAppState();
}

class _MapokuAppState extends State<MapokuApp> {
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = AppState();
    _state.init();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'mapOKU',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _Launch(),
      ),
    );
  }
}

/// Shows the splash for a moment, then fades into the app.
class _Launch extends StatefulWidget {
  const _Launch();

  @override
  State<_Launch> createState() => _LaunchState();
}

class _LaunchState extends State<_Launch> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduceMotion ? 1 : 450),
      child: _ready
          ? const ShellScreen(key: ValueKey('shell'))
          : const SplashScreen(key: ValueKey('splash')),
    );
  }
}
