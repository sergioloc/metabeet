import 'package:flutter/material.dart';

import '../../domain/entities/folder_entity.dart';

/// Panel izquierdo: muestra la carpeta importada y su árbol de subcarpetas.
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

    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.drive_folder_upload_outlined,
                  size: 28,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rootFolder.name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        rootFolder.path,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rootChildren.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Esta carpeta no contiene subcarpetas',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: rootChildren.length,
                    itemBuilder: (context, index) {
                      final folder = rootChildren[index];
                      return FolderTreeNode(
                        folder: folder,
                        loadChildren: loadChildren,
                        onFolderSelected: onFolderSelected,
                        selectedFolderPath: selectedFolderPath,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Nodo del árbol que carga sus subcarpetas de forma perezosa al expandirse.
///
/// Al expandir una carpeta también la selecciona, mostrando sus archivos de
/// audio en el panel derecho.
class FolderTreeNode extends StatefulWidget {
  const FolderTreeNode({
    super.key,
    required this.folder,
    required this.loadChildren,
    required this.onFolderSelected,
    required this.selectedFolderPath,
  });

  final FolderEntity folder;
  final Future<List<FolderEntity>> Function(String path) loadChildren;
  final void Function(FolderEntity folder) onFolderSelected;
  final String? selectedFolderPath;

  @override
  State<FolderTreeNode> createState() => _FolderTreeNodeState();
}

class _FolderTreeNodeState extends State<FolderTreeNode> {
  List<FolderEntity>? _children;
  bool _loaded = false;
  bool _loading = false;

  bool get _isSelected => widget.selectedFolderPath == widget.folder.path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: _isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: ExpansionTile(
        key: PageStorageKey(widget.folder.path),
        leading: Icon(Icons.folder_outlined, color: colorScheme.primary),
        title: Text(
          widget.folder.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onExpansionChanged: _onExpansionChanged,
        children: _children == null
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _loading
                      ? const LinearProgressIndicator(minHeight: 2)
                      : const SizedBox(height: 2),
                ),
              ]
            : _children!.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 40,
                      ),
                      child: Text(
                        'Sin subcarpetas',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ]
                : _children!
                    .map(
                      (folder) => FolderTreeNode(
                        folder: folder,
                        loadChildren: widget.loadChildren,
                        onFolderSelected: widget.onFolderSelected,
                        selectedFolderPath: widget.selectedFolderPath,
                      ),
                    )
                    .toList(growable: false),
      ),
    );
  }

  Future<void> _onExpansionChanged(bool expanded) async {
    if (expanded) {
      widget.onFolderSelected(widget.folder);
    }
    if (!expanded || _loaded) return;

    setState(() => _loading = true);
    try {
      final children = await widget.loadChildren(widget.folder.path);
      if (!mounted) return;
      setState(() {
        _children = children;
        _loaded = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _children = const [];
        _loaded = true;
        _loading = false;
      });
    }
  }
}