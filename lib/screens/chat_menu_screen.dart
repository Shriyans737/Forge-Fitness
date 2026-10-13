import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../services/friends_service.dart';
import 'chat_screen.dart';

enum _ConversationFilter { all, friends, groups }

class ChatMenuScreen extends StatefulWidget {
  const ChatMenuScreen({required this.service, super.key});

  final ChatService service;

  @override
  State<ChatMenuScreen> createState() => _ChatMenuScreenState();
}

class _ChatMenuScreenState extends State<ChatMenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  _ConversationFilter _filter = _ConversationFilter.all;
  bool _openingNewChat = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Chats'),
      actions: [
        IconButton(
          tooltip: 'New chat',
          onPressed: _openingNewChat ? null : _startNewChat,
          icon: const Icon(Icons.add_comment_outlined),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search chats',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                _filterChip('All', _ConversationFilter.all),
                _filterChip('Friends', _ConversationFilter.friends),
                _filterChip('Groups', _ConversationFilter.groups),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ChatConversation>>(
            stream: widget.service.conversations(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                debugPrint('Loading chat menu failed: $error');
                return Center(
                  child: Text(
                    kDebugMode
                        ? 'Chats unavailable: $error'
                        : 'Chats are unavailable right now.',
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final query = _searchController.text.trim().toLowerCase();
              final conversations = (snapshot.data ?? const <ChatConversation>[])
                  .where((conversation) {
                    if (_filter == _ConversationFilter.friends &&
                        conversation.isGroup) {
                      return false;
                    }
                    if (_filter == _ConversationFilter.groups &&
                        !conversation.isGroup) {
                      return false;
                    }
                    if (query.isEmpty) return true;
                    return conversation
                            .titleFor(widget.service.uid)
                            .toLowerCase()
                            .contains(query) ||
                        (conversation.lastMessage ?? '')
                            .toLowerCase()
                            .contains(query);
                  })
                  .toList(growable: false);
              if (conversations.isEmpty) {
                return _emptyState(
                  hasConversations: (snapshot.data ?? const []).isNotEmpty,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                itemCount: conversations.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  final unread =
                      conversation.isUnreadFor(widget.service.uid);
                  return ListTile(
                    onTap: () => _openConversation(conversation),
                    leading: CircleAvatar(
                      child: conversation.isGroup
                          ? const Icon(Icons.groups_rounded)
                          : Text(_initial(conversation.titleFor(widget.service.uid))),
                    ),
                    title: Text(
                      conversation.titleFor(widget.service.uid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      conversation.lastMessage?.isNotEmpty == true
                          ? conversation.lastMessage!
                          : 'Start a conversation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(
                            conversation.lastMessageAt ?? conversation.createdAt,
                          ),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        if (unread) ...[
                          const SizedBox(height: 5),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 19,
                              minHeight: 19,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE64A53),
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _openingNewChat ? null : _startNewChat,
      tooltip: 'Start a new chat',
      child: _openingNewChat
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.edit_rounded),
    ),
  );

  Widget _filterChip(String label, _ConversationFilter value) =>
      ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      );

  Widget _emptyState({required bool hasConversations}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasConversations ? Icons.search_off_rounded : Icons.forum_outlined,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            hasConversations ? 'No matching chats' : 'No chats yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!hasConversations) ...[
            const SizedBox(height: 6),
            const Text('Start a conversation with a friend.'),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _openingNewChat ? null : _startNewChat,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Start a chat'),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _startNewChat() async {
    if (_openingNewChat) return;
    setState(() => _openingNewChat = true);
    try {
      final friends = await FriendsService(
        uid: widget.service.uid,
      ).friends().first;
      if (!mounted) return;
      final conversation = await showModalBottomSheet<ChatConversation>(
        context: context,
        isScrollControlled: true,
        builder: (_) => NewChatSheet(
          service: widget.service,
          friends: friends,
        ),
      );
      if (conversation != null && mounted) {
        _openConversation(conversation);
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Starting chat from menu failed (${error.code}): '
        '${error.message}\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.code == 'unavailable'
                  ? 'Chats are offline right now.'
                  : 'Could not load friends (${error.code}).',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Starting chat from menu failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start a chat.')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingNewChat = false);
    }
  }

  void _openConversation(ChatConversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: '/chat',
          arguments: conversation.id,
        ),
        builder: (_) => ChatScreen(
          service: widget.service,
          conversation: conversation,
        ),
      ),
    );
  }

  static String _initial(String name) =>
      name.replaceFirst('@', '').characters.firstOrNull?.toUpperCase() ?? '?';

  static String _formatTime(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.month}/${local.day}';
  }
}
