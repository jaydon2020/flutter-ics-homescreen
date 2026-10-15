import '../../../../export.dart';

class TemperatureRowWidget extends ConsumerWidget {
  const TemperatureRowWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const TextStyle temperatureTextStyle = TextStyle(
      fontFamily: 'BrunoAce',
      color: Colors.white,
      fontSize: 44,
    );

    const TextStyle unitTextStyle = TextStyle(
      fontFamily: 'BrunoAce',
      color: Color(0xFFC1D8FF),
      fontSize: 38,
    );

    return Container(
      width:
          442, // needs to be adjusted after the celsius and fahrenheit symbols are fixed
      height: 130, // Height of the oval
      //padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        gradient: const RadialGradient(
          colors: [
            Color.fromARGB(255, 19, 24, 75),
            Color.fromARGB(127, 0, 0, 0)
          ],
          stops: [0.0, 0.7],
          radius: 1,
        ),
        //color: Colors.grey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
              65), // Half of the height for an oval effect
          side: const BorderSide(
            color: Color.fromARGB(156, 0, 0, 0),
            width: 2,
          ),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Inside temperature
          TemperatureWidget(
            tempStyle: temperatureTextStyle,
            unitStyle: unitTextStyle,
            isOutside: false,
          ),
          SizedBox(width: 10),
          // Outside temperature
          TemperatureWidget(
            tempStyle: temperatureTextStyle,
            unitStyle: unitTextStyle,
            isOutside: true,
          ),
        ],
      ),
    );
  }
}

class TemperatureWidget extends ConsumerWidget {
  const TemperatureWidget(
      {super.key,
      required this.tempStyle,
      required this.unitStyle,
      required this.isOutside});

  final TextStyle tempStyle;
  final TextStyle unitStyle;
  final bool isOutside;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double value = 0;
    String label = "Outside";
    if (isOutside) {
      value = ref.watch(
          vehicleProvider.select((vehicle) => vehicle.outsideTemperature));
    } else {
      value = ref.watch(
          vehicleProvider.select((vehicle) => vehicle.insideTemperature));
      label = "Inside";
    }
    final unit =
        ref.watch(unitStateProvider.select((unit) => unit.temperatureUnit));

    int temperatureAsInt = value.toInt();
    double convertedTemperature = unit == TemperatureUnit.celsius
        ? temperatureAsInt.toDouble()
        : (temperatureAsInt * 9 / 5) + 32;

    // Format the temperature for display.
    String temperatureDisplay = unit == TemperatureUnit.celsius
        ? '$temperatureAsInt'
        : convertedTemperature.toStringAsFixed(0);

    return Padding(
      padding: isOutside
          ? const EdgeInsets.only(
              right: 22) // Padding for the outside temperature
          : const EdgeInsets.only(
              left: 12), // Padding for the inside temperature
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.thermostat_outlined,
            color: Color(0xFF2962FF),
            size: 48,
          ),
          const SizedBox(width: 4), // Space between icon and text
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFC1D8FF),
                  fontSize: 26,
                ),
              ),
              RichText(
                text: TextSpan(
                  text: temperatureDisplay,
                  style: tempStyle,
                  children: <TextSpan>[
                    TextSpan(
                      text: unit == TemperatureUnit.celsius ? '°C' : '°F',
                      style: unitStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
