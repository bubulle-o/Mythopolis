import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:mythopolis/models/folder.dart';
import 'package:mythopolis/models/note.dart';
import 'package:mythopolis/screens/folder_screen.dart';
import 'package:mythopolis/screens/note_edit_screen.dart';
import 'package:mythopolis/services/folder_service.dart';
import 'dart:convert';
import 'package:mythopolis/services/note_service.dart';
import 'dart:io';

import 'package:mythopolis/providers/settings_provider.dart';
import 'package:mythopolis/utils/enum.dart';
import 'package:provider/provider.dart';


//////////////////////////////////////////////////////
//                   WIDGET PRINCIPAL               //
//////////////////////////////////////////////////////

class NoteReadScreen extends StatefulWidget {
  final Note note;

  const NoteReadScreen({super.key, required this.note});

  @override
  State<NoteReadScreen> createState() => _NoteReadScreenState();
}

class _NoteReadScreenState extends State<NoteReadScreen> {

  // Contrôleur Quill en lecture seule
  late QuillController _quillController;


  //////////////////////////////////////////////////////
  //                 INITIALISATION                   //
  //////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();

    // Charger le contenu existant ou document vide
    final content = widget.note.content;
    final doc = (content != null && content.isNotEmpty)
        ? Document.fromJson(jsonDecode(content))
        : Document();

    _quillController = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,  // lecture seule — l'utilisateur ne peut pas modifier
    );
  }

  @override
  void dispose() {
    _quillController.dispose();
    super.dispose();
  }


  //////////////////////////////////////////////////////
  //                     BUILD                        //
  //////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note.name),
        actions: [
          // Bouton pour passer en mode édition
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _goToEditScreen(context),
          ),
        ],
      ),
      body: _buildScrollingContent(),
    );
  }

  /// Bannière, texte et fond défilent ENSEMBLE : c'est le
  /// SingleChildScrollView qui défile, l'éditeur Quill ne défile plus
  /// lui-même (scrollable: false). La bannière disparaît en descendant.
  ///
  /// Le fond (thème clair uniquement) est une image à la largeur de la
  /// fenêtre, répétée verticalement bout à bout (ImageRepeat.repeatY) :
  /// plus le texte est long, plus il y a de copies, comme une image infinie.
  /// Il commence sous la bannière.
  Widget _buildScrollingContent() {
    final bool isLight =
        context.watch<SettingsProvider>().appTheme == AppTheme.light;
    final bool hasBanner = widget.note.bannerPath != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            children: [
              // Bannière (défile avec le texte)
              if (hasBanner)
                SizedBox(
                  height: kNoteBannerHeight,
                  width: double.infinity,
                  child: Image.file(
                    File(widget.note.bannerPath!),
                    fit: BoxFit.cover,
                    alignment: widget.note.bannerAlignment.toFlutterAlignment(),
                  ),
                ),
              _buildTextOnBackground(
                // Le fond couvre au moins le reste de l'écran, même
                // quand la note est courte
                minHeight: constraints.maxHeight - (hasBanner ? kNoteBannerHeight : 0),
                isLight: isLight,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Le texte de la note sur le fond "parchemin" répété.
  Widget _buildTextOnBackground({required double minHeight, required bool isLight}) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: isLight
          ? const BoxDecoration(
              image: DecorationImage(
                image: _scrollBackground,
                fit: BoxFit.fitWidth,           // largeur de la fenêtre
                alignment: Alignment.topCenter, // 1re copie en haut
                repeat: ImageRepeat.repeatY,    // copies vers le bas
              ),
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 24),
      child: QuillEditor.basic(
        controller: _quillController,
        config: QuillEditorConfig(
          scrollable: false, // c'est le SingleChildScrollView qui défile
          onLaunchUrl: _handleLinkTap,
          embedBuilders: FlutterQuillEmbeds.editorBuilders(),
        ),
      ),
    );
  }

  /// Fond de lecture du thème clair. L'image d'origine fait 2480 × 3508 px
  /// (2,6 Mo) : ResizeImage la décode à 1920 px de large, largement assez
  /// pour un écran, et ~2× moins lourd en mémoire.
  static const ImageProvider _scrollBackground = ResizeImage(
    AssetImage('lib/graphism/light_theme/scroll_background.jpg'),
    width: 1920,
  );



  //////////////////////////////////////////////////////
  //                   NAVIGATION                     //
  //////////////////////////////////////////////////////

  /// Navigation vers l'écran d'édition
  Future<void> _goToEditScreen(BuildContext context) async{
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditScreen(note: widget.note),
      ),
    );
  }


  //////////////////////////////////////////////////////
  //                     LIENS                        //
  //////////////////////////////////////////////////////

  /// Gère les liens internes de l'application.
  /// Un lien vers une note ou un dossier ouvre l'écran correspondant,
  /// les autres liens sont ignorés.
  Future<void> _handleLinkTap(String url) async {
    if (url.substring(8).startsWith('note_')) {
      Note note = await NoteService().loadNote(url.substring(8));
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NoteReadScreen(note: note)),
      );
    }

    if (url.substring(8).startsWith('folder_')) {
      Folder folder = await FolderService().loadFolder(url.substring(8));
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FolderScreen(folder: folder)),
      );
    } else {
      return;
    }
  }
}