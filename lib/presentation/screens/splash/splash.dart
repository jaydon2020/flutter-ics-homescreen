import 'package:flutter_ics_homescreen/export.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  static Page<void> page() => const MaterialPage<void>(child: SplashPage());
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    debugPrint(size.width.toString());
    debugPrint(size.height.toString());
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: SvgPicture.asset(
            'assets/splashTextures.svg',
            // Same reason as the home background: contain (the default) letterboxes
            // the 1080x1921 texture on any other aspect and leaves bare edges.
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        const Center(child: SplashContent()),
      ],
    );
  }
}
