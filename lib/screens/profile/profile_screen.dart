import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'contacts.dart';

/// Profile: accessibility needs, route preferences and emergency contacts.
/// Demo data for now; saved through MapokuRepository.saveProfile.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProfileState>();
    final p = state.profile;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Profile'),
            previousPageTitle: 'Back',
            backgroundColor: Palette.page.withValues(alpha: 0.9),
            border: null,
          ),
          if (p == null)
            const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 32),
              sliver: SliverList.list(
                children: [
                  _Identity(profile: p),
                  const SectionTitle('Accessibility needs'),
                  Group(
                    dividerIndent: 52,
                    children: [
                      for (final need in MobilityNeed.values)
                        _NeedRow(
                          need: need,
                          selected: p.needs.contains(need),
                          onTap: () => _save(context, (x) {
                            final needs = {...x.needs};
                            needs.contains(need) ? needs.remove(need) : needs.add(need);
                            return x.copyWith(needs: needs);
                          }),
                        ),
                    ],
                  ),
                  const SectionFooter('Pick all that apply. Routes and warnings are planned around these.'),
                  const SizedBox(height: 16),
                  _NeedsNote(initial: p.needsNote),
                  const SectionFooter('Optional. Helps others understand what fits, e.g. your wheelchair width.'),
                  const SectionTitle('Route preferences'),
                  Group(
                    children: [
                      _SwitchRow(
                        label: 'Avoid stairs',
                        value: p.prefs.avoidStairs,
                        onChanged: (v) => _save(context, (x) => x.copyWith(prefs: x.prefs.copyWith(avoidStairs: v))),
                      ),
                      _SwitchRow(
                        label: 'Need a working lift',
                        value: p.prefs.needsLift,
                        onChanged: (v) => _save(context, (x) => x.copyWith(prefs: x.prefs.copyWith(needsLift: v))),
                      ),
                      _SwitchRow(
                        label: 'Avoid steep slopes',
                        value: p.prefs.avoidSteepSlopes,
                        onChanged: (v) =>
                            _save(context, (x) => x.copyWith(prefs: x.prefs.copyWith(avoidSteepSlopes: v))),
                      ),
                      _SwitchRow(
                        label: 'Prefer covered walkways',
                        value: p.prefs.preferSheltered,
                        onChanged: (v) =>
                            _save(context, (x) => x.copyWith(prefs: x.prefs.copyWith(preferSheltered: v))),
                      ),
                    ],
                  ),
                  SectionTitle(
                    'Emergency contacts',
                    trailing: Pressable(
                      semanticLabel: 'Add emergency contact',
                      onTap: () => showContactSheet(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Text('Add', style: TextStyles.body.copyWith(color: Palette.moss)),
                      ),
                    ),
                  ),
                  const ContactsGroup(),
                  const SectionFooter(
                    'Your first contact is shown on the trip screen so you can call them in one tap. '
                    'mapOKU never contacts them for you.',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Saves a profile change and tells the user if it didn't go through.
Future<void> _save(BuildContext context, UserProfile Function(UserProfile) change) async {
  try {
    await context.read<ProfileState>().update(change);
  } catch (_) {
    if (!context.mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: const Text("Your change wasn't saved. Check your connection and try again."),
        actions: [CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.profile});

  final UserProfile profile;

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: profile.name);
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Your name'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && context.mounted) {
      await _save(context, (x) => x.copyWith(name: name));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Group(
      children: [
        Pressable(
          semanticLabel: 'Name, ${profile.name}. Edit',
          onTap: () => _editName(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(color: Palette.mint, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    profile.name.isEmpty ? '?' : profile.name.characters.first.toUpperCase(),
                    style: TextStyles.title2.copyWith(color: Palette.moss),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name, style: TextStyles.title3),
                      const SizedBox(height: 2),
                      Text(profile.email, style: TextStyles.subhead),
                    ],
                  ),
                ),
                Text('Edit', style: TextStyles.body.copyWith(color: Palette.moss)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

IconData needIcon(MobilityNeed n) => switch (n) {
      MobilityNeed.wheelchair => Icons.accessible_outlined,
      MobilityNeed.walkingAid => Icons.directions_walk,
      MobilityNeed.elderly => Icons.elderly,
      MobilityNeed.stroller => Icons.stroller_outlined,
      MobilityNeed.visuallyImpaired => Icons.visibility_off_outlined,
      MobilityNeed.hearingImpaired => Icons.hearing_disabled_outlined,
    };

class _NeedRow extends StatelessWidget {
  const _NeedRow({required this.need, required this.selected, required this.onTap});

  final MobilityNeed need;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        selected: selected,
        semanticLabel: need.label,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(needIcon(need), size: 24, color: Palette.ink),
              const SizedBox(width: 12),
              Expanded(child: Text(need.label, style: TextStyles.body)),
              if (selected) const Icon(CupertinoIcons.checkmark_alt, size: 22, color: Palette.moss),
            ],
          ),
        ),
      );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12, top: 8, bottom: 8),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyles.body)),
              CupertinoSwitch(value: value, activeTrackColor: Palette.moss, onChanged: onChanged),
            ],
          ),
        ),
      );
}

class _NeedsNote extends StatefulWidget {
  const _NeedsNote({required this.initial});

  final String initial;

  @override
  State<_NeedsNote> createState() => _NeedsNoteState();
}

class _NeedsNoteState extends State<_NeedsNote> {
  late final _c = TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!mounted) return;
      if (!_focus.hasFocus && _c.text.trim() != widget.initial) {
        _save(context, (x) => x.copyWith(needsNote: _c.text.trim()));
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Group(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _c,
              focusNode: _focus,
              minLines: 1,
              maxLines: 3,
              style: TextStyles.body,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                border: InputBorder.none,
                labelText: 'More about your needs',
                labelStyle: TextStyles.footnote,
                floatingLabelStyle: TextStyles.footnote,
                hintText: 'e.g. Manual wheelchair, about 65 cm wide',
                hintStyle: TextStyles.body.copyWith(color: Palette.tertiary),
              ),
            ),
          ),
        ],
      );
}
