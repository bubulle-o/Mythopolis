import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mythopolis/models/note.dart';
import 'package:mythopolis/providers/note_provider.dart';
import 'package:mythopolis/screens/note_read_screen.dart';
import 'package:mythopolis/services/note_service.dart';
import 'package:mythopolis/utils/enum.dart';
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
  late int _selectedHorizontal;
  late int _selectedVertical;
  late Note _currentNote;


  //////////////////////////////////////////////////////
  //                 INITIALISATION                   //
  //////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();

    _currentNote= widget.note;

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
              icon: Icon(Icons.image),  // ou tout autre widget
              onSelected: (value) {
                // value = la string du PopupMenuItem sélectionné
                if (value == 'add') _pickBanner();
                if (value == 'remove') _removeBanner();
                if (value == 'crop') _changeBannerAlignment();
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
        
        if (_currentNote.bannerPath != null)
            Container(
              height: 135,
              width: double.infinity,
              child: Image.file(File(_currentNote.bannerPath!), key: ValueKey(DateTime.now().millisecondsSinceEpoch), fit: BoxFit.cover, alignment: _currentNote.bannerAlignment.toFlutterAlignment()),
              
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

  //////////////////////////////////////////////////
  //                    LENS                      //
  //////////////////////////////////////////////////



  ///////////////////////////////////////////////////
  //                 Bannière                      //
  ///////////////////////////////////////////////////

  Future<void> _pickBanner() async{
    final picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);
    await context.read<NoteProvider>().pickBanner(_currentNote.id,image);
    // Recharger et rafraîchir
    final freshNote = await NoteService().loadNote(_currentNote.id);
    setState(() {
      _currentNote = freshNote;
    });
    imageCache.clear();
    imageCache.clearLiveImages();
  } 


  Future<void> _removeBanner() async{
    await context.read<NoteProvider>().removeBanner(_currentNote.id);
    // Recharger et rafraîchir
    final freshNote = await NoteService().loadNote(_currentNote.id);
    setState(() {
      _currentNote = freshNote;
    });
    imageCache.clear();
    imageCache.clearLiveImages();
    
  }


  Future<void> _changeBannerAlignment() async{
    _selectedHorizontal = divideAlignmentH(_currentNote.bannerAlignment);
    _selectedVertical = divideAlignmentV(_currentNote.bannerAlignment);
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: Text("Changer l'alignement de la banière"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                RadioGroup<int>(
                  groupValue: _selectedHorizontal,
                  onChanged: (value) => dialogSetState(() => _selectedHorizontal = value!),
                  child: Column(
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

                Divider(),

                RadioGroup<int>(
                  groupValue: _selectedVertical,
                  onChanged: (value) => dialogSetState (() => _selectedVertical = value!),
                  child: Column(
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
                ),// bas
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  BannerAlignment alignment = combineAlignment(_selectedHorizontal,_selectedVertical);
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
              child: Text('Valider'),
            ),
          ],
        ),
      )
    );
  }

  // switch sur les 9 combinaisons possibles
  BannerAlignment combineAlignment(int horizontal, int vertical) {
    if(horizontal<0 || horizontal>2 ||vertical<0 || vertical>2){
      return _currentNote.bannerAlignment;
    }

    if(vertical == 0){
      if(horizontal == 0){
        return BannerAlignment.topLeft;
      }

      else if(horizontal == 1){
        return BannerAlignment.topCenter;
      }

      else{
        return BannerAlignment.topRight;
      }
    
    }

    if(vertical == 1){
      if(horizontal == 0){
        return BannerAlignment.centerLeft;
      }

      else if(horizontal == 1){
        return BannerAlignment.center;
      }

      else{
        return BannerAlignment.centerRight;
      }
    
    }

    else {
      if(horizontal == 0){
        return BannerAlignment.bottomLeft;
      }

      else if(horizontal == 1){
        return BannerAlignment.bottomCenter;
      }

      else{
        return BannerAlignment.bottomRight;
      }
    
    }
    
  } 

  int divideAlignmentH (BannerAlignment alignement) {
    
    if(alignement== BannerAlignment.topLeft || alignement== BannerAlignment.topCenter || alignement== BannerAlignment.topRight){
      return 0;
    
    }

    else if(alignement== BannerAlignment.centerLeft || alignement== BannerAlignment.center || alignement== BannerAlignment.centerRight){
      return 1;
    
    }

    else{
      return 2;
    }
    
  } 

  int divideAlignmentV (BannerAlignment alignement) {
    
    if(alignement== BannerAlignment.topLeft || alignement== BannerAlignment.centerLeft || alignement== BannerAlignment.bottomLeft){
      return 0;
    
    }

    else if(alignement== BannerAlignment.topCenter || alignement== BannerAlignment.center || alignement== BannerAlignment.bottomCenter){
      return 1;
    
    }

    else{
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
      null,  // on ne change pas le nom
      null,  // on ne change pas le dossier parent
      jsonEncode(_quillController.document.toDelta().toJson()),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
  Future<void> _goToReadScreen(BuildContext context) async{
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