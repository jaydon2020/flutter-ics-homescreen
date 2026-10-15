import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:new_virtual_keyboard/virtual_keyboard.dart';

class TimePage extends ConsumerWidget {
  const TimePage({super.key});
  static Page<void> page() => const MaterialPage<void>(child: TimePage());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(children: [
        CommonTitle(
          title: 'Time',
          hasBackButton: true,
          onPressed: () {
            context.flow<AppState>().update((state) => AppState.dateTime);
          },
        ),
        const Expanded(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 144),
              child: SingleChildScrollView(child: TimeScreenWidget())),
        ),
      ]),
    );
  }
}

class TimeScreenWidget extends ConsumerStatefulWidget {
  const TimeScreenWidget({super.key});
  Page<void> page() => const MaterialPage<void>(child: TimeScreenWidget());

  @override
  TimeScreenWidgetState createState() => TimeScreenWidgetState();
}

class TimeScreenWidgetState extends ConsumerState<TimeScreenWidget> {
  late int selectedTimeHour;
  late int selectedTimeMinute;
  String selectedMeridien = "AM";

  TextEditingController hourController = TextEditingController();
  TextEditingController minuteController = TextEditingController();
  late DateTime currentTime;
  onPressed({required String type}) {
    if (type == "confirm") {
      if (hourController.text.isNotEmpty && minuteController.text.isNotEmpty) {
        String input =
            '${hourController.text}:${minuteController.text} $selectedMeridien';
        DateTime selectedeDatetime = DateFormat.jm().parse(input);
        selectedeDatetime = selectedeDatetime.copyWith(
            day: currentTime.day,
            year: currentTime.year,
            month: currentTime.month);
        ref
            .read(currentTimeProvider.notifier)
            .setCurrentTime(selectedeDatetime);

        // ref.read(dateTimeStateProvider.notifier).setTime(
        //     "${hourController.text}:${minuteController.text} $selectedMeridien");
        context.flow<AppState>().update((state) => AppState.dateTime);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Time can't be empty!")));
      }
    } else if (type == "cancel") {
      context.flow<AppState>().update((state) => AppState.dateTime);
    }
  }

