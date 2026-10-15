import 'package:flutter_ics_homescreen/export.dart';

class FanFocus extends StatefulWidget {
  const FanFocus(
      {super.key,
      required this.isSelected,
      required this.focusType,
      required this.onPressed});
  final bool isSelected;
  final String focusType;
  final VoidCallback onPressed;
  @override
  State<FanFocus> createState() => _FanFocusState();
}

class _FanFocusState extends State<FanFocus> {
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.sizeOf(context).height * 0.10;
    double iconSize = 32;

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: widget.isSelected
                ? [
                    AGLDemoColors.periwinkleColor,
                    AGLDemoColors.periwinkleColor.withValues(alpha: 0.25)
                  ]
                : [
                    AGLDemoColors.jordyBlueColor,
                    AGLDemoColors.jordyBlueColor.withValues(alpha: 0.2)
                  ]),
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(widget.focusType == "top_half" ? 16 : 0),
            topRight: Radius.circular(widget.focusType == "top_half" ? 16 : 0),
            bottomLeft:
                Radius.circular(widget.focusType == "bottom_half" ? 16 : 0),
            bottomRight:
                Radius.circular(widget.focusType == "bottom_half" ? 16 : 0)),
      ),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(widget.focusType == "top_half" ? 16 : 0),
              topRight:
                  Radius.circular(widget.focusType == "top_half" ? 16 : 0),
              bottomLeft:
                  Radius.circular(widget.focusType == "bottom_half" ? 16 : 0),
              bottomRight:
                  Radius.circular(widget.focusType == "bottom_half" ? 16 : 0)),
          color: widget.isSelected
              ? AGLDemoColors.neonBlueColor
              : AGLDemoColors.buttonFillEnabledColor,
          image: const DecorationImage(
              image: AssetImage("assets/PlusVector.png"),
              opacity: 0.5,
              fit: BoxFit.cover),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.only(
                topLeft:
                    Radius.circular(widget.focusType == "top_half" ? 16 : 0),
                topRight:
                    Radius.circular(widget.focusType == "top_half" ? 16 : 0),
                bottomLeft:
                    Radius.circular(widget.focusType == "bottom_half" ? 16 : 0),
                bottomRight: Radius.circular(
                    widget.focusType == "bottom_half" ? 16 : 0)),
            onTap: widget.onPressed,
            child: Row(
                crossAxisAlignment: widget.focusType == "top_half"
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 38),
                        child: Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: iconSize,
                          shadows: [
                            Shadow(
                                offset: Offset(1, widget.isSelected ? 2 : 4),
                                blurRadius: widget.isSelected ? 3 : 4,
                                color: Colors.black.withValues(alpha: 0.7))
                          ],
                        ),
                      ),
                      Image.asset(
                        "assets/${widget.focusType == "top_half" ? widget.isSelected ? "head_selected" : "head" : widget.isSelected ? "legs_selected" : "legs"}.png",
                        //fit: BoxFit.contain,
                        //  alignment: Alignment.bottomRight,
                        // width: widget.focusType == "top_half" ? 108 : 250,
                        // height: 180,
                      ),
                    ],
                  ),
                  SizedBox(
                    width: widget.focusType == "top_half" ? 5 : 40,
                  )
                ]),
          ),
        ),
      ),
    );
  }
}
