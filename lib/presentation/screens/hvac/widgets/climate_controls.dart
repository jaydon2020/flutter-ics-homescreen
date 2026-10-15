import 'package:flutter_ics_homescreen/export.dart';

class ClimateControls extends StatefulWidget {
  const ClimateControls(
      {super.key,
      required this.child,
      required this.isSelected,
      required this.onPressed});
  final Widget child;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  State<ClimateControls> createState() => _ClimateControlsState();
}

class _ClimateControlsState extends State<ClimateControls> {
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);

    return Container(
      margin: const EdgeInsets.all(8),
      width: size.width * 0.23,
      height: size.height * 0.07,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
                offset: Offset(
                    widget.isSelected ? 0 : 1, widget.isSelected ? 4 : 2),
                blurRadius: widget.isSelected ? 4 : 3,
                spreadRadius: 0,
                color: Colors.black.withValues(alpha: widget.isSelected ? 0.25 : 0.7))
          ],
          gradient: LinearGradient(
              colors: widget.isSelected
                  ? [
                      AGLDemoColors.periwinkleColor,
                      AGLDemoColors.periwinkleColor.withValues(alpha: 0.25)
                    ]
                  : [
                      AGLDemoColors.neonBlueColor,
                      AGLDemoColors.neonBlueColor.withValues(alpha: 0.2)
                    ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          border: Border.all(color: Colors.white12)),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                  offset: Offset(
                      widget.isSelected ? 0 : 1, widget.isSelected ? 4 : 2),
                  blurRadius: widget.isSelected ? 4 : 3,
                  spreadRadius: 0,
                  color:
                      Colors.black.withValues(alpha: widget.isSelected ? 0.25 : 0.7))
            ],
            color: widget.isSelected
                ? AGLDemoColors.neonBlueColor
                : AGLDemoColors.buttonFillEnabledColor,
            border: Border.all(color: Colors.white12)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            child: Center(
                child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: widget.child,
            )),
          ),
        ),
      ),
    );
  }
}
