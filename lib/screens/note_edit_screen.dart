import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mythopolis/models/note.dart';
import 'package:mythopolis/providers/note_provider.dart';
import 'package:mythopolis/screens/note_read_screen.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; 

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


  //////////////////////////////////////////////////////
  //                 INITIALISATION                   //
  //////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();

    // Charger le contenu existant ou créer un document vide
    final content = widget.note.content;
    final doc = (content != null && content.isNotEmpty)
        ? Document.fromJson(jsonDecode(content))
        : Document();

    _quillController = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    // OBLIGATOIRE : libérer la mémoire du contrôleur quand l'écran est détruit
    _quillController.dispose();
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
          title: Text(widget.note.name),
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
              icon: Icon(Icons.image),  // ou tout autre widget
              onSelected: (value) {
                // value = la string du PopupMenuItem sélectionné
                if (value == 'add') _pickBanner();
                if (value == 'remove') _removeBanner();
                if (value == 'crop') _cropBanner();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'add',
                  child: Text('Ajouter un bandeau'),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Supprimer'),
                ),
                PopupMenuItem(
                  value: 'crop',
                  child: Text('Recadrer'),
                ),
              ],
            )
          ],
        ),
        body: _buildEditor(),
      ),
    );
  }


  //////////////////////////////////////////////////////
  //                    ÉDITEUR                       //
  //////////////////////////////////////////////////////

  /// Éditeur Quill avec barre d'outils et marges latérales
  Widget _buildEditor() {
    return Column(
      children: [
        // Barre d'outils de mise en forme — prend toute la largeur
        QuillSimpleToolbar(
          controller: _quillController,
          config: QuillSimpleToolbarConfig(
            embedButtons: FlutterQuillEmbeds.toolbarButtons(),
            buttonOptions: QuillSimpleToolbarButtonOptions(
              fontFamily: QuillToolbarFontFamilyButtonOptions(
                items: const {
                  'Cardo': 'Cardo',
                  'EB Garamond': 'EBGaramond',
                  'Cinzel': 'Cinzel',
                  'MedievalSharp': 'MedievalSharp',
                  'UnifrakturMaguntia': 'UnifrakturMaguntia',
                  'Pirata One': 'PirataOne',
                  'Orbitron': 'Orbitron',
                  'Audiowide': 'Audiowide',
                  'Lexend': 'Lexend',
                },
              ),
            ),
          ),
        ),
        
        if (widget.note.bannerPath != null)
            Container(
              height: 135,
              width: double.infinity,
              child: Image.file(File(widget.note.bannerPath!), fit: BoxFit.cover),
              
            ), 
          // Affichage du contenu en lecture seule avec marges
        // Zone d'édition avec marges latérales
        Expanded(
          child: Container(
            // Marges latérales pour aérer l'écriture
            padding: const EdgeInsets.symmetric(
              horizontal: 64,  // marge gauche/droite
              vertical: 24,    // marge haut/bas
            ),
            child: QuillEditor.basic(
              controller: _quillController,
              config: QuillEditorConfig(
                embedBuilders: FlutterQuillEmbeds.editorBuilders(),
              ),
            ),
          ),
        ),
      ],
    );
  }


  ///////////////////////////////////////////////////
  //                 Bannière                      //
  ///////////////////////////////////////////////////

  Future<void> _pickBanner() async{
    final picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);
    await context.read<NoteProvider>().pickBanner(widget.note.id,image);
  } 


  Future<void> _removeBanner() async{
    await context.read<NoteProvider>().removeBanner(widget.note.id);
  }


  Future<void> _cropBanner() async{
    await context.read<NoteProvider>().cropBanner(widget.note.id);
  }

  //////////////////////////////////////////////////////
  //                  SAUVEGARDE                      //
  //////////////////////////////////////////////////////

  /// Sauvegarde le contenu Delta JSON dans la base de données
  Future<void> _saveNote() async {
    await context.read<NoteProvider>().changeNote(
      widget.note.id,
      null,  // on ne change pas le nom
      null,  // on ne change pas le dossier parent
      jsonEncode(_quillController.document.toDelta().toJson()),
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
  void _goToReadScreen(BuildContext context) {
    _saveNote();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteReadScreen(note: widget.note),
      ),
    );
  }
}