import 'package:flutter/material.dart';
import 'package:mythopolis/utils/shape_catalog.dart';


//////////////////////////////////////////////////////
//                 WIDGET PRINCIPAL                 //
//////////////////////////////////////////////////////

/// Menu de choix de la forme d'une zone photo.
/// Affiche toutes les formes (aperçu + nom) avec une recherche par nom.
/// Retourne le chemin de l'asset choisi, ou null si annulé.
class ShapePickerDialog extends StatefulWidget {
  const ShapePickerDialog({super.key});

  /// Ouvre le menu et attend le choix.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => const ShapePickerDialog(),
    );
  }

  @override
  State<ShapePickerDialog> createState() => _ShapePickerDialogState();
}

class _ShapePickerDialogState extends State<ShapePickerDialog> {

  // Liste des formes, chargée une fois à l'ouverture
  late final Future<List<String>> _shapePaths = ShapeCatalog.listShapePaths();

  // Texte de recherche (en minuscules)
  String _search = '';


  //////////////////////////////////////////////////////
  //                     BUILD                        //
  //////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir une forme'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            // Recherche par nom
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher une forme…',
              ),
              onChanged: (value) => setState(() => _search = value.toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }

  /// Grille des formes dont le nom contient la recherche.
  Widget _buildGrid() {
    return FutureBuilder<List<String>>(
      future: _shapePaths,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<String> paths = snapshot.data!
            .where((path) => ShapeCatalog.nameOf(path).toLowerCase().contains(_search))
            .toList();
        if (paths.isEmpty) {
          return const Center(child: Text('Aucune forme trouvée'));
        }

        return GridView.builder(
          // Cases d'environ 110 px de large, autant que la place permet
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 110,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85, // un peu plus haut que large (nom dessous)
          ),
          itemCount: paths.length,
          itemBuilder: (context, index) => _buildShapeTile(paths[index]),
        );
      },
    );
  }

  /// Une case : aperçu de la forme + son nom. Un clic la choisit.
  Widget _buildShapeTile(String assetPath) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pop(context, assetPath),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: FutureBuilder<ShapeInfo>(
                  future: ShapeCatalog.load(assetPath),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    // La forme est un masque : on la colorie avec la
                    // couleur du texte du thème (lisible en clair/sombre)
                    return Image.memory(
                      snapshot.data!.bytes,
                      fit: BoxFit.contain,
                      color: colors.onSurface,
                      colorBlendMode: BlendMode.srcIn,
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ShapeCatalog.nameOf(assetPath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
