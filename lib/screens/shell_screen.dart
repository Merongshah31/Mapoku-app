import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../state/app_scope.dart';
import '../widgets/mapoku_logo.dart';
import '../widgets/points_pill.dart';
import 'reports_screen.dart';
import 'rewards_screen.dart';
import 'routes_screen.dart';

/// App shell: shared header, tab content and an Apple-style bottom bar.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

typedef _NavTab = ({String label, IconData icon, IconData activeIcon});

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  static const List<_NavTab> _tabs = [
    (label: 'Map', icon: Icons.map_outlined, activeIcon: Icons.map),
    (label: 'Reports', icon: Icons.report_gmailerrorred_outlined, activeIcon: Icons.report_gmailerrorred),
    (label: 'Rewards', icon: Icons.redeem_outlined, activeIcon: Icons.redeem),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _ShellHeader(onAvatarTap: () => _showProfileSheet(context)),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                RoutesScreen(),
                ReportsScreen(),
                RewardsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _AppBottomNav(
        index: _index,
        tabs: _tabs,
        onChanged: (value) => setState(() => _index = value),
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    final state = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MapokuLogo(height: 28),
            const SizedBox(height: 16),
            Text(
              state.isLoggedIn ? state.displayName : 'Guest member',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              state.isLoggedIn
                  ? 'Signed in · thanks for keeping the map accessible.'
                  : 'Sign in to keep your points on every device.',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.monetization_on_outlined, color: AppColors.primary),
              title: const Text('Points balance'),
              trailing: Text(
                '${state.points} 🪙',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.favorite_border, color: AppColors.accent),
              title: Text('Freedom to move, for everyone.'),
              subtitle: Text('Supporting SDG 11 — Sustainable Cities'),
            ),
            const SizedBox(height: 8),
            if (state.isLoggedIn)
              OutlinedButton(onPressed: state.signOut, child: const Text('Log out'))
            else
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => const LoginSheet(),
                  );
                },
                child: const Text('Sign in'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({required this.onAvatarTap});

  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              const MapokuLogo(height: 30),
              const Spacer(),
              PointsPill(points: state.points),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.mintBorder),
                  ),
                  child: const Icon(Icons.person_outline, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBottomNav extends StatelessWidget {
  const _AppBottomNav({
    required this.index,
    required this.tabs,
    required this.onChanged,
  });

  final int index;
  final List<_NavTab> tabs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _NavButton(
                    label: tabs[i].label,
                    icon: tabs[i].icon,
                    activeIcon: tabs[i].activeIcon,
                    selected: i == index,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textTertiary;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.mint : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple demo sign-in sheet backed by the real login endpoint.
class LoginSheet extends StatefulWidget {
  const LoginSheet({super.key});

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Sign in to sync your reports and points.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'you@example.com', prefixIcon: Icon(Icons.mail_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: state.busy
                ? null
                : () async {
                    await state.signIn(email: _email.text.trim(), password: _password.text);
                    if (context.mounted) Navigator.of(context).pop();
                  },
            child: Text(state.busy ? 'Please wait…' : 'Sign in'),
          ),
        ],
      ),
    );
  }
}