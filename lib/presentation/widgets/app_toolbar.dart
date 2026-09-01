import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

class AppToolbar extends StatelessWidget implements PreferredSizeWidget {
  const AppToolbar({
    super.key,
    required this.appName,
    this.onImportPressed,
    this.onSavePressed,
    this.saveCount = 0,
  });

  final String appName;
  final VoidCallback? onImportPressed;
  final VoidCallback? onSavePressed;
  final int saveCount;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surface,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _BrandMark(colorScheme),
              const SizedBox(width: 12),
              Text(
                appName,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              if (saveCount > 0) ...[
                _ToolbarButton(
                  onPressed: onSavePressed,
                  accent: true,
                  icon: Icons.save_outlined,
                  label: 'Save ($saveCount)',
                ),
                const SizedBox(width: 8),
              ],
              _ToolbarButton(
                onPressed: onImportPressed,
                accent: true,
                emphasized: true,
                icon: Icons.folder_open_outlined,
                label: 'Import',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small beet/raspberry brand mark.
class _BrandMark extends StatelessWidget {
  const _BrandMark(this.colorScheme);

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentSoft, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.music_note_rounded,
        size: 17,
        color: Colors.white,
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.accent = false,
    this.emphasized = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool accent;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Color bg;
    final Color fg;
    if (emphasized) {
      bg = colorScheme.primary;
      fg = _contrastText(colorScheme.primary);
    } else if (accent) {
      bg = colorScheme.primary.withValues(alpha: 0.22);
      fg = colorScheme.primary;
    } else {
      bg = colorScheme.surfaceContainerHigh;
      fg = colorScheme.onSurface;
    }

    final enabled = onPressed != null;
    final bgColor =
        enabled ? bg : colorScheme.onSurface.withValues(alpha: 0.04);
    final fgColor = enabled ? fg : colorScheme.onSurfaceVariant;

    return Opacity(
      opacity: enabled ? 1 : 1,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(5),
            border: emphasized || accent
                ? null
                : Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: fgColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: fgColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _contrastText(Color background) {
  final hsl = HSLColor.fromColor(background);
  return hsl.lightness > 0.6 ? const Color(0xFF1E1E1E) : Colors.white;
}
