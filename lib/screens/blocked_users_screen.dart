import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({required this.service, super.key});

  final ChatService service;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Blocked users')),
    body: StreamBuilder<Map<String, String>>(
      stream: service.blockedUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          debugPrint('Blocked users stream failed: $error');
          return Center(
            child: Text(
              kDebugMode
                  ? 'Could not load blocked users: $error'
                  : 'Blocked users are unavailable right now.',
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data ?? const <String, String>{};
        if (users.isEmpty) {
          return const Center(child: Text('You have no blocked users.'));
        }
        return ListView(
          children: [
            for (final entry in users.entries)
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_outline_rounded),
                ),
                title: Text('@${entry.value}'),
                trailing: TextButton(
                  onPressed: () => unawaited(
                    _unblock(context, entry.key, service),
                  ),
                  child: const Text('Unblock'),
                ),
              ),
          ],
        );
      },
    ),
  );

  static Future<void> _unblock(
    BuildContext context,
    String uid,
    ChatService service,
  ) async {
    try {
      await service.unblockUser(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User unblocked')));
      }
    } catch (error, stackTrace) {
      debugPrint('Unblocking user failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kDebugMode ? 'Could not unblock user: $error' : 'Could not unblock user.',
            ),
          ),
        );
      }
    }
  }
}
