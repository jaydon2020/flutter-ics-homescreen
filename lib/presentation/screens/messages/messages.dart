import 'package:flutter_ics_homescreen/export.dart';
import 'package:intl/intl.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});
  static Page<void> page() => const MaterialPage<void>(child: MessagesPage());

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  final _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(phoneDataProvider);
    final conversation = data.conversations
        .where((item) => item.id == data.selectedConversationId)
        .firstOrNull;
    final inChat = conversation != null || data.composeAddress != null;
    return Column(
      children: [
        CommonTitle(
          title: inChat
              ? (conversation?.title ?? data.composeAddress!)
              : 'Messages',
          hasBackButton: true,
          onPressed: () {
            if (inChat) {
              ref.read(phoneDataProvider.notifier).closeConversation();
            } else {
              ref.read(appProvider.notifier).update(AppState.apps);
            }
          },
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width >= 700 ? 120 : 24,
              20,
              28,
              120,
            ),
            child: inChat
                ? _ChatView(
                    conversation: conversation,
                    address: conversation?.address ?? data.composeAddress!,
                    composer: _composer,
                  )
                : _ConversationList(data: data),
          ),
        ),
      ],
    );
  }
}

class _ConversationList extends ConsumerWidget {
  const _ConversationList({required this.data});
  final PhoneDataState data;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conversations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Messages synced from your phone',
                  style: TextStyle(
                    color: AGLDemoColors.periwinkleColor,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Compose message',
                onPressed: data.mapAvailable
                    ? () => _composeMessage(context, ref)
                    : null,
                icon: const Icon(Icons.edit_rounded),
                style: _headerButtonStyle(),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Refresh messages',
                onPressed: data.busy
                    ? null
                    : ref.read(phoneDataProvider.notifier).refreshConversations,
                icon: data.busy
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                style: _headerButtonStyle(),
              ),
            ],
          ),
        ],
      ),
      if (data.error != null) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AGLDemoColors.callDangerColor.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(data.error!, style: const TextStyle(color: Colors.white)),
        ),
      ],
      const SizedBox(height: 20),
      Expanded(
        child: data.conversations.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.forum_outlined,
                      size: 72,
                      color: AGLDemoColors.jordyBlueColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data.mapAvailable
                          ? 'No conversations'
                          : 'Message access unavailable',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enable message access for this car on your phone.',
                      style: TextStyle(
                        color: AGLDemoColors.periwinkleColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: data.conversations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final conversation = data.conversations[index];
                  final latest = conversation.latest!;
                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: Ink(
                      height: 128,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xff050711), Color(0xff101638)],
                        ),
                      ),
                      child: InkWell(
                        key: ValueKey('conversation-${conversation.id}'),
                        onTap: () => ref
                            .read(phoneDataProvider.notifier)
                            .openConversation(conversation.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: AGLDemoColors.callControlColor,
                                child: Text(
                                  conversation.title.isEmpty
                                      ? '?'
                                      : conversation.title[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conversation.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'h:mm a',
                                          ).format(latest.timestamp),
                                          style: const TextStyle(
                                            color:
                                                AGLDemoColors.periwinkleColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            latest.body ?? latest.subject,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color:
                                                  AGLDemoColors.periwinkleColor,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        if (latest.priority)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 8),
                                            child: Icon(
                                              Icons.priority_high_rounded,
                                              color: AGLDemoColors.yellowColor,
                                              size: 20,
                                            ),
                                          ),
                                        if (latest.attachmentSize > 0)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 8),
                                            child: Icon(
                                              Icons.attach_file_rounded,
                                              color:
                                                  AGLDemoColors.jordyBlueColor,
                                              size: 20,
                                            ),
                                          ),
                                        if (conversation.unreadCount > 0)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  AGLDemoColors.neonBlueColor,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Text(
                                              '${conversation.unreadCount}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AGLDemoColors.jordyBlueColor,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ],
  );

  static ButtonStyle _headerButtonStyle() => IconButton.styleFrom(
    minimumSize: const Size.square(56),
    foregroundColor: AGLDemoColors.jordyBlueColor,
    backgroundColor: AGLDemoColors.callControlColor,
  );

  static Future<void> _composeMessage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final address = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AGLDemoColors.callSurfaceColor,
        title: const Text('New message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            prefixIcon: Icon(Icons.phone_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (address != null && address.isNotEmpty) {
      ref.read(phoneDataProvider.notifier).composeTo(address);
    }
  }
}

