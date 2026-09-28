import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_exception.dart';
import '../../../core/app_theme.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

class FirstLoginSetupScreen extends ConsumerStatefulWidget {
  const FirstLoginSetupScreen({super.key});

  @override
  ConsumerState<FirstLoginSetupScreen> createState() =>
      _FirstLoginSetupScreenState();
}

class _FirstLoginSetupScreenState extends ConsumerState<FirstLoginSetupScreen> {
  static const minimumGenres = 3;

  final username = TextEditingController();
  final displayName = TextEditingController();
  final selectedGenres = <int>{};
  late Future<List<OnboardingGenre>> genresFuture;
  Timer? usernameDebounce;
  String initialUsername = '';
  _UsernameStatus usernameStatus = _UsernameStatus.idle;
  bool loaded = false;
  bool saving = false;
  int usernameCheck = 0;

  @override
  void initState() {
    super.initState();
    genresFuture = ref.read(authRepositoryProvider).fetchOnboardingGenres();
    username.addListener(_usernameChanged);
  }

  @override
  void dispose() {
    usernameDebounce?.cancel();
    username
      ..removeListener(_usernameChanged)
      ..dispose();
    displayName.dispose();
    super.dispose();
  }

  void _usernameChanged() {
    usernameDebounce?.cancel();
    final value = username.text.trim();
    if (value.isEmpty) {
      setState(() => usernameStatus = _UsernameStatus.idle);
      return;
    }
    if (value == initialUsername) {
      setState(() => usernameStatus = _UsernameStatus.available);
      return;
    }
    setState(() => usernameStatus = _UsernameStatus.checking);
    final check = ++usernameCheck;
    usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final available = await ref
            .read(authRepositoryProvider)
            .usernameAvailable(value);
        if (!mounted || check != usernameCheck) return;
        setState(
          () => usernameStatus = available
              ? _UsernameStatus.available
              : _UsernameStatus.taken,
        );
      } catch (_) {
        if (!mounted || check != usernameCheck) return;
        setState(() => usernameStatus = _UsernameStatus.unavailable);
      }
    });
  }

  bool get canSave =>
      username.text.trim().isNotEmpty &&
      usernameStatus == _UsernameStatus.available &&
      displayName.text.trim().isNotEmpty &&
      selectedGenres.length >= minimumGenres &&
      !saving;

  Future<void> _save() async {
    if (!canSave) return;
    setState(() => saving = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeOnboarding(
            username: username.text.trim(),
            displayName: displayName.text.trim(),
            preferredGenreIds: selectedGenres,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user != null && !loaded) {
      loaded = true;
      initialUsername = user.username;
      username.removeListener(_usernameChanged);
      username.text = user.username;
      username.addListener(_usernameChanged);
      usernameStatus = user.username.isEmpty
          ? _UsernameStatus.idle
          : _UsernameStatus.available;
      displayName.text = user.displayName ?? '';
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.heroDark,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.heroDark,
                AppTheme.heroGradientEnd,
                Color(0xFF35202D),
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 8,
                        shadowColor: Colors.black45,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Set up your account',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Choose a username and display name, then select at least three genres so we can recommend stories.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 22),
                              TextField(
                                controller: username,
                                autocorrect: false,
                                decoration: InputDecoration(
                                  labelText: 'Username *',
                                  suffixIcon: _UsernameStatusIcon(
                                    status: usernameStatus,
                                  ),
                                  helperText: switch (usernameStatus) {
                                    _UsernameStatus.available =>
                                      'Username is available.',
                                    _UsernameStatus.taken =>
                                      'That username is already taken.',
                                    _UsernameStatus.unavailable =>
                                      'Could not check availability.',
                                    _ => null,
                                  },
                                  helperStyle: TextStyle(
                                    color:
                                        usernameStatus == _UsernameStatus.taken
                                        ? AppTheme.destructive
                                        : usernameStatus ==
                                              _UsernameStatus.available
                                        ? const Color(0xFF059669)
                                        : AppTheme.mutedForeground,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: displayName,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Display name *',
                                  helperText: 'Required',
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'What do you like to read?',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                selectedGenres.length >= minimumGenres
                                    ? '${selectedGenres.length} genres selected'
                                    : 'Select at least $minimumGenres genres (${selectedGenres.length}/$minimumGenres)',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color:
                                          selectedGenres.length >= minimumGenres
                                          ? const Color(0xFF059669)
                                          : AppTheme.mutedForeground,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              FutureBuilder<List<OnboardingGenre>>(
                                future: genresFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState !=
                                      ConnectionState.done) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(20),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return Center(
                                      child: TextButton.icon(
                                        onPressed: () => setState(
                                          () => genresFuture = ref
                                              .read(authRepositoryProvider)
                                              .fetchOnboardingGenres(),
                                        ),
                                        icon: const Icon(Icons.refresh),
                                        label: const Text(
                                          'Retry loading genres',
                                        ),
                                      ),
                                    );
                                  }
                                  return Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: snapshot.requireData
                                        .map(
                                          (genre) => FilterChip(
                                            label: Text(
                                              genre.name,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            selected: selectedGenres.contains(
                                              genre.id,
                                            ),
                                            showCheckmark: false,
                                            selectedColor: AppTheme.primary
                                                .withValues(alpha: 0.18),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity: const VisualDensity(
                                              horizontal: -2,
                                              vertical: -2,
                                            ),
                                            onSelected: (selected) => setState(
                                              () => selected
                                                  ? selectedGenres.add(genre.id)
                                                  : selectedGenres.remove(
                                                      genre.id,
                                                    ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FilledButton(
                                    onPressed: canSave ? _save : null,
                                    child: saving
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Save'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _UsernameStatus { idle, checking, available, taken, unavailable }

class _UsernameStatusIcon extends StatelessWidget {
  const _UsernameStatusIcon({required this.status});

  final _UsernameStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
    _UsernameStatus.checking => const Padding(
      padding: EdgeInsets.all(14),
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    _UsernameStatus.available => const Icon(
      Icons.check,
      color: Color(0xFF059669),
    ),
    _UsernameStatus.taken => const Icon(
      Icons.close,
      color: AppTheme.destructive,
    ),
    _ => const SizedBox.shrink(),
  };
}
