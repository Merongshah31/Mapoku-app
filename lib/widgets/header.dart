import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../screens/profile/profile_screen.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Right side of the header on every tab: points (opens Rewards) and profile.
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key});

  @override
  Widget build(BuildContext context) {
    final points = context.select<AppState, int>((s) => s.points);
    final name = context.select<ProfileState, String?>((p) => p.profile?.name);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(
          semanticLabel: '$points points. Open rewards',
          onTap: () => context.read<AppNav>().go(AppNav.rewards),
          child: PointsPill(points),
        ),
        const SizedBox(width: 8),
        ProfileButton(name: name),
      ],
    );
  }
}

/// Round avatar with the user's initial. Opens the profile page.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key, this.name, this.size = 36});

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = (name == null || name!.isEmpty) ? null : name!.characters.first.toUpperCase();
    return Pressable(
      semanticLabel: 'Profile',
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute<void>(builder: (_) => const ProfileScreen()),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Palette.mint,
          shape: BoxShape.circle,
          border: Border.all(color: Palette.moss.withValues(alpha: 0.25)),
        ),
        alignment: Alignment.center,
        child: initial == null
            ? const Icon(CupertinoIcons.person_fill, size: 18, color: Palette.moss)
            : Text(initial, style: TextStyles.headline.copyWith(color: Palette.moss)),
      ),
    );
  }
}

/// iOS large-title header used on the Report and Rewards tabs:
/// brand on the left, points and profile on the right.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverNavigationBar(
      leading: const Align(widthFactor: 1, alignment: Alignment.centerLeft, child: Brand()),
      largeTitle: Text(title),
      trailing: const HeaderActions(),
      backgroundColor: Palette.page.withValues(alpha: 0.9),
      border: null,
      transitionBetweenRoutes: false,
    );
  }
}
