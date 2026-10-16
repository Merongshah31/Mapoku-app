import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../state/routes_controller.dart';
import '../profile/contacts.dart';
import '../profile/profile_screen.dart';
import '../../widgets/common.dart';
import '../../widgets/obstacle_ui.dart';

/// Content of the draggable sheet on the Routes tab.
/// Search → compare → navigate, all in one place, the way Apple Maps works.
class RouteSheetContent extends StatefulWidget {
  const RouteSheetContent({super.key, required this.scrollController, required this.bottomPadding});

  final ScrollController scrollController;
  final double bottomPadding;

  @override
  State<RouteSheetContent> createState() => _RouteSheetContentState();
}

class _RouteSheetContentState extends State<RouteSheetContent> {
  final _from = TextEditingController(text: 'Your location');
  String? _townshipId;
  final _to = TextEditingController();
  final _toFocus = FocusNode();

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    final needs = context.read<ProfileState>().profile?.needs ?? const <MobilityNeed>{};
    context.read<RoutesController>().search(from: _from.text, to: _to.text, needs: needs);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoutesController>();
    final Widget body = switch (c.phase) {
      RoutesPhase.idle || RoutesPhase.searching => _searchBody(c),
      RoutesPhase.results => _ResultsBody(onEdit: c.clear),
      RoutesPhase.navigating => const _NavigatingBody(),
    };

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottomPadding),
      children: [
        const _Grabber(),
        body,
      ],
    );
  }

  /// When the township changes, start from its station/entrance and clear "To".
  void _syncTownship(Township? t) {
    if (t == null || t.id == _townshipId) return;
    _townshipId = t.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _from.text = t.start.name;
      _to.clear();
    });
  }

  Widget _searchBody(RoutesController c) {
    final searching = c.phase == RoutesPhase.searching;
    final t = c.township;
    _syncTownship(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Where to?', style: TextStyles.title2),
              if (t != null) ...[
                const SizedBox(height: 2),
                Text('${t.name}, ${t.location}', style: TextStyles.subhead),
              ],
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Group(
                color: Palette.field,
                dividerIndent: 48,
                children: [
                  _PlaceField(
                    label: 'From',
                    controller: _from,
                    leading: const Icon(CupertinoIcons.location_fill, size: 18, color: Palette.ink),
                    onSubmitted: (_) => _toFocus.requestFocus(),
                  ),
                  _PlaceField(
                    label: 'To',
                    controller: _to,
                    focusNode: _toFocus,
                    hint: 'Search a place',
                    leading: const Icon(CupertinoIcons.placemark_fill, size: 18, color: Palette.moss),
                    onSubmitted: (_) => _search(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              semanticLabel: 'Swap start and destination',
              onTap: () {
                final t = _from.text;
                _from.text = _to.text;
                _to.text = t;
              },
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(CupertinoIcons.arrow_up_arrow_down, size: 20, color: Palette.secondary),
              ),
            ),
          ],
        ),
        if (c.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(c.error!, style: TextStyles.footnote.copyWith(color: Palette.amberText)),
          ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Find accessible routes',
          icon: CupertinoIcons.search,
          loading: searching,
          onPressed: _search,
        ),
        if (t != null) ...[
          SectionTitle('Popular in ${t.name}'),
          Group(
            dividerIndent: 60,
            children: [
              for (final p in t.popular)
                _RecentRow(
                  title: p.name,
                  subtitle: t.category,
                  onTap: () {
                    _to.text = p.name;
                    _search();
                  },
                ),
            ],
          ),
        ],
        const _PlannedFor(),
      ],
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 10),
          width: 36,
          height: 5,
          decoration: BoxDecoration(color: const Color(0x401E2B22), borderRadius: BorderRadius.circular(3)),
        ),
      );
}

