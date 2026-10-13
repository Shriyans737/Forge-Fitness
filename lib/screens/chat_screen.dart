import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/chat_service.dart';
import '../services/friends_service.dart';
import '../theme.dart';

class NewChatSheet extends StatefulWidget {
  const NewChatSheet({required this.service, required this.friends, super.key});

  final ChatService service;
  final List<FriendSummary> friends;

  @override
  State<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<NewChatSheet> {
  final TextEditingController _groupNameController = TextEditingController();
  final Set<String> _selected = {};
  bool _creating = false;
  bool _groupMode = false;
  bool _showFriends = false;
  String? _error;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'New chat',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_creating)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (!_groupMode && !_showFriends) ...[
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('Message a friend'),
                subtitle: const Text('Start a private conversation'),
                onTap: () => setState(() => _showFriends = true),
              ),
              ListTile(
                leading: const Icon(Icons.group_add_rounded),
                title: const Text('New group'),
                subtitle: const Text('Create a chat with two or more friends'),
                onTap: () => setState(() {
                  _groupMode = true;
                  _error = null;
                }),
              ),
            ] else if (_showFriends) ...[
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _showFriends = false),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Text(
                    'Message a friend',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              for (final friend in widget.friends)
                _friendTile(
                  friend,
                  onTap: () {
                    Navigator.pop(
                      context,
                      ChatConversation.directMessage(
                        currentUid: widget.service.uid,
                        currentUsername: widget.service.username,
                        friend: friend,
                      ),
                    );
                  },
                ),
            ] else ...[
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      _groupMode = false;
                      _groupNameController.clear();
                      _selected.clear();
                      _error = null;
                    }),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      'New group',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _groupNameController,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  border: OutlineInputBorder(),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final friend in widget.friends)
                      CheckboxListTile(
                        value: _selected.contains(friend.uid),
                        onChanged:
                            _selected.length >= 19 &&
                                !_selected.contains(friend.uid)
                            ? null
                            : (selected) => setState(() {
                                if (selected == true) {
                                  _selected.add(friend.uid);
                                } else {
                                  _selected.remove(friend.uid);
                                }
                              }),
                        secondary: _avatar(friend.displayName),
                        title: Text(friend.displayName),
                        subtitle: Text('@${friend.username}'),
                      ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _selected.length < 2 ? null : _createGroup,
                icon: const Icon(Icons.group_add_rounded),
                label: Text('Create group (${_selected.length}/2 minimum)'),
              ),
            ],
          ],
        ],
      ),
    ),
  );

  Widget _friendTile(FriendSummary friend, {required VoidCallback onTap}) =>
      ListTile(
        leading: _avatar(friend.displayName),
        title: Text(friend.displayName),
        subtitle: Text('@${friend.username}'),
        onTap: onTap,
      );

  Widget _avatar(String displayName) => CircleAvatar(
    child: Text(
      displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase(),
    ),
  );

  Future<void> _createGroup() async {
    final selectedFriends = widget.friends
        .where((friend) => _selected.contains(friend.uid))
        .toList(growable: false);
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final conversation = await widget.service.createGroup(
        name: _groupNameController.text,
        friends: selectedFriends,
      );
      if (mounted) Navigator.pop(context, conversation);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Create group failed: write=conversations/${widget.service.uid}; '
        'code=${error.code}; message=${error.message}\n$stackTrace',
      );
      if (mounted) {
        setState(() {
          _creating = false;
          _error = kDebugMode
              ? 'Could not create group (${error.code}): '
                    '${error.message ?? 'No details'}'
              : 'Could not create group. Please try again.';
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Create group failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _creating = false;
          _error = kDebugMode
              ? '$error'
              : 'Could not create group. Please try again.';
        });
      }
    }
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.service,
    required this.conversation,
    super.key,
  });

  final ChatService service;
  final ChatConversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Stream<List<ChatMessage>> _messagesStream;
  late ChatConversation _conversation;
  List<ChatMessage> _olderMessages = const [];
  bool _sending = false;
  bool _loadingOlder = false;
  bool _markingRead = false;
  bool _hasOlder = false;
  bool _olderExhausted = false;
  bool _preserveScrollOnce = false;
  bool _dmAllowed = true;
  late bool _muted;
  final Set<String> _revealedBlockedMessages = {};
  String? _failedText;
  String? _error;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _muted = widget.service.isMuted(_conversation.id);
    _messagesStream = widget.service.latestMessages(_conversation.id);
    if (!_conversation.isGroup) unawaited(_checkFriendship());
    if (_conversation.exists) unawaited(_markReadIfNeeded(_conversation));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkFriendship() async {
    final otherUid = _conversation.memberUids.firstWhere(
      (memberUid) => memberUid != widget.service.uid,
      orElse: () => '',
    );
    try {
      final allowed = await widget.service.isStillFriend(otherUid);
      if (mounted) setState(() => _dmAllowed = allowed);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'DM friendship check failed: uid=$otherUid; code=${error.code}; '
        'message=${error.message}\n$stackTrace',
      );
      if (mounted && error.code == 'permission-denied') {
        setState(() => _dmAllowed = false);
      }
    } catch (error, stackTrace) {
      debugPrint('DM friendship check failed: $error\n$stackTrace');
    }
  }

  Future<void> _markReadIfNeeded(ChatConversation conversation) async {
    if (_markingRead || !conversation.isUnreadFor(widget.service.uid)) return;
    _markingRead = true;
    try {
      await widget.service.markRead(conversation);
    } catch (error, stackTrace) {
      debugPrint('Chat read receipt write failed: $error\n$stackTrace');
    } finally {
      _markingRead = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_conversation.titleFor(widget.service.uid)),
          Text(
            _conversation.isGroup
                ? '${_conversation.memberUids.length} members'
                : 'Direct message',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: _onHeaderAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'mute',
              child: Text(_muted ? 'Unmute conversation' : 'Mute conversation'),
            ),
            if (_conversation.isGroup) ...[
              const PopupMenuItem(value: 'info', child: Text('Group info')),
              if (_conversation.creatorUid == widget.service.uid)
                const PopupMenuItem(value: 'add', child: Text('Add members')),
              const PopupMenuItem(value: 'block', child: Text('Block member')),
              const PopupMenuItem(value: 'leave', child: Text('Leave group')),
            ] else
              const PopupMenuItem(value: 'block', child: Text('Block user')),
          ],
        ),
      ],
    ),
    body: Column(
      children: [
        if (!_conversation.isGroup && !_dmAllowed)
          const MaterialBanner(
            content: Text("You can't message this person"),
            leading: Icon(Icons.person_off_outlined),
            actions: [SizedBox.shrink()],
          ),
        if (_error != null)
          MaterialBanner(
            content: Text(_error!),
            leading: const Icon(Icons.info_outline_rounded),
            actions: [
              TextButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        Expanded(
          child: !_conversation.exists
              ? const Center(child: Text('Send a message to start the chat.'))
              : StreamBuilder<ChatConversation?>(
                  stream: widget.service.watchConversation(_conversation.id),
                  builder: (context, conversationSnapshot) {
                    final liveConversation = conversationSnapshot.data;
                    if (liveConversation != null) {
                      _conversation = liveConversation;
                      unawaited(_markReadIfNeeded(_conversation));
                    }
                    return StreamBuilder<List<ChatMessage>>(
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          final firebaseError = snapshot.error;
                          if (firebaseError is FirebaseException) {
                            debugPrint(
                              'Chat messages stream failed '
                              '(${firebaseError.code}): '
                              '${firebaseError.message}\n${snapshot.stackTrace}',
                            );
                          }
                          return Center(
                            child: Text(
                              kDebugMode
                                  ? 'Could not load messages: ${snapshot.error}'
                                  : 'Messages are unavailable. '
                                        'Check your connection.',
                            ),
                          );
                        }
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final latest =                         snapshot.data ?? const <ChatMessage>[];
                        if (latest.length < 30) {
                          _hasOlder = false;
                          _olderExhausted = true;
                        } else if (!_olderExhausted) {
                          _hasOlder = true;
                        }
                        final knownIds = latest
                            .map((message) => message.id)
                            .toSet();
                        final messages = [
                          ..._olderMessages.where(
                            (message) => !knownIds.contains(message.id),
                          ),
                          ...latest,
                        ];
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_preserveScrollOnce) {
                            _preserveScrollOnce = false;
                            return;
                          }
                          if (mounted &&
                              !_loadingOlder &&
                              _scrollController.hasClients) {
                            _scrollToBottom();
                          }
                        });
                        return StreamBuilder<Map<String, String>>(
                          stream: widget.service.blockedUsers(),
                          builder: (context, blockedSnapshot) =>
                              _messageList(
                                messages,
                                latest,
                                blockedSnapshot.data ?? const {},
                              ),
                        );
                      },
                    );
                  },
                ),
        ),
        _composer(),
      ],
    ),
  );

  Widget _messageList(
    List<ChatMessage> messages,
    List<ChatMessage> latest,
    Map<String, String> blockedUsers,
  ) =>
      ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        itemCount: messages.length + (_hasOlder ? 1 : 0),
        itemBuilder: (context, index) {
          if (_hasOlder && index == 0) {
            return Center(
              child: TextButton(
                onPressed: _loadingOlder || latest.isEmpty
                    ? null
                    : () => _loadOlder(latest.first),
                child: _loadingOlder
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Load older messages'),
              ),
            );
          }
          final messageIndex = index - (_hasOlder ? 1 : 0);
          final message = messages[messageIndex];
          final previous = messageIndex > 0 ? messages[messageIndex - 1] : null;
          return Column(
            children: [
              if (_isNewDay(previous?.createdAt, message.createdAt))
                _dayDivider(message.createdAt),
              _bubble(
                message,
                blockedUsername: blockedUsers[message.senderUid],
              ),
            ],
          );
        },
      );

  Widget _dayDivider(DateTime? date) {
    final value = date?.toLocal() ?? DateTime.now();
    final label = _sameDay(value, DateTime.now())
        ? 'Today'
        : '${value.month}/${value.day}/${value.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage message, {String? blockedUsername}) {
    final mine = message.senderUid == widget.service.uid;
    final isBlocked = blockedUsername != null && !mine;
    final showBlockedMessage =
        !isBlocked || _revealedBlockedMessages.contains(message.id);
    final tokens = Theme.of(context).extension<ForgeTokens>();
    final time = message.createdAt?.toLocal();
    final timestamp = time == null
        ? 'Sending…'
        : '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: GestureDetector(
          onLongPress: () => _showMessageActions(
            message,
            isBlocked ? blockedUsername : null,
          ),
          child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
          decoration: BoxDecoration(
            color: mine
                ? (tokens?.accentTeal ?? Theme.of(context).colorScheme.primary)
                      .withValues(alpha: 0.2)
                : (tokens?.surfaceVariant ?? Theme.of(context).cardColor),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine && _conversation.isGroup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '@${message.senderName}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              if (isBlocked && !showBlockedMessage)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    const Text('Message from a blocked user'),
                    TextButton(
                      onPressed: () => setState(
                        () => _revealedBlockedMessages.add(message.id),
                      ),
                      child: const Text('Show'),
                    ),
                  ],
                )
              else
                Text(message.text),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  timestamp,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    final disabled = _sending || (!_conversation.isGroup && !_dmAllowed);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          children: [
            if (_sending)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('Sending…'),
                ),
              ),
            if (_failedText != null)
              Row(
                children: [
                  const Expanded(child: Text('Message failed to send.')),
                  TextButton.icon(
                    onPressed: _sending ? null : () => _send(_failedText!),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !disabled,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(22)),
                      ),
                    ),
                    onSubmitted: (_) => _send(_messageController.text),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: disabled
                      ? null
                      : () => _send(_messageController.text),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  tooltip: 'Send message',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _sending) return;
    if (text.length > 1000) {
      setState(() => _error = 'Messages can be up to 1000 characters.');
      return;
    }
    setState(() {
      _sending = true;
      _failedText = null;
      _error = null;
    });
    try {
      await widget.service.sendMessage(_conversation, text);
      _messageController.clear();
      if (mounted) {
        setState(() {
          _sending = false;
          _conversation = ChatConversation(
            id: _conversation.id,
            type: _conversation.type,
            memberUids: _conversation.memberUids,
            memberNames: _conversation.memberNames,
            creatorUid: _conversation.creatorUid,
            name: _conversation.name,
            lastMessage: text,
            lastSenderUid: widget.service.uid,
            lastMessageAt: DateTime.now(),
            lastRead: _conversation.lastRead,
            createdAt: _conversation.createdAt,
            exists: true,
          );
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } on ChatNotFriendException {
      if (mounted) {
        setState(() {
          _sending = false;
          _dmAllowed = false;
          _error = "You can't message this person";
        });
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Chat send UI failed: conversation=${_conversation.id}; '
        'code=${error.code}; message=${error.message}\n$stackTrace',
      );
      if (mounted) {
        setState(() {
          _sending = false;
          if (error.code == 'permission-denied' &&
              !_conversation.isGroup) {
            _dmAllowed = false;
            _failedText = null;
            _error = "You can't message this person";
          } else {
            _failedText = text;
            _error = kDebugMode
                ? 'Send failed (${error.code}): '
                      '${error.message ?? 'No details'}'
                : 'Could not send. Check your connection and retry.';
          }
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Chat send UI failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _sending = false;
          _failedText = text;
          _error = kDebugMode ? '$error' : 'Could not send. Please retry.';
        });
      }
    }
  }

  Future<void> _loadOlder(ChatMessage oldest) async {
    setState(() => _loadingOlder = true);
    try {
      final older = await widget.service.loadOlder(_conversation.id, oldest);
      if (mounted) {
        setState(() {
          _olderMessages = [...older, ..._olderMessages];
          _hasOlder = older.length == 30;
          _olderExhausted = older.length < 30;
          _preserveScrollOnce = true;
          _loadingOlder = false;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Loading older chat messages failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _loadingOlder = false;
          _error = kDebugMode
              ? 'Could not load older messages: $error'
              : 'Could not load older messages.';
        });
      }
    }
  }

  Future<void> _onHeaderAction(String action) async {
    switch (action) {
      case 'mute':
        final nextMuted = !_muted;
        try {
          await widget.service.setMuted(_conversation.id, nextMuted);
          if (mounted) {
            setState(() => _muted = nextMuted);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  nextMuted ? 'Conversation muted' : 'Conversation unmuted',
                ),
              ),
            );
          }
        } catch (error, stackTrace) {
          debugPrint('Updating chat mute setting failed: $error\n$stackTrace');
        }
        break;
      case 'info':
      case 'add':
      case 'leave':
        await _onGroupAction(action);
        break;
      case 'block':
        if (_conversation.isGroup) {
          await _chooseGroupMemberToBlock();
        } else {
          final otherUid = _conversation.memberUids.firstWhere(
            (memberUid) => memberUid != widget.service.uid,
            orElse: () => '',
          );
          if (otherUid.isNotEmpty) {
            await _confirmAndBlock(
              otherUid,
              _conversation.memberNames[otherUid] ?? 'friend',
            );
          }
        }
        break;
    }
  }

  Future<void> _showMessageActions(
    ChatMessage message,
    String? blockedUsername,
  ) async {
    final mine = message.senderUid == widget.service.uid;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report'),
                onTap: () => Navigator.pop(context, 'report'),
              ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: Text(
                  blockedUsername == null ? 'Block user' : 'Unblock user',
                ),
                onTap: () => Navigator.pop(context, 'block'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message copied')),
          );
        }
        break;
      case 'report':
        await _reportMessage(message);
        break;
      case 'delete':
        await _deleteMessage(message);
        break;
      case 'block':
        if (blockedUsername == null) {
          await _confirmAndBlock(message.senderUid, message.senderName);
        } else {
          await _confirmAndUnblock(message.senderUid, blockedUsername);
        }
        break;
    }
  }

  Future<void> _reportMessage(ChatMessage message) async {
    const reasons = [
      'Spam',
      'Harassment',
      'Inappropriate content',
      'Other',
    ];
    final noteController = TextEditingController();
    var reason = reasons.first;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Report message', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: [
                    for (final value in reasons)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) {
                    if (value != null) setSheetState(() => reason = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLength: 300,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Submit report'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (submitted != true || !mounted) {
      noteController.dispose();
      return;
    }
    try {
      await widget.service.reportMessage(
        reportedUid: message.senderUid,
        conversationId: _conversation.id,
        messageId: message.id,
        messageText: message.text,
        reason: reason,
        note: noteController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Reporting chat message failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit report. Try again.')),
        );
      }
    } finally {
      noteController.dispose();
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      await widget.service.deleteOwnMessage(_conversation, message);
    } catch (error, stackTrace) {
      debugPrint('Deleting chat message failed: $error\n$stackTrace');
      if (mounted) {
        setState(
          () => _error = kDebugMode ? '$error' : 'Could not delete message.',
        );
      }
    }
  }

  Future<void> _chooseGroupMemberToBlock() async {
    final candidates = _conversation.memberUids
        .where((memberUid) => memberUid != widget.service.uid)
        .toList(growable: false);
    final selectedUid = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Block a group member'),
        children: [
          for (final uid in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, uid),
              child: Text('@${_conversation.memberNames[uid] ?? 'friend'}'),
            ),
        ],
      ),
    );
    if (selectedUid != null && mounted) {
      await _confirmAndBlock(
        selectedUid,
        _conversation.memberNames[selectedUid] ?? 'friend',
      );
    }
  }

  Future<void> _confirmAndBlock(String otherUid, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block this person?'),
        content: const Text(
          'They will be removed from your friends, their direct chat will be '
          'hidden, and you will not receive their friend requests. In shared '
          'groups, their messages will be hidden unless you choose to show them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.service.blockUser(
        otherUid: otherUid,
        otherUsername: username,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Blocking chat user failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _error = kDebugMode ? '$error' : 'Could not block user.');
      }
    }
  }

  Future<void> _confirmAndUnblock(String otherUid, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock this person?'),
        content: Text('Show messages from @$username again?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.service.unblockUser(otherUid);
      if (mounted) setState(() => _revealedBlockedMessages.clear());
    } catch (error, stackTrace) {
      debugPrint('Unblocking chat user failed: $error\n$stackTrace');
    }
  }

  Future<void> _onGroupAction(String action) async {
    switch (action) {
      case 'info':
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_conversation.name ?? 'Group members'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final uid in _conversation.memberUids)
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline_rounded),
                      ),
                      title: Text(
                        '@${_conversation.memberNames[uid] ?? 'friend'}',
                      ),
                      subtitle: uid == _conversation.creatorUid
                          ? const Text('Creator')
                          : null,
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      case 'add':
        await _addMembers();
      case 'leave':
        await _leaveGroup();
    }
  }

  Future<void> _addMembers() async {
    try {
      final friends = await FriendsService(uid: widget.service.uid)
          .friends()
          .first;
      final candidates = friends
          .where((friend) => !_conversation.memberUids.contains(friend.uid))
          .toList();
      if (!mounted) return;
      final selected = <String>{};
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add members'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final friend in candidates)
                    CheckboxListTile(
                      value: selected.contains(friend.uid),
                      title: Text(friend.displayName),
                      subtitle: Text('@${friend.username}'),
                      onChanged: (value) => setDialogState(() {
                        if (value == true) {
                          selected.add(friend.uid);
                        } else {
                          selected.remove(friend.uid);
                        }
                      }),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      final additions = candidates
          .where((friend) => selected.contains(friend.uid))
          .toList(growable: false);
      await widget.service.addMembers(_conversation, additions);
    } catch (error, stackTrace) {
      debugPrint('Adding chat members failed: $error\n$stackTrace');
      if (mounted) {
        setState(
          () => _error = kDebugMode ? '$error' : 'Could not add members.',
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text(
          'You will no longer receive messages in this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.service.leaveGroup(_conversation);
      if (mounted) Navigator.pop(context);
    } catch (error, stackTrace) {
      debugPrint('Leaving group failed: $error\n$stackTrace');
      if (mounted) {
        setState(
          () => _error = kDebugMode ? '$error' : 'Could not leave group.',
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  static bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static bool _isNewDay(DateTime? previous, DateTime? current) =>
      current != null &&
      (previous == null || !_sameDay(previous.toLocal(), current.toLocal()));
}
