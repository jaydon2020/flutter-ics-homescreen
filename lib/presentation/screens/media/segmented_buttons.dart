import 'package:flutter_ics_homescreen/export.dart';

class SegmentedButtons extends StatefulWidget {
  const SegmentedButtons(
      {super.key,
      required this.navItems,
      required this.selectedNav,
      this.onChanged});

  final List<String> navItems;
  final String selectedNav;
  final ValueChanged<String>? onChanged;
  @override
  State<SegmentedButtons> createState() => _SegmentedButtonsState();
}

class _SegmentedButtonsState extends State<SegmentedButtons> {
  late List<String> navItems;
  late String selectedNav;

  @override
  void initState() {
    navItems = widget.navItems;
    selectedNav = widget.selectedNav;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 40),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                  offset: const Offset(0, 4),
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.25))
            ],
            borderRadius: BorderRadius.circular(40),
            color: AGLDemoColors.buttonFillEnabledColor,
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: navItems
                .map((e) => Container(
                      decoration: BoxDecoration(
                        borderRadius: selectedNav == e
                            ? BorderRadius.circular(40)
                            : BorderRadius.zero,
                        color: selectedNav == e
                            ? AGLDemoColors.backgroundInsetColor
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(40),
                          onTap: () {
                            setState(() {
                              selectedNav = e;
                            });
                            widget.onChanged?.call(e);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 24, horizontal: 32),
                            child: Text(
                              e,
                              style: TextStyle(
                                  color: selectedNav == e
                                      ? Colors.white
                                      : AGLDemoColors.periwinkleColor,
                                  fontSize: 26,
                                  fontWeight: selectedNav == e
                                      ? FontWeight.w700
                                      : FontWeight.w500),
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
