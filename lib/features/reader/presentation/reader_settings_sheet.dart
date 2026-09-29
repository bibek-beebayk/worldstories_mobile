import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../application/reader_appearance.dart';

/// Opens the reader appearance controls: text size, line height, theme,
/// custom theme creation and font. The same controls as the web reader's
/// settings panel; changes apply live to the page behind the sheet.
Future<void> showReaderSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      // Light barrier so the reader can see changes take effect.
      barrierColor: Colors.black26,
      builder: (context) => const _ReaderSettingsSheet(),
    );

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(readerAppearanceProvider);
    final controller = ref.read(readerAppearanceProvider.notifier);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          Text(
            'Reader Settings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Layout'),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.swap_vert),
                label: Text('Scroll'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.auto_stories_outlined),
                label: Text('Pages'),
              ),
            ],
            selected: {appearance.paged},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                controller.setPaged(selection.first),
          ),
          const SizedBox(height: 16),
          _Stepper(
            label: 'Text Size',
            value: '${appearance.fontSize.round()}px',
            decreaseLabel: 'A-',
            increaseLabel: 'A+',
            decreaseTooltip: 'Decrease text size',
            increaseTooltip: 'Increase text size',
            onDecrease: appearance.fontSize > ReaderAppearance.fontSizeMin
                ? () => controller.setFontSize(appearance.fontSize - 1)
                : null,
            onIncrease: appearance.fontSize < ReaderAppearance.fontSizeMax
                ? () => controller.setFontSize(appearance.fontSize + 1)
                : null,
          ),
          const SizedBox(height: 12),
          _Stepper(
            label: 'Line Height',
            value: appearance.lineHeight.toStringAsFixed(1),
            decreaseLabel: '−',
            increaseLabel: '+',
            decreaseTooltip: 'Decrease line height',
            increaseTooltip: 'Increase line height',
            onDecrease: appearance.lineHeight > ReaderAppearance.lineHeightMin
                ? () => controller.setLineHeight(appearance.lineHeight - 0.1)
                : null,
            onIncrease: appearance.lineHeight < ReaderAppearance.lineHeightMax
                ? () => controller.setLineHeight(appearance.lineHeight + 0.1)
                : null,
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Theme'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final theme in appearance.themes)
                _ThemeChip(
                  theme: theme,
                  selected: theme.key == appearance.theme.key,
                  onSelected: () => controller.setTheme(theme.key),
                  onDelete: theme.isCustom
                      ? () => controller.deleteCustomTheme(theme.key)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _CreateThemePanel(),
          const SizedBox(height: 20),
          const _SectionLabel('Font'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final font in readerFonts)
                ChoiceChip(
                  label: Text(font.label),
                  labelStyle: font.apply(
                    TextStyle(
                      fontSize: 15,
                      color: font.key == appearance.font.key
                          ? Colors.white
                          : AppTheme.foreground,
                    ),
                  ),
                  selected: font.key == appearance.font.key,
                  showCheckmark: false,
                  onSelected: (_) => controller.setFont(font.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppTheme.mutedForeground,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.decreaseTooltip,
    required this.increaseTooltip,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final String value;
  final String decreaseLabel;
  final String increaseLabel;
  final String decreaseTooltip;
  final String increaseTooltip;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _SectionLabel(label)),
      _StepButton(
        label: decreaseLabel,
        tooltip: decreaseTooltip,
        onPressed: onDecrease,
      ),
      SizedBox(
        width: 56,
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      _StepButton(
        label: increaseLabel,
        tooltip: increaseTooltip,
        onPressed: onIncrease,
      ),
    ],
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.theme,
    required this.selected,
    required this.onSelected,
    required this.onDelete,
  });

  final ReaderTheme theme;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => InputChip(
    avatar: CircleAvatar(
      backgroundColor: theme.background,
      child: Icon(
        theme.isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
        size: 14,
        color: theme.text,
      ),
    ),
    label: Text(theme.label),
    labelStyle: TextStyle(color: selected ? Colors.white : null),
    selected: selected,
    showCheckmark: false,
    onSelected: (_) => onSelected(),
    onDeleted: onDelete,
    deleteIcon: const Icon(Icons.close, size: 16),
    deleteIconColor: selected ? Colors.white : null,
    deleteButtonTooltipMessage: 'Delete theme',
  );
}

class _CreateThemePanel extends ConsumerStatefulWidget {
  const _CreateThemePanel();

  @override
  ConsumerState<_CreateThemePanel> createState() => _CreateThemePanelState();
}