class _PlaceField extends StatelessWidget {
  const _PlaceField({
    required this.label,
    required this.controller,
    required this.leading,
    this.hint,
    this.focusNode,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final Widget leading;
  final String? hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 20, child: leading),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: TextStyles.body,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                labelText: label,
                labelStyle: TextStyles.footnote,
                floatingLabelStyle: TextStyles.footnote,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: hint,
                hintStyle: TextStyles.body.copyWith(color: Palette.tertiary),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.title, required this.subtitle, required this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: 'Route to $title',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Palette.field, shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.placemark_fill, size: 17, color: Palette.moss),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyles.callout),
                    Text(subtitle, style: TextStyles.footnote),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right, size: 16, color: Palette.tertiary),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------- results

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoutesController>();
    final plan = c.plan!;
    final s = plan.suggestion;
    final n = plan.obstacles.length;
    final stepFreeSelected = c.selected == RouteKind.stepFree;

    final stepFreeDetail = s == null
        ? '${plan.stepFree.meters} m, no stairs. Avoids ${n == 0 ? 'every reported obstacle' : 'all $n reported obstacles'}.'
        : 'Goes to ${plan.stepFree.destination.name}, ${s.kmFromRequested} km away. '
            'Avoids all $n obstacles.';
    final extraMin = plan.stepFree.minutes - plan.standard.minutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Destination header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.requested.name, style: TextStyles.title2),
                    const SizedBox(height: 4),
                    if (n > 0)
                      Row(
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 15, color: Palette.amber),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '$n ${n == 1 ? 'obstacle' : 'obstacles'} reported on the usual way there',
                              style: TextStyles.subhead.copyWith(color: Palette.amberText),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Pressable(
                onTap: onEdit,
                semanticLabel: 'Change destination',
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(CupertinoIcons.xmark_circle_fill, size: 28, color: Color(0x591E2B22)),
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('Choose a route'),
        Group(
          dividerIndent: 52,
          children: [
            _RouteChoice(
              option: plan.stepFree,
              title: 'OKU-safe',
              tag: s == null ? null : 'Suggested',
              detail: stepFreeDetail,
              selected: stepFreeSelected,
            ),
            _RouteChoice(
              option: plan.standard,
              title: 'Standard',
              detail: n == 0
                  ? '${plan.standard.meters} m, the shortest way there.'
                  : '${plan.standard.meters} m. Shortest, but passes $n reported ${n == 1 ? 'obstacle' : 'obstacles'}.',
              warn: n > 0,
              selected: !stepFreeSelected,
            ),
          ],
        ),
        if (stepFreeSelected && s != null) ...[
          SectionTitle('Why ${plan.stepFree.destination.name}'),
          Group(children: [for (final r in s.reasons) _ReasonRow(r)]),
          SectionFooter('Adds ${s.extraMinutes} min compared with the standard route.'),
        ],
        if (stepFreeSelected && s == null && plan.stepFree.highlights.isNotEmpty) ...[
          const SectionTitle('Why this route'),
          Group(children: [for (final r in plan.stepFree.highlights) _ReasonRow(r)]),
          if (extraMin > 0)
            SectionFooter(
              'Times use a wheelchair pace for the OKU-safe route. It takes $extraMin min longer than the standard route.',
            ),
        ],
        if (!stepFreeSelected && n > 0) ...[
          const SectionTitle('Reported on this route'),
          Group(
            dividerIndent: 64,
            children: [
              for (final o in plan.obstacles) ObstacleRow(obstacle: o, onTap: () => showObstacleSheet(context, o)),
            ],
          ),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: stepFreeSelected ? 'Start OKU-safe route' : 'Start standard route',
          icon: CupertinoIcons.location_north_fill,
          onPressed: () {
            HapticFeedback.mediumImpact();
            c.start();
          },
        ),
      ],
    );
  }
}

class _RouteChoice extends StatelessWidget {
  const _RouteChoice({
    required this.option,
    required this.title,
    required this.detail,
    required this.selected,
    this.tag,
    this.warn = false,
  });

