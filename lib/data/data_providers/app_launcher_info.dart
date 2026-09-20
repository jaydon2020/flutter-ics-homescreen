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
  final _phone = AppLauncherInfo(
    id: 'phone',
    name: 'Phone',
    icon: 'phone.svg',
    internal: true,
  );
  final _messages = AppLauncherInfo(
    id: 'messages',
    name: 'Messages',
    icon: 'messages.svg',
    internal: true,
  );

  @override
  List<AppLauncherInfo> build() {
    return [_phone, _messages];
  }

  void update(List<AppLauncherInfo> newAppList) {
    // Phone and Messages remain available without the launcher service.
    state = [
      _phone,
      _messages,
      ...newAppList.where(
        (app) =>
            !(app.internal && {'calls', 'phone', 'messages'}.contains(app.id)),
      ),
    ];
  }
}
