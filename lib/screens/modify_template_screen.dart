import 'dart:io';
import 'package:mythopolis/models/page_model.dart';
import 'package:mythopolis/models/template.dart';
import 'package:mythopolis/providers/page_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';


//////////////////////////////////////////////////////
//                   WIDGET PRINCIPAL               //
//////////////////////////////////////////////////////

class ModifyTemplateScreen extends StatefulWidget {
  final Template template;

  const ModifyTemplateScreen({super.key, required this.template});

  @override
  State<ModifyTemplateScreen> createState() => _ModifyTemplateScreenState();
}

class _ModifyTemplateScreenState extends State<ModifyTemplateScreen> {
  int currentPage = 0;
  bool _showPagePanel = false;


  //////////////////////////////////////////////////////
  //                 INITIALISATION                   //
  //////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();
    // Charge les pages de la template
    Future.microtask(() =>
      context.read<PageProvider>().loadPagesFromTemplate(widget.template.id)
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageProvider = context.watch<PageProvider>();
    List<PageModel> allpages = pageProvider.getPages();

    if (allpages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final String? chemin = allpages[currentPage].backgroundPath;

    return Scaffold(
      appBar: AppBar(title: Text(widget.template.name)),
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
                      ),
                    );
                  },
                ),

                if (_showPagePanel)
                  GestureDetector(
                    onTap: () => setState(() => _showPagePanel = false),
                  ),

                if (_showPagePanel)
                  Positioned(
                    top: 0, bottom: 0, right: 0,
                    child: Container(
                      width: 200,
                      color: Colors.cyan,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 60,
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        border: Border(bottom: BorderSide(color: Colors.black)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.text_fields),
              tooltip: 'Ajouter du texte',
              onPressed: () { /* à venir */ },
            ),
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'Ajouter une zone de texte',
              onPressed: () { /* à venir */ },
            ),
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Ajouter une zone photo',
              onPressed: () { /* à venir */ },
            ),
            IconButton(
              icon: const Icon(Icons.star_half_rounded),
              tooltip: 'Ajouter une jauge',
              onPressed: () { /* à venir */ },
            ),
            IconButton(
              icon: const Icon(Icons.wallpaper),
              tooltip: "Changer l'image de fond",
              onPressed: () { /* à venir */ },
            ),
            IconButton(
              icon: const Icon(Icons.layers_rounded),
              tooltip: 'Gérer les pages',
              onPressed: () => setState(() => _showPagePanel = !_showPagePanel),
            ),
          ],
        ),
      ),
    );
  }
}