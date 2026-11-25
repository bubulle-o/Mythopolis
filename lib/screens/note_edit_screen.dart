import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mythopolis/models/note.dart';
import 'package:mythopolis/providers/note_provider.dart';
import 'package:mythopolis/screens/note_read_screen.dart';
import 'package:mythopolis/screens/widgets/quill_toolbar_editor.dart';
import 'package:mythopolis/services/note_service.dart';
import 'package:mythopolis/utils/enum.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' as math;


//////////////////////////////////////////////////////
//                   WIDGET PRINCIPAL               //
//////////////////////////////////////////////////////

class NoteEditScreen extends StatefulWidget {
  final Note note;

  const NoteEditScreen({super.key, required this.note});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {

  // Contrôleur Quill — gère le contenu ET l'historique Ctrl+Z nativement
  late QuillController _quillController;
  // Défilement de la page (bannière + texte), partagé avec l'éditeur
  final ScrollController _scrollController = ScrollController();
  late int _selectedHorizontal;
  late int _selectedVertical;
  late Note _currentNote;


  //////////////////////////////////////////////////////
  //                 INITIALISATION                   //
  //////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();

    _currentNote = widget.note;

    // Charger le contenu existant ou créer un document vide
    final content = widget.note.content;
    final doc = (content != null && content.isNotEmpty)
        ? Document.fromJson(jsonDecode(content))
        : Document();

    _quillController = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _selectedHorizontal = divideAlignmentH(widget.note.bannerAlignment);
    _selectedVertical = divideAlignmentV(widget.note.bannerAlignment);
  }

  @override
  void dispose() {
    // OBLIGATOIRE : libérer la mémoire du contrôleur quand l'écran est détruit
    _quillController.dispose();
    _scrollController.dispose();
    super.dispose();
  }


