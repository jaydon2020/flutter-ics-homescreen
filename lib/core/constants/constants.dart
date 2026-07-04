import '../../export.dart';

const splashWarning =
    'Please use the IVI system responsibly while driving. Keep your attention on the road, and use voice commands or hands-free controls when interacting with the system. Distracted driving can lead to accidents and serious injury. Follow all traffic laws and drive safely.';
const maxFuelLevel = 100.0;
const maxSpeed = 240.0;
const maxRpm = 8000;
final GlobalKey<ScaffoldState> homeScaffoldKey = GlobalKey();
const debugDisplay = bool.fromEnvironment('DEBUG_DISPLAY');
const debugShowCheckedModeBanner =
    bool.fromEnvironment('DEBUG_SHOW_CHECKED_MODE_BANNER');
const debugShowPerformanceOverlay =
    bool.fromEnvironment('DEBUG_SHOW_PERFORMANCE_OVERLAY');
const disableBkgAnimationDefault =
    bool.fromEnvironment('DISABLE_BKG_ANIMATION');
const randomHybridAnimationDefault =
    bool.fromEnvironment('RANDOM_HYBRID_ANIMATION');
const enableVoiceAssistantDefault =
    bool.fromEnvironment('ENABLE_VOICE_ASSISTANT');
const showBluetoothErrorsDefault =
    bool.fromEnvironment('SHOW_BLUETOOTH_ERRORS');
