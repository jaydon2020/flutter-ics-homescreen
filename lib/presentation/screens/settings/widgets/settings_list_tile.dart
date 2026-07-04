import 'package:flutter_ics_homescreen/export.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool? switchValue;
  final bool switchBusy;
  final ValueChanged<bool>? onSwitchChanged;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.switchValue,
    this.switchBusy = false,
    this.onSwitchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = switchValue ?? true;

    return Column(
      children: [
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: enabled ? [0.3, 1] : [0.8, 1],
                colors: enabled
                    ? <Color>[Colors.black, Colors.black12]
                    : <Color>[
                        const Color.fromARGB(50, 0, 0, 0),
                        Colors.transparent,
                      ],
              ),
            ),
            child: Card(
              color: Colors.transparent,
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 24,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: AGLDemoColors.periwinkleColor,
                      size: 48,
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                    switchValue != null
                        ? Container(
                            width: 126,
                            height: 80,
                            decoration: const ShapeDecoration(
                              color: AGLDemoColors.gradientBackgroundDarkColor,
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: Color(0xFF5477D4),
                                  width: 4,
                                ),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.fill,
                              child: Switch(
                                value: switchValue!,
                                onChanged: switchBusy ? null : onSwitchChanged,
                                inactiveTrackColor: Colors.transparent,
                                activeTrackColor: Colors.transparent,
                                thumbColor: WidgetStateProperty.all<Color>(
                                  AGLDemoColors.periwinkleColor,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