  //////////////////////////////////////////////////////
  //                     BUILD                        //
  //////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // Intercepte le bouton retour — affiche le dialog de sauvegarde
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showSaveDialog(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentNote.name),
          actions: [
            // Bouton enregistrer
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveNote,
            ),
            IconButton(
              icon: const Icon(Icons.remove_red_eye_rounded),
              onPressed: () => _goToReadScreen(context),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.image),
              onSelected: (value) {
                // value = la string du PopupMenuItem sélectionné
                if (value == 'add') _pickBanner();
                if (value == 'remove') _removeBanner();
                if (value == 'crop') _changeBannerAlignment();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'add', child: Text('Ajouter un bandeau')),
                const PopupMenuItem(value: 'remove', child: Text('Supprimer')),
                const PopupMenuItem(value: 'crop', child: Text('Recadrer')),
              ],
            ),
          ],
        ),
        body: _buildEditor(),
      ),
    );
  }


  //////////////////////////////////////////////////////
  //                    ÉDITEUR                       //
  //////////////////////////////////////////////////////

  /// Assemble : barre d'outils (fixe en haut), puis une zone qui défile
  /// contenant la bannière de la note (si elle existe) et le texte.
  /// La bannière défile avec le texte : elle disparaît quand on descend.
  Widget _buildEditor() {
    const double verticalPadding = 24;

    return Column(
      children: [
        // Barre d'outils réutilisable — ne connaît que le controller.
        // Hors de la zone qui défile : toujours visible.
        QuillToolbar(controller: _quillController),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool hasBanner = _currentNote.bannerPath != null;
              // Hauteur minimale de l'éditeur : le reste de l'écran sous
              // la bannière, pour qu'un clic n'importe où sous le texte
              // place bien le curseur.
              final double editorMinHeight = math.max(
                0,
                constraints.maxHeight
                    - (hasBanner ? kNoteBannerHeight : 0)
                    - 2 * verticalPadding,
              );

              return SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    // Bannière de la note
                    if (hasBanner)
                      SizedBox(
                        height: kNoteBannerHeight,
                        width: double.infinity,
                        child: Image.file(
                          File(_currentNote.bannerPath!),
                          key: ValueKey(DateTime.now().millisecondsSinceEpoch),
                          fit: BoxFit.cover,
                          alignment: _currentNote.bannerAlignment.toFlutterAlignment(),
                        ),
                      ),

                    // Zone d'édition avec marges latérales
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 64,             // marge gauche/droite
                        vertical: verticalPadding,  // marge haut/bas
                      ),
                      child: QuillEditor.basic(
                        controller: _quillController,
                        // MÊME contrôleur que le SingleChildScrollView :
                        // l'éditeur ne défile plus lui-même (scrollable:
                        // false), mais s'en sert pour faire défiler la page
                        // et garder le curseur visible pendant la frappe.
                        scrollController: _scrollController,
                        config: QuillEditorConfig(
                          scrollable: false,
                          minHeight: editorMinHeight,
                          embedBuilders: FlutterQuillEmbeds.editorBuilders(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  ///////////////////////////////////////////////////
  //                 Bannière                      //
  ///////////////////////////////////////////////////

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);
    await context.read<NoteProvider>().pickBanner(_currentNote.id, image);
    // Recharger et rafraîchir
    final freshNote = await NoteService().loadNote(_currentNote.id);
    setState(() {
      _currentNote = freshNote;
    });
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  Future<void> _removeBanner() async {
    await context.read<NoteProvider>().removeBanner(_currentNote.id);
    // Recharger et rafraîchir
    final freshNote = await NoteService().loadNote(_currentNote.id);
    setState(() {
      _currentNote = freshNote;
    });
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  Future<void> _changeBannerAlignment() async {
    _selectedHorizontal = divideAlignmentH(_currentNote.bannerAlignment);
    _selectedVertical = divideAlignmentV(_currentNote.bannerAlignment);
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: const Text("Changer l'alignement de la banière"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                RadioGroup<int>(
                  groupValue: _selectedHorizontal,
                  onChanged: (value) => dialogSetState(() => _selectedHorizontal = value!),
                  child: const Column(
                    children: [
                      RadioListTile<int>(
                        title: Text('Gauche'),
                        value: 0,
                      ),
                      RadioListTile<int>(
                        title: Text('Centre'),
                        value: 1,
                      ),
                      RadioListTile<int>(
                        title: Text('Droite'),
                        value: 2,
                      ),
                    ],
                  ),
                ),

                const Divider(),

                RadioGroup<int>(
                  groupValue: _selectedVertical,
                  onChanged: (value) => dialogSetState(() => _selectedVertical = value!),
                  child: const Column(
                    children: [
                      RadioListTile<int>(
                        title: Text('Haut'),
                        value: 0,
                      ),
                      RadioListTile<int>(
                        title: Text('Centre'),
                        value: 1,
                      ),
                      RadioListTile<int>(
                        title: Text('Bas'),
                        value: 2,
                      ),
                    ],
                  ),
                ), // bas
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  BannerAlignment alignment = combineAlignment(_selectedHorizontal, _selectedVertical);
                  await context.read<NoteProvider>().changeBannerAlignment(_currentNote.id, alignment);
                  final freshNote = await NoteService().loadNote(_currentNote.id);
                  setState(() {
                    _currentNote = freshNote;
                  });
                  imageCache.clear();
                  imageCache.clearLiveImages();
                  Navigator.pop(dialogContext);
                } catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  // switch sur les 9 combinaisons possibles
  BannerAlignment combineAlignment(int horizontal, int vertical) {
    if (horizontal < 0 || horizontal > 2 || vertical < 0 || vertical > 2) {
      return _currentNote.bannerAlignment;
    }

    if (vertical == 0) {
      if (horizontal == 0) {
        return BannerAlignment.topLeft;
      } else if (horizontal == 1) {
        return BannerAlignment.topCenter;
      } else {
        return BannerAlignment.topRight;
      }
    }

    if (vertical == 1) {
      if (horizontal == 0) {
        return BannerAlignment.centerLeft;
      } else if (horizontal == 1) {
        return BannerAlignment.center;
      } else {
        return BannerAlignment.centerRight;
      }
    }

    else {
      if (horizontal == 0) {
        return BannerAlignment.bottomLeft;
      } else if (horizontal == 1) {
        return BannerAlignment.bottomCenter;
      } else {
        return BannerAlignment.bottomRight;
      }
    }
  }

  int divideAlignmentH(BannerAlignment alignement) {
    if (alignement == BannerAlignment.topLeft ||
        alignement == BannerAlignment.centerLeft ||
        alignement == BannerAlignment.bottomLeft) {
      return 0;
    } else if (alignement == BannerAlignment.topCenter ||
        alignement == BannerAlignment.center ||
        alignement == BannerAlignment.bottomCenter) {
      return 1;
    } else {
      return 2;
    }
  }

  int divideAlignmentV(BannerAlignment alignement) {
    if (alignement == BannerAlignment.topLeft ||
        alignement == BannerAlignment.topCenter ||
        alignement == BannerAlignment.topRight) {
      return 0;
    } else if (alignement == BannerAlignment.centerLeft ||
        alignement == BannerAlignment.center ||
        alignement == BannerAlignment.centerRight) {
      return 1;
    } else {
      return 2;
    }
  }

  //////////////////////////////////////////////////////
  //                  SAUVEGARDE                      //
  //////////////////////////////////////////////////////

  /// Sauvegarde le contenu Delta JSON dans la base de données
  Future<void> _saveNote() async {
    await context.read<NoteProvider>().changeNote(
      _currentNote.id,
      null, // on ne change pas le nom
      null, // on ne change pas le dossier parent
      jsonEncode(_quillController.document.toDelta().toJson()),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note sauvegardée'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Dialog affiché quand l'utilisateur quitte sans sauvegarder
  Future<void> _showSaveDialog(BuildContext screenContext) async {
    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Voulez-vous enregistrer les modifications ?'),
        actions: [
          // Quitter sans sauvegarder
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // ferme le dialog
              Navigator.pop(screenContext); // ferme NoteEditScreen
              Navigator.pop(screenContext); // ferme NoteReadScreen → retour FolderScreen
            },
            child: const Text('Non'),
          ),
          // Sauvegarder puis quitter
          TextButton(
            onPressed: () async {
              await _saveNote();
              Navigator.pop(dialogContext); // ferme le dialog
              Navigator.pop(screenContext); // ferme NoteEditScreen
              Navigator.pop(screenContext); // ferme NoteReadScreen → retour FolderScreen
            },
            child: const Text('Oui'),
          ),
        ],
      ),
    );
  }


  //////////////////////////////////////////////////////
  //                   NAVIGATION                     //
  //////////////////////////////////////////////////////

  /// Navigation vers l'écran de lecture
  Future<void> _goToReadScreen(BuildContext context) async {
    await _saveNote();
    Note freshNote = await NoteService().loadNote(_currentNote.id);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => NoteReadScreen(note: freshNote),
      ),
    );
  }
}