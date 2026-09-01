import 'dart:async';
import 'dart:math';

import 'package:flutter_ics_homescreen/export.dart';

class DashBoard extends ConsumerStatefulWidget {
  const DashBoard({super.key});

  @override
  DashBoardState createState() => DashBoardState();
}

class DashBoardState extends ConsumerState<DashBoard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  static bool _isAnimationPlayed = false;
  Timer? timer;

  /// Delays the start of the intro fade; cancelled if the dashboard goes away
  /// first, so the callback can never touch a disposed controller.
  Timer? _fadeTimer;

  /// The dashboard paints the car illustration twice: the copy inside
  /// CarStatus fades in with the rest of the content, and an identical copy on
  /// top of it stays opaque, so the car looks fixed while the gauges appear.
  /// The overlay used to be pinned at a hard-coded `bottom: 138`, which only
  /// lands on the faded copy at the 1080x1920 design size — at any other view
  /// height the column lays out differently and the two cars separate.
  ///
  /// This link puts the overlay wherever the faded copy actually paints, in the
  /// same frame and without measuring anything. It also settles the horizontal
  /// case for free: CarStatus sizes its row to 652px against ~1030px of
  /// content, so the row overflows and centres the excess, and the car is
  /// painted about half the overflow left of its layout offset. A follower
  /// tracks the paint position, so the overflow simply does not matter.
  final LayerLink _carLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
      value: _isAnimationPlayed ? 1.0 : 0.0,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    // Start the animation on first build.
    if (!_isAnimationPlayed) {
      _fadeTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _animationController.forward();
        _isAnimationPlayed = true;
      });
    }

    bool randomHybridAnimation =
        ref.read(appConfigProvider).randomHybridAnimation;
    if (randomHybridAnimation) {
      timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        Random random = Random();
        int randomState = random.nextInt(4);
        var hybridState = HybridState.values[randomState];
        ref.read(hybridStateProvider.notifier).setHybridState(hybridState);
      });
    }
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _animationController.dispose();
    if (timer != null) {
      timer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Not FadeTransition: RenderOpacity skips painting its child entirely at
    // alpha 0, which would detach the leader layer the car overlay follows and
    // leave no car at all for the first 500ms. 1/255 is the smallest alpha that
    // still paints, and is indistinguishable from invisible.
    Widget fadeContent = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(
        opacity: _animation.value.clamp(1 / 255, 1.0),
        child: child,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const RepaintBoundary(
              child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //mainAxisSize: MainAxisSize.max,
            children: [
              RPMProgressIndicator(),
              SpeedProgressIndicator(),
              FuelProgressIndicator(),
            ],
          )),
          const RepaintBoundary(child: HybridModel()),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TemperatureRowWidget(),
              RangeWidget(),
            ],
          ),
          CarStatus(carLink: _carLink),
        ],
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: fadeContent,
        ),
        // Painted on top of the faded copy, wherever that lands. The column is
        // child 0, so the leader is always painted before this follower reads
        // it. Positioned deliberately: a non-positioned child would make the
        // Stack size itself to the car (625x440) and the column would lay out
        // inside that. Where it is pinned makes no difference — the follower
        // layer's transform, not its layout offset, places what it paints.
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _carLink,
            showWhenUnlinked: false,
            child: ref.read(carImageProvider),
          ),
        ),
      ],
    );
  }
}
