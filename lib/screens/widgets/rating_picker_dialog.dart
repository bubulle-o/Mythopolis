import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mythopolis/models/rating.dart';
import 'package:mythopolis/services/rating_service.dart';
import 'package:mythopolis/utils/rating_images.dart';


//////////////////////////////////////////////////////
//                 WIDGET PRINCIPAL                 //
//////////////////////////////////////////////////////

/// Menu de choix d'une jauge, en deux étapes :
/// 1. le TYPE (aperçu plein + vide + nom), ou « Nouvelle jauge » ;
/// 2. la COULEUR (sautée s'il n'y en a qu'une, ex. jauge personnalisée).
/// Le jaune est la couleur par défaut : aperçu du type et premier choix.
/// Retourne l'ID de la jauge choisie (Rating.id), ou null si annulé.
class RatingPickerDialog extends StatefulWidget {
  const RatingPickerDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => const RatingPickerDialog(),
    );
  }

  @override
  State<RatingPickerDialog> createState() => _RatingPickerDialogState();
}

class _RatingPickerDialogState extends State<RatingPickerDialog> {

  // Toutes les jauges, regroupées par type : { "rond": [jaune, rouge…] }
  late final Future<Map<String, List<Rating>>> _ratingsByType = _loadRatings();

  // Type choisi à l'étape 1 (null = on est à l'étape 1)
  String? _selectedType;


  //////////////////////////////////////////////////////
  //                   CHARGEMENT                     //
  //////////////////////////////////////////////////////

  /// Charge les jauges et les regroupe par type, jaune en premier.
  Future<Map<String, List<Rating>>> _loadRatings() async {
    final List<Rating> ratings = await RatingService().getAllRatings();
    final Map<String, List<Rating>> byType = {};
    for (final Rating rating in ratings) {
      byType.putIfAbsent(rating.name, () => []).add(rating);
    }
    for (final List<Rating> colors in byType.values) {
      colors.sort((a, b) {
        // La couleur par défaut d'abord, puis ordre alphabétique
        if (a.color == RatingService.defaultColor) return -1;
        if (b.color == RatingService.defaultColor) return 1;
        return (a.color ?? '').compareTo(b.color ?? '');
      });
    }
    return byType;
  }


  //////////////////////////////////////////////////////
  //                     BUILD                        //
  //////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final String? type = _selectedType;

    return AlertDialog(
      title: Row(
        children: [
          // Étape 2 : flèche pour revenir au choix du type
          if (type != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _selectedType = null),
            ),
          Text(type == null ? 'Choisir une jauge' : 'Couleur : $type'),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 420,
        child: FutureBuilder<Map<String, List<Rating>>>(
          future: _ratingsByType,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Erreur : ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final byType = snapshot.data!;
            return type == null
                ? _buildTypeGrid(byType)
                : _buildColorGrid(byType[type] ?? []);
          },
        ),
      ),
      actions: [
        if (type == null)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle jauge'),
            onPressed: _createCustomRating,
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }

  /// Étape 1 : un aperçu par type (couleur par défaut, plein + vide).
  Widget _buildTypeGrid(Map<String, List<Rating>> byType) {
    if (byType.isEmpty) return const Center(child: Text('Aucune jauge'));
    final List<String> types = byType.keys.toList();

    return _grid(
      itemCount: types.length,
      itemBuilder: (index) {
        final String type = types[index];
        final List<Rating> colors = byType[type]!;
        return _RatingTile(
          rating: colors.first, // jaune si disponible (tri plus haut)
          label: type,
          showEmpty: true,
          onTap: () {
            // Une seule couleur : pas d'étape 2
            if (colors.length == 1) {
              Navigator.pop(context, colors.first.id);
            } else {
              setState(() => _selectedType = type);
            }
          },
        );
      },
    );
  }

  /// Étape 2 : une case par couleur du type choisi.
  Widget _buildColorGrid(List<Rating> colors) {
    return _grid(
      itemCount: colors.length,
      itemBuilder: (index) {
        final Rating rating = colors[index];
        return _RatingTile(
          rating: rating,
          label: rating.color ?? rating.name,
          showEmpty: false,
          onTap: () => Navigator.pop(context, rating.id),
        );
      },
    );
  }

  /// Grille commune aux deux étapes.
  Widget _grid({required int itemCount, required Widget Function(int) itemBuilder}) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => itemBuilder(index),
    );
  }

  /// « Nouvelle jauge » : crée une jauge personnalisée et la choisit.
  Future<void> _createCustomRating() async {
    final String? id = await showDialog<String>(
      context: context,
      builder: (context) => const _CustomRatingDialog(),
    );
    if (id != null && mounted) Navigator.pop(context, id);
  }
}


//////////////////////////////////////////////////////
//                CASE D'UNE JAUGE                  //
//////////////////////////////////////////////////////

/// Case cliquable : image pleine (+ vide si [showEmpty]) et un nom.
class _RatingTile extends StatelessWidget {
  final Rating rating;
  final String label;
  final bool showEmpty;
  final VoidCallback onTap;

  const _RatingTile({
    required this.rating,
    required this.label,
    required this.showEmpty,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: FutureBuilder<RatingImages>(
                  future: RatingImages.load(rating.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final images = snapshot.data!;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: Image.memory(images.full, fit: BoxFit.contain)),
                        if (showEmpty) ...[
                          const SizedBox(width: 4),
                          Flexible(child: Image.memory(images.empty, fit: BoxFit.contain)),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}


//////////////////////////////////////////////////////
//             NOUVELLE JAUGE PERSONNALISÉE         //
//////////////////////////////////////////////////////

/// Nom + image pleine + image vide → jauge personnalisée (une couleur).
/// Retourne l'ID de la jauge créée, ou null si annulé.
class _CustomRatingDialog extends StatefulWidget {
  const _CustomRatingDialog();

  @override
  State<_CustomRatingDialog> createState() => _CustomRatingDialogState();
}

class _CustomRatingDialogState extends State<_CustomRatingDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _fullPath;
  String? _emptyPath;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Tout est rempli : le bouton Créer devient actif.
  bool get _isComplete =>
      _nameController.text.trim().isNotEmpty && _fullPath != null && _emptyPath != null;

  /// Choix d'une image sur l'ordinateur.
  Future<String?> _pickImage() async {
    final XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery);
    return file?.path;
  }

  Future<void> _create() async {
    try {
      final String id = await RatingService()
          .addCustomRating(_nameController.text, _fullPath!, _emptyPath!);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      // Ex. nom déjà utilisé : affiché dans la fenêtre
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle jauge'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Nom de la jauge'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildImageChoice(
                    label: 'Image pleine',
                    path: _fullPath,
                    onPick: () async {
                      final path = await _pickImage();
                      if (path != null) setState(() => _fullPath = path);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildImageChoice(
                    label: 'Image vide',
                    path: _emptyPath,
                    onPick: () async {
                      final path = await _pickImage();
                      if (path != null) setState(() => _emptyPath = path);
                    },
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _isComplete ? _create : null,
          child: const Text('Créer'),
        ),
      ],
    );
  }

  /// Aperçu de l'image choisie (ou cadre vide) + bouton pour la choisir.
  Widget _buildImageChoice({
    required String label,
    required String? path,
    required VoidCallback onPick,
  }) {
    return Column(
      children: [
        Container(
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: path == null
              ? const Icon(Icons.image_outlined)
              : Image.file(File(path), fit: BoxFit.contain),
        ),
        const SizedBox(height: 6),
        OutlinedButton(onPressed: onPick, child: Text(label)),
      ],
    );
  }
}
