import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mythopolis/models/page_model.dart';


//////////////////////////////////////////////////////
//              WIDGET RÉUTILISABLE                 //
//////////////////////////////////////////////////////

/// Panneau latéral de gestion des pages (template ou fiche).
///
/// Affichage seul : il ne connaît ni le provider ni la base. Chaque action
/// est remontée à l'écran parent via un callback, avec l'INDEX de la page
/// concernée — c'est l'écran qui décide quelle page afficher ensuite.
///
/// - clic          → sélectionne la page (le panneau reste ouvert)
/// - clic droit    → menu Dupliquer / Supprimer
/// - icône ≡       → cliquer-glisser pour changer l'ordre
/// - bouton du bas → ajouter une page
class PagePanel extends StatelessWidget {
  final List<PageModel> pages;
  final int currentIndex;

  // Dimensions du canvas, pour garder les proportions des miniatures
  final int canvasWidth;
  final int canvasHeight;

  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<int> onDuplicate;
  final ValueChanged<int> onDelete;

  /// [newIndex] est la position FINALE de la page.
  final void Function(int oldIndex, int newIndex) onReorder;

  const PagePanel({
    super.key,
    required this.pages,
    required this.currentIndex,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onSelect,
    required this.onAdd,
    required this.onDuplicate,
    required this.onDelete,
    required this.onReorder,
  });


  //////////////////////////////////////////////////////
  //                     BUILD                        //
  //////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainer,
      elevation: 4,
      child: SizedBox(
        width: 200,
        child: Column(
          children: [
            // Liste des pages (défile) — prend toute la place disponible
            Expanded(
              child: ReorderableListView.builder(
                // On fournit nos propres poignées (icône ≡) : sans ça,
                // Flutter en ajoute automatiquement sur desktop.
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: pages.length,
                // onReorderItem donne directement la position FINALE
                // (l'ancien onReorder était décalé de 1 en descendant).
                onReorderItem: (oldIndex, newIndex) {
                  if (oldIndex != newIndex) onReorder(oldIndex, newIndex);
                },
                itemBuilder: (context, index) => _buildPageTile(context, index),
              ),
            ),

            // Bouton global, toujours visible sous la liste
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une page'),
                  onPressed: onAdd,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  //////////////////////////////////////////////////////
  //                  LIGNE D'UNE PAGE                //
  //////////////////////////////////////////////////////

  /// Une ligne : numéro, miniature, poignée de déplacement.
  Widget _buildPageTile(BuildContext context, int index) {
    final PageModel page = pages[index];
    final bool isSelected = index == currentIndex;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return GestureDetector(
      // La key est OBLIGATOIRE pour ReorderableListView : elle lui permet
      // de suivre chaque élément pendant le déplacement. L'ID est stable.
      key: ValueKey(page.id),
      onSecondaryTapUp: (details) => _showContextMenu(context, index, details),
      child: InkWell(
        onTap: () => onSelect(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // Numéro = position dans la liste (1, 2, 3…)
              SizedBox(
                width: 24,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Miniature, bordée de couleur si c'est la page affichée
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? colors.primary : colors.outlineVariant,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: _buildThumbnail(page),
                ),
              ),
              const SizedBox(width: 4),

              // Poignée : cliquer-glisser dessus déplace la page
              ReorderableDragStartListener(
                index: index,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Version réduite de la page, aux proportions du canvas.
  /// Pour l'instant une page = son fond ; les zones viendront plus tard.
  Widget _buildThumbnail(PageModel page) {
    final String? path = page.backgroundPath;

    return AspectRatio(
      aspectRatio: canvasWidth / canvasHeight,
      child: path == null
          ? const ColoredBox(color: Colors.white)
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              // Décode l'image en petit : inutile de charger 1240×1754
              // pixels en mémoire pour l'afficher sur ~120.
              cacheWidth: 240,
              errorBuilder: (context, error, stack) =>
                  const ColoredBox(color: Colors.white),
            ),
    );
  }


  //////////////////////////////////////////////////////
  //                     ACTIONS                      //
  //////////////////////////////////////////////////////

  /// Menu du clic droit, ouvert à la position de la souris.
  void _showContextMenu(BuildContext context, int index, TapUpDetails details) {
    final Offset position = details.globalPosition;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy,
      ),
      items: [
        const PopupMenuItem(value: 'duplicate', child: Text('Dupliquer')),
        PopupMenuItem(
          value: 'delete',
          // On ne peut pas supprimer la dernière page restante
          // (le service le refuse aussi, ceci n'est que l'affichage).
          enabled: pages.length > 1,
          child: const Text('Supprimer'),
        ),
      ],
    ).then((value) {
      if (value == 'duplicate') onDuplicate(index);
      if (value == 'delete') onDelete(index);
    });
  }
}
