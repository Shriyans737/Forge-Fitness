import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/motion.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme.dart';
import 'chat_menu_screen.dart';
import 'chat_screen.dart';

const String chatMenuRouteName = '/chat-menu';
const String chatRouteName = '/chat';
const String showChatButtonSetting = 'showChatButton';
const String chatButtonPositionSetting = 'floatingChatButtonPosition';

final ValueNotifier<bool> forgeMainShellVisible = ValueNotifier(false);
final ValueNotifier<bool> forgeMainShellDelayComplete = ValueNotifier(false);
int _mountedMainShellCount = 0;
bool _mainShellDelayCompletedThisLaunch = false;
Timer? _mainShellVisibilityTimer;

void registerForgeMainShell() {
  _mountedMainShellCount++;
  if (!forgeMainShellVisible.value) forgeMainShellVisible.value = true;
  if (!_mainShellDelayCompletedThisLaunch &&
      _mainShellVisibilityTimer == null) {
    _mainShellVisibilityTimer = Timer(const Duration(milliseconds: 1500), () {
      _mainShellVisibilityTimer = null;
      if (_mountedMainShellCount == 0) return;
      _mainShellDelayCompletedThisLaunch = true;
      forgeMainShellDelayComplete.value = true;
    });
  }
}

void unregisterForgeMainShell() {
  if (_mountedMainShellCount > 0) _mountedMainShellCount--;
  final visible = _mountedMainShellCount > 0;
  if (forgeMainShellVisible.value != visible) {
    forgeMainShellVisible.value = visible;
  }
  if (!visible && !_mainShellDelayCompletedThisLaunch) {
    _mainShellVisibilityTimer?.cancel();
    _mainShellVisibilityTimer = null;
    forgeMainShellDelayComplete.value = false;
  }
}

class ForgeRouteObserver extends NavigatorObserver {
  final ValueNotifier<Route<dynamic>?> currentRoute = ValueNotifier(null);
  final List<Route<dynamic>> _routes = [];

  bool get chatUiIsShowing =>
      _routes.isNotEmpty &&
      (_routes.last.settings.name == chatMenuRouteName ||
          _routes.last.settings.name == chatRouteName);

