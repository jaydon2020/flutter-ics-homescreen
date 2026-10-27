import 'package:flutter/foundation.dart';

enum PhoneConnectionStatus { disconnected, connecting, ready, error }

enum RecentCallType { incoming, outgoing, missed, unknown }

enum PhoneTransferStatus { queued, active, suspended, complete, failed }

@immutable
class PhoneContact {
  const PhoneContact({
    required this.id,
    required this.name,
    required this.numbers,
    this.photo,
  });

  final String id;
  final String name;
  final List<String> numbers;
  final Uint8List? photo;

  String get primaryNumber => numbers.isEmpty ? '' : numbers.first;
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

@immutable
class RecentCall {
  const RecentCall({
    required this.id,
    required this.name,
    required this.number,
    required this.timestamp,
    required this.type,
  });

  final String id;
  final String name;
  final String number;
  final DateTime timestamp;
  final RecentCallType type;
}

@immutable
class PhoneTransferProgress {
  const PhoneTransferProgress({
    required this.id,
    required this.status,
    this.transferred = 0,
    this.total = 0,
    this.error,
  });

  final String id;
  final PhoneTransferStatus status;
  final int transferred;
  final int total;
  final String? error;
}

@immutable
class PhoneDataState {
  const PhoneDataState({
    this.status = PhoneConnectionStatus.disconnected,
    this.deviceAddress,
    this.deviceName,
    this.contacts = const [],
    this.contactsAddress,
    this.recents = const [],
    this.transfers = const {},
    this.busy = false,
    this.error,
    this.pbapAvailable = false,
  });

  final PhoneConnectionStatus status;
  final String? deviceAddress;
  final String? deviceName;
  final List<PhoneContact> contacts;
  final String? contactsAddress;
  final List<RecentCall> recents;
  final Map<String, PhoneTransferProgress> transfers;
  final bool busy;
  final String? error;
  final bool pbapAvailable;

  PhoneDataState copyWith({
    PhoneConnectionStatus? status,
    String? deviceAddress,
    String? deviceName,
    List<PhoneContact>? contacts,
    String? contactsAddress,
    List<RecentCall>? recents,
    Map<String, PhoneTransferProgress>? transfers,
    bool? busy,
    String? error,
    bool clearError = false,
    bool? pbapAvailable,
  }) => PhoneDataState(
    status: status ?? this.status,
    deviceAddress: deviceAddress ?? this.deviceAddress,
    deviceName: deviceName ?? this.deviceName,
    contacts: contacts ?? this.contacts,
    contactsAddress: contactsAddress ?? this.contactsAddress,
    recents: recents ?? this.recents,
    transfers: transfers ?? this.transfers,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
    pbapAvailable: pbapAvailable ?? this.pbapAvailable,
  );
}

String normalizePhoneNumber(String value) {
  final trimmed = value.trim();
  final plus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  return plus && digits.isNotEmpty ? '+$digits' : digits;
}
