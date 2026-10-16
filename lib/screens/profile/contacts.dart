import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

const _relationships = ['Parent', 'Spouse', 'Sibling', 'Child', 'Caregiver', 'Friend', 'Other'];

/// Opens the phone app with this contact's number.
Future<void> callContact(BuildContext context, EmergencyContact c) async {
  final digits = c.phone.replaceAll(RegExp(r'[^0-9+]'), '');
  var ok = false;
  try {
    ok = await launchUrl(Uri(scheme: 'tel', path: digits));
  } on PlatformException {
    ok = false;
  }
  if (!ok && context.mounted) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text("Can't call from this device"),
        content: Text('Call ${c.name} on ${c.phone} from another phone.'),
        actions: [CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }
}

/// The list of emergency contacts on the profile page.
/// Swipe a row left to delete it, tap it to edit.
class ContactsGroup extends StatelessWidget {
  const ContactsGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final contacts = context.select<ProfileState, List<EmergencyContact>>((s) => s.profile?.contacts ?? const []);

    if (contacts.isEmpty) {
      return Group(
        children: [
          Pressable(
            semanticLabel: 'Add an emergency contact',
            onTap: () => showContactSheet(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(CupertinoIcons.person_crop_circle_fill, size: 26, color: Palette.moss),
                  SizedBox(width: 12),
                  Expanded(child: Text('Add someone to call in an emergency', style: TextStyles.body)),
                  Icon(CupertinoIcons.chevron_right, size: 16, color: Palette.tertiary),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Group(
      dividerIndent: 68,
      children: [
        for (var i = 0; i < contacts.length; i++)
          Dismissible(
            key: ValueKey(contacts[i].id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: const Color(0xFFD64545),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            confirmDismiss: (_) => _confirmDelete(context, contacts[i]),
            onDismissed: (_) => _delete(context, contacts[i]),
            child: _ContactRow(contact: contacts[i], primary: i == 0),
          ),
      ],
    );
  }

  Future<bool> _confirmDelete(BuildContext context, EmergencyContact c) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Remove ${c.name}?'),
        content: const Text('They will no longer show as an emergency contact.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    return ok ?? false;
  }

  void _delete(BuildContext context, EmergencyContact c) {
    HapticFeedback.mediumImpact();
    context.read<ProfileState>().update((p) => p.copyWith(contacts: p.contacts.where((x) => x.id != c.id).toList()));
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.primary});

  final EmergencyContact contact;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.surface,
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              semanticLabel: '${contact.name}, ${contact.relationship}, ${contact.phone}. Edit',
              onTap: () => showContactSheet(context, existing: contact),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: Palette.mint, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        contact.name.isEmpty ? '?' : contact.name.characters.first.toUpperCase(),
                        style: TextStyles.headline.copyWith(color: Palette.moss),
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
                              Text(contact.name, style: TextStyles.body),
                              if (primary) const Tag('Primary'),
                            ],
                          ),
                          Text('${contact.relationship}, ${contact.phone}', style: TextStyles.footnote),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Pressable(
            semanticLabel: 'Call ${contact.name}',
            onTap: () => callContact(context, contact),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Palette.moss, shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.phone_fill, size: 19, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add a new contact, or edit one when [existing] is given.
Future<void> showContactSheet(BuildContext context, {EmergencyContact? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _ContactSheet(existing: existing),
  );
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet({this.existing});

  final EmergencyContact? existing;

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late String _relationship = widget.existing?.relationship ?? 'Parent';
  bool _saving = false;

  bool get _valid =>
      _name.text.trim().isNotEmpty && _phone.text.replaceAll(RegExp(r'[^0-9]'), '').length >= 9;

  @override
  void initState() {
    super.initState();
    _name.addListener(_refresh);
    _phone.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final contact = EmergencyContact(
      id: widget.existing?.id ?? 'ec_${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      relationship: _relationship,
      phone: _phone.text.trim(),
    );
    try {
      await context.read<ProfileState>().update((p) {
        final list = [...p.contacts];
        final i = list.indexWhere((c) => c.id == contact.id);
        if (i >= 0) {
          list[i] = contact;
        } else {
          list.add(contact);
        }
        return p.copyWith(contacts: list);
      });
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(editing ? 'Edit contact' : 'Emergency contact', style: TextStyles.title2),
          const SizedBox(height: 16),
          Group(
            color: Palette.field,
            children: [
              _Field(controller: _name, label: 'Name', hint: 'e.g. Aminah', autofocus: !editing, words: true),
              _Field(controller: _phone, label: 'Phone', hint: 'e.g. +60 12-345 6789', phone: true),
            ],
          ),
          const SizedBox(height: 18),
          Text('Relationship', style: TextStyles.subhead.copyWith(color: Palette.ink)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _relationships)
                Pressable(
                  selected: r == _relationship,
                  semanticLabel: r,
                  onTap: () => setState(() => _relationship = r),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: r == _relationship ? Palette.moss : Palette.field,
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    child: Text(
                      r,
                      style: TextStyles.callout.copyWith(color: r == _relationship ? Colors.white : Palette.ink),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: editing ? 'Save changes' : 'Add contact',
            loading: _saving,
            onPressed: _valid ? _submit : null,
          ),
          if (!_valid && _phone.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Enter a phone number with at least 9 digits.', textAlign: TextAlign.center, style: TextStyles.footnote),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.autofocus = false,
    this.phone = false,
    this.words = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool autofocus;
  final bool phone;
  final bool words;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: phone ? TextInputType.phone : TextInputType.name,
          textCapitalization: words ? TextCapitalization.words : TextCapitalization.none,
          style: TextStyles.body,
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: label,
            labelStyle: TextStyles.footnote,
            floatingLabelStyle: TextStyles.footnote,
            hintText: hint,
            hintStyle: TextStyles.body.copyWith(color: Palette.tertiary),
          ),
        ),
      );
}
