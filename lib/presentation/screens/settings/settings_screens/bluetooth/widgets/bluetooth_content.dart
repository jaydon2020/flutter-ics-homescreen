import '../../../../../../../export.dart';
import 'package:flutter_ics_homescreen/core/utils/helpers.dart';

const double _bluetoothPrimaryTileHeight = 130;

final _savedBluetoothDevicesExpandedProvider = StateProvider<bool>((ref) {
  return true;
});

final _unknownBluetoothDevicesExpandedProvider = StateProvider<bool>((ref) {
  return false;
});

final _showPairBluetoothDeviceProvider = StateProvider<bool>((ref) {
  return false;
});

final _showAllSavedBluetoothDevicesProvider = StateProvider<bool>((ref) {
  return false;
});

final _showBluetoothTipsProvider = StateProvider<bool>((ref) {
  return false;
});

final _expandedBluetoothDeviceIdProvider = StateProvider<String?>((ref) {
  return null;
});

final _disconnectingDeviceIdProvider = StateProvider<String?>((ref) {
  return null;
});

class BluetoothContent extends ConsumerWidget {
  const BluetoothContent({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bluetoothState = ref.watch(bluetoothPowerProvider);
    final state = bluetoothState.valueOrNull;
    final errorMessage = bluetoothState.whenOrNull(
          error: (error, _) => error.toString(),
        ) ??
        state?.error;
    final pairableDevices = state?.devices
            .where((device) =>
                !device.paired && !device.connected && !device.isSavedOnly)
            .toList() ??
        const <BluetoothDeviceInfo>[];
    final connectedDevices =
        state?.devices.where((device) => device.connected).toList() ??
            const <BluetoothDeviceInfo>[];
    final savedDevices = state?.devices
            .where((device) =>
                !device.connected && (device.paired || device.isSavedOnly))
            .toList() ??
        const <BluetoothDeviceInfo>[];
    final showPairNewDevicePage = ref.watch(_showPairBluetoothDeviceProvider);
    final showAllSavedDevicesPage =
        ref.watch(_showAllSavedBluetoothDevicesProvider);
    final showTipsPage = ref.watch(_showBluetoothTipsProvider);
    final title = showPairNewDevicePage
        ? 'Pair New Device'
        : showAllSavedDevicesPage
            ? 'Paired Devices'
            : showTipsPage
                ? 'Tips & Tutorial'
                : 'Bluetooth';

    return Column(
      children: [
        CommonTitle(
          title: title,
          hasBackButton: true,
          onPressed: () async {
            if (showPairNewDevicePage) {
              ref.read(_showPairBluetoothDeviceProvider.notifier).state = false;
              if (state?.isScanning ?? false) {
                await ref.read(bluetoothPowerProvider.notifier).stopScan();
              }
              return;
            }
            if (showAllSavedDevicesPage) {
              ref.read(_showAllSavedBluetoothDevicesProvider.notifier).state =
                  false;
              return;
            }
            if (showTipsPage) {
              ref.read(_showBluetoothTipsProvider.notifier).state = false;
              return;
            }
            ref.read(appProvider.notifier).back();
          },
        ),
        Expanded(
          child: showPairNewDevicePage
              ? _PairBluetoothDeviceView(
                  bluetoothState: bluetoothState,
                  devices: pairableDevices,
                )
              : showAllSavedDevicesPage
                  ? _AllSavedBluetoothDevicesView(devices: savedDevices)
                  : showTipsPage
                      ? const _BluetoothTipsView()
                      : _BluetoothSettingsOverview(
                          bluetoothState: bluetoothState,
                          connectedDevices: connectedDevices,
                          savedDevices: savedDevices,
                        ),
        ),
        if (errorMessage != null && errorMessage.trim().isNotEmpty)
          _BluetoothErrorBanner(message: errorMessage),
        const SizedBox(
          height: 100,
        )
      ],
    );
  }
}

class _BluetoothSettingsOverview extends ConsumerWidget {
  final AsyncValue<BluetoothPowerState> bluetoothState;
  final List<BluetoothDeviceInfo> connectedDevices;
  final List<BluetoothDeviceInfo> savedDevices;

  const _BluetoothSettingsOverview({
    required this.bluetoothState,
    required this.connectedDevices,
    required this.savedDevices,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<BluetoothPowerState>>(bluetoothPowerProvider,
        (previous, next) {
      final previousConnectedIds = previous?.valueOrNull?.devices
              .where((device) => device.connected)
              .map((device) => device.id)
              .toSet() ??
          const <String>{};
      final connectedDevices = next.valueOrNull?.devices
              .where((device) => device.connected)
              .toList() ??
          const <BluetoothDeviceInfo>[];
      final hasNewConnection = connectedDevices
          .any((device) => !previousConnectedIds.contains(device.id));

      if (!hasNewConnection) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_showPairBluetoothDeviceProvider.notifier).state = false;
        final state = ref.read(bluetoothPowerProvider).valueOrNull;
        if (state?.isScanning ?? false) {
          ref.read(bluetoothPowerProvider.notifier).stopScan();
        }
      });
    });

