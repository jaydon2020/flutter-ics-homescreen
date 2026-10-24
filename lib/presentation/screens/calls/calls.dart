import 'package:flutter_ics_homescreen/export.dart';
import 'package:intl/intl.dart';

enum _PhoneSection { recents, contacts, dial }

class CallsPage extends ConsumerStatefulWidget {
  const CallsPage({super.key});
  static Page<void> page() => const MaterialPage<void>(child: CallsPage());

  @override
  ConsumerState<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends ConsumerState<CallsPage> {
  _PhoneSection _section = _PhoneSection.dial;
  String _number = '';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callStateProvider);
    if (call.hasCall) {
      return Column(
        children: [
          CommonTitle(
            title: 'Phone',
            hasBackButton: true,
            onPressed: () =>
                ref.read(appProvider.notifier).update(AppState.apps),
          ),
          const Expanded(child: ActiveCallScreen()),
        ],
      );
    }
    final phone = ref.watch(phoneDataProvider);
    return Column(
      children: [
        CommonTitle(
          title: 'Phone',
          hasBackButton: true,
          onPressed: () => ref.read(appProvider.notifier).update(AppState.apps),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final landscape = constraints.maxWidth > constraints.maxHeight;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth >= 700 ? 120 : 24,
                  20,
                  28,
                  120,
                ),
                child: Column(
                  children: [
                    _PhoneStatus(call: call, phone: phone),
                    const SizedBox(height: 16),
                    _SectionSelector(
                      selected: _section,
                      onChanged: (section) =>
                          setState(() => _section = section),
                    ),
                    if (call.error != null || phone.error != null) ...[
                      const SizedBox(height: 12),
                      _InlineError(
                        message: call.error ?? phone.error!,
                        onRetry: () {
                          ref.read(callStateProvider.notifier).retry();
                          ref.read(phoneDataProvider.notifier).retry();
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    Expanded(
                      child: switch (_section) {
                        _PhoneSection.recents => _RecentsView(
                          items: phone.recents,
                        ),
                        _PhoneSection.contacts => _ContactsView(
                          contacts: phone.contacts,
                          query: _query,
                          onQueryChanged: (value) =>
                              setState(() => _query = value),
                        ),
                        _PhoneSection.dial => _DialView(
                          number: _number,
                          landscape: landscape,
                          enabled: call.connected && !call.busy,
                          onDigit: (digit) {
                            if (_number.length < 32) {
                              setState(() => _number += digit);
                            }
                          },
                          onClear: () => setState(() => _number = ''),
                          onDelete: () {
                            if (_number.isNotEmpty) {
                              setState(
                                () => _number = _number.substring(
                                  0,
                                  _number.length - 1,
                                ),
                              );
                            }
                          },
                        ),
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PhoneStatus extends StatelessWidget {
  const _PhoneStatus({required this.call, required this.phone});
  final CallState call;
  final PhoneDataState phone;

  @override
  Widget build(BuildContext context) {
    final ready = call.connected;
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AGLDemoColors.callControlColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.phone_rounded,
              color: AGLDemoColors.jordyBlueColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Phone',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  phone.deviceName ?? 'No phone connected',
                  style: const TextStyle(
                    color: AGLDemoColors.periwinkleColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color:
                  (ready
                          ? AGLDemoColors.greenColor
                          : AGLDemoColors.periwinkleColor)
                      .withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  ready
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_disabled_rounded,
                  size: 19,
                  color: ready
                      ? AGLDemoColors.greenColor
                      : AGLDemoColors.periwinkleColor,
                ),
                const SizedBox(width: 8),
                Text(
                  ready
                      ? 'Ready'
                      : phone.deviceName == null
                      ? 'Disconnected'
                      : 'Calls unavailable',
                  style: TextStyle(
                    color: ready
                        ? AGLDemoColors.greenColor
                        : AGLDemoColors.periwinkleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionSelector extends StatelessWidget {
  const _SectionSelector({required this.selected, required this.onChanged});
  final _PhoneSection selected;
  final ValueChanged<_PhoneSection> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    decoration: BoxDecoration(
      color: AGLDemoColors.backgroundInsetColor.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(28),
    ),
    padding: const EdgeInsets.all(6),
    child: Row(
      children: [
        for (final section in _PhoneSection.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: section == selected,
              child: InkWell(
                key: ValueKey('phone-tab-${section.name}'),
                borderRadius: BorderRadius.circular(22),
                onTap: () => onChanged(section),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: section == selected
                        ? AGLDemoColors.buttonFillEnabledColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    section.name[0].toUpperCase() + section.name.substring(1),
                    style: TextStyle(
                      color: section == selected
                          ? Colors.white
                          : AGLDemoColors.periwinkleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _RecentsView extends ConsumerWidget {
  const _RecentsView({required this.items});
  final List<RecentCall> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_rounded,
        title: 'No recent calls',
        subtitle: 'Call history will sync from the connected phone.',
      );
    }
    return RefreshIndicator(
      onRefresh: ref.read(phoneDataProvider.notifier).refreshRecents,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final missed = item.type == RecentCallType.missed;
          final icon = switch (item.type) {
            RecentCallType.outgoing => Icons.call_made_rounded,
            RecentCallType.missed => Icons.call_missed_rounded,
            _ => Icons.call_received_rounded,
          };
          return _PhoneRow(
            leading: _InitialAvatar(name: item.name),
            title: item.name,
            subtitle: item.number,
            meta: DateFormat('MMM d  •  h:mm a').format(item.timestamp),
            statusIcon: icon,
            statusColor: missed
                ? AGLDemoColors.callDangerColor
                : AGLDemoColors.jordyBlueColor,
            primaryIcon: Icons.call_rounded,
            onPrimary: () => ref
                .read(callStateProvider.notifier)
                .startCall(item.number, name: item.name),
          );
        },
      ),
    );
  }
}

class _ContactsView extends ConsumerStatefulWidget {
  const _ContactsView({
    required this.contacts,
    required this.query,
    required this.onQueryChanged,
  });
  final List<PhoneContact> contacts;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  ConsumerState<_ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends ConsumerState<_ContactsView> {
  final _scrollController = ScrollController();
  bool _refreshing = false;

  Future<void> _refreshContacts() async {
    setState(() => _refreshing = true);
    try {
      await ref.read(phoneDataProvider.notifier).refreshContacts(force: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canRefresh = ref.watch(
      phoneDataProvider.select(
        (phone) => phone.status == PhoneConnectionStatus.ready && !phone.busy,
      ),
    );
    final normalized = widget.query.toLowerCase();
    final filtered = widget.contacts
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(normalized) ||
              contact.numbers.any((number) => number.contains(widget.query)),
        )
        .toList();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: widget.onQueryChanged,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Search contacts',
                  hintStyle: const TextStyle(
                    color: AGLDemoColors.periwinkleColor,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AGLDemoColors.jordyBlueColor,
                  ),
                  filled: true,
                  fillColor: AGLDemoColors.callSurfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: _refreshing ? 'Refreshing contacts' : 'Refresh contacts',
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              onPressed: canRefresh && !_refreshing ? _refreshContacts : null,
              icon: _refreshing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 32),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState(
                  icon: Icons.contacts_rounded,
                  title: 'No contacts found',
                  subtitle: 'Connect a phone with contact sharing enabled.',
                )
              : RawScrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  interactive: true,
                  thickness: 28,
                  minThumbLength: 80,
                  radius: const Radius.circular(14),
                  thumbColor: AGLDemoColors.periwinkleColor,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(right: 36),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final contact = filtered[index];
                      final letter = contact.name.isEmpty
                          ? '#'
                          : contact.name[0].toUpperCase();
                      final previousLetter = index == 0
                          ? null
                          : filtered[index - 1].name.isEmpty
                          ? '#'
                          : filtered[index - 1].name[0].toUpperCase();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (letter != previousLetter)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                              child: Text(
                                letter,
                                style: const TextStyle(
                                  color: AGLDemoColors.jordyBlueColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          _PhoneRow(
                            wifiGradient: true,
                            leading: _ContactAvatar(contact: contact),
                            title: contact.name,
                            subtitle: contact.primaryNumber,
                            primaryIcon: Icons.call_rounded,
                            onPrimary: () =>
                                _callContact(context, ref, contact),
                            secondaryIcon: Icons.message_rounded,
                            onSecondary: () {
                              ref
                                  .read(phoneDataProvider.notifier)
                                  .composeTo(contact.primaryNumber);
                              ref
                                  .read(appProvider.notifier)
                                  .update(AppState.messages);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _callContact(
    BuildContext context,
    WidgetRef ref,
    PhoneContact contact,
  ) async {
    if (contact.numbers.length == 1) {
      await ref
          .read(callStateProvider.notifier)
          .startCall(contact.primaryNumber, name: contact.name);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AGLDemoColors.callSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Call ${contact.name}'),
        children: [
          for (final number in contact.numbers)
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              onPressed: () {
                Navigator.pop(context);
                ref
                    .read(callStateProvider.notifier)
                    .startCall(number, name: contact.name);
              },
              child: Row(
                children: [
                  const Icon(
                    Icons.call_rounded,
                    color: AGLDemoColors.greenColor,
                  ),
                  const SizedBox(width: 16),
                  Text(number, style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DialView extends ConsumerWidget {
  const _DialView({
    required this.number,
    required this.landscape,
    required this.enabled,
    required this.onDigit,
    required this.onClear,
    required this.onDelete,
  });
  final String number;
  final bool landscape;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numberArea = SizedBox(
      height: 64,
      child: Center(
        child: number.isEmpty
            ? const Text(
                'Enter a number',
                style: TextStyle(
                  color: AGLDemoColors.periwinkleColor,
                  fontSize: 18,
                ),
              )
            : FittedBox(
                child: Text(
                  number,
                  key: const ValueKey('dialed-number'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
      ),
    );
    final keypad = PhoneKeypad(
      key: const ValueKey('dial-keypad'),
      keyPrefix: 'dial-key',
      onKeyPressed: onDigit,
      onZeroLongPress: () => onDigit('+'),
    );
    final actions = Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: number.isEmpty ? null : onClear,
            child: const Text('Clear', style: TextStyle(fontSize: 17)),
          ),
        ),
        Expanded(
          child: Center(
            child: SizedBox.square(
              dimension: 76,
              child: ElevatedButton(
                onPressed: !enabled || number.isEmpty
                    ? null
                    : () => ref
                          .read(callStateProvider.notifier)
                          .startCall(number),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AGLDemoColors.greenColor,
                  disabledBackgroundColor: AGLDemoColors.callControlColor,
                  foregroundColor: AGLDemoColors.backgroundInsetColor,
                  shape: const CircleBorder(),
                ),
                child: const Icon(Icons.call_rounded, size: 34),
              ),
            ),
          ),
        ),
        Expanded(
          child: IconButton(
            tooltip: 'Delete last digit',
            onPressed: number.isEmpty ? null : onDelete,
            icon: const Icon(Icons.backspace_outlined),
            color: AGLDemoColors.periwinkleColor,
            iconSize: 30,
          ),
        ),
      ],
    );
    if (landscape) {
      return Row(
        children: [
          Expanded(child: numberArea),
          const SizedBox(width: 40),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                children: [keypad, const SizedBox(height: 16), actions],
              ),
            ),
          ),
        ],
      );
    }
    return SingleChildScrollView(
      reverse: true,
      child: Column(
        children: [
          numberArea,
          const SizedBox(height: 12),
          keypad,
          const SizedBox(height: 16),
          actions,
        ],
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    this.wifiGradient = false,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.primaryIcon,
    required this.onPrimary,
    this.meta,
    this.statusIcon,
    this.statusColor,
    this.secondaryIcon,
    this.onSecondary,
  });
  final Widget leading;
  final bool wifiGradient;
  final String title;
  final String subtitle;
  final String? meta;
  final IconData? statusIcon;
  final Color? statusColor;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Container(
    height: 128,
    padding: const EdgeInsets.symmetric(horizontal: 22),
    decoration: BoxDecoration(
      gradient: wifiGradient
          ? const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xff2388e8), AGLDemoColors.buttonFillEnabledColor],
            )
          : const LinearGradient(
              colors: [Color(0xff050711), Color(0xff101638)],
            ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        leading,
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  if (statusIcon != null) ...[
                    Icon(statusIcon, size: 17, color: statusColor),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AGLDemoColors.periwinkleColor,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (meta != null) ...[
          Text(
            meta!,
            style: const TextStyle(
              color: AGLDemoColors.periwinkleColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
        ],
        if (secondaryIcon != null) ...[
          SizedBox.square(
            dimension: 64,
            child: IconButton(
              onPressed: onSecondary,
              tooltip: 'Message',
              icon: Icon(secondaryIcon),
              color: AGLDemoColors.jordyBlueColor,
              iconSize: 28,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 8),
        ],
        SizedBox.square(
          dimension: 64,
          child: IconButton(
            onPressed: onPrimary,
            tooltip: 'Call',
            icon: Icon(primaryIcon),
            color: AGLDemoColors.greenColor,
            iconSize: 30,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    ),
  );
}

class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar({required this.contact});
  final PhoneContact contact;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 34,
    backgroundColor: AGLDemoColors.callControlColor,
    backgroundImage: contact.photo == null ? null : MemoryImage(contact.photo!),
    child: contact.photo == null
        ? Text(
            contact.initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          )
        : null,
  );
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 34,
    backgroundColor: AGLDemoColors.callControlColor,
    child: Text(
      name.isEmpty ? '?' : name[0].toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AGLDemoColors.jordyBlueColor, size: 64),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AGLDemoColors.periwinkleColor,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.only(left: 16),
    decoration: BoxDecoration(
      color: AGLDemoColors.callDangerColor.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AGLDemoColors.callDangerColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
