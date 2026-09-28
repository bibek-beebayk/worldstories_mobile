import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_exception.dart';
import '../application/auth_controller.dart';

class AccountInfoScreen extends ConsumerStatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  ConsumerState<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends ConsumerState<AccountInfoScreen> {
  final name = TextEditingController();
  final bio = TextEditingController();
  final avatar = TextEditingController();
  bool loaded = false;
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    avatar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.value;
    if (user != null && !loaded) {
      loaded = true;
      name.text = user.displayName ?? '';
      bio.text = user.bio ?? '';
      avatar.text = user.avatarUrl ?? '';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account info')),
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
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bio,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: avatar,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Avatar URL'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() => saving = true);
                          try {
                            await ref
                                .read(authControllerProvider.notifier)
                                .updateProfile(
                                  displayName: name.text.trim(),
                                  bio: bio.text.trim(),
                                  avatarUrl: avatar.text.trim(),
                                );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account info updated.'),
                              ),
                            );
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(apiErrorMessage(error))),
                            );
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ],
            ),
    );
  }
}
