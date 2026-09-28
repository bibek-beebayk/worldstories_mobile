import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../data/favorite_repository.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    super.key,
    required this.storySlug,
    required this.initialIsFavorite,
    required this.initialFavoritesCount,
  });
  final String storySlug;
  final bool initialIsFavorite;
  final int initialFavoritesCount;
  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  late bool isFavorite = widget.initialIsFavorite;
  late int favoritesCount = widget.initialFavoritesCount;
  bool busy = false;

  Future<void> _toggle() async {
    if (busy) return;
    if (ref.read(authControllerProvider).value == null) {
      context.push('/sign-in');
      return;
    }
    setState(() => busy = true);
    final previousFavorite = isFavorite;
    final previousCount = favoritesCount;
    setState(() {
      isFavorite = !isFavorite;
      favoritesCount += isFavorite ? 1 : -1;
    });
    try {
      final result = await ref
          .read(favoriteRepositoryProvider)
          .setFavorite(widget.storySlug, isFavorite);
      if (!mounted) return;
      setState(() {
        isFavorite = result.isFavorite;
        favoritesCount = result.favoritesCount;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isFavorite = previousFavorite;
        favoritesCount = previousCount;
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: busy ? null : _toggle,
    icon: Icon(
      isFavorite ? Icons.favorite : Icons.favorite_border,
      color: isFavorite ? Colors.redAccent : null,
    ),
    label: Text('$favoritesCount'),
  );
}
