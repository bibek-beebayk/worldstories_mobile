import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_exception.dart';
import '../../../core/app_theme.dart';
import '../application/auth_controller.dart';
import 'legal_document_dialog.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(next.error!))));
      }
    });
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              right: -110,
              top: -90,
              child: _Glow(size: 330, opacity: 0.13),
            ),
            const Positioned(
              left: -130,
              bottom: -120,
              child: _Glow(size: 380, opacity: 0.09),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          elevation: 8,
                          shadowColor: Colors.black45,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _LoginHero(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  24,
                                  24,
                                  22,
                                ),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: 250,
                                      height: 46,
                                      child: OutlinedButton.icon(
                                        onPressed: auth.isLoading
                                            ? null
                                            : () => ref
                                                  .read(
                                                    authControllerProvider
                                                        .notifier,
                                                  )
                                                  .signIn(),
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: AppTheme.foreground,
                                          side: const BorderSide(
                                            color: AppTheme.border,
                                          ),
                                          shape: const StadiumBorder(),
                                        ),
                                        icon: auth.isLoading
                                            ? const SizedBox.square(
                                                dimension: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const _GoogleMark(),
                                        label: Text(
                                          auth.isLoading
                                              ? 'Signing in…'
                                              : 'Continue with Google',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const _LegalNotice(),
                                  ],
                                ),
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
          ],
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 245,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.heroGradientEnd,
            AppTheme.heroDark,
            Color(0xFF202B3D),
          ],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            right: -42,
            top: -44,
            child: _Glow(size: 170, opacity: 0.18),
          ),
          const Positioned(
            left: -52,
            bottom: -74,
            child: _Glow(size: 180, opacity: 0.09),
          ),
          const Positioned(right: 4, top: 62, child: _BookWorldDecoration()),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        'W',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'WorldStories',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox(
                  width: 255,
                  child: Text(
                    'Welcome back, storyteller',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: AppTheme.displayFont,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const SizedBox(
                  width: 260,
                  child: Text(
                    'Sign in to save favorites, track your reading progress, and pick up right where you left off.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppTheme.primary.withValues(alpha: opacity),
    ),
  );
}

class _BookWorldDecoration extends StatelessWidget {
  const _BookWorldDecoration();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 145,
    height: 125,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
        ),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white12, width: 1.5),
          ),
        ),
        const Icon(Icons.menu_book_rounded, color: Colors.white38, size: 58),
        const Positioned(
          right: 6,
          top: 5,
          child: Icon(Icons.auto_awesome, color: AppTheme.primary, size: 22),
        ),
        const Positioned(
          left: 8,
          bottom: 4,
          child: Icon(Icons.auto_awesome, color: AppTheme.primary, size: 15),
        ),
      ],
    ),
  );
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => const Text(
    'G',
    style: TextStyle(
      color: Color(0xFF4285F4),
      fontSize: 19,
      fontWeight: FontWeight.w800,
      fontFamily: 'sans-serif',
    ),
  );
}

class _LegalNotice extends StatelessWidget {
  const _LegalNotice();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 3,
      children: [
        Text("By continuing, you agree to WorldStories'", style: style),
        _LegalLink(
          label: 'Terms of Service',
          onTap: () => showLegalDocumentDialog(context, LegalDocument.terms),
        ),
        Text('and', style: style),
        _LegalLink(
          label: 'Privacy Policy',
          onTap: () => showLegalDocumentDialog(context, LegalDocument.privacy),
        ),
        Text('.', style: style),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
