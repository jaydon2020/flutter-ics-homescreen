import 'package:flutter_ics_homescreen/export.dart';

class ChildLockLeft extends ConsumerWidget {
  const ChildLockLeft({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isChildLockActiveLeft = ref.watch(
        vehicleProvider.select((vehicle) => vehicle.isChildLockActiveLeft));

    return GestureDetector(
      onTap: () {
        debugPrint('Tapped child lock left');
        ref.read(vehicleProvider.notifier).setChildLock(side: 'left');
      },
      child: Container(
        height: 120,
        width: 150,
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Child Lock',
              style: TextStyle(
                fontSize: 26, // Set the font size to 26
              ),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  isChildLockActiveLeft ? Icons.lock : Icons.lock_open,
                  color:
                      isChildLockActiveLeft ? Colors.white : Colors.redAccent,
                  size: 16,
                ),
                Text(
                  isChildLockActiveLeft ? 'Activated' : 'Unlocked',
                  style: TextStyle(
                    color:
                        isChildLockActiveLeft ? Colors.white : Colors.redAccent,
                    fontSize: 26, // Set the font size to 26
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChildLockRight extends ConsumerWidget {
  const ChildLockRight({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isChildLockActiveRight = ref.watch(
        vehicleProvider.select((vehicle) => vehicle.isChildLockActiveRight));

    return GestureDetector(
      onTap: () {
        debugPrint('Tapped child lock right');
        ref.read(vehicleProvider.notifier).setChildLock(side: 'right');
      },
      child: Container(
        height: 120,
        width: 150,
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Child Lock',
              style: TextStyle(
                fontSize: 26, // Set the font size to 26
              ),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  isChildLockActiveRight ? 'Activated' : 'Unlocked',
                  style: TextStyle(
                    color: isChildLockActiveRight
                        ? Colors.white
                        : Colors.redAccent,
                    fontSize: 26, // Set the font size to 26
                  ),
                ),
                Icon(
                  isChildLockActiveRight ? Icons.lock : Icons.lock_open,
                  color:
                      isChildLockActiveRight ? Colors.white : Colors.redAccent,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
