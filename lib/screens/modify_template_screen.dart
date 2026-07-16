import 'dart:io';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:mythopolis/models/page_model.dart';
import 'package:mythopolis/models/template.dart';
import 'package:mythopolis/providers/page_provider.dart';
import 'package:mythopolis/providers/template_provider.dart';
import 'package:mythopolis/screens/note_edit_screen.dart';
import 'package:mythopolis/screens/widgets/quill_toolbar_editor.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';


//////////////////////////////////////////////////////
//                   WIDGET PRINCIPAL               //
//////////////////////////////////////////////////////

class ModifyTemplateScreen
 extends StatefulWidget {
  final Template template;
  
  const ModifyTemplateScreen({super.key, required this.template});

  @override
  State<ModifyTemplateScreen> createState() => _ModifyTemplateScreenState();
}
  
class _ModifyTemplateScreenState extends State<ModifyTemplateScreen> {
  late QuillController _quillController;
  int currentPage =0;
  bool _showPagePanel = false ;
  bool _quillEditor = false ;
  


  //////////////////////////////////////////////////////
  //                 INITIALISATION                   //
  //////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();
    
    // Charge les dossiers enfants du dossier courant
    Future.microtask(() => 
      context.read<PageProvider>().loadPagesFromTemplate(widget.template.id)
    );

    final content =null;
    final doc = (content != null && content.isNotEmpty)
        ? Document.fromJson(jsonDecode(content))
        : Document();

    _quillController = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageProvider = context.watch<PageProvider>();
    final String name = widget.template.name;
    List<PageModel> allpages = pageProvider.getPages();

    if (allpages.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }
    final String? chemin = allpages[currentPage].backgroundPath;

    return Scaffold(
      appBar: AppBar(title: const Text('Nom de la template')),
      body: Column(
        children: [ 
          _buildToolbar(),

          Expanded(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: widget.template.canvasWidth.toDouble(),
                          height: widget.template.canvasHeight.toDouble(),
                          child: chemin == null
                            ? Container(color: Colors.white)
                            : Image.file(File(chemin)),
                        ),
                      )
                    );
                  }
                ),

                if(_showPagePanel)
                GestureDetector(onTap: () => setState(() => _showPagePanel =false)),

                if(_showPagePanel)
                Positioned(
                  top: 0, bottom: 0, right: 0,   
                  child: Container(
                    width: 200,
                    color: Colors.cyan, 
                  )
                ),


                  
              ]
            )
          
          ),
        ]   
      ),
      bottomNavigationBar: Container(
        height: 60,
        // vide pour l'instant, ou une Row avec des placeholders
      ),
    );
  }

  Widget _buildToolbar(){
    if(_quillEditor){
      return Expanded(
          child: QuillToolbarEditor(controller: _quillController),
        );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,                          // fond léger
        border: Border(bottom: BorderSide(color: Colors.black) ),         // séparation
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,    // scrollable comme Quill
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.text_fields),
              tooltip: 'Ajouter du texte',
              onPressed: () { /* à venir */ },
            ),
            IconButton(
              icon: Icon(Icons.add_box_outlined),
              tooltip: 'Ajouter une zone de texte',
              onPressed: () { /* à venir */ },
            ),
            IconButton(
              icon: Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Ajouter une zone photo',
              onPressed: () { /* à venir */ },
            ),
            IconButton(
              icon: Icon(Icons.star_half_rounded),
              tooltip: 'Ajouter une jauge',
              onPressed: () { /* à venir */ },
            ),
            IconButton(
              icon: Icon(Icons.wallpaper),
              tooltip: "Changer l'image de fond",
              onPressed: () { /* à venir */ },
            ),
            IconButton(
              icon: Icon(Icons.layers_rounded),
              tooltip: 'Gérer les pages',
              onPressed: () => setState(() => _showPagePanel = true)
            )
          ],
        ),
      ),
    );
  }

}