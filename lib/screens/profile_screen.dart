import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/profile.dart';
import '../state/app_scope.dart';
import '../widgets/contacts.dart';
import '../widgets/login_sheet.dart';
import '../widgets/ui_kit.dart';

/// Profile: accessibility needs, route preferences and emergency contacts.
/// Stored on the device through [AppState.updateProfile].
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.profile;
    final bottom = MediaQuery.paddingOf(context).bottom;

    Future<void> save(UserProfile Function(UserProfile) change) =>
        _save(context, change);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 32),
        children: [
          _Identity(name: state.memberName, signedIn: state.isLoggedIn),
          const SectionTitle('Accessibility needs'),
          AppGroup(
            dividerIndent: 52,
            children: [
              for (final need in MobilityNeed.values)
                _NeedRow(
                  need: need,
                  selected: p.needs.contains(need),
                  onTap: () => save((x) {
                    final needs = {...x.needs};
                    needs.contains(need) ? needs.remove(need) : needs.add(need);
                    return x.copyWith(needs: needs);
                  }),
                ),
            ],
          ),
          const SectionFooter(
            'Pick all that apply. Your first choice sets the default route mode on the map.',
          ),
          const SizedBox(height: 16),
          _NeedsNote(
            initial: p.needsNote,
            onSave: (text) => save((x) => x.copyWith(needsNote: text)),
          ),
          const SectionFooter(
            'Optional. Helps others understand what fits, e.g. your wheelchair width.',
          ),
          const SectionTitle('Route preferences'),
          AppGroup(
            children: [
              _SwitchRow(
                label: 'Avoid stairs',
                value: p.prefs.avoidStairs,
                onChanged: (v) => save(
                  (x) => x.copyWith(prefs: x.prefs.copyWith(avoidStairs: v)),
                ),
              ),
              _SwitchRow(
                label: 'Need a working lift',
                value: p.prefs.needsLift,
                onChanged: (v) => save(
                  (x) => x.copyWith(prefs: x.prefs.copyWith(needsLift: v)),
                ),
              ),
              _SwitchRow(
                label: 'Avoid steep slopes',
                value: p.prefs.avoidSteepSlopes,
                onChanged: (v) => save(
                  (x) =>
                      x.copyWith(prefs: x.prefs.copyWith(avoidSteepSlopes: v)),
                ),
              ),
              _SwitchRow(
                label: 'Prefer covered walkways',
                value: p.prefs.preferSheltered,
                onChanged: (v) => save(
                  (x) =>
                      x.copyWith(prefs: x.prefs.copyWith(preferSheltered: v)),
                ),
              ),
            ],
          ),
          SectionTitle(
            'Emergency contacts',
            trailing: TextButton(
              onPressed: () => showContactSheet(context),
              child: const Text('Add'),
            ),
          ),
          const ContactsGroup(),
          const SectionFooter(
            'Your first contact is marked Primary. mapOKU never contacts them for you.',
          ),
          const SectionTitle('Account'),
          AppGroup(
            children: [
              if (state.isLoggedIn)
                _ActionRow(
                  icon: CupertinoIcons.square_arrow_right,
                  label: 'Log out',
                  onTap: state.signOut,
                )
              else
                _ActionRow(
                  icon: CupertinoIcons.person_crop_circle,
                  label: 'Sign in to sync your points',
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => const LoginSheet(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Saves a profile change and tells the member if it didn't go through.
Future<void> _save(
  BuildContext context,
  UserProfile Function(UserProfile) change,
) async {
  try {
    await AppScope.of(context).updateProfile(change);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text("Your change wasn't saved. Try again.")),
      );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.name, required this.signedIn});

  final String name;
  final bool signedIn;

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: name == 'Guest' ? '' : name);
    final result = await showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Aminah'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && context.mounted) {
      await _save(context, (x) => x.copyWith(name: result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppGroup(
      children: [
        Semantics(
          button: true,
          label: 'Name, $name. Edit',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => _editName(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          signedIn ? 'Signed in' : 'Guest member',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

IconData needIcon(MobilityNeed need) => switch (need) {
  MobilityNeed.wheelchair => Icons.accessible_outlined,
  MobilityNeed.walkingAid => Icons.directions_walk,
  MobilityNeed.elderly => Icons.elderly,
  MobilityNeed.stroller => Icons.stroller_outlined,
  MobilityNeed.visuallyImpaired => Icons.visibility_off_outlined,
  MobilityNeed.hearingImpaired => Icons.hearing_disabled_outlined,
};

class _NeedRow extends StatelessWidget {
  const _NeedRow({
    required this.need,
    required this.selected,
    required this.onTap,
  });

  final MobilityNeed need;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: need.label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(needIcon(need), size: 24, color: AppColors.textPrimary),
            const SizedBox(width: 12),
            Expanded(child: Text(need.label, style: kBodyStyle)),
            if (selected)
              const Icon(CupertinoIcons.checkmark_alt, size: 22, color: AppColors.primary),
          ],
        ),
      ),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Padding(
      padding: const EdgeInsets.only(left: 16, right: 12, top: 6, bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: kBodyStyle)),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: kBodyStyle)),
        ],
      ),
    ),
  );
}

class _NeedsNote extends StatefulWidget {
  const _NeedsNote({required this.initial, required this.onSave});

  final String initial;
  final ValueChanged<String> onSave;

  @override
  State<_NeedsNote> createState() => _NeedsNoteState();
}

class _NeedsNoteState extends State<_NeedsNote> {
  late final _controller = TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!mounted || _focus.hasFocus) return;
      if (_controller.text.trim() != widget.initial) {
        widget.onSave(_controller.text.trim());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppGroup(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          minLines: 1,
          maxLines: 3,
          style: kBodyStyle,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            labelText: 'More about your needs',
            hintText: 'e.g. Manual wheelchair, about 65 cm wide',
          ),
        ),
      ),
    ],
  );
}
