import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:mythopolis/models/crop_area.dart';
import 'package:mythopolis/models/page_model.dart';
import 'package:mythopolis/screens/widgets/background_crop_dialog.dart';
import 'package:mythopolis/models/template.dart';
import 'package:mythopolis/providers/page_provider.dart';
import 'package:mythopolis/screens/widgets/page_panel.dart';
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
  // Vrai pendant le recadrage/compression d'un fond (barre de progression)
  bool _isProcessingBackground = false;


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
    // Filet de sécurité : l'index ne doit jamais sortir de la liste
    currentPage = currentPage.clamp(0, allpages.length - 1);
    final String? chemin = allpages[currentPage].backgroundPath;

    return Scaffold(
      appBar: AppBar(title: Text(widget.template.name)),
      body: Column(
        children: [
          _buildToolbar(),
          if (_isProcessingBackground) const LinearProgressIndicator(),

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

                // Fond grisé : couvre tout sauf le panneau (dessiné après,
                // donc par-dessus). Un clic dessus ferme le panneau.
                if (_showPagePanel)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _showPagePanel = false),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ),

                if (_showPagePanel)
                  Positioned(
                    top: 0, bottom: 0, right: 0,
                    child: PagePanel(
                      pages: allpages,
                      currentIndex: currentPage,
                      canvasWidth: widget.template.canvasWidth,
                      canvasHeight: widget.template.canvasHeight,
                      onSelect: (index) => setState(() => currentPage = index),
                      onAdd: _addPage,
                      onDuplicate: _duplicatePage,
                      onDelete: _deletePage,
                      onReorder: _reorderPage,
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
            // Menu : changer / supprimer le fond de la page affichée
            PopupMenuButton<String>(
              icon: const Icon(Icons.wallpaper),
              tooltip: "Modification de l'image de fond",
              enabled: !_isProcessingBackground,
              onSelected: (value) {
                if (value == 'change') _changeBackground();
                if (value == 'remove') _removeBackground();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'change',
                  child: Text("Changer l'image de fond"),
                ),
                PopupMenuItem(
                  value: 'remove',
                  // Rien à supprimer si la page n'a pas de fond
                  enabled: _currentPageModel()?.backgroundPath != null,
                  child: const Text("Supprimer l'image de fond"),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.layers_rounded),
              tooltip: 'Gérer les pages',
              onPressed: () => setState(() => _showPagePanel = !_showPagePanel)
            ),
          ],
        ),
      ),
    );
  }


  //////////////////////////////////////////////////////
  //                  IMAGE DE FOND                   //
  //////////////////////////////////////////////////////

  /// Page affichée, ou null si les pages ne sont pas encore chargées.
  PageModel? _currentPageModel() {
    final pages = context.read<PageProvider>().getPages();
    if (pages.isEmpty) return null;
    return pages[currentPage.clamp(0, pages.length - 1)];
  }

  /// Choix d'une image sur l'ordinateur → recadrage → enregistrement
  /// (recadrée puis compressée à la taille du canvas par le service).
  Future<void> _changeBackground() async {
    final PageModel? page = _currentPageModel();
    if (page == null) return;
    final pageProvider = context.read<PageProvider>();

    // Sur Windows, ouvre l'explorateur de fichiers
    final XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    final CropArea? crop = await BackgroundCropDialog.show(
      context,
      imagePath: file.path,
      targetWidth: widget.template.canvasWidth,
      targetHeight: widget.template.canvasHeight,
    );
    if (crop == null || !mounted) return; // annulé

    setState(() => _isProcessingBackground = true);
    await _runSafely(() => pageProvider.setBackground(
          page.id,
          file.path,
          crop,
          widget.template.canvasWidth,
          widget.template.canvasHeight,
        ));
    if (mounted) setState(() => _isProcessingBackground = false);
  }

  /// Retire le fond de la page affichée (fond blanc).
  Future<void> _removeBackground() async {
    final PageModel? page = _currentPageModel();
    if (page == null) return;
    final pageProvider = context.read<PageProvider>();
    await _runSafely(() => pageProvider.removeBackground(page.id));
  }


  //////////////////////////////////////////////////////
  //                GESTION DES PAGES                 //
  //////////////////////////////////////////////////////

  /// Ajoute une page vierge juste après la page affichée et bascule dessus.
  Future<void> _addPage() async {
    final pageProvider = context.read<PageProvider>();
    final String currentId = pageProvider.getPages()[currentPage].id;

    await _runSafely(() async {
      await pageProvider.addPageTemplateAfter(
        widget.template.id,
        currentId,
        widget.template.canvasWidth,
        widget.template.canvasHeight,
      );
      if (!mounted) return;
      setState(() => currentPage = currentPage + 1);
    });
  }

  /// Duplique la page [index] (copie insérée juste après) et bascule sur la copie.
  Future<void> _duplicatePage(int index) async {
    final pageProvider = context.read<PageProvider>();
    final String id = pageProvider.getPages()[index].id;

    await _runSafely(() async {
      await pageProvider.duplicatePage(id);
      if (!mounted) return;
      setState(() => currentPage = index + 1);
    });
  }

  /// Supprime la page [index] et recale la page affichée :
  /// - page supprimée AVANT l'affichée → on recule d'un cran (même page) ;
  /// - page affichée supprimée → même index (= la suivante), ou la
  ///   nouvelle dernière si c'était la dernière ;
  /// - page supprimée APRÈS → rien ne change.
  Future<void> _deletePage(int index) async {
    final pageProvider = context.read<PageProvider>();
    final String id = pageProvider.getPages()[index].id;

    await _runSafely(() async {
      await pageProvider.deletePage(id);
      if (!mounted) return;
      final int lastIndex = pageProvider.getPages().length - 1;
      setState(() {
        if (index < currentPage) {
          currentPage = currentPage - 1;
        } else if (index == currentPage && currentPage > lastIndex) {
          currentPage = lastIndex;
        }
      });
    });
  }

  /// Déplace la page [oldIndex] en [newIndex] (position finale) et suit
  /// la page affichée :
  /// - c'est elle qui bouge → elle prend sa nouvelle position ;
  /// - une page passe de devant à derrière elle → elle recule d'un cran ;
  /// - une page passe de derrière à devant elle → elle avance d'un cran.
  Future<void> _reorderPage(int oldIndex, int newIndex) async {
    setState(() {
      if (oldIndex == currentPage) {
        currentPage = newIndex;
      } else if (oldIndex < currentPage && newIndex >= currentPage) {
        currentPage = currentPage - 1;
      } else if (oldIndex > currentPage && newIndex <= currentPage) {
        currentPage = currentPage + 1;
      }
    });

    // Le provider met sa liste à jour tout de suite (avant d'écrire en base),
    // donc l'affichage et currentPage restent synchronisés.
    await _runSafely(
      () => context.read<PageProvider>().reorderPage(oldIndex, newIndex),
    );
  }

  /// Exécute une action et affiche l'erreur éventuelle dans une SnackBar.
  Future<void> _runSafely(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

}