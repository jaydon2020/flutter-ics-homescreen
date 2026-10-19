import 'dart:async';

import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_ics_homescreen/data/services/service_retry.dart';
import 'package:protos/radio_api.dart' as api;

class RadioClient {
  final RadioConfig config;
  final Ref ref;
  late api.ClientChannel channel;
  late api.RadioClient stub;
  late final ServiceRetry _retry;
  StreamSubscription<api.StatusResponse>? _subscription;
  bool _connecting = false;
  bool _disposed = false;

  RadioClient({required this.config, required this.ref}) {
    debugPrint(
      "Connecting to radio service at ${config.hostname}:${config.port}",
    );
    api.ChannelCredentials creds = const api.ChannelCredentials.insecure();
    channel = api.ClientChannel(
      config.hostname,
      port: config.port,
      options: api.ChannelOptions(credentials: creds),
    );
    stub = api.RadioClient(channel);

    _retry = ServiceRetry('Radio service', config.hostname, config.port);
    ref.onDispose(() {
      _disposed = true;
      _retry.dispose();
      unawaited(_subscription?.cancel());
      unawaited(channel.shutdown());
    });
  }

  Future<void> connect() async {
    if (_disposed || _connecting) return;
    _connecting = true;
    try {
      await getBandParameters();
      if (_disposed) return;
      await getStatusEvents();
    } catch (error) {
      _reportError(error);
    } finally {
      _connecting = false;
    }
  }

  void _reportError(Object error) => _retry.failed(error, connect);

  Future<void> getStatusEvents() async {
    await _subscription?.cancel();
    if (_disposed) return;
    _subscription = stub
        .getStatusEvents(api.StatusRequest())
        .listen(
          (event) {
            if (_disposed) return;
            _retry.recovered();
            handleStatusEvent(event);
          },
          onError: (Object error, StackTrace _) => _reportError(error),
          onDone: () {
            if (!_disposed) {
              _reportError(
                const api.GrpcError.unavailable('Radio status stream closed'),
              );
            }
          },
          cancelOnError: true,
        );
  }

  Future<void> getBandParameters() async {
    final response = await stub.getBandParameters(
      api.GetBandParametersRequest(band: api.Band.BAND_FM),
      options: api.CallOptions(timeout: const Duration(seconds: 5)),
    );
    if (_disposed) return;
    ref
        .read(radioStateProvider.notifier)
        .updateBandParameters(
          freqMin: response.min,
          freqMax: response.max,
          freqStep: response.step,
        );
    final frequency = await stub.getFrequency(
      api.GetFrequencyRequest(),
      options: api.CallOptions(timeout: const Duration(seconds: 5)),
    );
    if (!_disposed) {
      ref
          .read(radioStateProvider.notifier)
          .updateFrequency(frequency.frequency);
    }
  }

  void handleStatusEvent(api.StatusResponse response) {
    switch (response.whichStatus()) {
      case api.StatusResponse_Status.frequency:
        var status = response.frequency;
        ref.read(radioStateProvider.notifier).updateFrequency(status.frequency);
        break;
      case api.StatusResponse_Status.play:
        var status = response.play;
        ref.read(radioStateProvider.notifier).updatePlaying(status.playing);
        break;
      case api.StatusResponse_Status.scan:
        var status = response.scan;
        if (status.stationFound) {
          ref.read(radioStateProvider.notifier).updateScanning(false);
        }
        break;
      default:
        break;
    }
  }

  void start() async {
    try {
      await stub.start(api.StartRequest());
    } catch (e) {
      _reportError(e);
    }
  }

  void stop() async {
    try {
      await stub.stop(api.StopRequest());
    } catch (e) {
      _reportError(e);
    }
  }

  void setFrequency(int frequency) async {
    var radioState = ref.read(radioStateProvider);
    if ((frequency < radioState.freqMin) ||
        (frequency > radioState.freqMax) ||
        ((frequency - radioState.freqMin) % radioState.freqStep) != 0) {
      debugPrint("setFrequency: invalid frequency $frequency!");
      return;
    }
    try {
      await stub
          .setFrequency(api.SetFrequencyRequest(frequency: frequency));
    } catch (e) {
      _reportError(e);
    }
  }

  void tuneForward() async {
    var radioState = ref.read(radioStateProvider);
    if (radioState.freqCurrent < radioState.freqMax) {
      int frequency = radioState.freqCurrent + radioState.freqStep;
      if (frequency > radioState.freqMax) {
        frequency = radioState.freqMax;
      }
      try {
        await stub
            .setFrequency(api.SetFrequencyRequest(frequency: frequency));
      } catch (e) {
        _reportError(e);
      }
    }
  }

  void tuneBackward() async {
    var radioState = ref.read(radioStateProvider);
    if (radioState.freqCurrent > radioState.freqMin) {
      int frequency = radioState.freqCurrent - radioState.freqStep;
      if (frequency < radioState.freqMin) {
        frequency = radioState.freqMin;
      }
      try {
        await stub
            .setFrequency(api.SetFrequencyRequest(frequency: frequency));
      } catch (e) {
        _reportError(e);
      }
    }
  }

  void scanForward() async {
    try {
      await stub.scanStart(api.ScanStartRequest(
          direction: api.ScanDirection.SCAN_DIRECTION_FORWARD));
    } catch (e) {
      _reportError(e);
    }
  }

  void scanBackward() async {
    try {
      await stub.scanStart(api.ScanStartRequest(
          direction: api.ScanDirection.SCAN_DIRECTION_BACKWARD));
    } catch (e) {
      _reportError(e);
    }
  }

  void scanStop() async {
    try {
      await stub.scanStop(api.ScanStopRequest());
    } catch (e) {
      _reportError(e);
    }
  }
}