  final RouteOption option;
  final String title;
  final String detail;
  final String? tag;
  final bool selected;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final c = context.read<RoutesController>();
    return Pressable(
      selected: selected,
      semanticLabel: '$title route, ${option.minutes} minutes. $detail',
      onTap: () => c.select(option.kind),
      child: Container(
        color: selected ? Palette.mint : null,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                size: 24,
                color: selected ? Palette.moss : Palette.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(title, style: TextStyles.headline),
                      if (tag != null) Tag(tag!),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyles.subhead.copyWith(color: warn ? Palette.amberText : Palette.secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${option.minutes}', style: TextStyles.title3),
                const TextSpan(text: ' min', style: TextStyles.subhead),
              ]),
              style: const TextStyle(fontFeatures: TextStyles.tabular),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(CupertinoIcons.checkmark, size: 16, color: Palette.moss),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyles.callout)),
          ],
        ),
      );
}

// ---------------------------------------------------------------- navigating

class _NavigatingBody extends StatelessWidget {
  const _NavigatingBody();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoutesController>();
    final o = c.selectedOption!;
    final stepFree = o.kind == RouteKind.stepFree;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.destination.name, style: TextStyles.title2),
                    const SizedBox(height: 2),
                    Text(stepFree ? 'OKU-safe route' : 'Standard route', style: TextStyles.subhead),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${o.minutes}', style: TextStyles.title2.copyWith(color: Palette.moss)),
                  TextSpan(text: ' min', style: TextStyles.subhead.copyWith(color: Palette.moss)),
                ]),
                style: const TextStyle(fontFeatures: TextStyles.tabular),
              ),
            ],
          ),
        ),
        const SectionTitle('Directions'),
        Group(
          dividerIndent: 64,
          children: [for (final s in o.steps) _StepRow(s)],
        ),
        const _EmergencyCall(),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'End route',
          tone: ButtonTone.plain,
          onPressed: () {
            HapticFeedback.lightImpact();
            c.endTrip();
          },
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.step);

  final RouteStep step;

  IconData get _icon => switch (step.turn) {
        Turn.straight => CupertinoIcons.arrow_up,
        Turn.left => CupertinoIcons.arrow_turn_up_left,
        Turn.right => CupertinoIcons.arrow_turn_up_right,
        Turn.arrive => CupertinoIcons.flag_fill,
      };

  @override
  Widget build(BuildContext context) {
    final caution = step.caution;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: Palette.mint, borderRadius: BorderRadius.circular(10)),
            child: Icon(_icon, size: 19, color: Palette.moss),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(step.instruction, style: TextStyles.callout),
                ),
                if (caution != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: Palette.amberSoft, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 14, color: Palette.amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(caution, style: TextStyles.footnote.copyWith(color: Palette.amberText)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- profile ties

/// Shows whose needs the route is planned around, with a link to change them.
class _PlannedFor extends StatelessWidget {
  const _PlannedFor();

  @override
  Widget build(BuildContext context) {
    final needs = context.select<ProfileState, Set<MobilityNeed>?>((p) => p.profile?.needs);
    final text = (needs == null || needs.isEmpty)
        ? 'Routes avoid obstacles other users have reported.'
        : 'Planned for: ${needs.map((n) => n.label).join(', ')}.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$text ', style: TextStyles.footnote),
          Pressable(
            semanticLabel: 'Change accessibility needs',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              CupertinoPageRoute<void>(builder: (_) => const ProfileScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Change', style: TextStyles.footnote.copyWith(color: Palette.moss, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-tap call to the primary emergency contact while on a trip.
class _EmergencyCall extends StatelessWidget {
  const _EmergencyCall();

  @override
  Widget build(BuildContext context) {
    final contacts = context.select<ProfileState, List<EmergencyContact>>((p) => p.profile?.contacts ?? const []);
    if (contacts.isEmpty) return const SizedBox.shrink();
    final c = contacts.first;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Group(
        children: [
          Pressable(
            semanticLabel: 'Call ${c.name}, your emergency contact',
            onTap: () => callContact(context, c),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: Palette.moss, shape: BoxShape.circle),
                    child: const Icon(CupertinoIcons.phone_fill, size: 17, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Call ${c.name}', style: TextStyles.callout.copyWith(fontWeight: FontWeight.w600)),
                        Text('Emergency contact, ${c.relationship}', style: TextStyles.footnote),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
