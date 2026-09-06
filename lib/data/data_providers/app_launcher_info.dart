import 'package:flutter_ics_homescreen/export.dart';

class AppLauncherInfo {
  final String id;
  final String name;
  final String icon;
  final bool internal;

  AppLauncherInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.internal,
  });
}

class AppLauncherList extends Notifier<List<AppLauncherInfo>> {
  final _calls = AppLauncherInfo(
    id: 'calls',
    name: 'Calls',
    icon: 'calls.svg',
    internal: true,
  );

  @override
  List<AppLauncherInfo> build() {
    return [_calls];
  }

  void update(List<AppLauncherInfo> newAppList) {
    // The dial pad is built in and remains available without the launcher service.
    state = [
      _calls,
      ...newAppList.where((app) => !(app.internal && app.id == 'calls')),
    ];
  }
}
