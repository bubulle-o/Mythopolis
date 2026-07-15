import 'dart:io';

import 'package:mythopolis/models/page_model.dart';
import 'package:mythopolis/models/template.dart';
import 'package:mythopolis/providers/page_provider.dart';
import 'package:mythopolis/providers/template_provider.dart';
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

  int currentPage =0;


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
  }

  @override
  Widget build(BuildContext context) {
    final pageProvider = context.watch<PageProvider>();

    List<PageModel> allpages = pageProvider.getPages();

    if (allpages.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }
    final String? chemin = allpages[currentPage].backgroundPath;

    return Scaffold(
      appBar: AppBar(title: const Text("Barre d'outil")),
      body: LayoutBuilder(
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

        },
      ),
      bottomNavigationBar: Container(
        height: 60,
        // vide pour l'instant, ou une Row avec des placeholders
      ),
    );
  }

}