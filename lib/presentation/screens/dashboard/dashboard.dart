import '/export.dart';
import 'widgets/dashboard_content.dart';

final dashboardTextureProvider = Provider((ref) {
  return SvgPicture.asset(
    'assets/dashboardTextures.svg',
    // 1080x1840 art: cover so it fills a view of another aspect instead of
    // letterboxing (see home.dart's background providers).
    fit: BoxFit.cover,
    alignment: Alignment.center,
  );
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  static Page<void> page() => const MaterialPage<void>(child: DashboardPage());
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 150.0),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: ref.read(dashboardTextureProvider),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 50, horizontal: 140),
          child: DashBoard(),
        ),
      ],
    );
  }
}
