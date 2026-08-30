import 'package:flutter/material.dart';

class AppToolbar extends StatelessWidget implements PreferredSizeWidget {
  const AppToolbar({
    super.key,
    required this.appName,
    this.onImportPressed,
  });

  final String appName;
  final VoidCallback? onImportPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppBar(
      backgroundColor: colorScheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Row(
        children: [
          Icon(Icons.music_note_rounded, color: colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            appName,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: FilledButton.icon(
            onPressed: onImportPressed,
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('Import'),
          ),
        ),
      ],
    );
  }
}