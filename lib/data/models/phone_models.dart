import 'package:flutter/foundation.dart';

enum PhoneConnectionStatus { disconnected, connecting, ready, error }

enum RecentCallType { incoming, outgoing, missed, unknown }

enum PhoneMessageDirection { incoming, outgoing, unknown }

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
class PhoneMessage {
  const PhoneMessage({
    required this.id,
    required this.conversationKey,
    required this.sender,
    required this.senderAddress,
    required this.recipient,
    required this.recipientAddress,
    required this.timestamp,
    required this.direction,
    required this.read,
    required this.deleted,
    required this.priority,
    required this.attachmentSize,
    this.subject = '',
    this.body,
    this.attachmentPath,
  });

  final String id;
  final String conversationKey;
  final String sender;
  final String senderAddress;
  final String recipient;
  final String recipientAddress;
  final DateTime timestamp;
  final PhoneMessageDirection direction;
  final bool read;
  final bool deleted;
  final bool priority;
  final int attachmentSize;
  final String subject;
  final String? body;
  final String? attachmentPath;

  PhoneMessage copyWith({
    bool? read,
    bool? deleted,
    String? body,
    String? attachmentPath,
  }) => PhoneMessage(
    id: id,
    conversationKey: conversationKey,
    sender: sender,
    senderAddress: senderAddress,
    recipient: recipient,
    recipientAddress: recipientAddress,
    timestamp: timestamp,
    direction: direction,
    read: read ?? this.read,
    deleted: deleted ?? this.deleted,
    priority: priority,
    attachmentSize: attachmentSize,
    subject: subject,
    body: body ?? this.body,
    attachmentPath: attachmentPath ?? this.attachmentPath,
  );
}

@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.address,
    required this.messages,
  });

  final String id;
  final String title;
  final String address;
  final List<PhoneMessage> messages;

  PhoneMessage? get latest => messages.isEmpty ? null : messages.first;
  int get unreadCount => messages.where((message) => !message.read).length;
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
    this.messages = const [],
    this.conversations = const [],
    this.transfers = const {},
    this.busy = false,
    this.error,
    this.selectedConversationId,
    this.composeAddress,
    this.pbapAvailable = false,
    this.mapAvailable = false,
  });

  final PhoneConnectionStatus status;
  final String? deviceAddress;
  final String? deviceName;
  final List<PhoneContact> contacts;
  final String? contactsAddress;
  final List<RecentCall> recents;
  final List<PhoneMessage> messages;
  final List<Conversation> conversations;
  final Map<String, PhoneTransferProgress> transfers;
  final bool busy;
  final String? error;
  final String? selectedConversationId;
  final String? composeAddress;
  final bool pbapAvailable;
  final bool mapAvailable;

  PhoneDataState copyWith({
    PhoneConnectionStatus? status,
    String? deviceAddress,
    String? deviceName,
    List<PhoneContact>? contacts,
    String? contactsAddress,
    List<RecentCall>? recents,
    List<PhoneMessage>? messages,
    List<Conversation>? conversations,
    Map<String, PhoneTransferProgress>? transfers,
    bool? busy,
    String? error,
    bool clearError = false,
    String? selectedConversationId,
    String? composeAddress,
    bool clearSelectedConversation = false,
    bool clearComposeAddress = false,
    bool? pbapAvailable,
    bool? mapAvailable,
  }) => PhoneDataState(
    status: status ?? this.status,
    deviceAddress: deviceAddress ?? this.deviceAddress,
    deviceName: deviceName ?? this.deviceName,
    contacts: contacts ?? this.contacts,
    contactsAddress: contactsAddress ?? this.contactsAddress,
    recents: recents ?? this.recents,
    messages: messages ?? this.messages,
    conversations: conversations ?? this.conversations,
    transfers: transfers ?? this.transfers,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
    selectedConversationId: clearSelectedConversation
        ? null
        : selectedConversationId ?? this.selectedConversationId,
    composeAddress: clearComposeAddress
        ? null
        : composeAddress ?? this.composeAddress,
    pbapAvailable: pbapAvailable ?? this.pbapAvailable,
    mapAvailable: mapAvailable ?? this.mapAvailable,
  );
}

String normalizePhoneNumber(String value) {
  final trimmed = value.trim();
  final plus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  return plus && digits.isNotEmpty ? '+$digits' : digits;
}
