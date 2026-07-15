import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mythopolis/providers/template_provider.dart';
import 'package:mythopolis/utils/enum.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;

/// Popup de choix du format d'un nouvelle template.
/// Trois modes : format prédéfini, dimensions personnalisées, image de fond.
/// Le mode retenu est celui de l'onglet actif au moment de valider.
class CreateTemplateDialog extends StatefulWidget {
  final String name; // le nom saisi dans la popup précédente
  const CreateTemplateDialog({super.key, required this.name});

  @override
  State<CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<CreateTemplateDialog>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;

  // Onglet 1 — format prédéfini
  CanvasFormat _preset = CanvasFormat.a4;
  bool _isPortrait = true;

  // Onglet 2 — dimensions personnalisées

  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();

  // Onglet 3 — image de fond
  String? _imagePath;
  String? _imageName;
  int _imageWidth = 0;
  int _imageHeight = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _heightController.dispose();
    _widthController.dispose();
    super.dispose();
  }

  //////////////////////////////////////////////////////
  //                     BUILD                        //
  //////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    
    return Dialog(
      child: SizedBox(
        width: 400,
        height: 450,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                widget.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Prédéfini'),
                Tab(text: 'Sélecteur'),
                Tab(text: 'Image'),
              ],
            ),

            // Expanded donne au TabBarView la hauteur restante de la Column.
            // Sans lui, le TabBarView n'a aucune hauteur et Flutter plante.
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPresetTab(),
                  _buildSelector(),
                  _buildImageSelector()
                ],
              ),
            ),

            _buildActions(),
          ],
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////
  //                 ONGLET PRÉDÉFINI                 //
  //////////////////////////////////////////////////////

  Widget _buildPresetTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Orientation
          RadioGroup<bool>(
            groupValue: _isPortrait,
            onChanged: (value) => setState(() => _isPortrait = value!),
            child: Column(
              children: [
                RadioListTile<bool>(title: Text('Portrait'), value: true),
                RadioListTile<bool>(title: Text('Paysage'), value: false),
              ],
            ),
          ),

          Divider(),

          // Formats : générés depuis l'enum, donc ajouter un format
          // dans CanvasFormat suffit à le faire apparaître ici.
          RadioGroup<CanvasFormat>(
            groupValue: _preset,
            onChanged: (value) => setState(() => _preset = value!),
            child: Column(
              children: CanvasFormat.values.map((format) {
                return RadioListTile<CanvasFormat>(
                  title: Text(format.label),
                  subtitle: Text('${format.width} × ${format.height} px'),
                  value: format,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }


  //////////////////////////////////////////////////////
  //                 ONGLET SÉLÉCTEUR                 //
  //////////////////////////////////////////////////////

  Widget _buildSelector(){
    return Column(
      children: [
        TextField(
          controller: _widthController,
          decoration: InputDecoration(hintText: 'Largeur (<2048)'),
          keyboardType: TextInputType.number
        ),
        TextField(
          controller: _heightController,
          decoration: InputDecoration(hintText: 'Hauteur (<2048)'),
          keyboardType: TextInputType.number 
        )
      ]
    );

  }

  ////////////////////////////////////////////////////////
  //                    ONGLET IMAGE                    //
  ////////////////////////////////////////////////////////
  
  Widget _buildImageSelector(){
    return Column(
      children: [
        TextButton(
            onPressed: _pickImage,
            child: Text("Choix d'une image"),
          ),
        if(_imageName == null)
          Center(child: Text("Pas d'image sélectionnée."))
        else 
          Center(child: Text('Image sélectionnée : ${_imageName!}'))
        
      ],
      
    );

  }


  Future<void> _pickImage() async {
  final picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final Uint8List bytes = await image.readAsBytes();
    final ui.Image decoded = await decodeImageFromList(bytes);
    final int w = decoded.width;
    final int h = decoded.height;
    decoded.dispose();

    if (!mounted) return;

    int targetW = w;
    int targetH = h;

    if (w > 2048 || h > 2048) {
      // confirmation utilisateur (voir plus bas)
      final bool ok = await _confirmCompression();
      if (!ok) return; // elle refuse → on annule l'import

      // le plus grand côté doit devenir 2048
      double factor = 2048 / (w > h ? w : h);
      targetW = (w * factor).round();
      targetH = (h * factor).round();
    }

    setState(() {
      _imagePath = image.path;
      _imageName = image.name;
      _imageWidth = targetW;
      _imageHeight = targetH;
    });
  }

  Future<bool> _confirmCompression() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Image trop grande'),
        content: Text('Cette image dépasse 2048 px et va être compressée. Continuer ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),  // ← renvoie false
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),   // ← renvoie true
            child: Text('Continuer'),
          ),
        ],
      ),
    );

    return result ?? false;   // null (fermé sans choisir) → considéré comme "non"
  }

  //////////////////////////////////////////////////////
  //                    VALIDATION                    //
  //////////////////////////////////////////////////////

  Widget _buildActions() {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: _onCreate,
            child: Text('Créer'),
          ),
        ],
      ),
    );
  }

  /// Résout les dimensions du canvas selon l'onglet actif.
  /// Retourne null si le mode actif n'est pas exploitable.
  (int, int)? _resolveCanvasSize() {
    switch (_tabController.index) {
      case 0:
        if(_isPortrait){
          return (_preset.width, _preset.height);
        }
        else {
          return (_preset.height,_preset.width);
        }
        
      case 1:
        int? customHeight = int.tryParse(_heightController.text);
        int? customWidth = int.tryParse(_widthController.text);

        if(customHeight == null || customWidth == null || customHeight > 2048 ||customWidth > 2048 || customHeight < 1 || customWidth < 1){
          throw Exception('Les longueurs fournies ne sont pas comprises entre 1 et 2048.'); 
        }
        
        return (customWidth , customHeight);

      case 2:
        if (_imagePath == null) {
          throw Exception('Aucune image sélectionnée.');
        }
        return (_imageWidth, _imageHeight);
    }
    return null;
  }


  void _onCreate() async {
    try {
      final size = _resolveCanvasSize();

      if (size == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Format incomplet')),
        );
        return;
      }

      String? backgroundPath;
      if (_tabController.index == 2) {
        backgroundPath = _imagePath;
      }

      await context.read<TemplateProvider>().createTemplate(
        widget.name, size.$1, size.$2, backgroundPath,
      );

      if (!mounted) return;
      Navigator.pop(context);
      // TODO : ouvrir l'éditeur
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}