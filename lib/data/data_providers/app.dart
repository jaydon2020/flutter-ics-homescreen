import '../../export.dart';

final homeScreenProvider = Provider((ref) {
  final Map<String, String> envVars = Platform.environment;
  final ciFlagStr = envVars['HOMESCREEN_DEMO_CI'];
  final bool ciFlag = ciFlagStr != null && ciFlagStr != "0";
  return ciFlag ? const HomeScreenCI() : const HomeScreen();
});

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
      showPerformanceOverlay: debugShowPerformanceOverlay,
      theme: theme,
      // Lays every route out on the 1080x1920 canvas the UI was drawn for and
      // scales it to whatever view the embedder gives us. A no-op — literally
      // returns its child — when the view already is 1080x1920.
      builder: (context, child) => DesignScale(child: child!),
      home: const AppView(),
    );
  }
}

class AppView extends ConsumerWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(homeScreenProvider);
  }
}
