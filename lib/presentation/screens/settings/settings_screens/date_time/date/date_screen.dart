import 'package:flutter_calendar_carousel/classes/event.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';
import 'package:flutter_ics_homescreen/export.dart';
import 'package:intl/intl.dart';

class DatePage extends ConsumerWidget {
  const DatePage({super.key});
  static Page<void> page() => const MaterialPage<void>(child: DatePage());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(children: [
        CommonTitle(
          title: 'Date',
          hasBackButton: true,
          onPressed: () {
            ref.read(currentTimeProvider.notifier).isYearChanged = false;
            context.flow<AppState>().update((state) => AppState.dateTime);
          },
        ),
        const Expanded(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 144),
              child: SingleChildScrollView(child: DateScreenWidget())),
        ),
      ]),
    );
  }
}

class DateScreenWidget extends ConsumerStatefulWidget {
  const DateScreenWidget({super.key});
  Page<void> page() => const MaterialPage<void>(child: DateScreenWidget());

  @override
  DateScreenWidgetState createState() => DateScreenWidgetState();
}

class DateScreenWidgetState extends ConsumerState<DateScreenWidget> {
  late DateTime _currentDate;
  late DateTime _currentDate2;
  late String _currentMonth;
  late DateTime _targetDateTime;

  onPressed({required String type}) {
    if (type == "confirm") {
      DateTime selectedeDate = _currentDate.copyWith(
          day: _currentDate2.day,
          year: _currentDate2.year,
          month: _currentDate2.month);

      ref.read(currentTimeProvider.notifier).setCurrentTime(selectedeDate);
      context.flow<AppState>().update((state) => AppState.dateTime);
    } else if (type == "cancel") {
      ref.read(currentTimeProvider.notifier).isYearChanged = false;
      context.flow<AppState>().update((state) => AppState.dateTime);
    }
  }

  @override
  void initState() {
    _currentDate = ref.read(currentTimeProvider);
    int? selectedYear = ref.read(currentTimeProvider.notifier).selectedYear;
    if (selectedYear != null &&
        ref.read(currentTimeProvider.notifier).isYearChanged) {
      _currentDate = _currentDate.copyWith(year: selectedYear);
    }
    _currentDate2 = _currentDate;
    _currentMonth = DateFormat.yMMM().format(_currentDate);
    _targetDateTime = _currentDate;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);

    final calendarCarouselNoHeader = CalendarCarousel<Event>(
      onDayPressed: (date, events) {
        setState(() => _currentDate2 = date);
      },
      daysHaveCircularBorder: true,
      showOnlyCurrentMonthDate: false,
      weekendTextStyle:
          const TextStyle(color: AGLDemoColors.periwinkleColor, fontSize: 40),
      daysTextStyle:
          const TextStyle(color: AGLDemoColors.periwinkleColor, fontSize: 40),
      thisMonthDayBorderColor: Colors.transparent,
      weekFormat: false,
      height: 720.0,
      selectedDateTime: _currentDate2,
      targetDateTime: _targetDateTime,
      selectedDayButtonColor: AGLDemoColors.buttonFillEnabledColor,
      customGridViewPhysics: const NeverScrollableScrollPhysics(),
      showHeader: false,
      todayTextStyle:
          const TextStyle(color: AGLDemoColors.periwinkleColor, fontSize: 40),
      nextDaysTextStyle: const TextStyle(color: Colors.transparent),
      todayButtonColor: Colors.transparent,
      selectedDayTextStyle: const TextStyle(color: Colors.white, fontSize: 40),
      minSelectedDate: _currentDate.subtract(const Duration(days: 10958)),
      maxSelectedDate: _currentDate.add(const Duration(days: 10958)),
      prevDaysTextStyle: const TextStyle(
        color: Colors.transparent,
      ),
      weekdayTextStyle: const TextStyle(color: Colors.white, fontSize: 26),
      todayBorderColor: AGLDemoColors.buttonFillEnabledColor,
      onCalendarChanged: (DateTime date) {
        setState(() {
          _targetDateTime = date;
          _currentMonth = DateFormat.yMMM().format(_targetDateTime);
        });
      },
      onDayLongPressed: (DateTime date) {},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(
            top: 30.0,
            bottom: 16.0,
            left: 16.0,
            right: 16.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                  child: TextButton(
                onPressed: () {
                  context.flow<AppState>().update((state) => AppState.year);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentMonth,
                      style: const TextStyle(
                        color: AGLDemoColors.periwinkleColor,
                        fontSize: 40.0,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 40,
                        color: AGLDemoColors.periwinkleColor,
                      ),
                    )
                  ],
                ),
              )),
              Row(
                children: [
                  TextButton(
                    child: const Padding(
                      padding: EdgeInsets.all(15.0),
                      child: Icon(
                        Icons.arrow_back_ios,
                        size: 30,
                        color: AGLDemoColors.periwinkleColor,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _targetDateTime = DateTime(
                            _targetDateTime.year, _targetDateTime.month - 1);
                        _currentMonth =
                            DateFormat.yMMM().format(_targetDateTime);
                      });
                    },
                  ),
                  TextButton(
                    child: const Padding(
                      padding: EdgeInsets.all(15.0),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 30,
                        color: AGLDemoColors.periwinkleColor,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _targetDateTime = DateTime(
                            _targetDateTime.year, _targetDateTime.month + 1);
                        _currentMonth =
                            DateFormat.yMMM().format(_targetDateTime);
                      });
                    },
                  ),
                ],
              )
            ],
          ),
        ),
        Container(
          child: calendarCarouselNoHeader,
        ),
        const SizedBox(
          height: 180,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onHighlightChanged: (value) {
                  // setState(() {
                  //   isCancelButtonHighlighted = value;
                  // });
                },
                onTap: () {
                  onPressed(type: "cancel");

                  // onTap(type: "cancel");
                },
                child: Container(
                  width: size.width / 3.2,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 1.5,
                            offset: const Offset(1, 2))
                      ],
                      gradient: LinearGradient(colors: [
                        AGLDemoColors.resolutionBlueColor,
                        AGLDemoColors.neonBlueColor.withValues(alpha: 0.15),
                      ]),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                          color:
                              AGLDemoColors.neonBlueColor.withValues(alpha: 0.20))),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                          color: AGLDemoColors.periwinkleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 40,
                          letterSpacing: 0.4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onHighlightChanged: (value) {
                  // setState(() {
                  //   isCancelButtonHighlighted = value;
                  // });
                },
                onTap: () {
                  onPressed(type: "confirm");
                  // onTap(type: "cancel");
                },
                child: Container(
                  width: MediaQuery.sizeOf(context).width / 3.2,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 1.5,
                            offset: const Offset(1, 2))
                      ],
                      gradient: LinearGradient(colors: [
                        AGLDemoColors.resolutionBlueColor,
                        AGLDemoColors.neonBlueColor.withValues(alpha: 0.15),
                      ]),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                          color:
                              AGLDemoColors.neonBlueColor.withValues(alpha: 0.20))),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      "Confirm",
                      style: TextStyle(
                          color: AGLDemoColors.periwinkleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 40,
                          letterSpacing: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