  String? get viewedChatId {
    for (final route in _routes.reversed) {
      if (route.settings.name == chatMenuRouteName) return null;
      if (route.settings.name == chatRouteName) {
        final id = route.settings.arguments;
        return id is String ? id : null;
      }
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _routes.add(route);
    currentRoute.value = route;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    currentRoute.value = _routes.isEmpty ? previousRoute : _routes.last;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    currentRoute.value = _routes.isEmpty ? previousRoute : _routes.last;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _routes.remove(oldRoute);
    if (newRoute != null) _routes.add(newRoute);
    currentRoute.value = _routes.lastOrNull;
  }
}

class FloatingChatOverlay extends StatefulWidget {
  const FloatingChatOverlay({
    required this.navigatorKey,
    required this.routeObserver,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final ForgeRouteObserver routeObserver;

  @override
  State<FloatingChatOverlay> createState() => _FloatingChatOverlayState();
}

class _FloatingChatOverlayState extends State<FloatingChatOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _buttonFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final AnimationController _buttonScale = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.65,
        end: 1.08,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 65,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.08,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
  ]).animate(_buttonScale);

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;
  StreamSubscription<List<ChatConversation>>? _conversationSubscription;
  StreamSubscription<Map<String, String>>? _blockedSubscription;
  late final ValueListenable<Route<dynamic>?> _routeListenable =
      widget.routeObserver.currentRoute;
  ChatService? _chatService;
  String? _uid;
  String? _username;
  List<ChatConversation> _conversations = const [];
  Map<String, String> _blockedUsers = const {};
  Map<String, DateTime> _lastMessageTimes = {};
  final List<ChatConversation> _pendingBanners = [];
  ChatConversation? _bannerConversation;
  int _bannerBurstCount = 1;
  Timer? _bannerDebounce;
  Timer? _bannerDismiss;
  Offset? _buttonTopLeft;
  bool _conversationStreamInitialized = false;
  bool _blockedStreamInitialized = false;
  bool _bannerVisible = false;
  bool _appIsForeground = true;
  String? _lastHideReason;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    forgeMainShellVisible.addListener(_onShellVisibilityChanged);
    forgeMainShellDelayComplete.addListener(_onShellVisibilityChanged);
    _onShellVisibilityChanged();
    if (AuthService.isFirebaseInitialized) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        _onAuthChanged,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Floating chat auth stream failed: $error\n$stackTrace');
        },
      );
    }
    _buttonScale.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    forgeMainShellVisible.removeListener(_onShellVisibilityChanged);
    forgeMainShellDelayComplete.removeListener(_onShellVisibilityChanged);
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _conversationSubscription?.cancel();
    _blockedSubscription?.cancel();
    _bannerDebounce?.cancel();
    _bannerDismiss?.cancel();
    _buttonFade.dispose();
    _buttonScale.dispose();
    super.dispose();
  }

  void _onShellVisibilityChanged() {
    if (!forgeMainShellVisible.value || !forgeMainShellDelayComplete.value) {
      _buttonFade
        ..stop()
        ..value = 0;
      _buttonScale
        ..stop()
        ..value = 0;
      _lastHideReason = null;
      if (mounted) setState(() {});
      return;
    }
    if (_buttonFade.value >= 1) return;
    if (mounted) setState(() {});
    _buttonFade.forward(from: 0);
    _buttonScale.forward(from: 0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsForeground = state == AppLifecycleState.resumed;
  }

  void _onAuthChanged(User? user) {
    final nextUid = user?.uid;
    if (_uid == nextUid) return;
    _profileSubscription?.cancel();
    _clearChatBinding();
    _uid = nextUid;
    _username = null;
    if (nextUid == null) {
      if (mounted) setState(() {});
      return;
    }
    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(nextUid)
        .snapshots()
        .listen(
          (snapshot) {
            final value = snapshot.data()?['username'];
            final nextUsername = value is String && value.trim().isNotEmpty
                ? value.trim()
                : null;
            if (_username == nextUsername) return;
            _username = nextUsername;
            _bindChatService();
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              'Floating chat profile stream failed: $error\n$stackTrace',
            );
            _clearChatBinding();
            if (mounted) setState(() {});
          },
        );
  }

  void _bindChatService() {
    _conversationSubscription?.cancel();
    _blockedSubscription?.cancel();
    _chatService = null;
    _conversations = const [];
    _blockedUsers = const {};
    _lastMessageTimes = {};
    _conversationStreamInitialized = false;
    _blockedStreamInitialized = false;
    final uid = _uid;
    final username = _username;
    if (uid == null || username == null) {
      if (mounted) setState(() {});
      return;
    }
    final service = ChatService(uid: uid, username: username);
    _chatService = service;
    _conversationSubscription = service.conversations().listen(
      _onConversationsChanged,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'Floating chat conversation stream failed: $error\n$stackTrace',
        );
      },
    );
    _blockedSubscription = service.blockedUsers().listen(
      (blocked) {
        _blockedUsers = blocked;
        _blockedStreamInitialized = true;
        if (mounted) setState(() {});
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Floating chat block stream failed: $error\n$stackTrace');
      },
    );
    if (mounted) setState(() {});
  }

  void _clearChatBinding() {
    _conversationSubscription?.cancel();
    _blockedSubscription?.cancel();
    _bannerDebounce?.cancel();
    _bannerDismiss?.cancel();
    _conversationSubscription = null;
    _blockedSubscription = null;
    _chatService = null;
    _conversations = const [];
    _blockedUsers = const {};
    _lastMessageTimes = {};
    _conversationStreamInitialized = false;
    _blockedStreamInitialized = false;
    _pendingBanners.clear();
    _bannerConversation = null;
    _bannerBurstCount = 1;
    _bannerVisible = false;
  }

  void _onConversationsChanged(List<ChatConversation> conversations) {
    final firstSnapshot = !_conversationStreamInitialized;
    final currentChatId = _currentlyViewedChatId;
    if (!firstSnapshot && _blockedStreamInitialized && _appIsForeground) {
      for (final conversation in conversations) {
        final timestamp = conversation.lastMessageAt;
        if (timestamp == null) continue;
        final previousTimestamp = _lastMessageTimes[conversation.id];
        if (previousTimestamp == null ||
            !timestamp.isAfter(previousTimestamp) ||
            conversation.lastSenderUid == _uid ||
            _chatService?.isMuted(conversation.id) == true ||
            currentChatId == conversation.id ||
            _isSenderBlocked(conversation)) {
          continue;
        }
        _pendingBanners.add(conversation);
      }
      if (_pendingBanners.isNotEmpty) {
        _bannerDebounce?.cancel();
        _bannerDebounce = Timer(
          const Duration(milliseconds: 300),
          _showPendingBanner,
        );
      }
    }
    _lastMessageTimes = {
      for (final conversation in conversations)
        if (conversation.lastMessageAt != null)
          conversation.id: conversation.lastMessageAt!,
    };
    _conversationStreamInitialized = true;
    _conversations = conversations;
    if (mounted) setState(() {});
  }

  bool _isSenderBlocked(ChatConversation conversation) {
    final sender = conversation.lastSenderUid;
    return conversation.isGroup &&
        sender != null &&
        _blockedUsers.containsKey(sender);
  }

  String? get _currentlyViewedChatId {
    return widget.routeObserver.viewedChatId;
  }

  void _showPendingBanner() {
    if (!mounted || _pendingBanners.isEmpty) return;
    final burstCount = _pendingBanners.length;
    setState(() {
      _bannerConversation = _pendingBanners.last;
      _bannerBurstCount = burstCount;
      _pendingBanners.clear();
      _bannerVisible = true;
    });
    _buttonScale
      ..stop()
      ..forward(from: 0);
    _bannerDismiss?.cancel();
    _bannerDismiss = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _bannerVisible = false);
    });
  }

  bool get _isChatRoute {
    return widget.routeObserver.chatUiIsShowing;
  }

  bool get _showButtonPreference {
    if (!Hive.isBoxOpen('settings')) return true;
    return Hive.box<dynamic>('settings').get(showChatButtonSetting) == false
        ? false
        : true;
  }

  void _openChatMenu() {
    final service = _chatService;
    final navigator = widget.navigatorKey.currentState;
    if (service == null || navigator == null) return;
    navigator.push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: chatMenuRouteName),
        builder: (_) => ChatMenuScreen(service: service),
      ),
    );
  }

  void _openBannerConversation() {
    final conversation = _bannerConversation;
    final service = _chatService;
    final navigator = widget.navigatorKey.currentState;
    if (conversation == null || service == null || navigator == null) return;
    setState(() => _bannerVisible = false);
    navigator.push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: chatRouteName,
          arguments: conversation.id,
        ),
        builder: (_) =>
            ChatScreen(service: service, conversation: conversation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return ValueListenableBuilder<Route<dynamic>?>(
      valueListenable: _routeListenable,
      builder: (context, currentRoute, _) {
        if (!Hive.isBoxOpen('settings')) {
          return _buildOverlay(
            context,
            keyboardOpen: keyboardOpen,
            viewPadding: viewPadding,
            showPreference: true,
          );
        }
        return ValueListenableBuilder<Box<dynamic>>(
          valueListenable: Hive.box<dynamic>('settings')
              .listenable(keys: [showChatButtonSetting]),
          builder: (context, _, _) => _buildOverlay(
            context,
            keyboardOpen: keyboardOpen,
            viewPadding: viewPadding,
            showPreference: _showButtonPreference,
          ),
        );
      },
    );
  }

  Widget _buildOverlay(
    BuildContext context, {
    required bool keyboardOpen,
    required EdgeInsets viewPadding,
    required bool showPreference,
  }) {
    final position = _validatedButtonPosition(
      MediaQuery.sizeOf(context),
      viewPadding,
    );
    final hideReason = _chatButtonHideReason(
      keyboardOpen: keyboardOpen,
      showPreference: showPreference,
      positionValid: position != null,
    );
    if (kDebugMode && hideReason != _lastHideReason) {
      debugPrint(
        hideReason == null
            ? 'Floating chat button visible'
            : 'Floating chat button hidden: $hideReason',
      );
    }
    _lastHideReason = hideReason;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_bannerVisible && _bannerConversation != null)
          Positioned(
            top: viewPadding.top + 8,
            left: 14,
            right: 14,
            child: _messageBanner(_bannerConversation!),
          ),
        if (hideReason == null && position != null)
          _positionedButton(MediaQuery.sizeOf(context), viewPadding, position),
      ],
    );
  }

  String? _chatButtonHideReason({
    required bool keyboardOpen,
    required bool showPreference,
    required bool positionValid,
  }) {
    if (!forgeMainShellVisible.value) {
      return 'splash/onboarding (main shell not mounted)';
    }
    if (!forgeMainShellDelayComplete.value) {
      return 'main shell waiting for 1.5-second delay';
    }
    if (_uid == null) return 'signed out';
    if (keyboardOpen) return 'keyboard open';
    if (_isChatRoute) return 'chat route open';
    if (_username == null || _chatService == null) {
      return 'no Friends profile/username';
    }
    if (!showPreference) return 'setting off';
    if (!positionValid) return 'position invalid';
    return null;
  }

  Offset? _validatedButtonPosition(Size size, EdgeInsets viewPadding) {
    const diameter = 58.0;
    final maxBottom = math.max(
      viewPadding.bottom + ForgeMotion.navBarHeight + 18,
      viewPadding.bottom + diameter + 8,
    );
    final defaultPosition = Offset(
      size.width - diameter - 18,
      size.height - maxBottom - diameter,
    );
    final position = _buttonTopLeft ?? _readStoredPosition();
    if (position == null) return defaultPosition;
    if (!_isPositionValid(position, size, viewPadding, diameter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _buttonTopLeft = defaultPosition);
        if (Hive.isBoxOpen('settings')) {
          unawaited(_persistButtonPosition(defaultPosition));
        }
      });
      return null;
    }
    return position;
  }

  bool _isPositionValid(
    Offset position,
    Size size,
    EdgeInsets viewPadding,
    double diameter,
  ) {
    final minimumTop = viewPadding.top + 8;
    final maximumTop =
        size.height -
        viewPadding.bottom -
        ForgeMotion.navBarHeight -
        diameter -
        18;
    final maximumLeft = size.width - diameter - 8;
    if (!position.dx.isFinite ||
        !position.dy.isFinite ||
        position.dx < 8 ||
        position.dx > maximumLeft ||
        position.dy < minimumTop ||
        position.dy > maximumTop) {
      return false;
    }
    final navTop =
        size.height -
        viewPadding.bottom -
        ForgeMotion.navBarHeight -
        ForgeMotion.navBottomInset;
    return position.dy + diameter <= navTop;
  }

  Widget _positionedButton(Size size, EdgeInsets viewPadding, Offset position) {
    const diameter = 58.0;
    if (_buttonTopLeft == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _buttonTopLeft == null) {
          setState(() => _buttonTopLeft = position);
        }
      });
    }
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _buttonTopLeft = _clampPosition(
              position + details.delta,
              size,
              viewPadding,
              diameter,
            );
          });
        },
        onPanEnd: (_) => _snapButtonToEdge(size, viewPadding, diameter),
        child: FadeTransition(
          opacity: _buttonFade,
          child: ScaleTransition(scale: _scale, child: _chatButton(diameter)),
        ),
      ),
    );
  }

  Offset? _readStoredPosition() {
    if (!Hive.isBoxOpen('settings')) return null;
    final stored = Hive.box<dynamic>('settings').get(chatButtonPositionSetting);
    if (stored is List && stored.length == 2) {
      final left = stored[0];
      final top = stored[1];
      if (left is num && top is num) {
        return Offset(left.toDouble(), top.toDouble());
      }
    }
    return null;
  }

  Offset _clampPosition(
    Offset position,
    Size size,
    EdgeInsets viewPadding,
    double diameter,
  ) {
    final left = position.dx.clamp(
      8.0,
      math.max(8.0, size.width - diameter - 8),
    );
    final top = position.dy.clamp(
      viewPadding.top + 8,
      math.max(
        viewPadding.top + 8,
        size.height -
            viewPadding.bottom -
            ForgeMotion.navBarHeight -
            diameter -
            18,
      ),
    );
    return Offset(left.toDouble(), top.toDouble());
  }

  void _snapButtonToEdge(Size size, EdgeInsets viewPadding, double diameter) {
    final current = _buttonTopLeft;
    if (current == null) return;
    final x = current.dx + diameter / 2 < size.width / 2
        ? 8.0
        : size.width - diameter - 8;
    final snapped = Offset(
      x,
      current.dy
          .clamp(
            viewPadding.top + 8,
            size.height -
                viewPadding.bottom -
                ForgeMotion.navBarHeight -
                diameter -
                18,
          )
          .toDouble(),
    );
    setState(() => _buttonTopLeft = snapped);
    if (Hive.isBoxOpen('settings')) {
      unawaited(_persistButtonPosition(snapped));
    }
  }

  Future<void> _persistButtonPosition(Offset position) async {
    try {
      await Hive.box<dynamic>('settings')
          .put(chatButtonPositionSetting, [position.dx, position.dy]);
    } catch (error, stackTrace) {
      debugPrint(
        'Saving floating chat button position failed: $error\n$stackTrace',
      );
    }
  }

  Widget _chatButton(double diameter) {
    final unread = _conversations
        .where(
          (conversation) =>
              conversation.isUnreadFor(_uid!) &&
              _chatService?.isMuted(conversation.id) != true,
        )
        .length;
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Material(
      color: tokens.accentTeal,
      elevation: 8,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _openChatMenu,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.chat_bubble_rounded,
                color: tokens.background,
                size: 27,
              ),
              if (unread > 0)
                Positioned(
                  top: -2,
                  right: -3,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE64A53),
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.surface, width: 2),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageBanner(ChatConversation conversation) {
    final senderUid = conversation.lastSenderUid;
    final sender = conversation.isGroup
        ? conversation.memberNames[senderUid] ?? 'Friend'
        : conversation.titleFor(_uid!);
    final preview = _bannerBurstCount > 1
        ? '$_bannerBurstCount new messages'
        : conversation.lastMessage ?? 'New message';
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return AnimatedSlide(
      offset: _bannerVisible ? Offset.zero : const Offset(0, -1.3),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _bannerVisible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: tokens.surface,
          elevation: 12,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openBannerConversation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tokens.surfaceVariant,
                    child: conversation.isGroup
                        ? const Icon(Icons.groups_rounded)
                        : Text(sender.characters.first.toUpperCase()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sender,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