    final state = bluetoothState.valueOrNull;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 144),
      children: [
        bluetoothState.when(
          loading: () => const _BluetoothEmptyState(
            text: 'Checking adapter status...',
            topRounded: true,
            bottomRounded: true,
          ),
          error: (error, _) => const SizedBox(),
          data: (state) => const SizedBox(),
        ),
        if (connectedDevices.isNotEmpty) ...[
          _ConnectedBluetoothDevicesSection(devices: connectedDevices),
          const SizedBox(height: 32),
        ],
        _PairNewDeviceTile(
          enabled: state?.isPowered == true,
          onTap: state?.isPowered == true
              ? () {
                  ref.read(_showPairBluetoothDeviceProvider.notifier).state =
                      true;
                  ref.read(bluetoothPowerProvider.notifier).startScan();
                }
              : null,
        ),
        const SizedBox(height: 32),
        _SavedBluetoothDevicesTile(
          devices: savedDevices,
          totalCount: savedDevices.length,
        ),
        const SizedBox(height: 32),
        _BluetoothTipsTile(
          onTap: () {
            ref.read(_showBluetoothTipsProvider.notifier).state = true;
          },
        ),
      ],
    );
  }
}

class _AllSavedBluetoothDevicesView extends StatelessWidget {
  final List<BluetoothDeviceInfo> devices;

  const _AllSavedBluetoothDevicesView({
    required this.devices,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 144),
      children: [
        _SavedBluetoothDevicesTile(
          devices: devices,
          totalCount: devices.length,
          forceExpanded: true,
        ),
      ],
    );
  }
}

class _ConnectedBluetoothDevicesSection extends ConsumerWidget {
  final List<BluetoothDeviceInfo> devices;

  const _ConnectedBluetoothDevicesSection({
    required this.devices,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedDeviceId = ref.watch(_expandedBluetoothDeviceIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BluetoothSectionTitle(title: 'Connected Device'),
        const SizedBox(height: 12),
        for (var index = 0; index < devices.length; index++) ...[
          Builder(builder: (context) {
            final isDeviceExpanded = expandedDeviceId == devices[index].id;
            return Column(
              children: [
                _SavedBluetoothDeviceRow(
                  device: devices[index],
                  topRounded: index == 0,
                  bottomRounded:
                      index == devices.length - 1 && !isDeviceExpanded,
                ),
                if (isDeviceExpanded)
                  _ExpandedPairedDeviceSettings(
                    device: devices[index],
                    bottomRounded: index == devices.length - 1,
                  ),
              ],
            );
          }),
          if (index != devices.length - 1) const SizedBox(height: 2),
        ],
      ],
    );
  }
}

class _PairBluetoothDeviceView extends ConsumerWidget {
  final AsyncValue<BluetoothPowerState> bluetoothState;
  final List<BluetoothDeviceInfo> devices;

