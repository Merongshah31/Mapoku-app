import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_colors.dart';
import '../models/profile.dart';
import '../state/app_scope.dart';
import 'ui_kit.dart';

const _relationships = [
  'Parent',
  'Spouse',
  'Sibling',
  'Child',
  'Caregiver',
  'Friend',
  'Other',
];

/// Opens the phone app with this contact's number.
Future<void> callContact(BuildContext context, EmergencyContact contact) async {
  final digits = contact.phone.replaceAll(RegExp(r'[^0-9+]'), '');
  var ok = false;
  try {
    ok = await launchUrl(Uri(scheme: 'tel', path: digits));
  } on PlatformException {
    ok = false;
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    showAdaptiveDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text("Can't call from this device"),
        content: Text(
          'Call ${contact.name} on ${contact.phone} from another phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
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
    final contacts = AppScope.of(context).profile.contacts;

    if (contacts.isEmpty) {
      return AppGroup(
        children: [
          InkWell(
            onTap: () => showContactSheet(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.person_add,
                    size: 24,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add someone to call in an emergency',
                      style: kBodyStyle,
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return AppGroup(
      dividerIndent: 68,
      children: [
        for (var i = 0; i < contacts.length; i++)
          Dismissible(
            key: ValueKey(contacts[i].id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: AppColors.danger,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            confirmDismiss: (_) => _confirmDelete(context, contacts[i]),
            onDismissed: (_) => _delete(context, contacts[i]),
            child: _ContactRow(contact: contacts[i], primary: i == 0),
          ),
      ],
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    EmergencyContact contact,
  ) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text('Remove ${contact.name}?'),
        content: const Text(
          'They will no longer show as an emergency contact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _delete(BuildContext context, EmergencyContact contact) {
    HapticFeedback.mediumImpact();
    AppScope.of(context).updateProfile(
      (p) => p.copyWith(
        contacts: p.contacts.where((x) => x.id != contact.id).toList(),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.primary});

  final EmergencyContact contact;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.card,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label:
                  '${contact.name}, ${contact.relationship}, ${contact.phone}. Edit',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => showContactSheet(context, existing: contact),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.mint,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          contact.name.isEmpty
                              ? '?'
                              : contact.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
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
                                Text(contact.name, style: kBodyStyle),
                                if (primary) const _PrimaryTag(),
                              ],
                            ),
                            Text(
                              '${contact.relationship}, ${contact.phone}',
                              style: kFootnoteStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
            child: IconButton.filled(
              tooltip: 'Call ${contact.name}',
              onPressed: () => callContact(context, contact),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(44, 44),
              ),
              icon: const Icon(CupertinoIcons.phone_fill, size: 19, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryTag extends StatelessWidget {
  const _PrimaryTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Text(
      'Primary',
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    ),
  );
}

/// Add a new contact, or edit one when [existing] is given.
Future<void> showContactSheet(
  BuildContext context, {
  EmergencyContact? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
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
      _name.text.trim().isNotEmpty &&
      _phone.text.replaceAll(RegExp(r'[^0-9]'), '').length >= 9;

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
      await AppScope.of(context).updateProfile((p) {
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
    final insets =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editing ? 'Edit contact' : 'Emergency contact',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          AppGroup(
            color: AppColors.field,
            bordered: false,
            children: [
              _Field(
                controller: _name,
                label: 'Name',
                hint: 'e.g. Aminah',
                autofocus: !editing,
                words: true,
              ),
              _Field(
                controller: _phone,
                label: 'Phone',
                hint: 'e.g. +60 12-345 6789',
                phone: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Relationship',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _relationships)
                Semantics(
                  button: true,
                  selected: r == _relationship,
                  label: r,
                  excludeSemantics: true,
                  child: Material(
                    color: r == _relationship
                        ? AppColors.primary
                        : AppColors.field,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => _relationship = r),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        child: Text(
                          r,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: r == _relationship
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _valid && !_saving ? _submit : null,
            child: Text(
              _saving ? 'Saving…' : (editing ? 'Save changes' : 'Add contact'),
            ),
          ),
          if (!_valid && _phone.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Enter a phone number with at least 9 digits.',
              textAlign: TextAlign.center,
              style: kFootnoteStyle,
            ),
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
      textCapitalization: words
          ? TextCapitalization.words
          : TextCapitalization.none,
      style: kBodyStyle,
      decoration: InputDecoration(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        labelText: label,
        hintText: hint,
      ),
    ),
  );
}
