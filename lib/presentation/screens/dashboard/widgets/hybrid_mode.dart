import 'package:flutter_ics_homescreen/export.dart';

class HybridModel extends ConsumerStatefulWidget {
  const HybridModel({super.key});

  @override
  HybridModelState createState() => HybridModelState();
}

class HybridModelState extends ConsumerState<HybridModel> {
  @override
  Widget build(BuildContext context) {
    bool randomHybridAnimation =
        ref.watch(appConfigProvider).randomHybridAnimation;
    if (!randomHybridAnimation) {
      ref.listen<Vehicle>(vehicleProvider, (Vehicle? previous, Vehicle next) {
        ref.watch(hybridStateProvider.notifier).updateHybridState(
            next.speed,
            next.engineSpeed,
            false); //TODO get brake value and improve state logic
      });
    }

    return const SizedBox(
      width: 500,
      height: 500,
      child: Stack(
        children: [
          HybridBackground(),
          TopArrow(),
          LeftArrow(),
          RightArrow(),
          BatteryHybrid(),
        ],
      ),
    );
  }
}
