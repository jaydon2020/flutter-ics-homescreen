import 'package:flutter_ics_homescreen/export.dart';

class HourlyForecast extends StatefulWidget {
  const HourlyForecast({super.key});

  @override
  State<HourlyForecast> createState() => _HourlyForecastState();
}

class _HourlyForecastState extends State<HourlyForecast> {
  String selectedForescastTime = "01:00 pm";
  List<ForecastModel> foreCastList = [
    ForecastModel(
        time: "01:00 pm", image: "assets/weatherStat.svg", weather: "29.1°"),
    ForecastModel(
        time: "02:00 pm", image: "assets/weatherStat.svg", weather: "28.1°"),
    ForecastModel(
        time: "03:00 pm", image: "assets/weatherStat.svg", weather: "27.1°"),
    ForecastModel(
        time: "04:00 pm", image: "assets/weatherStat.svg", weather: "29.1°"),
  ];
  @override
  Widget build(BuildContext context) {
    double weatherIconSize = 126;
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AGLDemoColors.periwinkleColor.withValues(alpha: 0.2),
          AGLDemoColors.periwinkleColor
        ]),
        boxShadow: [
          BoxShadow(
              offset: const Offset(1, 2),
              blurRadius: 16,
              color: Colors.black.withValues(alpha: 0.5))
        ],
        borderRadius: BorderRadius.circular(40),
        //  border: Border.all(color: Colors.white12),
      ),
      child: Container(
        padding: const EdgeInsets.only(top: 5, bottom: 20, left: 5, right: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          // border: Border.all(color: AGLDemoColors.periwinkleColor),
          // boxShadow: [
          //   BoxShadow(
          //       offset: const Offset(1, 2),
          //       blurRadius: 16,
          //       color: Colors.black.withValues(alpha: 0.5))
          // ],
          gradient: const RadialGradient(
            //center: Alignment(0.7, -0.6), // near the top right
            radius: 1,
            colors: <Color>[
              Color.fromARGB(255, 12, 16, 57), // yellow sun
              Color.fromARGB(255, 0, 0, 0), // blue sky
            ],
          ),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Hourly Forecast",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 44),
                  ),
                  Text(
                    "March 9",
                    style: GoogleFonts.firaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w200,
                        fontSize: 44),
                  ),
                ]),
          ),
          const SizedBox(
            height: 20,
          ),
          SizedBox(
            height: 320,
            child: ListView.builder(
                itemCount: foreCastList.length,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        color: foreCastList[index].time == selectedForescastTime
                            ? AGLDemoColors.resolutionBlueColor
                            : Colors.transparent),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            foreCastList[index].time,
                            style: GoogleFonts.firaSans(
                                fontWeight: FontWeight.w100,
                                color: Colors.white,
                                fontSize: 40),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: SvgPicture.asset(
                              "assets/weatherStat.svg",
                              width: weatherIconSize,
                              height: weatherIconSize,
                            ),
                          ),
                          Text(
                            foreCastList[index].weather,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 40),
                          ),
                        ]),
                  );
                }),
          )
        ]),
      ),
    );
  }
}

class ForecastModel {
  final String time;
  final String image;
  final String weather;

  ForecastModel(
      {required this.time, required this.image, required this.weather});
}