  const _PairBluetoothDeviceView({
    required this.bluetoothState,
    required this.devices,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = bluetoothState.valueOrNull;
    final namedDevices =
        devices.where((device) => _hasUsableBluetoothName(device)).toList();
    final unknownDevices =
        devices.where((device) => !_hasUsableBluetoothName(device)).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 144),
            children: [
              bluetoothState.when(
                loading: () => const _BluetoothEmptyState(
                  text: 'Checking adapter status...',
                  topRounded: true,
                  bottomRounded: true,
                ),
                error: (error, _) => const SizedBox(),
                data: (state) => const SizedBox(),
              ),
              if (state != null) ...[
                const _BluetoothSectionTitle(title: 'Device Name'),
                const SizedBox(height: 12),
                _CurrentBluetoothDeviceTile(
                  name: state.adapterName?.trim().isNotEmpty == true
                      ? state.adapterName!
                      : 'This device',
                ),
                const SizedBox(height: 32),
                _BluetoothSectionHeaderAction(
                  title: 'Available Devices',
                  action: _BluetoothRefreshAction(
                    isScanning: state.isScanning,
                    onTap: state.isPowered && !state.isChanging
                        ? () {
                            ref
                                .read(bluetoothPowerProvider.notifier)
                                .toggleScan();
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (state != null && devices.isEmpty)
                _BluetoothEmptyState(
                  text: state.isScanning
                      ? 'Searching for nearby devices...'
                      : 'No new devices found.',
                  topRounded: true,
                  bottomRounded: true,
                ),
              for (var index = 0; index < namedDevices.length; index++) ...[
                _BluetoothDeviceTile(
                  device: namedDevices[index],
                  topRounded: true,
                  bottomRounded: true,
                ),
                const SizedBox(height: 8),
              ],
              if (state != null && unknownDevices.isNotEmpty) ...[
                const SizedBox(height: 24),
                _UnknownBluetoothDevicesTile(devices: unknownDevices),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PairNewDeviceTile extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _PairNewDeviceTile({
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: _BluetoothPressEffect(
        onTap: onTap,
        child: Container(
          height: _bluetoothPrimaryTileHeight,
          alignment: Alignment.center,
          decoration: _bluetoothGroupDecoration(
            topRounded: true,
            bottomRounded: true,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 17, horizontal: 24),
            child: Row(
              children: [
                Icon(
                  Icons.add,
                  color: AGLDemoColors.periwinkleColor,
                  size: 48,
                ),
                SizedBox(width: 24),
                Expanded(
                  child: Text(
                    'Pair New Device',
                    style: TextStyle(fontSize: 36),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AGLDemoColors.periwinkleColor,
                  size: 48,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentBluetoothDeviceTile extends ConsumerWidget {
  final String name;

  const _CurrentBluetoothDeviceTile({
    required this.name,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: _bluetoothPrimaryTileHeight,
      alignment: Alignment.center,
      decoration: _bluetoothGroupDecoration(
        topRounded: true,
        bottomRounded: true,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
        child: Row(
          children: [
            const Icon(
              Icons.bluetooth,
              color: AGLDemoColors.periwinkleColor,
              size: 48,
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 36),
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                _showAdapterNameDialog(context, ref, name);
              },
              icon: const Icon(
                Icons.edit,
                color: AGLDemoColors.periwinkleColor,
                size: 44,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BluetoothSectionTitle extends StatelessWidget {
  final String title;

  const _BluetoothSectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title,
        style: const TextStyle(
          color: AGLDemoColors.periwinkleColor,
          fontSize: 28,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _BluetoothSectionHeaderAction extends StatelessWidget {
  final String title;
  final Widget action;

  const _BluetoothSectionHeaderAction({
    required this.title,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AGLDemoColors.periwinkleColor,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          action,
        ],
      ),
    );
  }
}

class _BluetoothRefreshAction extends StatelessWidget {
  final bool isScanning;
  final VoidCallback? onTap;

  const _BluetoothRefreshAction({
    required this.isScanning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: isScanning
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AGLDemoColors.periwinkleColor,
                ),
              ),
            )
          : const Icon(
              Icons.refresh,
              color: AGLDemoColors.periwinkleColor,
              size: 30,
            ),
      label: Text(
        isScanning ? 'Scanning' : 'Refresh',
        style: const TextStyle(
          color: AGLDemoColors.periwinkleColor,
          fontSize: 24,
        ),
      ),
    );
  }
}

class _SavedBluetoothDevicesTile extends ConsumerWidget {
  final List<BluetoothDeviceInfo> devices;
  final int totalCount;
  final VoidCallback? onSeeAll;
  final bool forceExpanded;

  const _SavedBluetoothDevicesTile({
    required this.devices,
    required this.totalCount,
    this.onSeeAll,
    this.forceExpanded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded =
        forceExpanded || ref.watch(_savedBluetoothDevicesExpandedProvider);
    final expandedDeviceId = ref.watch(_expandedBluetoothDeviceIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BluetoothSectionTitle(title: 'Paired devices'),
        const SizedBox(height: 12),
        _BluetoothSeeAllRow(
          totalCount: totalCount,
          isExpanded: isExpanded,
          topRounded: true,
          bottomRounded: !isExpanded,
          onTap: forceExpanded
              ? null
              : () {
                  ref
                      .read(_savedBluetoothDevicesExpandedProvider.notifier)
                      .state = !isExpanded;
                },
        ),
        if (isExpanded) ...[
          const SizedBox(height: 2),
          if (devices.isEmpty)
            const _BluetoothEmptyState(
              text: 'No paired devices yet.',
              topRounded: false,
              bottomRounded: true,
            )
          else ...[
            for (var index = 0; index < devices.length; index++) ...[
              Builder(builder: (context) {
                final isDeviceExpanded = expandedDeviceId == devices[index].id;
                return Column(
                  children: [
                    _SavedBluetoothDeviceRow(
                      device: devices[index],
                      topRounded: false,
                      bottomRounded:
                          index == devices.length - 1 && !isDeviceExpanded,
                    ),
                    if (isDeviceExpanded)
                      _ExpandedPairedDeviceSettings(
                        device: devices[index],
                        bottomRounded: index == devices.length - 1,
                      ),
                  ],
                );
              }),
              if (index != devices.length - 1) const SizedBox(height: 2),
            ],
          ],
        ],
      ],
    );
  }
}

class _SavedBluetoothDeviceRow extends ConsumerStatefulWidget {
  final BluetoothDeviceInfo device;
  final bool topRounded;
  final bool bottomRounded;

  const _SavedBluetoothDeviceRow({
    required this.device,
    this.topRounded = false,
    this.bottomRounded = false,
  });

  @override
  ConsumerState<_SavedBluetoothDeviceRow> createState() =>
      _SavedBluetoothDeviceRowState();
}

class _SavedBluetoothDeviceRowState
    extends ConsumerState<_SavedBluetoothDeviceRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothPowerProvider).valueOrNull;
    final device = widget.device;
    final name = device.name.isEmpty ? 'Unknown device' : device.name;
    final isBusy = bluetoothState?.busyDeviceId == device.id;
    final canConnect = bluetoothState?.isPowered == true &&
        bluetoothState?.busyDeviceId == null &&
        !device.connected;
    final isExpanded = ref.watch(_expandedBluetoothDeviceIdProvider) == device.id;
    final isDisconnecting = isBusy && ref.watch(_disconnectingDeviceIdProvider) == device.id;

    void handleTap() {
      if (isExpanded) {
        ref.read(_expandedBluetoothDeviceIdProvider.notifier).state = null;
      } else if (canConnect) {
        ref.read(_disconnectingDeviceIdProvider.notifier).state = null;
        ref.read(bluetoothPowerProvider.notifier).connectDevice(device.id);
      }
    }

    return GestureDetector(
      onTap: handleTap,
      onTapDown: (canConnect || isExpanded) ? (_) => setState(() => _isPressed = true) : null,
      onTapCancel: () => setState(() => _isPressed = false),
      onTapUp: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: _bluetoothPrimaryTileHeight,
          alignment: Alignment.center,
          decoration: _bluetoothGroupDecoration(
            topRounded: widget.topRounded,
            bottomRounded: widget.bottomRounded,
            highlighted: isBusy || device.connected,
            disconnecting: isDisconnecting,
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
                  child: Row(
                    children: [
                      Icon(
                        _getDeviceIcon(name),
                        color: device.connected ? Colors.white : AGLDemoColors.periwinkleColor,
                        size: 44,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 32,
                            color: device.connected ? Colors.white : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isBusy
                    ? Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: Row(
                          key: const ValueKey('connecting'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isDisconnecting
                                  ? 'Disconnecting...'
                                  : 'Connecting...',
                              style: TextStyle(
                                color: device.connected ? Colors.white : AGLDemoColors.periwinkleColor,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 34,
                              height: 34,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  device.connected ? Colors.white : AGLDemoColors.periwinkleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        key: const ValueKey('settings'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Vertical Divider Line "|"
                          Container(
                            width: 1.5,
                            height: 64,
                            color: device.connected 
                                ? Colors.white.withValues(alpha: 0.5)
                                : AGLDemoColors.periwinkleColor.withValues(alpha: 0.25),
                          ),
                          // Settings icon with square touch target
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final expandedNotifier = ref.read(
                                  _expandedBluetoothDeviceIdProvider.notifier);
                              expandedNotifier.state =
                                  expandedNotifier.state == device.id
                                      ? null
                                      : device.id;
                            },
                            child: Container(
                              width: 110, // Generous width touch zone
                              height: _bluetoothPrimaryTileHeight, // 130
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.settings,
                                color: device.connected
                                    ? Colors.white
                                    : isExpanded
                                        ? AGLDemoColors.neonBlueColor
                                        : AGLDemoColors.periwinkleColor,
                                size: 44,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnknownBluetoothDevicesTile extends ConsumerWidget {
  final List<BluetoothDeviceInfo> devices;

  const _UnknownBluetoothDevicesTile({
    required this.devices,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(_unknownBluetoothDevicesExpandedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BluetoothSectionTitle(title: 'Unknown devices'),
        const SizedBox(height: 12),
        _BluetoothSeeAllRow(
          totalCount: devices.length,
          isExpanded: isExpanded,
          topRounded: true,
          bottomRounded: !isExpanded,
          onTap: () {
            ref.read(_unknownBluetoothDevicesExpandedProvider.notifier).state =
                !isExpanded;
          },
        ),
        if (isExpanded) ...[
          const SizedBox(height: 2),
          for (var index = 0; index < devices.length; index++) ...[
            _UnknownBluetoothDeviceRow(
              device: devices[index],
              topRounded: false,
              bottomRounded: index == devices.length - 1,
            ),
            if (index != devices.length - 1) const SizedBox(height: 2),
          ],
        ],
      ],
    );
  }
}

class _UnknownBluetoothDeviceRow extends ConsumerStatefulWidget {
  final BluetoothDeviceInfo device;
  final bool topRounded;
  final bool bottomRounded;

  const _UnknownBluetoothDeviceRow({
    required this.device,
    required this.topRounded,
    required this.bottomRounded,
  });

  @override
  ConsumerState<_UnknownBluetoothDeviceRow> createState() =>
      _UnknownBluetoothDeviceRowState();
}

class _UnknownBluetoothDeviceRowState
    extends ConsumerState<_UnknownBluetoothDeviceRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothPowerProvider).valueOrNull;
    final isBusy = bluetoothState?.busyDeviceId == widget.device.id;
    final canConnect = bluetoothState?.isPowered == true &&
        bluetoothState?.busyDeviceId == null &&
        !widget.device.connected;

    Future<void> connect() async {
      if (!canConnect) {
        return;
      }
      await ref
          .read(bluetoothPowerProvider.notifier)
          .connectDevice(widget.device.id);
    }

    return GestureDetector(
      onTap: connect,
      onTapDown: canConnect ? (_) => setState(() => _isPressed = true) : null,
      onTapCancel: () => setState(() => _isPressed = false),
      onTapUp: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: _bluetoothPrimaryTileHeight,
          alignment: Alignment.center,
          decoration: _bluetoothGroupDecoration(
            topRounded: widget.topRounded,
            bottomRounded: widget.bottomRounded,
            highlighted: isBusy,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.devices,
                  color: AGLDemoColors.periwinkleColor,
                  size: 44,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    widget.device.address.isEmpty
                        ? 'Unknown address'
                        : widget.device.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(width: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: isBusy
                      ? const Row(
                          key: ValueKey('connecting'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Connecting...',
                              style: TextStyle(
                                color: AGLDemoColors.periwinkleColor,
                                fontSize: 22,
                              ),
                            ),
                            SizedBox(width: 14),
                            SizedBox(
                              width: 34,
                              height: 34,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AGLDemoColors.periwinkleColor,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(
                          key: ValueKey('idle'),
                          width: 44,
                          height: 44,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BluetoothSeeAllRow extends StatelessWidget {
  final int totalCount;
  final bool isExpanded;
  final bool topRounded;
  final bool bottomRounded;
  final VoidCallback? onTap;

  const _BluetoothSeeAllRow({
    required this.totalCount,
    required this.isExpanded,
    required this.topRounded,
    required this.bottomRounded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BluetoothPressEffect(
      onTap: onTap,
      child: Container(
        height: _bluetoothPrimaryTileHeight,
        alignment: Alignment.center,
        decoration: _bluetoothGroupDecoration(
          topRounded: topRounded,
          bottomRounded: bottomRounded,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          child: Row(
            children: [
              Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.chevron_right,
                color: AGLDemoColors.periwinkleColor,
                size: 44,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  'See All',
                  style: const TextStyle(
                    color: AGLDemoColors.periwinkleColor,
                    fontSize: 28,
                  ),
                ),
              ),
              Text(
                '$totalCount',
                style: const TextStyle(
                  color: AGLDemoColors.periwinkleColor,
                  fontSize: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BluetoothGroupHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool topRounded;
  final bool bottomRounded;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _BluetoothGroupHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.topRounded,
    required this.bottomRounded,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BluetoothPressEffect(
      onTap: onTap,
      child: Container(
        height: _bluetoothPrimaryTileHeight,
        alignment: Alignment.center,
        decoration: _bluetoothGroupDecoration(
          topRounded: topRounded,
          bottomRounded: bottomRounded,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          child: Row(
            children: [
              Icon(
                icon,
                color: AGLDemoColors.periwinkleColor,
                size: 48,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 36),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AGLDemoColors.periwinkleColor,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 24),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _bluetoothGroupDecoration({
  required bool topRounded,
  required bool bottomRounded,
  bool highlighted = false,
  bool disconnecting = false,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.vertical(
      top: topRounded ? const Radius.circular(24) : Radius.zero,
      bottom: bottomRounded ? const Radius.circular(24) : Radius.zero,
    ),
    gradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      stops: disconnecting
          ? const [0.1, 1]
          : highlighted
              ? const [0, 0.01, 0.8]
              : const [0.1, 1],
      colors: disconnecting
          ? <Color>[
              Colors.redAccent.withValues(alpha: 0.65),
              Colors.redAccent.withValues(alpha: 0.16),
            ]
          : highlighted
              ? <Color>[
                  Colors.white,
                  Colors.blue,
                  const Color.fromARGB(16, 41, 98, 255),
                ]
              : const <Color>[Colors.black, Colors.black12],
    ),
  );
}

class _BluetoothPressEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _BluetoothPressEffect({
    required this.child,
    required this.onTap,
  });

  @override
  State<_BluetoothPressEffect> createState() => _BluetoothPressEffectState();
}

class _BluetoothPressEffectState extends State<_BluetoothPressEffect> {
  bool _isPressed = false;
  bool _isBlooming = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _isPressed == value) {
      return;
    }
    setState(() => _isPressed = value);
  }

  void _triggerBloom() {
    if (widget.onTap == null) {
      return;
    }
    setState(() => _isBlooming = true);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) {
        setState(() => _isBlooming = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTapUp: enabled
          ? (_) {
              _setPressed(false);
              _triggerBloom();
            }
          : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: _isPressed || _isBlooming
                  ? <Color>[
                      AGLDemoColors.neonBlueColor.withValues(alpha: 0.22),
                      AGLDemoColors.periwinkleColor.withValues(alpha: 0.08),
                    ]
                  : const <Color>[
                      Colors.transparent,
                      Colors.transparent,
                    ],
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: _isPressed || _isBlooming
                  ? [
                      BoxShadow(
                        color:
                            AGLDemoColors.neonBlueColor.withValues(alpha: 0.32),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _BluetoothTipsTile extends StatelessWidget {
  final VoidCallback onTap;

  const _BluetoothTipsTile({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BluetoothPressEffect(
      onTap: onTap,
      child: Container(
        height: _bluetoothPrimaryTileHeight,
        alignment: Alignment.center,
        decoration: _bluetoothGroupDecoration(
          topRounded: true,
          bottomRounded: true,
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AGLDemoColors.periwinkleColor,
                size: 48,
              ),
              SizedBox(width: 24),
              Expanded(
                child: Text(
                  'Tips & Tutorial',
                  style: TextStyle(fontSize: 36),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AGLDemoColors.periwinkleColor,
                size: 48,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedPairedDeviceSettings extends ConsumerWidget {
  final BluetoothDeviceInfo device;
  final bool bottomRounded;

  const _ExpandedPairedDeviceSettings({
    required this.device,
    required this.bottomRounded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bluetoothState = ref.watch(bluetoothPowerProvider).valueOrNull;
    final currentDevice = bluetoothState?.devices
            .where((item) => item.id == device.id)
            .firstOrNull ??
        device;
    final notifier = ref.read(bluetoothPowerProvider.notifier);
    final isBusy = bluetoothState?.busyDeviceId == currentDevice.id;
    final canChange = bluetoothState?.isPowered == true &&
        bluetoothState?.busyDeviceId == null;
    final isDisconnecting = isBusy && ref.watch(_disconnectingDeviceIdProvider) == currentDevice.id;

    return Container(
      decoration: _bluetoothGroupDecoration(
        topRounded: false,
        bottomRounded: bottomRounded,
        highlighted: isBusy || currentDevice.connected,
        disconnecting: isDisconnecting,
      ).copyWith(
        border: Border(
          top: BorderSide(
            color: AGLDemoColors.periwinkleColor.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _InlineDeviceActionButton(
                    icon: Icons.edit,
                    label: 'Rename',
                    enabled: canChange,
                    onTap: () {
                      _showDeviceRenameDialog(context, ref, currentDevice);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InlineDeviceActionButton(
                    icon: currentDevice.connected
                        ? Icons.bluetooth_disabled
                        : Icons.bluetooth_connected,
                    label: currentDevice.connected ? 'Disconnect' : 'Connect',
                    enabled: canChange,
                    onTap: () {
                      if (currentDevice.connected) {
                        ref.read(_disconnectingDeviceIdProvider.notifier).state = currentDevice.id;
                        notifier.disconnectDevice(currentDevice.id);
                        ref.read(_expandedBluetoothDeviceIdProvider.notifier).state = null;
                      } else {
                        ref.read(_disconnectingDeviceIdProvider.notifier).state = null;
                        notifier.connectDevice(currentDevice.id);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InlineDeviceActionButton(
                    icon: Icons.link_off,
                    label: 'Unpair Device',
                    enabled: canChange,
                    destructive: true,
                    onTap: () async {
                      await notifier.forgetDevice(currentDevice.id);
                      ref
                          .read(_expandedBluetoothDeviceIdProvider.notifier)
                          .state = null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineDeviceActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool destructive;
  final VoidCallback onTap;

  const _InlineDeviceActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? Colors.redAccent : AGLDemoColors.periwinkleColor;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: _BluetoothPressEffect(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            border:
                Border.all(color: color.withValues(alpha: 0.75), width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BluetoothTipsView extends StatelessWidget {
  const _BluetoothTipsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 144),
      children: const [
        _BluetoothTipsInfoCard(
          icon: Icons.add,
          title: 'Pair New Device',
          description:
              'Scan nearby Bluetooth devices and connect a new accessory.',
          topRounded: true,
          bottomRounded: false,
        ),
        SizedBox(height: 2),
        _BluetoothTipsInfoCard(
          icon: Icons.bluetooth_connected,
          title: 'Paired devices',
          description:
              'Tap a paired device to reconnect. Use the settings icon for device details.',
          topRounded: false,
          bottomRounded: false,
        ),
        SizedBox(height: 2),
        _BluetoothTipsInfoCard(
          icon: Icons.devices,
          title: 'Unknown devices',
          description:
              'Devices without a public name are grouped by address to reduce noise.',
          topRounded: false,
          bottomRounded: true,
        ),
      ],
    );
  }
}

class _BluetoothTipsInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool topRounded;
  final bool bottomRounded;

  const _BluetoothTipsInfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.topRounded,
    required this.bottomRounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      alignment: Alignment.center,
      decoration: _bluetoothGroupDecoration(
        topRounded: topRounded,
        bottomRounded: bottomRounded,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        child: Row(
          children: [
            Icon(
              icon,
              color: AGLDemoColors.periwinkleColor,
              size: 44,
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AGLDemoColors.periwinkleColor,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BluetoothScanButton extends StatelessWidget {
  final bool isPowered;
  final bool isScanning;
  final bool isBusy;
  final VoidCallback? onTap;

  const _BluetoothScanButton({
    required this.isPowered,
    required this.isScanning,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final Widget label = isScanning
        ? const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFFC1D8FF),
                  ),
                ),
              ),
              SizedBox(width: 24),
              Text(
                'Stop Scanning',
                style: TextStyle(
                  color: Color(0xFFC1D8FF),
                  fontSize: 44,
                ),
              ),
            ],
          )
        : const Text(
            'Scan for New Device',
            style: TextStyle(
              color: Color(0xFFC1D8FF),
              fontSize: 44,
            ),
          );
    final Widget button = GestureDetector(
      onTap: onTap,
      child: Container(
        height: _bluetoothPrimaryTileHeight,
        width: 501,
        decoration: BoxDecoration(
          gradient: Gradient.lerp(
            const LinearGradient(colors: <Color>[
              Color(0xFF2962FF),
              Color(0x802962FF),
            ]),
            const LinearGradient(colors: <Color>[
              Color(0xFF1A237E),
              Color(0xFF141F64),
            ]),
            0.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              blurRadius: 2,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: const Color(0xFF285DF4),
            width: 1,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        child: Center(child: label),
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 150.0),
          child: button,
        ),
      ),
    );
  }
}

class _BluetoothErrorBanner extends ConsumerWidget {
  final String message;

  const _BluetoothErrorBanner({
    required this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 144),
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.7),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [Helpers.boxDropShadowRegular],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 36,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AGLDemoColors.periwinkleColor,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  ref.read(bluetoothPowerProvider.notifier).clearError();
                },
                icon: const Icon(
                  Icons.close,
                  color: AGLDemoColors.periwinkleColor,
                  size: 34,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BluetoothEmptyState extends StatelessWidget {
  final String text;
  final bool topRounded;
  final bool bottomRounded;

  const _BluetoothEmptyState({
    required this.text,
    this.topRounded = false,
    this.bottomRounded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _bluetoothPrimaryTileHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: topRounded ? const Radius.circular(24) : Radius.zero,
          bottom: bottomRounded ? const Radius.circular(24) : Radius.zero,
        ),
        gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              Color.fromARGB(50, 0, 0, 0),
              Colors.transparent,
            ]),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AGLDemoColors.periwinkleColor,
          fontSize: 30,
        ),
      ),
    );
  }
}

class _BluetoothDeviceTile extends ConsumerWidget {
  final BluetoothDeviceInfo device;
  final bool savedOnly;
  final bool topRounded;
  final bool bottomRounded;

  const _BluetoothDeviceTile({
    required this.device,
    this.savedOnly = false,
    this.topRounded = false,
    this.bottomRounded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bluetoothState = ref.watch(bluetoothPowerProvider).valueOrNull;
    final isBusy = bluetoothState?.busyDeviceId == device.id;
    final canChangeConnection = bluetoothState?.isPowered == true &&
        bluetoothState?.busyDeviceId == null;
    final deviceName = device.name.isEmpty ? 'Unknown device' : device.name;
    final isHighlighted = device.connected;
    final canPopout = device.connected || savedOnly;

    return GestureDetector(
      onTap: canPopout
          ? () {
              ref.read(_expandedBluetoothDeviceIdProvider.notifier).state =
                  device.id;
            }
          : ((canChangeConnection && !device.connected)
              ? () {
                  ref
                      .read(bluetoothPowerProvider.notifier)
                      .connectDevice(device.id);
                }
              : null),
      child: Container(
        height: _bluetoothPrimaryTileHeight,
        alignment: Alignment.center,
        decoration: isHighlighted
            ? BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: topRounded ? const Radius.circular(24) : Radius.zero,
                  bottom:
                      bottomRounded ? const Radius.circular(24) : Radius.zero,
                ),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: const [0, 0.01, 0.8],
                  colors: <Color>[
                    Colors.white,
                    AGLDemoColors.neonBlueColor,
                    AGLDemoColors.neonBlueColor.withValues(alpha: 0.15)
                  ],
                ),
              )
            : _bluetoothGroupDecoration(
                topRounded: topRounded,
                bottomRounded: bottomRounded,
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          child: Row(
            children: [
              const Icon(
                Icons.devices,
                color: AGLDemoColors.periwinkleColor,
                size: 48,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 36),
                ),
              ),
              const SizedBox(width: 24),
              if (device.connected)
                isBusy
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AGLDemoColors.periwinkleColor),
                        ),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          ref
                              .read(_expandedBluetoothDeviceIdProvider.notifier)
                              .state = device.id;
                        },
                        icon: const Icon(
                          Icons.settings,
                          color: AGLDemoColors.periwinkleColor,
                          size: 44,
                        ),
                      )
              else if (isBusy)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Connecting...',
                      style: TextStyle(
                        color: AGLDemoColors.periwinkleColor,
                        fontSize: 26,
                      ),
                    ),
                    SizedBox(width: 15),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AGLDemoColors.periwinkleColor),
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(width: 190),
            ],
          ),
        ),
      ),
    );
  }
}

bool _hasUsableBluetoothName(BluetoothDeviceInfo device) {
  final name = device.name.trim();
  if (name.isEmpty) {
    return false;
  }

  final address = device.address.trim();
  if (address.isNotEmpty && name.toLowerCase() == address.toLowerCase()) {
    return false;
  }

  return !RegExp(r'^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$').hasMatch(name);
}

IconData _getDeviceIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('keyboard') || lower.contains('keychron')) {
    return Icons.keyboard;
  } else if (lower.contains('mouse') || lower.contains('trackpad')) {
    return Icons.mouse;
  } else if (lower.contains('phone') ||
      lower.contains('poco') ||
      lower.contains('pixel')) {
    return Icons.phone_android;
  } else if (lower.contains('tab') || lower.contains('ipad')) {
    return Icons.tablet_mac;
  } else if (lower.contains('headphone') ||
      lower.contains('headset') ||
      lower.contains('audio') ||
      lower.contains('speaker') ||
      lower.contains('buds')) {
    return Icons.headphones;
  } else {
    return Icons.devices;
  }
}

Future<void> _showAdapterNameDialog(
  BuildContext context,
  WidgetRef ref,
  String currentName,
) async {
  final controller = TextEditingController(text: currentName);

  await showDialog<void>(
    context: context,
    builder: (context) {
      var isSaving = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 600,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 32),
              decoration: BoxDecoration(
                color: AGLDemoColors.backgroundInsetColor,
                border: Border.all(
                  color: AGLDemoColors.neonBlueColor,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [Helpers.boxDropShadowRegular],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Device Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Visible to nearby devices',
                    style: TextStyle(
                      color: AGLDemoColors.periwinkleColor,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !isSaving,
                    maxLength: 248,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                    ),
                    decoration: InputDecoration(
                      counterStyle: const TextStyle(
                        color: AGLDemoColors.periwinkleColor,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AGLDemoColors.periwinkleColor,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AGLDemoColors.neonBlueColor,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) async {
                      await _saveAdapterName(
                        context,
                        ref,
                        controller.text,
                        setDialogState,
                        (value) => isSaving = value,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            isSaving ? null : () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AGLDemoColors.periwinkleColor,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        height: 58,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  await _saveAdapterName(
                                    context,
                                    ref,
                                    controller.text,
                                    setDialogState,
                                    (value) => isSaving = value,
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AGLDemoColors.neonBlueColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(fontSize: 24),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  controller.dispose();
}

Future<void> _saveAdapterName(
  BuildContext context,
  WidgetRef ref,
  String name,
  StateSetter setDialogState,
  ValueChanged<bool> setSaving,
) async {
  final trimmedName = name.trim();
  if (trimmedName.isEmpty) {
    return;
  }

  setDialogState(() => setSaving(true));
  await ref.read(bluetoothPowerProvider.notifier).renameAdapter(trimmedName);
  if (context.mounted) {
    Navigator.of(context).pop();
  }
}

Future<void> _showDeviceRenameDialog(
  BuildContext context,
  WidgetRef ref,
  BluetoothDeviceInfo device,
) async {
  final controller = TextEditingController(text: device.name);

  await showDialog<void>(
    context: context,
    builder: (context) {
      var isSaving = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 600,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 32),
              decoration: BoxDecoration(
                color: AGLDemoColors.backgroundInsetColor,
                border: Border.all(
                  color: AGLDemoColors.neonBlueColor,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [Helpers.boxDropShadowRegular],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Rename Device',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Change the display name of this device',
                    style: TextStyle(
                      color: AGLDemoColors.periwinkleColor,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !isSaving,
                    maxLength: 248,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                    ),
                    decoration: InputDecoration(
                      counterStyle: const TextStyle(
                        color: AGLDemoColors.periwinkleColor,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AGLDemoColors.periwinkleColor,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AGLDemoColors.neonBlueColor,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) async {
                      await _saveDeviceName(
                        context,
                        ref,
                        device.id,
                        controller.text,
                        setDialogState,
                        (value) => isSaving = value,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            isSaving ? null : () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AGLDemoColors.periwinkleColor,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        height: 58,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  await _saveDeviceName(
                                    context,
                                    ref,
                                    device.id,
                                    controller.text,
                                    setDialogState,
                                    (value) => isSaving = value,
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AGLDemoColors.neonBlueColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(fontSize: 24),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  controller.dispose();
}

Future<void> _saveDeviceName(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  String name,
  StateSetter setDialogState,
  ValueChanged<bool> setSaving,
) async {
  final trimmedName = name.trim();
  if (trimmedName.isEmpty) {
    return;
  }

  setDialogState(() => setSaving(true));
  await ref
      .read(bluetoothPowerProvider.notifier)
      .renameDevice(deviceId, trimmedName);
  if (context.mounted) {
    Navigator.of(context).pop();
  }
}
