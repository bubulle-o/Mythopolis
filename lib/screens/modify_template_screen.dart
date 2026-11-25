import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mythopolis/models/photo_zone.dart';
import 'package:mythopolis/models/text_zone.dart';
import 'package:mythopolis/providers/photo_zone_provider.dart';
import 'package:mythopolis/screens/widgets/photo_zone_widget.dart';
import 'package:mythopolis/screens/widgets/shape_picker_dialog.dart';
import 'package:mythopolis/utils/shape_catalog.dart';
import 'package:mythopolis/providers/text_zone_provider.dart';
import 'package:mythopolis/screens/widgets/quill_toolbar_editor.dart';
import 'package:mythopolis/screens/widgets/text_zone_widget.dart';
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

  // ── Zones de texte ────────────────────────────────
  // Page dont les zones sont chargées dans TextZoneProvider
  String? _zonesPageId;
  // Zone sélectionnée (bordure + poignées), ou null
  String? _selectedZoneId;
  // Zone en mode format (double-clic) et son controller Quill,
  // branché sur la barre d'outils "format seul"
  String? _editingZoneId;
  QuillController? _editingController;

  // Repère le canvas pour convertir la position d'un dépôt (drop)
  // en coordonnées du canvas
  final GlobalKey _canvasKey = GlobalKey();
  // Focus de l'écran, pour les raccourcis clavier (Suppr, Échap)
  final FocusNode _canvasFocus = FocusNode();


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
  void dispose() {
    _canvasFocus.dispose();
    super.dispose();
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
    final PageModel page = allpages[currentPage];
    _syncZonesWithPage(page.id);

    // Raccourcis clavier : Suppr supprime la zone sélectionnée,
    // Échap désélectionne. Actifs tant que _canvasFocus a le focus.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.delete): _deleteSelectedZone,
        const SingleActivator(LogicalKeyboardKey.escape): _clearSelection,
      },
      child: Focus(
        focusNode: _canvasFocus,
        autofocus: true,
        child: _buildScaffold(allpages, page),
      ),
    );
  }

  Widget _buildScaffold(List<PageModel> allpages, PageModel page) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.template.name)),
      body: Column(
        children: [
          _buildToolbar(),
          if (_isProcessingBackground) const LinearProgressIndicator(),
          // Barre Quill "format seul", visible pendant le mode format
          if (_editingController != null) _buildFormatToolbar(),

          Expanded(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    // Échelle d'affichage du canvas (FittedBox contain) →
                    // combien de pixels du canvas pour 1 pixel d'écran.
                    final double fitScale = math.min(
                      constraints.maxWidth / widget.template.canvasWidth,
                      constraints.maxHeight / widget.template.canvasHeight,
                    );
                    return Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          key: _canvasKey,
                          width: widget.template.canvasWidth.toDouble(),
                          height: widget.template.canvasHeight.toDouble(),
                          child: _buildCanvas(page, 1 / fitScale),
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
            // Texte fixe et zone de texte : même bouton, même mécanique
            // (clic = au centre, glisser = à l'endroit du dépôt)
            _buildAddTextButton(
              isLocked: true,
              icon: Icons.text_fields,
              label: 'Texte fixe',
            ),
            _buildAddTextButton(
              isLocked: false,
              icon: Icons.add_box_outlined,
              label: 'Zone de texte',
            ),
            // Ouvre le menu des formes ; la zone apparaît au centre
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Ajouter une zone photo',
              onPressed: _addPhotoZone,
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
  //                     CANVAS                       //
  //////////////////////////////////////////////////////

  /// La page : fond + zones de texte, et cible du glisser-déposer.
  /// Tout ici est en pixels du canvas (la FittedBox réduit l'ensemble).
  /// [uiScale] : pixels du canvas pour 1 pixel d'écran.
  Widget _buildCanvas(PageModel page, double uiScale) {
    final String? chemin = page.backgroundPath;
    final Size canvasSize = Size(
      widget.template.canvasWidth.toDouble(),
      widget.template.canvasHeight.toDouble(),
    );

    // Le provider peut encore contenir les zones de la page précédente
    // pendant le chargement : on ne garde que celles de cette page.
    final List<TextZone> zones = context
        .watch<TextZoneProvider>()
        .getTextZones()
        .where((zone) => zone.parentPage == page.id)
        .toList();
    final List<PhotoZone> photoZones = context
        .watch<PhotoZoneProvider>()
        .getPhotoZones()
        .where((zone) => zone.parentPage == page.id)
        .toList();

    return DragTarget<String>(
      // N'accepte que les boutons "zone de texte" et "texte fixe"
      onWillAcceptWithDetails: (details) =>
          details.data == _textZoneDragData || details.data == _fixedTextDragData,
      onAcceptWithDetails: (details) => _addTextZoneAt(
        details.offset,
        page.id,
        isLocked: details.data == _fixedTextDragData,
      ),
      builder: (context, candidates, rejected) {
        return Stack(
          children: [
            // Fond de page. Un clic sur le fond désélectionne la zone.
            Positioned.fill(
              child: GestureDetector(
                onTap: _clearSelection,
                child: chemin == null
                    ? Container(color: Colors.white)
                    : Image.file(File(chemin)),
              ),
            ),

            // Zones photo, sous les zones de texte (un texte peut être
            // posé sur une photo), dans l'ordre d'empilement
            for (final PhotoZone zone in photoZones)
              PhotoZoneWidget(
                key: ValueKey(zone.id),
                zone: zone,
                canvasSize: canvasSize,
                uiScale: uiScale,
                isSelected: zone.id == _selectedZoneId,
                onSelect: () => _selectZone(zone.id),
                onRectChanged: (rect) => _savePhotoZoneRect(zone.id, rect),
                onDelete: () => _deleteZone(zone.id),
              ),

            // Zones de texte, dans l'ordre d'empilement (zOrder croissant)
            for (final TextZone zone in zones)
              TextZoneWidget(
                key: ValueKey(zone.id),
                zone: zone,
                canvasSize: canvasSize,
                uiScale: uiScale,
                isSelected: zone.id == _selectedZoneId,
                isEditing: zone.id == _editingZoneId,
                onSelect: () => _selectZone(zone.id),
                onStartEditing: (controller) => _startEditingZone(zone.id, controller),
                onRectChanged: (rect) => _saveZoneRect(zone.id, rect),
                onContentChanged: (json) => _saveZoneContent(zone.id, json),
                onDelete: () => _deleteZone(zone.id),
              ),

            // Survol pendant un glisser : léger voile pour montrer la cible
            if (candidates.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }


  //////////////////////////////////////////////////////
  //                  ZONES DE TEXTE                  //
  //////////////////////////////////////////////////////

  // Les "zones" regroupent deux sortes d'éléments, distingués par isLocked :
  // - zone de texte (isLocked = false) : placeholder, remplie dans la fiche ;
  // - texte fixe   (isLocked = true)  : contenu tapé dans la template.

  /// Données transportées par le glisser-déposer des boutons de la barre.
  static const String _textZoneDragData = 'textZone';
  static const String _fixedTextDragData = 'fixedText';

  /// Taille d'une nouvelle zone de texte, en fractions de la page.
  static const double _newZoneWidth = 0.4;
  static const double _newZoneHeight = 0.15;
  /// Un texte fixe est deux fois plus petit (quelques mots en général).
  static const double _newFixedTextWidth = _newZoneWidth / 2;
  static const double _newFixedTextHeight = _newZoneHeight / 2;

  /// Bouton de la barre d'outils qui ajoute une zone de texte
  /// ([isLocked] = false) ou un texte fixe ([isLocked] = true).
  /// Clic : au centre de la page. Glisser sur la page : à cet endroit
  /// (le DragTarget est dans _buildCanvas).
  Widget _buildAddTextButton({
    required bool isLocked,
    required IconData icon,
    required String label,
  }) {
    return Draggable<String>(
      data: isLocked ? _fixedTextDragData : _textZoneDragData,
      // Le "fantôme" suit la souris par son coin haut-gauche
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _buildTextZoneDragFeedback(label),
      child: IconButton(
        icon: Icon(icon),
        tooltip: 'Ajouter : $label '
            '(clic : au centre, glisser : à l\'endroit voulu)',
        onPressed: () => _addTextZoneAtCenter(isLocked: isLocked),
      ),
    );
  }

  /// Ce qui suit la souris pendant le glisser : un petit cadre.
  Widget _buildTextZoneDragFeedback(String label) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 120,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.15),
          border: Border.all(color: colors.primary, width: 2),
        ),
        child: Text(label),
      ),
    );
  }

  /// Charge les zones (texte et photo) quand la page affichée change
  /// (appelé dans build). On sort aussi de la sélection : elle
  /// concernait l'ancienne page.
  void _syncZonesWithPage(String pageId) {
    if (_zonesPageId == pageId) return;
    _zonesPageId = pageId;
    _selectedZoneId = null;
    _editingZoneId = null;
    _editingController = null;
    // Pas de notifyListeners pendant un build : on décale d'un instant
    Future.microtask(() {
      if (!mounted) return;
      context.read<TextZoneProvider>().loadTextZonesFromPage(pageId);
      context.read<PhotoZoneProvider>().loadPhotoZonesFromPage(pageId);
    });
  }

  /// Dépôt d'un bouton sur la page : crée une zone centrée sur la souris.
  /// [globalOffset] est en coordonnées écran ; globalToLocal le convertit
  /// en pixels du canvas (en tenant compte de la réduction FittedBox).
  Future<void> _addTextZoneAt(
    Offset globalOffset,
    String pageId, {
    required bool isLocked,
  }) async {
    final RenderBox? canvasBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox == null) return;
    final Offset local = canvasBox.globalToLocal(globalOffset);

    // Centre de la zone = position de la souris, en fractions de la page
    await _createTextZone(
      pageId,
      local.dx / canvasBox.size.width,
      local.dy / canvasBox.size.height,
      isLocked: isLocked,
    );
  }

  /// Clic sur un bouton : crée une zone au centre de la page affichée.
  Future<void> _addTextZoneAtCenter({required bool isLocked}) async {
    final String? pageId = _zonesPageId;
    if (pageId == null) return;
    await _createTextZone(pageId, 0.5, 0.5, isLocked: isLocked);
  }

  /// Crée une zone centrée sur ([centerX], [centerY]) — en fractions de
  /// la page — en la gardant entièrement dans la page, puis la sélectionne.
  /// Le service y met le placeholder (zone de texte) ou « Texte par
  /// défaut » (texte fixe).
  Future<void> _createTextZone(
    String pageId,
    double centerX,
    double centerY, {
    required bool isLocked,
  }) async {
    final double width = isLocked ? _newFixedTextWidth : _newZoneWidth;
    final double height = isLocked ? _newFixedTextHeight : _newZoneHeight;

    // Coin haut-gauche = centre - demi-taille, bloqué aux bords
    final double x = (centerX - width / 2).clamp(0, 1 - width);
    final double y = (centerY - height / 2).clamp(0, 1 - height);

    final textZoneProvider = context.read<TextZoneProvider>();
    await _runSafely(() async {
      final String id = await textZoneProvider.addTextZone(
        parentPage: pageId,
        width: width,
        height: height,
        topLeftCornerX: x,
        topLeftCornerY: y,
        isLocked: isLocked,
      );
      _selectZone(id);
    });
  }

  /// Sélectionne une zone. Sort du mode format si c'était une autre zone.
  void _selectZone(String id) {
    if (!mounted) return;
    setState(() {
      if (_editingZoneId != id) {
        _editingZoneId = null;
        _editingController = null;
      }
      _selectedZoneId = id;
    });
    // Récupère le focus pour que la touche Suppr fonctionne
    _canvasFocus.requestFocus();
  }

  /// Désélectionne tout et sort du mode format.
  void _clearSelection() {
    setState(() {
      _selectedZoneId = null;
      _editingZoneId = null;
      _editingController = null;
    });
  }

  /// Double-clic sur une zone : branche son controller sur la barre format.
  void _startEditingZone(String id, QuillController controller) {
    setState(() {
      _selectedZoneId = id;
      _editingZoneId = id;
      _editingController = controller;
    });
  }

  /// Barre Quill "format seul" + bouton pour sortir du mode format.
  Widget _buildFormatToolbar() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: QuillToolbar(controller: _editingController!, formatOnly: true),
          ),
          TextButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Terminer'),
            onPressed: _clearSelection,
          ),
        ],
      ),
    );
  }

  /// Sauvegarde la position/taille d'une zone (fractions de la page).
  Future<void> _saveZoneRect(String id, Rect rect) async {
    final textZoneProvider = context.read<TextZoneProvider>();
    await _runSafely(() => textZoneProvider.updateTextZone(
          id: id,
          topLeftCornerX: rect.left,
          topLeftCornerY: rect.top,
          width: rect.width,
          height: rect.height,
        ));
  }

  /// Sauvegarde le contenu (Delta JSON) après un changement de style.
  Future<void> _saveZoneContent(String id, String json) async {
    final textZoneProvider = context.read<TextZoneProvider>();
    await _runSafely(() => textZoneProvider.updateTextZone(id: id, content: json));
  }

  /// Supprime une zone, texte ou photo (clic droit → Supprimer, ou Suppr).
  /// Le type se reconnaît au début de l'ID ("photoZone_…" / "textZone_…").
  Future<void> _deleteZone(String id) async {
    final textZoneProvider = context.read<TextZoneProvider>();
    final photoZoneProvider = context.read<PhotoZoneProvider>();
    if (_selectedZoneId == id) _clearSelection();
    await _runSafely(() => _isPhotoZone(id)
        ? photoZoneProvider.deletePhotoZone(id)
        : textZoneProvider.deleteTextZone(id));
  }

  /// Vrai si [id] désigne une zone photo.
  bool _isPhotoZone(String id) => id.startsWith('photoZone_');


  //////////////////////////////////////////////////////
  //                   ZONES PHOTO                    //
  //////////////////////////////////////////////////////

  /// Largeur d'une nouvelle zone photo, en fraction de la page ;
  /// la hauteur découle des proportions de la forme.
  static const double _newPhotoZoneWidth = 0.3;

  /// Menu des formes → zone créée au centre de la page, aux proportions
  /// de la forme, puis sélectionnée.
  Future<void> _addPhotoZone() async {
    final String? pageId = _zonesPageId;
    if (pageId == null) return;
    final photoZoneProvider = context.read<PhotoZoneProvider>();

    final String? shapePath = await ShapePickerDialog.show(context);
    if (shapePath == null) return; // annulé

    await _runSafely(() async {
      final ShapeInfo shape = await ShapeCatalog.load(shapePath);
      final double pageW = widget.template.canvasWidth.toDouble();
      final double pageH = widget.template.canvasHeight.toDouble();

      // Taille en pixels : 30 % de la largeur de page, hauteur selon les
      // proportions ; réduite si elle dépasse 60 % de la hauteur.
      double widthPx = _newPhotoZoneWidth * pageW;
      double heightPx = widthPx / shape.aspectRatio;
      if (heightPx > 0.6 * pageH) {
        heightPx = 0.6 * pageH;
        widthPx = heightPx * shape.aspectRatio;
      }

      // En fractions de la page, centrée
      final double width = widthPx / pageW;
      final double height = heightPx / pageH;
      final String id = await photoZoneProvider.addPhotoZone(
        parentPage: pageId,
        shapePath: shapePath,
        width: width,
        height: height,
        topLeftCornerX: (1 - width) / 2,
        topLeftCornerY: (1 - height) / 2,
      );
      _selectZone(id);
    });
  }

  /// Sauvegarde la position/taille d'une zone photo (fractions de la page).
  Future<void> _savePhotoZoneRect(String id, Rect rect) async {
    final photoZoneProvider = context.read<PhotoZoneProvider>();
    await _runSafely(() => photoZoneProvider.updatePhotoZone(
          id: id,
          topLeftCornerX: rect.left,
          topLeftCornerY: rect.top,
          width: rect.width,
          height: rect.height,
        ));
  }

  /// Touche Suppr : supprime la zone sélectionnée.
  /// Ignorée en mode format (on règle le style, pas la zone).
  void _deleteSelectedZone() {
    final String? id = _selectedZoneId;
    if (id == null || _editingZoneId != null) return;
    _deleteZone(id);
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