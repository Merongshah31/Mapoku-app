import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'screens/shell_screen.dart';
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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'mapOKU',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const ShellScreen(),
      ),
    );
  }
}