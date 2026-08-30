import 'package:flutter/material.dart';

import '../../domain/entities/folder_entity.dart';

/// Vista raíz del árbol de subcarpetas de la carpeta importada.
class FolderTreeView extends StatelessWidget {
  const FolderTreeView({
    super.key,
    required this.rootFolder,
    required this.rootChildren,
    required this.loadChildren,
  });

  final FolderEntity rootFolder;
  final List<FolderEntity> rootChildren;
  final Future<List<FolderEntity>> Function(String path) loadChildren;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.drive_folder_upload_outlined,
                  size: 32,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rootFolder.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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
          Flexible(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                if (rootChildren.isNotEmpty)
                  ...rootChildren.map(
                    (folder) => FolderTreeNode(
                      folder: folder,
                      loadChildren: loadChildren,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Esta carpeta no contiene subcarpetas',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nodo del árbol que carga sus subcarpetas de forma perezosa al expandirse.
class FolderTreeNode extends StatefulWidget {
  const FolderTreeNode({
    super.key,
    required this.folder,
    required this.loadChildren,
  });

  final FolderEntity folder;
  final Future<List<FolderEntity>> Function(String path) loadChildren;

  @override
  State<FolderTreeNode> createState() => _FolderTreeNodeState();
}

class _FolderTreeNodeState extends State<FolderTreeNode> {
  List<FolderEntity>? _children;
  bool _loaded = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ExpansionTile(
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
                    ),
                  )
                  .toList(growable: false),
    );
  }

  Future<void> _onExpansionChanged(bool expanded) async {
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