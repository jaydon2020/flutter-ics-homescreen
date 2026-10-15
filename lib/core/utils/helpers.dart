import 'package:flutter_ics_homescreen/export.dart';

class Helpers {
  static Shadow dropShadowRegular = Shadow(
      color: Colors.black.withValues(alpha: 0.70),
      offset: const Offset(1, 2),
      blurRadius: 3);
  static BoxShadow boxDropShadowRegular = BoxShadow(
      color: Colors.black.withValues(alpha: 0.70),
      offset: const Offset(1, 2),
      blurRadius: 3);

  static Shadow dropShadowBig = Shadow(
      color: Colors.black.withValues(alpha: 0.70),
      offset: const Offset(1, 4),
      blurRadius: 4);
}
