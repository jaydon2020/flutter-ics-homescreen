import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_ics_homescreen/core/constants/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toml/toml.dart';

class KuksaConfig {
  final String hostname;
  final int port;
  final String authorizationFile;
  final String authorization;
  final bool useTls;
  final String caCertificateFile;
  final String readCaCertificateFile;
  final List<int> caCertificate;
  final String tlsServerName;

  static String globalConfigFilePath = '/etc/xdg/AGL/kuksa.toml';
  static String appConfigFilePath =
      '/etc/xdg/AGL/flutter-ics-homescreen/kuksa.toml';
  static String defaultHostname = 'localhost';
  static int defaultPort = 55555;
  static String defaultCaCertPath = '/etc/kuksa-val/CA.pem';

  KuksaConfig(
      {required this.hostname,
      required this.port,
      required this.authorizationFile,
      required this.authorization,
      required this.useTls,
      required this.caCertificateFile,
      required this.readCaCertificateFile,
      required this.caCertificate,
      required this.tlsServerName});

  static KuksaConfig defaultConfig() {
    return KuksaConfig(
        hostname: KuksaConfig.defaultHostname,
        port: KuksaConfig.defaultPort,
        authorizationFile: "",
        authorization: "",
        useTls: false,
        caCertificateFile: KuksaConfig.defaultCaCertPath,
        readCaCertificateFile: "",
        caCertificate: [],
        tlsServerName: "");
  }
}

KuksaConfig readKuksaConfig(String configFilePath, KuksaConfig defaultConfig) {
  try {
    print("Reading KUKSA configuration ${configFilePath}");
    final configFile = File(configFilePath);
    String content = configFile.readAsStringSync();
    final configMap = TomlDocument.parse(content).toMap();

    String hostname = defaultConfig.hostname;
    if (configMap.containsKey('hostname')) {
      hostname = configMap['hostname'];
    }

    int port = defaultConfig.port;
    if (configMap.containsKey('port')) {
      port = configMap['port'];
    }

    String tokenFile = defaultConfig.authorizationFile;
    String token = defaultConfig.authorization;
    if (configMap.containsKey('authorization')) {
      String s = configMap['authorization'];
      if (s.isNotEmpty) {
        if (s.startsWith("/")) {
          tokenFile = s;
          debugPrint("Reading authorization token $tokenFile");
          try {
            token = File(tokenFile).readAsStringSync();
          } on Exception catch (_) {
            print("ERROR: Could not read authorization token file $tokenFile");
            token = "";
          }
        } else {
          token = s;
        }
      }
    }
    //debugPrint("authorization file = $tokenFile");
    //debugPrint("authorization = $token");

    bool useTls = defaultConfig.useTls;
    if (configMap.containsKey('use-tls')) {
      var value = configMap['use-tls'];
      if (value is bool) useTls = value;
    }
    //debugPrint("Use TLS = $useTls");

    String caCertFile = defaultConfig.caCertificateFile;
    String readCaCertFile = defaultConfig.readCaCertificateFile;
    List<int> caCert = defaultConfig.caCertificate;
    if (configMap.containsKey('ca-certificate')) {
      caCertFile = configMap['ca-certificate'];
    }
    if (caCertFile.isNotEmpty && caCertFile != readCaCertFile) {
      try {
        caCert = File(caCertFile).readAsBytesSync();
      } on Exception catch (_) {
        print("ERROR: Could not read CA certificate file $caCertFile");
        caCert = [];
      }
      readCaCertFile = caCertFile;
    }
    //debugPrint("CA cert file = $caCertFile");
    //debugPrint("CA cert = $caCert");

    String tlsServerName = defaultConfig.tlsServerName;
    if (configMap.containsKey('tls-server-name')) {
      tlsServerName = configMap['tls-server-name'];
    }

    return KuksaConfig(
        hostname: hostname,
        port: port,
        authorizationFile: tokenFile,
        authorization: token,
        useTls: useTls,
        caCertificateFile: caCertFile,
        readCaCertificateFile: readCaCertFile,
        caCertificate: caCert,
        tlsServerName: tlsServerName);
  } on Exception catch (_) {
    return defaultConfig;
  }
}

class RadioConfig {
  final String hostname;
  final int port;
  final String presets;

  static String defaultHostname = 'localhost';
  static int defaultPort = 50053;
  static String defaultPresets =
      '/etc/xdg/AGL/flutter-ics-homescreen/radio-presets.toml';

  RadioConfig(
      {required this.hostname, required this.port, required this.presets});

  static RadioConfig defaultConfig() {
    return RadioConfig(
        hostname: RadioConfig.defaultHostname,
        port: RadioConfig.defaultPort,
        presets: RadioConfig.defaultPresets);
  }
}

