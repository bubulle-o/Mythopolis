import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mythopolis/models/photo_zone.dart';
import 'package:mythopolis/models/rating_zone.dart';
import 'package:mythopolis/providers/rating_zone_provider.dart';
import 'package:mythopolis/screens/widgets/rating_options_dialog.dart';
import 'package:mythopolis/screens/widgets/rating_picker_dialog.dart';
import 'package:mythopolis/screens/widgets/rating_zone_widget.dart';
import 'package:mythopolis/utils/rating_geometry.dart';
import 'package:mythopolis/utils/rating_images.dart';
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
                // Page zoomable (voir section ZOOM)
                _buildZoomableCanvas(page),

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
      bottomNavigationBar: _buildZoomBar(),
    );
  }


  //////////////////////////////////////////////////////
  //                      ZOOM                        //
  //////////////////////////////////////////////////////

  // Principe : la page est dessinée à l'échelle  fitScale × _zoom
  //   - fitScale : échelle où la page entière tient dans la zone (= 100 %) ;
  //   - _zoom    : de 1 (100 %) à 5 (500 %).
  // _pan est la position du coin haut-gauche de la page dans la zone
  // d'affichage (pixels écran). Quand la page est plus petite que la zone
  // dans une direction, elle y est centrée ; sinon on peut la déplacer,
  // sans laisser de vide sur les bords.

  static const double _minZoom = 1;
  static const double _maxZoom = 5;
  /// Multiplicateur des boutons [−] / [+].
  static const double _zoomStep = 1.25;

  double _zoom = 1;
  Offset _pan = Offset.zero;

  // Dernières valeurs connues de l'affichage (mises à jour à chaque
  // build), utilisées par la souris et les boutons entre deux builds.
  Size _viewportSize = Size.zero;
  double _fitScale = 1;

  // Vrai pendant un déplacement de la vue au clic molette
  bool _isPanningView = false;

  /// Échelle réelle : pixels écran par pixel de la page.
  double get _scale => _fitScale * _zoom;

  /// Taille de la page à l'écran, à l'échelle actuelle.
  Size get _scaledCanvasSize => Size(
        widget.template.canvasWidth * _scale,
        widget.template.canvasHeight * _scale,
      );

  /// Corrige une position de page : centrée si elle tient dans la zone,
  /// sinon gardée sans vide sur les bords.
  Offset _clampPan(Offset pan) {
    final Size page = _scaledCanvasSize;
    double clampAxis(double value, double pageLength, double viewLength) {
      if (pageLength <= viewLength) return (viewLength - pageLength) / 2; // centrée
      return value.clamp(viewLength - pageLength, 0.0);
    }
    return Offset(
      clampAxis(pan.dx, page.width, _viewportSize.width),
      clampAxis(pan.dy, page.height, _viewportSize.height),
    );
  }

  /// Change le zoom en gardant fixe le point de la page situé sous
  /// [focal] (la souris, ou le centre de la zone pour les boutons).
  void _setZoom(double newZoom, Offset focal) {
    newZoom = newZoom.clamp(_minZoom, _maxZoom);
    // Point de la page (pixels de la page) actuellement sous le focal…
    final Offset pagePoint = (focal - _pan) / _scale;
    setState(() {
      _zoom = newZoom;
      // …qui doit y rester après le zoom
      _pan = _clampPan(focal - pagePoint * _scale);
    });
  }

  /// Déplace la vue de [delta] pixels écran.
  void _panView(Offset delta) {
    setState(() => _pan = _clampPan(_pan + delta));
  }

  /// Fin du déplacement de la vue au clic molette.
  void _stopPanningView() {
    if (_isPanningView) setState(() => _isPanningView = false);
  }

  /// Retour à la page entière (100 %, centrée). Appelé aussi au
  /// changement de page.
  void _resetZoom() {
    _zoom = 1;
    _pan = Offset.zero; // recentrée par _clampPan au prochain build
  }

  /// Molette : Ctrl → zoom vers la souris ; Maj → défilement horizontal ;
  /// sinon → défilement vertical.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final Offset scroll = event.scrollDelta;
    if (HardwareKeyboard.instance.isControlPressed) {
      // Molette vers le haut (dy < 0) → zoom avant ; exp : zoom régulier
      _setZoom(_zoom * math.exp(-scroll.dy / 400), event.localPosition);
    } else if (HardwareKeyboard.instance.isShiftPressed) {
      // Certaines souris envoient déjà dx avec Maj, d'autres seulement dy
      _panView(Offset(-(scroll.dx != 0 ? scroll.dx : scroll.dy), 0));
    } else {
      _panView(Offset(-scroll.dx, -scroll.dy));
    }
  }

  /// La page, zoomée et positionnée dans la zone d'affichage.
  /// Un Listener (et non un GestureDetector) capte molette et clic
  /// molette : il n'entre pas en concurrence avec les gestes des zones,
  /// qui n'écoutent que le clic gauche.
  Widget _buildZoomableCanvas(PageModel page) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _viewportSize = constraints.biggest;
        // 100 % = la page entière tient dans la zone
        _fitScale = math.min(
          constraints.maxWidth / widget.template.canvasWidth,
          constraints.maxHeight / widget.template.canvasHeight,
        );
        // La fenêtre a pu changer de taille : on revalide la position
        _pan = _clampPan(_pan);
        final Size scaled = _scaledCanvasSize;

        return Listener(
          onPointerSignal: _onPointerSignal,
          // Clic molette : début / suite / fin du déplacement de la vue
          // (setState : le curseur "main fermée" s'affiche / disparaît)
          onPointerDown: (event) {
            if (event.buttons & kMiddleMouseButton != 0) {
              setState(() => _isPanningView = true);
            }
          },
          onPointerMove: (event) {
            if (_isPanningView) _panView(event.delta);
          },
          onPointerUp: (_) => _stopPanningView(),
          onPointerCancel: (_) => _stopPanningView(),
          child: MouseRegion(
            cursor: _isPanningView ? SystemMouseCursors.grabbing : MouseCursor.defer,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: _pan.dx,
                    top: _pan.dy,
                    width: scaled.width,
                    height: scaled.height,
                    // La page garde sa taille réelle (pixels de la page) ;
                    // FittedBox la réduit/agrandit à la taille affichée.
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        key: _canvasKey,
                        width: widget.template.canvasWidth.toDouble(),
                        height: widget.template.canvasHeight.toDouble(),
                        // 1 / _scale : pixels de la page pour 1 pixel écran
                        // (poignées et bordures gardent leur taille écran)
                        child: _buildCanvas(page, 1 / _scale),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Barre du bas : [−] pourcentage [+] et « Page entière ».
  Widget _buildZoomBar() {
    // Les boutons zooment vers le centre de la zone d'affichage
    final Offset center = _viewportSize.center(Offset.zero);

    return BottomAppBar(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'Zoom arrière',
            onPressed: _zoom > _minZoom ? () => _setZoom(_zoom / _zoomStep, center) : null,
          ),
          // Largeur fixe : le texte ne fait pas bouger les boutons
          SizedBox(
            width: 56,
            child: Text('${(_zoom * 100).round()} %', textAlign: TextAlign.center),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Zoom avant (ou Ctrl + molette)',
            onPressed: _zoom < _maxZoom ? () => _setZoom(_zoom * _zoomStep, center) : null,
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            icon: const Icon(Icons.fit_screen),
            label: const Text('Page entière'),
            onPressed: _zoom != 1 ? () => setState(_resetZoom) : null,
          ),
        ],
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
            // Ouvre le menu des jauges ; la jauge apparaît au centre
            IconButton(
              icon: const Icon(Icons.star_half_rounded),
              tooltip: 'Ajouter une jauge',
              onPressed: _addRatingZone,
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
    final List<RatingZone> ratingZones = context
        .watch<RatingZoneProvider>()
        .getRatingZones()
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

            // Jauges : au premier plan, au-dessus de tout le reste
            for (final RatingZone zone in ratingZones)
              RatingZoneWidget(
                key: ValueKey(zone.id),
                zone: zone,
                canvasSize: canvasSize,
                uiScale: uiScale,
                isSelected: zone.id == _selectedZoneId,
                isEditing: zone.id == _editingZoneId,
                onSelect: () => _selectZone(zone.id),
                onStartIconResize: () => _startIconResize(zone.id),
                onRectChanged: (rect) => _saveRatingZone(zone.copyWith(
                  topLeftCornerX: rect.left,
                  topLeftCornerY: rect.top,
                  width: rect.width,
                  height: rect.height,
                )),
                onIconSizeChanged: (size) => _saveRatingZone(zone.copyWith(iconSize: size)),
                onOpenOptions: () => _openRatingOptions(zone),
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
    // Nouvelle page : retour au zoom initial (page entière)
    _resetZoom();
    _selectedZoneId = null;
    _editingZoneId = null;
    _editingController = null;
    // Pas de notifyListeners pendant un build : on décale d'un instant
    Future.microtask(() {
      if (!mounted) return;
      context.read<TextZoneProvider>().loadTextZonesFromPage(pageId);
      context.read<PhotoZoneProvider>().loadPhotoZonesFromPage(pageId);
      context.read<RatingZoneProvider>().loadRatingZonesFromPage(pageId);
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

  /// Supprime une zone, texte, photo ou jauge (clic droit → Supprimer, ou
  /// Suppr). Le type se reconnaît au début de l'ID ("photoZone_…",
  /// "ratingZone_…", "textZone_…").
  Future<void> _deleteZone(String id) async {
    final textZoneProvider = context.read<TextZoneProvider>();
    final photoZoneProvider = context.read<PhotoZoneProvider>();
    final ratingZoneProvider = context.read<RatingZoneProvider>();
    if (_selectedZoneId == id) _clearSelection();
    await _runSafely(() {
      if (id.startsWith('photoZone_')) return photoZoneProvider.deletePhotoZone(id);
      if (id.startsWith('ratingZone_')) return ratingZoneProvider.deleteRatingZone(id);
      return textZoneProvider.deleteTextZone(id);
    });
  }


  //////////////////////////////////////////////////////
  //                     JAUGES                       //
  //////////////////////////////////////////////////////

  /// Réglages d'une nouvelle jauge.
  static const int _newRatingCount = 5;
  /// Largeur d'une icône, en fraction de la largeur de la page.
  static const double _newRatingIconWidth = 0.06;

  /// Menu des jauges → jauge créée au centre de la page, sur une ligne,
  /// avec un peu d'espace entre les icônes, puis sélectionnée.
  Future<void> _addRatingZone() async {
    final String? pageId = _zonesPageId;
    if (pageId == null) return;
    final ratingZoneProvider = context.read<RatingZoneProvider>();

    final String? ratingId = await RatingPickerDialog.show(context);
    if (ratingId == null) return; // annulé

    await _runSafely(() async {
      final RatingImages images = await RatingImages.load(ratingId);
      final double pageW = widget.template.canvasWidth.toDouble();
      final double pageH = widget.template.canvasHeight.toDouble();

      // Icône et cadre en pixels : cadre minimal + 30 % d'espace en largeur
      final double iconW = _newRatingIconWidth * pageW;
      final Size icon = Size(iconW, iconW / images.aspectRatio);
      final Size minFrame = RatingGeometry.minFrameSize(
        layout: RatingLayout.line,
        count: _newRatingCount,
        rowCount: 2,
        icon: icon,
      );
      final double frameW = math.min(minFrame.width * 1.3, pageW);
      final double frameH = math.min(minFrame.height, pageH);

      final String id = await ratingZoneProvider.addRatingZone(RatingZone(
        id: '',      // calculé par le service
        parentPage: pageId,
        ratingId: ratingId,
        width: frameW / pageW,
        height: frameH / pageH,
        iconSize: iconW / pageW,
        topLeftCornerX: (1 - frameW / pageW) / 2,
        topLeftCornerY: (1 - frameH / pageH) / 2,
        currentValue: 0,
        maxValue: _newRatingCount,
        layout: RatingLayout.line,
        rowCount: 2,
        showEmpty: true,
        zOrder: 0,   // calculé par le service
      ));
      _selectZone(id);
    });
  }

  /// Double-clic sur une jauge : mode "taille des icônes" (pas de barre
  /// Quill : _editingController reste null).
  void _startIconResize(String id) {
    setState(() {
      _selectedZoneId = id;
      _editingZoneId = id;
      _editingController = null;
    });
    _canvasFocus.requestFocus();
  }

  /// Enregistre une jauge modifiée (position, taille, options).
  Future<void> _saveRatingZone(RatingZone zone) async {
    final ratingZoneProvider = context.read<RatingZoneProvider>();
    await _runSafely(() => ratingZoneProvider.updateRatingZone(zone));
  }

  /// Clic droit → Options… : applique les nouvelles options, puis s'assure
  /// que les icônes ne se superposent pas :
  /// 1. le cadre grandit si besoin (sans sortir de la page) ;
  /// 2. si la page est trop petite, ce sont les icônes qui rétrécissent.
  Future<void> _openRatingOptions(RatingZone zone) async {
    final RatingOptions? options = await RatingOptionsDialog.show(context, (
      count: zone.maxValue,
      value: zone.currentValue,
      showEmpty: zone.showEmpty,
      layout: zone.layout,
      rowCount: zone.rowCount,
    ));
    if (options == null) return; // annulé

    await _runSafely(() async {
      final RatingImages images = await RatingImages.load(zone.ratingId);
      final double pageW = widget.template.canvasWidth.toDouble();
      final double pageH = widget.template.canvasHeight.toDouble();

      // Icône et cadre actuels, en pixels
      double iconW = zone.iconSize * pageW;
      final Size minFrame = RatingGeometry.minFrameSize(
        layout: options.layout,
        count: options.count,
        rowCount: options.rowCount,
        icon: Size(iconW, iconW / images.aspectRatio),
      );

      // 1. Cadre agrandi jusqu'au minimum, limité à la page
      final double frameW = math.min(math.max(zone.width * pageW, minFrame.width), pageW);
      final double frameH = math.min(math.max(zone.height * pageH, minFrame.height), pageH);

      // 2. Icônes réduites si le cadre (limité par la page) est trop petit
      iconW = math.min(
        iconW,
        RatingGeometry.maxIconWidth(
          layout: options.layout,
          count: options.count,
          rowCount: options.rowCount,
          frame: Size(frameW, frameH),
          iconAspectRatio: images.aspectRatio,
        ),
      );

      // Le cadre agrandi ne doit pas déborder : on le recule si besoin
      final double left = math.min(zone.topLeftCornerX * pageW, pageW - frameW);
      final double top = math.min(zone.topLeftCornerY * pageH, pageH - frameH);

      await _saveRatingZone(zone.copyWith(
        maxValue: options.count,
        currentValue: options.value,
        showEmpty: options.showEmpty,
        layout: options.layout,
        rowCount: options.rowCount,
        iconSize: iconW / pageW,
        width: frameW / pageW,
        height: frameH / pageH,
        topLeftCornerX: left / pageW,
        topLeftCornerY: top / pageH,
      ));
    });
  }


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