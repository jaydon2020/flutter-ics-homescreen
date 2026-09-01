import '/export.dart';

class HvacPage extends StatelessWidget {
  const HvacPage({super.key});

  static Page<void> page() => const MaterialPage<void>(child: HvacPage());
  @override
  Widget build(BuildContext context) {
    // print(MediaQuery.of(context).size);
    // print(MediaQuery.of(context).size.width *
    //     MediaQuery.of(context).devicePixelRatio);
    // print(MediaQuery.of(context).size.height *
    //     MediaQuery.of(context).devicePixelRatio);
    return Stack(
      children: [
        // SizedBox(
        //   width: double.infinity,
        //   height: double.infinity,
        //   //color: Colors.black,
        //   // decoration:
        //   //   BoxDecoration(gradient: AGLDemoColors.gradientBackgroundColor),
        //   child: SvgPicture.asset(
        //     'assets/HVACBackground.svg',
        //     alignment: Alignment.center,
        //     fit: BoxFit.cover,
        //     //width: 200,
        //     //height: 200,
        //   ),
        // ),
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          // color: Colors.black,
          child: SvgPicture.asset(
            'assets/backgroundTextures.svg',
            // 1080x1921 art: cover so it fills a view of another aspect instead
            // of letterboxing (see home.dart's background providers).
            fit: BoxFit.cover,
            alignment: Alignment.center,
            //width: 200,
            //height: 200,
          ),
        ),
        const SingleChildScrollView(child: HVAC()),
      ],
    );
  }
}