class StorageConfig {
  final String hostname;
  final int port;

  static String defaultHostname = 'localhost';
  static int defaultPort = 50054;

  StorageConfig({required this.hostname, required this.port});

  static StorageConfig defaultConfig() {
    return StorageConfig(
        hostname: StorageConfig.defaultHostname,
        port: StorageConfig.defaultPort);
  }
}

class MpdConfig {
  final String hostname;
  final int port;

  static String defaultHostname = 'localhost';
  static int defaultPort = 6600;

  MpdConfig({required this.hostname, required this.port});

  static MpdConfig defaultConfig() {
    return MpdConfig(
        hostname: MpdConfig.defaultHostname, port: MpdConfig.defaultPort);
  }
}

class VoiceAgentConfig {
  final String hostname;
  final int port;

  static String defaultHostname = 'localhost';
  static int defaultPort = 51053;

  VoiceAgentConfig({required this.hostname, required this.port});

  static VoiceAgentConfig defaultConfig() {
    return VoiceAgentConfig(
        hostname: VoiceAgentConfig.defaultHostname,
        port: VoiceAgentConfig.defaultPort);
  }
}

class AppConfig {
  final bool disableBkgAnimation;
  final bool plainBackground;
  final bool randomHybridAnimation;
  final KuksaConfig kuksaConfig;
  final RadioConfig radioConfig;
  final StorageConfig storageConfig;
  final MpdConfig mpdConfig;
  final VoiceAgentConfig voiceAgentConfig;
  final bool enableVoiceAssistant;
  final bool enableCoverArtNative;

  static String configFilePath = '/etc/xdg/AGL/flutter-ics-homescreen.toml';

  AppConfig(
      {required this.disableBkgAnimation,
      required this.plainBackground,
      required this.randomHybridAnimation,
      required this.kuksaConfig,
      required this.radioConfig,
      required this.storageConfig,
      required this.mpdConfig,
      required this.voiceAgentConfig,
      required this.enableVoiceAssistant,
      required this.enableCoverArtNative});

  static KuksaConfig parseKuksaConfig() {
    final KuksaConfig defaultConfig = KuksaConfig.defaultConfig();
    try {
      final Map<String, String> envVars = Platform.environment;
      final configHome = envVars['XDG_CONFIG_HOME'];

      // Read global configuration
      var configFilePath = KuksaConfig.globalConfigFilePath;
      if (configHome != null) {
        configFilePath = configHome + "/AGL/kuksa.toml";
      }
      var config = defaultConfig;
      config = readKuksaConfig(configFilePath, config);

      // Read app-specific configuration
      configFilePath = KuksaConfig.appConfigFilePath;
      if (configHome != null) {
        configFilePath =
            configHome + "/AGL/flutter-cluster-dashboard/kuksa.toml";
      }
      config = readKuksaConfig(configFilePath, config);
      return config;
    } catch (_) {
      debugPrint("Invalid KUKSA.val configuration, using defaults");
      return defaultConfig;
    }
  }

  static RadioConfig parseRadioConfig(Map radioMap) {
    try {
      String hostname = RadioConfig.defaultHostname;
      if (radioMap.containsKey('hostname')) {
        hostname = radioMap['hostname'];
      }

      int port = RadioConfig.defaultPort;
      if (radioMap.containsKey('port')) {
        port = radioMap['port'];
      }

      String presets = RadioConfig.defaultPresets;
      if (radioMap.containsKey('presets')) {
        presets = radioMap['presets'];
      }

      return RadioConfig(hostname: hostname, port: port, presets: presets);
    } catch (_) {
      debugPrint("Invalid radio configuration, using defaults");
      return RadioConfig.defaultConfig();
    }
  }

  static StorageConfig parseStorageConfig(Map storageMap) {
    try {
      String hostname = StorageConfig.defaultHostname;
      if (storageMap.containsKey('hostname')) {
        hostname = storageMap['hostname'];
      }

      int port = StorageConfig.defaultPort;
      if (storageMap.containsKey('port')) {
        port = storageMap['port'];
      }

      return StorageConfig(hostname: hostname, port: port);
    } catch (_) {
      debugPrint("Invalid storage configuration, using defaults");
      return StorageConfig.defaultConfig();
    }
  }

  static MpdConfig parseMpdConfig(Map mpdMap) {
    try {
      String hostname = MpdConfig.defaultHostname;
      if (mpdMap.containsKey('hostname')) {
        hostname = mpdMap['hostname'];
      }

      int port = MpdConfig.defaultPort;
      if (mpdMap.containsKey('port')) {
        port = mpdMap['port'];
      }

      return MpdConfig(hostname: hostname, port: port);
    } catch (_) {
      debugPrint("Invalid MPD configuration, using defaults");
      return MpdConfig.defaultConfig();
    }
  }

