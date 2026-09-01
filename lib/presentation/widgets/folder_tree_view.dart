import 'package:flutter/material.dart';

import '../../domain/entities/folder_entity.dart';

/// Left panel: folder tree of the imported folder, styled like an IDE.
class FolderTreeView extends StatelessWidget {
  const FolderTreeView({
    super.key,
    required this.rootFolder,
    required this.rootChildren,
    required this.loadChildren,
    required this.selectedFolderPath,
    required this.onFolderSelected,
  });

  final FolderEntity rootFolder;
  final List<FolderEntity> rootChildren;
  final Future<List<FolderEntity>> Function(String path) loadChildren;
  final String? selectedFolderPath;
  final void Function(FolderEntity folder) onFolderSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isRootSelected = selectedFolderPath == rootFolder.path;

    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Icon(Icons.folder_rounded,
                    size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Library',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Root folder entry
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _TreeRow(
              selected: isRootSelected,
              leading: const Icon(Icons.storage_rounded, size: 18),
              title: rootFolder.name,
              subtitle: rootFolder.path,
              onTap: () => onFolderSelected(rootFolder),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: rootChildren.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_off_outlined,
                            size: 36,
                            color: colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'This folder has no subfolders',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: rootChildren.length,
                    itemBuilder: (context, index) {
                      final folder = rootChildren[index];
                      return _FolderTreeNode(
                        folder: folder,
                        depth: 0,
                        loadChildren: loadChildren,
                        selectedFolderPath: selectedFolderPath,
                        onFolderSelected: onFolderSelected,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A rounded, hover-aware selectable tree row.
class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.selected,
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final bool selected;
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color:
                selected ? colorScheme.primary.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(5),
            border: selected
                ? Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.4),
                  )
                : null,
          ),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                child: leading,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tree node that loads its subfolders on build and selects the folder
/// when clicked.
class _FolderTreeNode extends StatefulWidget {
  const _FolderTreeNode({
    required this.folder,
    required this.depth,
    required this.loadChildren,
    required this.selectedFolderPath,
    required this.onFolderSelected,
  });

  final FolderEntity folder;
  final int depth;
  final Future<List<FolderEntity>> Function(String path) loadChildren;
  final String? selectedFolderPath;
  final void Function(FolderEntity folder) onFolderSelected;

  @override
  State<_FolderTreeNode> createState() => _FolderTreeNodeState();
}

class _FolderTreeNodeState extends State<_FolderTreeNode> {
  List<FolderEntity>? _children;
  bool _expanded = false;
  bool _hovered = false;

  bool get _isSelected => widget.selectedFolderPath == widget.folder.path;

  bool get _hasSubfolders => _children != null && _children!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final Color rowColor;
    if (_isSelected) {
      rowColor = colorScheme.primary.withValues(alpha: 0.16);
    } else if (_hovered) {
      rowColor = colorScheme.onSurface.withValues(alpha: 0.06);
    } else {
      rowColor = Colors.transparent;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: widget.folder.path,
          waitDuration: const Duration(milliseconds: 600),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: rowColor,
                  borderRadius: BorderRadius.circular(5),
                  border: _isSelected
                      ? Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                        )
                      : null,
                ),
                child: InkWell(
                  onTap: () => widget.onFolderSelected(widget.folder),
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    height: 30,
                    child: Row(
                      children: [
                        SizedBox(width: widget.depth * 16),
                        SizedBox(
                          width: 24,
                          height: 30,
                          child: Center(child: _buildArrow(colorScheme)),
                        ),
                        Icon(
                          _hasSubfolders && _expanded
                              ? Icons.folder_open_rounded
                              : Icons.folder_rounded,
                          size: 17,
                          color: _isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: _isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: _isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ..._buildChildren(),
      ],
    );
  }

  Widget _buildArrow(ColorScheme colorScheme) {
    if (_children == null) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (!_hasSubfolders) {
      return const SizedBox.shrink();
    }
    return InkResponse(
      onTap: _toggleExpansion,
      radius: 14,
      child: AnimatedRotation(
        turns: _expanded ? 0.25 : 0,
        duration: const Duration(milliseconds: 150),
        child: Icon(
          Icons.chevron_right,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  List<Widget> _buildChildren() {
    final children = _children ?? const [];
    return children
        .map(
          (folder) => _FolderTreeNode(
            folder: folder,
            depth: widget.depth + 1,
            loadChildren: widget.loadChildren,
            selectedFolderPath: widget.selectedFolderPath,
            onFolderSelected: widget.onFolderSelected,
          ),
        )
        .toList(growable: false);
  }

  void _toggleExpansion() {
    if (!_hasSubfolders) return;
    setState(() => _expanded = !_expanded);
  }

  Future<void> _loadChildren() async {
    try {
      final children = await widget.loadChildren(widget.folder.path);
      if (!mounted) return;
      setState(() => _children = children);
    } catch (_) {
      if (!mounted) return;
      setState(() => _children = const []);
    }
  }
}
