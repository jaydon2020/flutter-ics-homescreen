import 'package:flutter_ics_homescreen/export.dart';

import 'bluetooth_dialog.dart';

/// Original in-memory Bluetooth demo used when the native backend is disabled.
class BluetoothDemoContent extends ConsumerStatefulWidget {
  const BluetoothDemoContent({super.key});

  @override
  ConsumerState<BluetoothDemoContent> createState() =>
      _BluetoothDemoContentState();
}

class _BluetoothDemoContentState extends ConsumerState<BluetoothDemoContent> {
  final _devices = [
    'bt',
    'BT Phone 0',
    'BT Phone 1',
    'BT Phone 2',
    'BT Phone 1'
  ];

  int? _connectedIndex = 0;
  bool _connecting = false;

  Future<void> _connect(int index) async {
    if (_connecting || _connectedIndex == index) return;
    setState(() {
      _connectedIndex = index;
      _connecting = true;
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _connecting = false);
  }

  Future<void> _disconnect(int index) async {
    final confirmed = await showBluetoothConfirmationDialog(
      context,
      title: 'Disconnect Device?',
      message: 'Disconnect ${_devices[index]}?',
      confirmLabel: 'Disconnect',
    );
    if (confirmed && mounted) setState(() => _connectedIndex = null);
  }

  void _remove(int index) {
    setState(() {
      _devices.removeAt(index);
      if (_connectedIndex == index) {
        _connectedIndex = null;
      } else if (_connectedIndex != null && _connectedIndex! > index) {
        _connectedIndex = _connectedIndex! - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CommonTitle(
          title: 'Bluetooth',
          hasBackButton: true,
          onPressed: () => ref.read(appProvider.notifier).back(),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 144),
            itemCount: _devices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final selected = _connectedIndex == index;
              return Container(
                height: 130,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: selected ? const [0, 0.01, 0.8] : const [0.1, 1],
                    colors: selected
                        ? const [
                            Colors.white,
                            Colors.blue,
                            Color.fromARGB(16, 41, 98, 255),
                          ]
                        : const [Colors.black, Colors.black12],
                  ),
                ),
                child: InkWell(
                  onTap: () => _connect(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 17,
                      horizontal: 24,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _devices[index],
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AGLDemoColors.periwinkleColor,
                              fontSize: 40,
                            ),
                          ),
                        ),
                        if (selected && _connecting) ...[
                          const Padding(
                            padding: EdgeInsets.only(right: 15),
                            child: Text(
                              'Connecting...',
                              style: TextStyle(fontSize: 26),
                            ),
                          ),
                          const SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        ] else ...[
                          if (selected)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1C2D92),
                                  side: const BorderSide(
                                    color: Color(0xFF285DF4),
                                    width: 2,
                                  ),
                                ),
                                onPressed: () => _disconnect(index),
                                child: const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: Text(
                                    'Disconnect',
                                    style: TextStyle(
                                      color: Color(0xFFC1D8FF),
                                      fontSize: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _remove(index),
                            icon: const Icon(
                              Icons.close,
                              color: AGLDemoColors.periwinkleColor,
                              size: 48,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 150),
          child: GenericButton(
            height: 130,
            width: 501,
            text: 'Scan for New Device',
            onTap: () {},
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}