class _CreateThemePanelState extends ConsumerState<_CreateThemePanel> {
  final nameController = TextEditingController();
  var expanded = false;
  var background = const Color(0xFF1F2937);
  var border = const Color(0xFF374151);
  var text = const Color(0xFFE5E7EB);
  var link = const Color(0xFF93C5FD);
  var isDark = true;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  bool get _textContrastOk => hasAccessibleTextContrast(text, background);
  bool get _linkContrastOk => hasAccessibleTextContrast(link, background);
  bool get _canSave =>
      nameController.text.trim().isNotEmpty &&
      _textContrastOk &&
      _linkContrastOk;

  void _save() {
    if (!_canSave) return;
    ref
        .read(readerAppearanceProvider.notifier)
        .createCustomTheme(
          name: nameController.text,
          background: background,
          border: border,
          text: text,
          link: link,
          isDark: isDark,
        );
    nameController.clear();
    FocusScope.of(context).unfocus();
    setState(() => expanded = false);
  }

  Future<void> _pick(
    String label,
    Color current,
    ValueChanged<Color> onPicked,
  ) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(label: label, initial: current),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(AppTheme.radius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: const Text('Create Theme'),
          trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => expanded = !expanded),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live preview of the theme being built.
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: background,
                    border: Border.all(color: border, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(color: text, height: 1.5),
                      children: [
                        const TextSpan(text: 'The quick brown fox, with a '),
                        TextSpan(
                          text: 'link',
                          style: TextStyle(
                            color: link,
                            decoration: TextDecoration.underline,
                            decorationColor: link,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  maxLength: 24,
                  decoration: const InputDecoration(
                    hintText: 'Theme name',
                    isDense: true,
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3.4,
                  children: [
                    _ColorField(
                      label: 'Background',
                      color: background,
                      onTap: () => _pick(
                        'Background',
                        background,
                        (value) => background = value,
                      ),
                    ),
                    _ColorField(
                      label: 'Border',
                      color: border,
                      onTap: () =>
                          _pick('Border', border, (value) => border = value),
                    ),
                    _ColorField(
                      label: 'Text',
                      color: text,
                      onTap: () => _pick('Text', text, (value) => text = value),
                    ),
                    _ColorField(
                      label: 'Links',
                      color: link,
                      onTap: () =>
                          _pick('Links', link, (value) => link = value),
                    ),
                  ],
                ),
                if (!_textContrastOk || !_linkContrastOk)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Choose text and link colors with stronger contrast '
                      'against the background.',
                      style: TextStyle(
                        color: AppTheme.destructive,
                        fontSize: 12,
                      ),
                    ),
                  ),
                CheckboxListTile(
                  value: isDark,
                  onChanged: (value) => setState(() => isDark = value ?? true),
                  title: const Text('Treat as dark theme'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: const Text('Save Theme'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ColorField extends StatelessWidget {
  const _ColorField({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppTheme.border),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A small swatch-plus-hex color picker (the web uses the browser's native
/// color input, which Flutter has no equivalent of).
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.label, required this.initial});

  final String label;
  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  static const _swatches = [
    Color(0xFFFFFFFF),
    Color(0xFFF8FAFC),
    Color(0xFFF4EDE0),
    Color(0xFFEFE3CF),
    Color(0xFFFEF3C7),
    Color(0xFFDCFCE7),
    Color(0xFFDBEAFE),
    Color(0xFFFCE7F3),
    Color(0xFFE5E7EB),
    Color(0xFF9CA3AF),
    Color(0xFF93C5FD),
    Color(0xFFFCA5A5),
    Color(0xFF86EFAC),
    Color(0xFFFDE68A),
    Color(0xFFC4B5FD),
    Color(0xFFED405A),
    Color(0xFF2563EB),
    Color(0xFF0D9488),
    Color(0xFF7C3AED),
    Color(0xFFB45309),
    Color(0xFF374151),
    Color(0xFF1F2937),
    Color(0xFF1B2230),
    Color(0xFF111827),
    Color(0xFF3B2F2F),
    Color(0xFF1E3A2F),
    Color(0xFF0F172A),
    Color(0xFF000000),
  ];

  late Color color = widget.initial;
  late final hexController = TextEditingController(
    text: colorToHex(widget.initial),
  );

  @override
  void dispose() {
    hexController.dispose();
    super.dispose();
  }

  void _select(Color value) => setState(() {
    color = value;
    hexController.text = colorToHex(value);
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.label),
    content: SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final swatch in _swatches)
                GestureDetector(
                  onTap: () => _select(swatch),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: swatch.toARGB32() == color.toARGB32()
                            ? AppTheme.primary
                            : AppTheme.border,
                        width: swatch.toARGB32() == color.toARGB32() ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: hexController,
                  decoration: const InputDecoration(
                    labelText: 'Hex',
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final parsed = hexToColor(value);
                    if (parsed != null) setState(() => color = parsed);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, color),
        child: const Text('Use color'),
      ),
    ],
  );
}
