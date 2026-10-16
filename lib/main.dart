import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/theme.dart';
import 'data/repository.dart';
import 'screens/report/report_screen.dart';
import 'screens/rewards/rewards_screen.dart';
import 'screens/routes/routes_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'state/app_state.dart';
import 'state/routes_controller.dart';

void main() {
  // Swap MockMapokuRepository for the real API client when the backend is ready.
  final MapokuRepository repo = MockMapokuRepository();

  runApp(
    MultiProvider(
      providers: [
        Provider<MapokuRepository>.value(value: repo),
        ChangeNotifierProvider(create: (_) => AppNav()),
        ChangeNotifierProvider(create: (_) => AppState(repo)..load()),
        ChangeNotifierProvider(create: (_) => ProfileState(repo)..load()),
        ChangeNotifierProvider(create: (_) => ReportsController(repo)..load()),
        ChangeNotifierProvider(create: (_) => RoutesController(repo)..load()),
      ],
      child: const MapokuApp(),
    ),
  );
}

class MapokuApp extends StatelessWidget {
  const MapokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mapOKU',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Launch(),
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
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 700),
      child: _ready ? const HomeShell() : const SplashScreen(),
    );
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<AppNav>().tab;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        // Lets the map run under the translucent tab bar, like Apple Maps.
        extendBody: true,
        body: IndexedStack(
          index: tab,
          children: const [RoutesScreen(), ReportScreen(), RewardsScreen()],
        ),
        bottomNavigationBar: CupertinoTabBar(
          currentIndex: tab,
          onTap: (i) {
            if (i != tab) HapticFeedback.selectionClick();
            context.read<AppNav>().go(i);
          },
          activeColor: Palette.moss,
          inactiveColor: Palette.tertiary,
          backgroundColor: Palette.surface.withValues(alpha: 0.92),
          iconSize: 26,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.map),
              activeIcon: Icon(CupertinoIcons.map_fill),
              label: 'Routes',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.exclamationmark_triangle),
              activeIcon: Icon(CupertinoIcons.exclamationmark_triangle_fill),
              label: 'Report',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.gift),
              activeIcon: Icon(CupertinoIcons.gift_fill),
              label: 'Rewards',
            ),
          ],
        ),
      ),
    );
  }
}
