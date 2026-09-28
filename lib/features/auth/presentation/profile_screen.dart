import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: auth.isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
          ? Center(
              child: FilledButton(
                onPressed: () => context.go('/sign-in'),
                child: const Text('Sign in'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('Account info'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/account-info'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.collections_bookmark),
                  title: const Text('My Library'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/my-library'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insights),
                  title: const Text('Reading stats'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/stats'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mood),
                  title: const Text('Browse by mood'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/moods'),
                ),
                const Divider(height: 32),
                TextButton(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go('/');
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
    );
  }
}
