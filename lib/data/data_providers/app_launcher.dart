import 'package:flutter_ics_homescreen/export.dart';
import 'package:protos/applauncher_api.dart';
import 'package:protos/agl_shell_api.dart';

class AppLauncher {
  final Ref ref;

  late ClientChannel aglShellChannel;
  late AglShellManagerServiceClient aglShell;
  late ClientChannel appLauncherChannel;
  late AppLauncherClient appLauncher;

  List<String> availableOutputs = [];
  String appOutput = "";
  List<String> appStack = ['homescreen'];
  String raiseAppId = "";

  AppLauncher({required this.ref}) {
    aglShellChannel = ClientChannel('localhost',
        port: 14005,
        options: const ChannelOptions(credentials: ChannelCredentials.insecure()));

    aglShell = AglShellManagerServiceClient(aglShellChannel);

    appLauncherChannel = ClientChannel('localhost',
        port: 50052,
        options: const ChannelOptions(credentials: ChannelCredentials.insecure()));
    appLauncher = AppLauncherClient(appLauncherChannel);
  }

  run() async {
    getAvailableOutputs();
    getAppList();
    handleAppLaunchEvents();
    handleAglShellStatusEvents();
  }

  handleAppLaunchEvents() async {
    debugPrint("Listening for applaunchd events");
    try {
      var response = appLauncher.getStatusEvents(StatusRequest());
      await for (var event in response) {
        if (event.hasApp()) {
          AppStatus appStatus = event.app;
          debugPrint("Got app status:");
          debugPrint("$appStatus");
          if (appStatus.hasId() && appStatus.hasStatus()) {
            if (appStatus.status == "started") {
              if (!appRunning(appStatus.id)) {
                // Need to wait for compositor to tell us it's ready
                //debugPrint('${appStatus.id} not ready, wait for compositor');
                raiseAppId = appStatus.id;
              } else {
                //debugPrint('${appStatus.id} running, activating');
                activateApp(appStatus.id);
              }
            } else if (appStatus.status == "terminated") {
              deactivateApp(appStatus.id);
              if (raiseAppId == appStatus.id) {
                raiseAppId = "";
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('$e');
    }
  }

  handleAglShellStatusEvents() async {
    debugPrint("Listening for agl-compositor events");
    try {
      var response = aglShell.appStatusState(AppStateRequest());
      await for (var event in response) {
        //debugPrint("Got compositor app state: ${event.appId} = ${event.state}");
        //debugPrint('raiseAppId = $raiseAppId');
        if (raiseAppId != "" && event.appId == raiseAppId && event.state == 0) {
          debugPrint("Compositor ready, activating ${event.appId}");
          activateApp(raiseAppId);
          raiseAppId = "";
        }
      }
    } catch (e) {
      debugPrint('$e');
    }
  }

  getAvailableOutputs() async {
    try {
      var response = await aglShell.getOutputs(OutputRequest());
      availableOutputs = [];
      appOutput = "";
      for (OutputResponse output in response.outputs) {
        availableOutputs.add(output.name);
      }
      //debugPrint('available outputs: $availableOutputs');
      if (availableOutputs.isEmpty) {
        debugPrint('No display outputs available!');
      } else {
        appOutput = availableOutputs[0];
        String preferredOutput = ref.read(appConfigProvider).preferredOutput;
        if (preferredOutput != "") {
          if (availableOutputs.contains(preferredOutput)) {
            appOutput = preferredOutput;
          } else {
            debugPrint('Preferred output $preferredOutput is not available!');
          }
        }
        debugPrint('Using display output $appOutput');
      }
    } catch (e) {
      debugPrint('$e');
    }
  }

  getAppList() async {
    try {
      var response = await appLauncher.listApplications(ListRequest());
      List<AppLauncherInfo> apps = [];
      for (AppInfo info in response.apps) {
        debugPrint("Got app:");
        debugPrint("$info");
        // Existing icons are currently not usable, so leave blank for now
        apps.add(AppLauncherInfo(
            id: info.id, name: info.name, icon: info.iconPath, internal: false));
      }
      apps.sort((a, b) => a.name.compareTo(b.name));

      // Add built-in app widgets
      apps.insert(
          0,
          AppLauncherInfo(
              id: "clock", name: "Clock", icon: "clock.svg", internal: true));
      apps.insert(
          0,
          AppLauncherInfo(
              id: "weather",
              name: "Weather",
              icon: "weather.svg",
              internal: true));

      ref.read(appLauncherListProvider.notifier).update(apps);
    } catch (e) {
      debugPrint('$e');
    }
  }

  void startApp(String id) async {
    await appLauncher.startApplication(StartRequest(id: id));
  }

  addAppToStack(String id) {
    if (!appStack.contains(id)) {
      appStack.add(id);
    } else {
      int current = appStack.indexOf(id);
      if (current != (appStack.length - 1)) {
        appStack.removeAt(current);
        appStack.add(id);
      }
    }
  }

  bool appRunning(String id) {
    return appStack.contains(id);
  }

  activateSelf() async {
    activateApp('homescreen');
  }

  activateApp(String id) async {
    //debugPrint('appStack.last = ${appStack.last}, id = $id');
    if (appStack.last != id) {
      if (appOutput != "") {
        //debugPrint('activateApp: activating $id on $appOutput');
        var req = ActivateRequest(appId: id, outputName: appOutput);
        aglShell.activateApp(req);
      } else {
        debugPrint('No output!');
      }
      addAppToStack(id);
    }
  }

  deactivateApp(String id) async {
    if (appStack.contains(id)) {
      var req = DeactivateRequest(appId: id);
      aglShell.deactivateApp(req);
      appStack.remove(id);
      if (appStack.isNotEmpty) {
        activateApp(appStack.last);
      }
    }
  }
}
