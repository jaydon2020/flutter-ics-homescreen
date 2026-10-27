import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_ics_homescreen/core/constants/colors.dart';

class CallAvatar extends StatelessWidget {
  const CallAvatar({
    required this.photo,
    required this.size,
    this.icon = Icons.person_rounded,
    this.iconSize,
    this.iconColor = AGLDemoColors.periwinkleColor,
    this.backgroundColor = AGLDemoColors.callControlColor,
    this.borderColor,
    super.key,
  });

  final Uint8List? photo;
  final double size;
  final IconData icon;
  final double? iconSize;
  final Color iconColor;
  final Color backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Icon(
      icon,
      size: iconSize ?? size * 0.52,
      color: iconColor,
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
      ),
      child: photo == null
          ? fallback()
          : Image.memory(
              photo!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback(),
            ),
    );
  }
}