  static VoiceAgentConfig parseVoiceAgentConfig(Map voiceAgentMap) {
    try {
      String hostname = VoiceAgentConfig.defaultHostname;
      if (voiceAgentMap.containsKey('hostname')) {
        hostname = voiceAgentMap['hostname'];
      }

      int port = VoiceAgentConfig.defaultPort;
      if (voiceAgentMap.containsKey('port')) {
        port = voiceAgentMap['port'];
      }

      return VoiceAgentConfig(hostname: hostname, port: port);
    } catch (_) {
      debugPrint("Invalid VoiceAgent configuration, using defaults");
      return VoiceAgentConfig.defaultConfig();
    }
  }
}

final appConfigProvider = Provider((ref) {
  final configFile = File(AppConfig.configFilePath);
  try {
    // KUKSA configuration is in its own file(s)
    KuksaConfig kuksaConfig = AppConfig.parseKuksaConfig();

    print("Reading configuration ${AppConfig.configFilePath}");
    var configMap = {};
    try {
      String content = configFile.readAsStringSync();
      configMap = TomlDocument.parse(content).toMap();
    } catch (_) {
      debugPrint("Could not read ${AppConfig.configFilePath}");
      configMap = {};
    }

    RadioConfig radioConfig;
    if (configMap.containsKey('radio')) {
      radioConfig = AppConfig.parseRadioConfig(configMap['radio']);
    } else {
      radioConfig = RadioConfig.defaultConfig();
    }

    StorageConfig storageConfig;
    if (configMap.containsKey('storage')) {
      storageConfig = AppConfig.parseStorageConfig(configMap['storage']);
    } else {
      storageConfig = StorageConfig.defaultConfig();
    }

    MpdConfig mpdConfig;
    if (configMap.containsKey('mpd')) {
      mpdConfig = AppConfig.parseMpdConfig(configMap['mpd']);
    } else {
      mpdConfig = MpdConfig.defaultConfig();
    }

    VoiceAgentConfig voiceAgentConfig;
    if (configMap.containsKey('voiceAgent')) {
      voiceAgentConfig =
          AppConfig.parseVoiceAgentConfig(configMap['voiceAgent']);
    } else {
      voiceAgentConfig = VoiceAgentConfig.defaultConfig();
    }

    bool enableVoiceAssistant = enableVoiceAssistantDefault;
    if (configMap.containsKey('enable-voice-assistant')) {
      var value = configMap['enable-voice-assistant'];
      if (value is bool) {
        enableVoiceAssistant = value;
      }
    }

    bool disableBkgAnimation = disableBkgAnimationDefault;
    if (configMap.containsKey('disable-bg-animation')) {
      var value = configMap['disable-bg-animation'];
      if (value is bool) {
        disableBkgAnimation = value;
      }
    }

    bool plainBackground = false;
    if (configMap.containsKey('plain-bg')) {
      var value = configMap['plain-bg'];
      if (value is bool) {
        plainBackground = value;
      }
    }

    bool randomHybridAnimation = randomHybridAnimationDefault;
    if (configMap.containsKey('random-hybrid-animation')) {
      var value = configMap['random-hybrid-animation'];
      if (value is bool) {
        randomHybridAnimation = value;
      }
    }

    final enableCoverArtNative =
        configMap['bluetooth']?['enable-cover-art-native'] == true;

    return AppConfig(
        disableBkgAnimation: disableBkgAnimation,
        plainBackground: plainBackground,
        randomHybridAnimation: randomHybridAnimation,
        kuksaConfig: kuksaConfig,
        radioConfig: radioConfig,
        storageConfig: storageConfig,
        mpdConfig: mpdConfig,
        voiceAgentConfig: voiceAgentConfig,
        enableVoiceAssistant: enableVoiceAssistant,
        enableCoverArtNative: enableCoverArtNative);
  } catch (_) {
    return AppConfig(
        disableBkgAnimation: disableBkgAnimationDefault,
        plainBackground: false,
        randomHybridAnimation: randomHybridAnimationDefault,
        kuksaConfig: KuksaConfig.defaultConfig(),
        radioConfig: RadioConfig.defaultConfig(),
        storageConfig: StorageConfig.defaultConfig(),
        mpdConfig: MpdConfig.defaultConfig(),
        voiceAgentConfig: VoiceAgentConfig.defaultConfig(),
        enableVoiceAssistant: enableVoiceAssistantDefault,
        enableCoverArtNative: false);
  }
});
