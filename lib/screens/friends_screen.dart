import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'friend_profile_screen.dart';
import 'blocked_users_screen.dart';
import 'chat_screen.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/friends_service.dart';
import '../services/profile_service.dart';
import 'challenges_screen.dart';
import 'sharing_settings_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({required this.displayName, super.key});

  final String displayName;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

typedef FriendsHomeScreen = FriendsScreen;

class _FriendsScreenState extends State<FriendsScreen> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  late final TextEditingController _usernameController;
  late final TextEditingController _friendCodeController;
  Timer? _availabilityTimer;
  String? _uid;
  FriendsService? _friendsService;
  ChatService? _chatService;
  UserProfile? _profile;
  String? _errorMessage;
  String? _availabilityMessage;
  String? _friendCodeMessage;
  String? _requestActionMessage;
  bool _loading = true;
  bool _saving = false;
  bool _sendingRequest = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: ProfileService.usernameSuggestionFromDisplayName(
        widget.displayName,
      ),
    );
    _friendCodeController = TextEditingController();
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _availabilityTimer?.cancel();
    _usernameController.dispose();
    _friendCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final uid = await _authService.signInAnonymouslyIfNeeded();
      final profile = await _profileService.getProfile(uid);
      if (!mounted) return;
      setState(() {
        _uid = uid;
        _friendsService = FriendsService(uid: uid);
        _chatService = profile == null
            ? null
            : ChatService(uid: uid, username: profile.username);
        _profile = profile;
        _loading = false;
      });
    } on FirebaseException catch (error, stackTrace) {
      _reportError(_firebaseErrorMessage(error));
      debugPrint('Friends profile load failed (${error.code}): $stackTrace');
    } catch (error, stackTrace) {
      _reportError('Friends are offline. Check your internet connection.');
      debugPrint('Friends profile load failed: $error\n$stackTrace');
    }
  }

  void _reportError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _loading = false;
      _saving = false;
    });
  }

  String _firebaseErrorMessage(FirebaseException error) => switch (error.code) {
    'operation-not-allowed' =>
      'Anonymous sign-in is not enabled for this Firebase project.',
    'permission-denied' =>
      'Friends access is blocked. Check the Firestore security rules.',
    'firebase-not-initialized' ||
    'unavailable' ||
    'network-request-failed' ||
    'deadline-exceeded' =>
      'Friends are offline. Check your internet connection.',
    _ => 'Friends are unavailable right now. Please try again.',
  };

  Widget _streamError(Object error, StackTrace? stackTrace) {
    if (error is FirebaseException) {
      debugPrint(
        'Friends stream failed (${error.code}): '
        '${error.message}\n${stackTrace ?? StackTrace.current}',
      );
      if (error.code == 'unavailable') {
        return const _SectionOffline();
      }
      if (kDebugMode) {
        return _SectionEmpty(
          'Couldn’t load this section (${error.code}): '
          '${error.message ?? 'No additional details.'}',
        );
      }
      return const _SectionEmpty(
        'Couldn’t load this section. Please try again.',
      );
    }

    debugPrint(
      'Friends stream failed: $error\n${stackTrace ?? StackTrace.current}',
    );
    if (kDebugMode) {
      return _SectionEmpty('Couldn’t load this section: $error');
    }
    return const _SectionEmpty('Couldn’t load this section. Please try again.');
  }

  void _onUsernameChanged(String value) {
    final normalized = value.toLowerCase();
    if (normalized != value) {
      _usernameController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    _availabilityTimer?.cancel();
    setState(() {
      _availabilityMessage = ProfileService.isValidUsername(normalized)
          ? 'Checking availability…'
          : 'Use 3–16 lowercase letters, numbers, or underscores.';
    });
    if (!ProfileService.isValidUsername(normalized) || _uid == null) return;
    _availabilityTimer = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_checkAvailability(normalized)),
    );
  }

  Future<void> _checkAvailability(String username) async {
    try {
      final available = await _profileService.isUsernameAvailable(
        _uid!,
        username,
      );
      if (!mounted || _usernameController.text != username) return;
      setState(() {
        _availabilityMessage = available
            ? 'Username is available.'
            : 'That username is already taken.';
      });
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Username availability check failed (${error.code}): $stackTrace',
      );
      if (!mounted || _usernameController.text != username) return;
      setState(() {
        _availabilityMessage = _firebaseErrorMessage(error);
      });
    } catch (error, stackTrace) {
      debugPrint('Username availability check failed: $error\n$stackTrace');
      if (!mounted || _usernameController.text != username) return;
      setState(() {
        _availabilityMessage =
            'Can’t check right now. Check your connection and try again.';
      });
    }
  }

  Future<void> _createProfile() async {
    final uid = _uid;
    final username = _usernameController.text.trim();
    if (uid == null || !ProfileService.isValidUsername(username)) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      if (!await _profileService.isUsernameAvailable(uid, username)) {
        if (mounted) {
          setState(() {
            _saving = false;
            _availabilityMessage = 'That username is already taken.';
          });
        }
        return;
      }
      final profile = await _profileService.createProfile(
        uid: uid,
        username: username,
        displayName: widget.displayName,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _saving = false;
      });
    } on UsernameTakenException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _availabilityMessage = 'That username is already taken.';
      });
    } on ProfileAlreadyExistsException {
      await _loadProfile();
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Friends profile creation failed (${error.code}): $stackTrace',
      );
      _reportError(_firebaseErrorMessage(error));
    } catch (error, stackTrace) {
      debugPrint('Friends profile creation failed: $error\n$stackTrace');
      _reportError('Couldn’t save your profile. Please try again.');
    }
  }

  Future<void> _copyFriendCode(String friendCode) async {
    await Clipboard.setData(ClipboardData(text: friendCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Friend code copied')));
  }

  Future<void> _shareFriendCode(UserProfile profile) async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Add me on Forge! My friend code is ${profile.friendCode}.',
      ),
    );
  }

  Future<void> _sendFriendRequest() async {
    final service = _friendsService;
    if (service == null) return;
    setState(() {
      _sendingRequest = true;
      _friendCodeMessage = null;
    });
    try {
      final message = await service.sendRequestByCode(
        _friendCodeController.text,
      );
      if (!mounted) return;
      setState(() {
        _friendCodeController.clear();
        _friendCodeMessage = message;
        _sendingRequest = false;
      });
    } on FriendServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _friendCodeMessage = error.message;
        _sendingRequest = false;
      });
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Friend request send failed (${error.code}): '
        '${error.message}\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _friendCodeMessage = _firebaseErrorMessage(error);
        _sendingRequest = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Friend request send failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _friendCodeMessage =
            'Couldn’t send the request. Check your connection and try again.';
        _sendingRequest = false;
      });
    }
  }

  Future<void> _performRequestAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _requestActionMessage = null);
    try {
      await action();
      if (!mounted) return;
      setState(() => _requestActionMessage = successMessage);
    } on FriendServiceException catch (error) {
      if (!mounted) return;
      setState(() => _requestActionMessage = error.message);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Friend request action failed (${error.code}): '
        '${error.message}\n$stackTrace',
      );
      if (!mounted) return;
      setState(() => _requestActionMessage = _firebaseErrorMessage(error));
    } catch (error, stackTrace) {
      debugPrint('Friend request action failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _requestActionMessage =
            'Couldn’t update the request. Check your connection and try again.';
      });
    }
  }

  Future<void> _removeFriend(FriendSummary friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text('Remove ${friend.displayName} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _performRequestAction(
      () => _friendsService!.removeFriend(friend.uid),
      'Friend removed.',
    );
  }

  Future<void> _openNewChat() async {
    final friendsService = _friendsService;
    final chatService = _chatService;
    if (friendsService == null || chatService == null) return;
    try {
      final friends = await friendsService.friends().first;
      if (!mounted) return;
      if (friends.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add friends before starting a chat.')),
        );
        return;
      }
      final conversation = await showModalBottomSheet<ChatConversation>(
        context: context,
        isScrollControlled: true,
        builder: (_) => NewChatSheet(service: chatService, friends: friends),
      );
      if (conversation != null && mounted) _openChat(conversation);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Opening new chat failed (${error.code}): ${error.message}\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.code == 'unavailable'
                  ? 'Chats are offline right now.'
                  : kDebugMode
                  ? 'Could not load friends (${error.code}).'
                  : 'Could not load friends.',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Opening new chat failed: $error\n$stackTrace');
    }
  }

  void _openChat(ChatConversation conversation) {
    final service = _chatService;
    if (service == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/chat', arguments: conversation.id),
        builder: (_) =>
            ChatScreen(service: service, conversation: conversation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          bottom: _profile != null
              ? TabBar(
                  isScrollable: true,
                  tabs: [
                    const Tab(text: 'Friends'),
                    Tab(
                      child: StreamBuilder<int>(
                        stream: _chatService?.unreadCount(),
                        builder: (context, snapshot) =>
                            _tabWithBadge('Chats', snapshot.data ?? 0),
                      ),
                    ),
                    const Tab(text: 'Requests'),
                    Tab(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('challengeInvites')
                            .where('toUid', isEqualTo: _uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.docs.length ?? 0;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Challenges'),
                              if (count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE64A53),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                )
              : null,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _offlineState()
              : _profile != null
              ? _profileShell(_profile!)
              : _usernameForm(),
        ),
      ),
    );
  }

  Widget _offlineState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 44),
          const SizedBox(height: 12),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _usernameForm() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Find your people',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text('Choose a username to create your Forge friends profile.'),
      const SizedBox(height: 24),
      TextField(
        controller: _usernameController,
        maxLength: 16,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
        ],
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Username',
          prefixText: '@',
        ),
        onChanged: _onUsernameChanged,
        onSubmitted: (_) => _createProfile(),
      ),
      if (_availabilityMessage != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_availabilityMessage!),
        ),
      if (_errorMessage != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      FilledButton(
        onPressed:
            _saving || !ProfileService.isValidUsername(_usernameController.text)
            ? null
            : _createProfile,
        child: _saving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Create profile'),
      ),
    ],
  );

  Widget _profileShell(UserProfile profile) {
    final uid = _uid;
    final friendsService = _friendsService;
    if (uid == null || friendsService == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _profileHeader(profile),
        Expanded(
          child: TabBarView(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 112),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.block_rounded),
                    title: const Text('Blocked users'),
                    subtitle: const Text('Manage people you have blocked'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _chatService == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              settings: const RouteSettings(
                                name: '/friends/blocked',
                              ),
                              builder: (_) =>
                                  BlockedUsersScreen(service: _chatService!),
                            ),
                          ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.ios_share_rounded),
                    title: const Text('Sharing'),
                    subtitle: const Text('Choose what your friends can see'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(
                          name: '/friends/sharing',
                        ),
                        builder: (_) => const SharingSettingsScreen(),
                      ),
                    ),
                  ),
                  _addFriendSection(),
                  const SizedBox(height: 24),
                  _friendsSection(),
                ],
              ),
              _chatsSection(),
              ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 112),
                children: [_requestsSection()],
              ),
              ChallengesTab(
                uid: uid,
                username: profile.username,
                friendsService: friendsService,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabWithBadge(String label, int count) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label),
      if (count > 0) ...[
        const SizedBox(width: 6),
        Container(
          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFE64A53),
            shape: BoxShape.circle,
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ],
  );

  Widget _chatsSection() {
    final service = _chatService;
    if (service == null) return const SizedBox.shrink();
    return StreamBuilder<List<ChatConversation>>(
      stream: service.conversations(),
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? const <ChatConversation>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 112),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _openNewChat,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('New chat'),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)
              const _SectionLoading()
            else if (snapshot.hasError)
              _streamError(snapshot.error!, snapshot.stackTrace)
            else if (conversations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Icon(Icons.forum_outlined, size: 48),
                    const SizedBox(height: 12),
                    const Text('Your conversations will appear here.'),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _openNewChat,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New chat'),
                    ),
                  ],
                ),
              )
            else
              for (final conversation in conversations)
                Card(
                  child: ListTile(
                    leading: conversation.isGroup
                        ? const CircleAvatar(child: Icon(Icons.group_rounded))
                        : CircleAvatar(
                            child: Text(
                              conversation
                                  .titleFor(service.uid)
                                  .replaceFirst('@', '')
                                  .characters
                                  .first
                                  .toUpperCase(),
                            ),
                          ),
                    title: Text(conversation.titleFor(service.uid)),
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
                          _chatTime(
                            conversation.lastMessageAt ??
                                conversation.createdAt,
                          ),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        if (conversation.isUnreadFor(service.uid))
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: Color(0xFFE64A53),
                            ),
                          ),
                      ],
                    ),
                    onTap: () => _openChat(conversation),
                  ),
                ),
          ],
        );
      },
    );
  }

  String _chatTime(DateTime? date) {
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

  Widget _profileHeader(UserProfile profile) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your friends profile',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('@${profile.username}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    profile.friendCode,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      letterSpacing: 4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy friend code',
                  onPressed: () => _copyFriendCode(profile.friendCode),
                  icon: const Icon(Icons.copy_rounded),
                ),
                IconButton(
                  tooltip: 'Share friend code',
                  onPressed: () => _shareFriendCode(profile),
                  icon: const Icon(Icons.share_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _sectionTitle(String title, {int? badgeCount}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      if (badgeCount != null && badgeCount > 0)
        CircleAvatar(
          radius: 13,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: Text(
            '$badgeCount',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
    ],
  );

  Widget _addFriendSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Add friend'),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _friendCodeController,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                UpperCaseTextFormatter(),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Friend code',
                counterText: '',
              ),
              onChanged: (_) => setState(() => _friendCodeMessage = null),
              onSubmitted: (_) => _sendFriendRequest(),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed:
                _sendingRequest || _friendCodeController.text.trim().length != 6
                ? null
                : _sendFriendRequest,
            child: _sendingRequest
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
        ],
      ),
      if (_friendCodeMessage != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_friendCodeMessage!),
        ),
    ],
  );

  Widget _requestsSection() {
    final service = _friendsService!;
    return StreamBuilder<List<FriendRequest>>(
      stream: service.incomingRequests(),
      builder: (context, incomingSnapshot) {
        final incoming = incomingSnapshot.data ?? const <FriendRequest>[];
        return StreamBuilder<List<FriendRequest>>(
          stream: service.outgoingRequests(),
          builder: (context, outgoingSnapshot) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Requests', badgeCount: incoming.length),
              if (_requestActionMessage != null) ...[
                const SizedBox(height: 8),
                Text(_requestActionMessage!),
              ],
              if (incomingSnapshot.connectionState == ConnectionState.waiting &&
                  !incomingSnapshot.hasData)
                const _SectionLoading()
              else if (incomingSnapshot.hasError)
                _streamError(
                  incomingSnapshot.error!,
                  incomingSnapshot.stackTrace,
                )
              else if (incoming.isEmpty)
                const _SectionEmpty('No incoming requests.')
              else
                for (final request in incoming) _incomingRequestTile(request),
              const SizedBox(height: 8),
              if (outgoingSnapshot.connectionState == ConnectionState.waiting &&
                  !outgoingSnapshot.hasData)
                const _SectionLoading()
              else if (outgoingSnapshot.hasError)
                _streamError(
                  outgoingSnapshot.error!,
                  outgoingSnapshot.stackTrace,
                )
              else if ((outgoingSnapshot.data ?? const []).isEmpty)
                const _SectionEmpty('No outgoing requests.')
              else
                for (final request
                    in outgoingSnapshot.data ?? const <FriendRequest>[])
                  _outgoingRequestTile(request),
            ],
          ),
        );
      },
    );
  }

  Widget _incomingRequestTile(FriendRequest request) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.fromDisplayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('@${request.fromUsername}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => _performRequestAction(
                  () => _friendsService!.acceptRequest(request),
                  'Friend request accepted.',
                ),
                child: const Text('Accept'),
              ),
              OutlinedButton(
                onPressed: () => _performRequestAction(
                  () => _friendsService!.declineRequest(request),
                  'Request declined.',
                ),
                child: const Text('Decline'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _outgoingRequestTile(FriendRequest request) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    title: Text(request.counterpartyDisplayName ?? 'Friend'),
    subtitle: Text('@${request.counterpartyUsername ?? 'friend'} · Pending'),
    trailing: TextButton(
      onPressed: () => _performRequestAction(
        () => _friendsService!.cancelRequest(request),
        'Request cancelled.',
      ),
      child: const Text('Cancel'),
    ),
  );

  Widget _friendsSection() => StreamBuilder<List<FriendSummary>>(
    stream: _friendsService!.friends(),
    builder: (context, snapshot) {
      final friends = snapshot.data ?? const <FriendSummary>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Friends'),
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData)
            const _SectionLoading()
          else if (snapshot.hasError)
            _streamError(snapshot.error!, snapshot.stackTrace)
          else if (friends.isEmpty)
            const _SectionEmpty('Your friends will appear here.')
          else
            for (final friend in friends) _friendTile(friend),
        ],
      );
    },
  );

  Widget _friendTile(FriendSummary friend) => Card(
    child: ListTile(
      leading: CircleAvatar(
        child: Text(
          friend.displayName.isEmpty
              ? '?'
              : friend.displayName.characters.first.toUpperCase(),
        ),
      ),
      title: Text(friend.displayName),
      subtitle: Text('@${friend.username}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/friends/profile'),
          builder: (_) => FriendProfileScreen(friend: friend),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Message',
            onPressed: () {
              final profile = _profile;
              if (profile != null) {
                _openChat(
                  ChatConversation.directMessage(
                    currentUid: _uid!,
                    currentUsername: profile.username,
                    friend: friend,
                  ),
                );
              }
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'remove') _removeFriend(friend);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'remove', child: Text('Remove friend')),
            ],
          ),
        ],
      ),
    ),
  );
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _SectionOffline extends StatelessWidget {
  const _SectionOffline();

  @override
  Widget build(BuildContext context) => const _SectionEmpty(
    'Can’t load this section while offline. It will retry when connected.',
  );
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).hintColor),
    ),
  );
}