  @override
  void initState() {
    currentTime = ref.read(currentTimeProvider);
    String time = DateFormat('hh:mm a').format(currentTime);

    List<String> split = time.split(":");
    selectedTimeHour = int.parse(split[0]);
    List<String> splitMeridian = split[1].split(" ");

    selectedTimeMinute = int.parse(splitMeridian[0]);

    setState(() {
      selectedMeridien = splitMeridian[1];
      hourController.text = selectedTimeHour.toString();
      minuteController.text = selectedTimeMinute.toString();
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(
          height: 60,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TimeTextField(
              controller: hourController,
              type: "hour",
            ),
            const Padding(
              padding: EdgeInsets.all(15),
              child: Text(
                ":",
                style: TextStyle(
                    color: AGLDemoColors.periwinkleColor, fontSize: 44),
              ),
            ),
            TimeTextField(
              controller: minuteController,
              type: "minute",
            ),
          ],
        ),
        const SizedBox(
          height: 50,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  ),
                  border: Border.all(color: AGLDemoColors.periwinkleColor),
                  color: selectedMeridien == "AM"
                      ? AGLDemoColors.neonBlueColor
                      : Colors.transparent),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  ),
                  onTap: () {
                    setState(() {
                      selectedMeridien = "AM";
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top: 17, bottom: 17, right: 30, left: 25),
                    child: Row(
                      children: [
                        selectedMeridien == "AM"
                            ? const Icon(
                                Icons.check,
                                size: 48,
                                color: Colors.white,
                              )
                            : const SizedBox(
                                width: 48,
                                height: 48,
                              ),
                        const SizedBox(
                          width: 3,
                        ),
                        Text(
                          "AM",
                          style: TextStyle(
                              color: selectedMeridien == "AM"
                                  ? Colors.white
                                  : AGLDemoColors.periwinkleColor,
                              fontSize: 40),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  border: Border.all(color: AGLDemoColors.periwinkleColor),
                  color: selectedMeridien == "PM"
                      ? AGLDemoColors.neonBlueColor
                      : Colors.transparent),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  onTap: () {
                    setState(() {
                      selectedMeridien = "PM";
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top: 17, bottom: 17, right: 30, left: 25),
                    child: Row(
                      children: [
                        selectedMeridien == "PM"
                            ? const Icon(
                                Icons.check,
                                size: 48,
                                color: Colors.white,
                              )
                            : const SizedBox(
                                width: 48,
                                height: 48,
                              ),
                        const SizedBox(
                          width: 3,
                        ),
                        Text(
                          "PM",
                          style: TextStyle(
                              color: selectedMeridien == "PM"
                                  ? Colors.white
                                  : AGLDemoColors.periwinkleColor,
                              fontSize: 40),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 200,
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
                    padding: EdgeInsets.symmetric(vertical: 10),
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
                    padding: EdgeInsets.symmetric(vertical: 10),
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

class TimeTextField extends StatefulWidget {
  const TimeTextField(
      {super.key, required this.controller, required this.type});
  final TextEditingController controller;
  final String type;

  @override
  State<TimeTextField> createState() => _TimeTextFieldState();
}

class _TimeTextFieldState extends State<TimeTextField> {
  TextEditingController controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    controller = widget.controller;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  onKeyBoardEvent(RawKeyEvent event) {
    if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      if (controller.text != "") {
        int value = int.tryParse(controller.text) ?? 0;
        if (widget.type == "hour") {
          if (value > 11) {
            controller.text = "12";
          } else {
            controller.text = (value + 1).toString();
          }
        } else if (widget.type == "minute") {
          if (value > 58) {
            controller.text = "59";
          } else {
            controller.text = (value + 1).toString();
          }
        }
        return KeyEventResult.handled;
      } else {
        controller.text = "0";
        return KeyEventResult.handled;
      }
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      if (controller.text.isNotEmpty) {
        int value = int.tryParse(controller.text) ?? 0;
        if (value < 1) {
          controller.text = "0";
        } else {
          controller.text = (value - 1).toString();
        }
        return KeyEventResult.handled;
      } else {
        controller.text = "0";
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void showKeyboard() {
    var ctx = homeScaffoldKey.currentContext;
    showModalBottomSheet(
      elevation: 0.0,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      context: ctx!,
      builder: (ctx) {
        return Container(
          height: 479,
          width: 1080,
          decoration: const BoxDecoration(
            color: AGLDemoColors.resolutionBlueColor,
            border: Border(
                top: BorderSide(
              color: Color(0xFF295EF7),
              width: 1,
            )),
          ),
          child: VirtualKeyboard(
            height: 478,
            textColor: AGLDemoColors.periwinkleColor,
            fontSize: 40,
            // [A-Z, 0-9]
            type: VirtualKeyboardType.Numeric,
            // Callback for key press event
            onKeyPress: (key) {
              _onKeyPress(key);
            },
          ),
        );
      },
    );
  }

  _onKeyPress(VirtualKeyboardKey key) {
    String text = controller.text;

    if (key.keyType == VirtualKeyboardKeyType.String) {
      if (key.text != ".") {
        text = text + key.text!;
        int value = int.parse(text);

        if (widget.type == "hour") {
          if (value > 11) {
            text = "12";
          }
        } else if (widget.type == "minute") {
          if (value > 58) {
            text = "59";
          }
        }
      }
    } else if (key.keyType == VirtualKeyboardKeyType.Action) {
      switch (key.action) {
        case VirtualKeyboardKeyAction.Backspace:
          if (text.isEmpty) return;
          text = text.substring(0, text.length - 1);
          break;
        // case VirtualKeyboardKeyAction.Return:
        //   text = '$text\n';
        //   break;
        default:
      }
    }
    controller.text = text;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 185,
        child: RawKeyboardListener(
          focusNode: FocusNode(onKey: (node, event) {
            return onKeyBoardEvent(event);
          }),
          child: TextField(
            onTap: () {
              showKeyboard();
            },
            style: const TextStyle(color: Colors.white, fontSize: 40),
            decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 23),
                filled: true,
                fillColor: AGLDemoColors.blueGlowFillColor.withValues(alpha: 0.1)),
            controller: controller,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (value) {
              if (value.isNotEmpty) {
                if (widget.type == "hour") {
                  if (int.parse(value) > 12) {
                    widget.controller.text = '12';
                  }
                } else if (widget.type == "minute") {
                  if (int.parse(value) > 59) {
                    widget.controller.text = '59';
                  }
                }
              }
            },
          ),
        ));
  }
}