class _ChatView extends ConsumerWidget {
  const _ChatView({
    required this.conversation,
    required this.address,
    required this.composer,
  });
  final Conversation? conversation;
  final String address;
  final TextEditingController composer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(phoneDataProvider);
    final messages =
        conversation?.messages.reversed.toList() ?? const <PhoneMessage>[];
    return Column(
      children: [
        Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AGLDemoColors.callSurfaceColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: AGLDemoColors.callControlColor,
                child: Icon(
                  Icons.person_rounded,
                  color: AGLDemoColors.periwinkleColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation?.title ?? address,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      address,
                      style: const TextStyle(
                        color: AGLDemoColors.periwinkleColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Call ${conversation?.title ?? address}',
                onPressed: () => ref
                    .read(callStateProvider.notifier)
                    .startCall(address, name: conversation?.title),
                icon: const Icon(Icons.call_rounded),
                color: AGLDemoColors.greenColor,
                iconSize: 30,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(56),
                  backgroundColor: AGLDemoColors.greenColor.withValues(
                    alpha: .1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text(
                    'Start a conversation',
                    style: TextStyle(
                      color: AGLDemoColors.periwinkleColor,
                      fontSize: 18,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _MessageBubble(message: messages[index]),
                ),
        ),
        if (data.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              data.error!,
              style: const TextStyle(color: AGLDemoColors.callDangerColor),
            ),
          ),
        SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: composer,
                  minLines: 1,
                  maxLines: 3,
                  enabled: !data.busy && data.mapAvailable,
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: const TextStyle(
                      color: AGLDemoColors.periwinkleColor,
                    ),
                    filled: true,
                    fillColor: AGLDemoColors.callSurfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 17,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox.square(
                dimension: 58,
                child: IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: data.busy || !data.mapAvailable
                      ? null
                      : () async {
                          final text = composer.text.trim();
                          if (text.isEmpty) return;
                          await ref
                              .read(phoneDataProvider.notifier)
                              .sendMessage(address, text);
                          composer.clear();
                        },
                  icon: data.busy
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AGLDemoColors.neonBlueColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({required this.message});
  final PhoneMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outgoing = message.direction == PhoneMessageDirection.outgoing;
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () async {
          await ref.read(phoneDataProvider.notifier).deleteMessage(message.id);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Message deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => ref
                    .read(phoneDataProvider.notifier)
                    .restoreMessage(message.id),
              ),
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: outgoing
                ? AGLDemoColors.buttonFillEnabledColor
                : AGLDemoColors.callSurfaceColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(outgoing ? 22 : 6),
              bottomRight: Radius.circular(outgoing ? 6 : 22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.body ?? message.subject,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.35,
                ),
              ),
              if (message.attachmentSize > 0)
                TextButton.icon(
                  onPressed: () => ref
                      .read(phoneDataProvider.notifier)
                      .downloadAttachment(message.id),
                  icon: const Icon(Icons.download_rounded),
                  label: Text('Attachment (${message.attachmentSize} B)'),
                ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('h:mm a').format(message.timestamp),
                    style: const TextStyle(
                      color: AGLDemoColors.periwinkleColor,
                      fontSize: 12,
                    ),
                  ),
                  if (outgoing) ...[
                    const SizedBox(width: 6),
                    Icon(
                      message.read
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 16,
                      color: AGLDemoColors.jordyBlueColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
