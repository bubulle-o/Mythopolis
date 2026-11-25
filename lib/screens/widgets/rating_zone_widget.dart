import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mythopolis/models/rating_zone.dart';
import 'package:mythopolis/utils/rating_geometry.dart';
import 'package:mythopolis/utils/rating_images.dart';


//////////////////////////////////////////////////////
//              WIDGET RÉUTILISABLE                 //
//////////////////////////////////////////////////////

/// Une jauge posée sur la page d'une template.
///
/// Même principe que les autres zones : à placer dans un Stack de la
/// taille du canvas ; coordonnées stockées en fractions de la page.
///
/// Comportement :
/// - clic          → sélectionne le CADRE (bordure + 8 poignées)
/// - glisser       → déplace la jauge
/// - poignées      → redimensionne le cadre = espace les icônes
///                   (jamais plus petit que ce que demandent les icônes)
/// - double-clic   → mode "taille des icônes" : la 1re icône a 4 poignées
///                   de coin ; sa nouvelle taille s'applique à toutes
/// - clic droit    → menu Options… / Supprimer
///
/// Dans l'éditeur, toutes les icônes sont visibles : les [currentValue]
/// premières pleines, les autres vides (l'option "vides visibles en
/// lecture" ne joue qu'en lecture de fiche).
class RatingZoneWidget extends StatefulWidget {
  final RatingZone zone;

  /// Taille du canvas en pixels (ex. 1240 × 1754 pour un A4).
  final Size canvasSize;

  /// Nombre de pixels du canvas pour 1 pixel d'écran (voir TextZoneWidget).
  final double uiScale;

  final bool isSelected;
  /// Mode "taille des icônes" (après un double-clic).
  final bool isEditing;

  final VoidCallback onSelect;
  final VoidCallback onStartIconResize;
  /// Fin d'un déplacement / redimensionnement du cadre (fractions de la page).
  final ValueChanged<Rect> onRectChanged;
  /// Fin d'un redimensionnement d'icône : largeur en fraction de la page.
  final ValueChanged<double> onIconSizeChanged;
  final VoidCallback onOpenOptions;
  final VoidCallback onDelete;

  const RatingZoneWidget({
    super.key,
    required this.zone,
    required this.canvasSize,
    required this.uiScale,
    required this.isSelected,
    required this.isEditing,
    required this.onSelect,
    required this.onStartIconResize,
    required this.onRectChanged,
    required this.onIconSizeChanged,
    required this.onOpenOptions,
    required this.onDelete,
  });

  @override
  State<RatingZoneWidget> createState() => _RatingZoneWidgetState();
}

class _RatingZoneWidgetState extends State<RatingZoneWidget> {

  // Images de la jauge (null tant qu'elles ne sont pas chargées)
  RatingImages? _images;

  // Valeurs pendant un geste en cours (pixels du canvas).
  // null = pas de geste : on affiche les valeurs enregistrées.
  // On ne sauvegarde qu'à la fin du geste.
  Rect? _gestureRect;
  double? _gestureIconWidth;


  //////////////////////////////////////////////////////
  //                 INITIALISATION                   //
  //////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void didUpdateWidget(covariant RatingZoneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nouvelle version venue de la base : le geste est terminé
    if (!identical(oldWidget.zone, widget.zone)) {
      _gestureRect = null;
      _gestureIconWidth = null;
    }
    if (oldWidget.zone.ratingId != widget.zone.ratingId) _loadImages();
  }

  /// Charge les images (depuis le cache de RatingImages si déjà lues).
  void _loadImages() {
    RatingImages.load(widget.zone.ratingId).then((images) {
      if (mounted) setState(() => _images = images);
    });
  }


  //////////////////////////////////////////////////////
  //                   GÉOMÉTRIE                      //
  //////////////////////////////////////////////////////

  /// Cadre enregistré, converti de fractions en pixels du canvas.
  Rect get _savedRect => Rect.fromLTWH(
        widget.zone.topLeftCornerX * widget.canvasSize.width,
        widget.zone.topLeftCornerY * widget.canvasSize.height,
        widget.zone.width * widget.canvasSize.width,
        widget.zone.height * widget.canvasSize.height,
      );

  /// Cadre affiché : celui du geste en cours, sinon l'enregistré.
  Rect get _rect => _gestureRect ?? _savedRect;

  /// Largeur / hauteur d'une icône (1 tant que l'image n'est pas lue).
  double get _ratio => _images?.aspectRatio ?? 1;

  /// Taille d'une icône en pixels du canvas.
  Size get _iconSize {
    final double width =
        _gestureIconWidth ?? widget.zone.iconSize * widget.canvasSize.width;
    return Size(width, width / _ratio);
  }

  /// Cadre minimal pour que les icônes ne se superposent pas.
  Size get _minFrame => RatingGeometry.minFrameSize(
        layout: widget.zone.layout,
        count: widget.zone.maxValue,
        rowCount: widget.zone.rowCount,
        icon: _iconSize,
      );

  /// Demi-taille d'une poignée, en pixels du canvas (≈ 6 px à l'écran).
  double get _handleHalf => 6 * widget.uiScale;

  /// Comme clamp, mais sans erreur si les bornes sont inversées
  /// (cas d'un cadre déjà plus petit que le minimum) : renvoie [lo].
  static double _clamp(double v, double lo, double hi) =>
      math.max(lo, math.min(v, hi));

  /// Déplace la jauge sans la faire sortir de la page.
  void _move(Offset delta) {
    final Rect r = _rect;
    setState(() {
      _gestureRect = Rect.fromLTWH(
        _clamp(r.left + delta.dx, 0, widget.canvasSize.width - r.width),
        _clamp(r.top + delta.dy, 0, widget.canvasSize.height - r.height),
        r.width,
        r.height,
      );
    });
  }

  /// Redimensionne le CADRE depuis la poignée (ax, ay) : -1 gauche/haut,
  /// 1 droite/bas, 0 aucun. Jamais plus petit que le cadre minimal des
  /// icônes, jamais hors de la page.
  void _resizeFrame(int ax, int ay, Offset delta) {
    final Rect r = _rect;
    final Size min = _minFrame;
    double left = r.left, top = r.top, right = r.right, bottom = r.bottom;

    if (ax == -1) left = _clamp(left + delta.dx, 0, right - min.width);
    if (ax == 1) right = _clamp(right + delta.dx, left + min.width, widget.canvasSize.width);
    if (ay == -1) top = _clamp(top + delta.dy, 0, bottom - min.height);
    if (ay == 1) bottom = _clamp(bottom + delta.dy, top + min.height, widget.canvasSize.height);

    setState(() => _gestureRect = Rect.fromLTRB(left, top, right, bottom));
  }

  /// Redimensionne les ICÔNES depuis un coin (ax, ay) de la 1re icône, en
  /// gardant leurs proportions. Jamais plus grandes que ce que permet le
  /// cadre (pas de superposition), jamais minuscules.
  void _resizeIcon(int ax, int ay, Offset delta) {
    final Size icon = _iconSize;
    // Moyenne de ce que demandent les mouvements horizontal et vertical
    final double widthFromX = icon.width + ax * delta.dx;
    final double widthFromY = (icon.height + ay * delta.dy) * _ratio;
    final double wanted = (widthFromX + widthFromY) / 2;

    final double maxWidth = RatingGeometry.maxIconWidth(
      layout: widget.zone.layout,
      count: widget.zone.maxValue,
      rowCount: widget.zone.rowCount,
      frame: _rect.size,
      iconAspectRatio: _ratio,
    );
    final double minWidth = math.min(12 * widget.uiScale, maxWidth);

    setState(() => _gestureIconWidth = _clamp(wanted, minWidth, maxWidth));
  }

  /// Fin d'un geste sur le cadre : position en fractions de la page.
  void _commitFrame() {
    final Rect? r = _gestureRect;
    if (r == null) return;
    final Size c = widget.canvasSize;
    widget.onRectChanged(Rect.fromLTWH(
      r.left / c.width, r.top / c.height, r.width / c.width, r.height / c.height,
    ));
  }

  /// Fin d'un geste sur une icône : largeur en fraction de la page.
  void _commitIcon() {
    final double? width = _gestureIconWidth;
    if (width == null) return;
    widget.onIconSizeChanged(width / widget.canvasSize.width);
  }

  /// Menu du clic droit, ouvert à la position de la souris.
  void _showContextMenu(TapUpDetails details) {
    widget.onSelect();
    final Offset p = details.globalPosition;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(p.dx, p.dy, p.dx, p.dy),
      items: const [
        PopupMenuItem(value: 'options', child: Text('Options…')),
        PopupMenuItem(value: 'delete', child: Text('Supprimer')),
      ],
    ).then((value) {
      if (value == 'options') widget.onOpenOptions();
      if (value == 'delete') widget.onDelete();
    });
  }


  //////////////////////////////////////////////////////
  //                     BUILD                        //
  //////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final double h = _handleHalf;
    final Rect frame = _rect;
    final Size icon = _iconSize;

    // Centres des icônes dans le cadre
    final List<Offset> centers = RatingGeometry.iconCenters(
      layout: widget.zone.layout,
      count: widget.zone.maxValue,
      rowCount: widget.zone.rowCount,
      frame: frame.size,
      icon: icon,
    );
    // Rectangle de la 1re icône (repère du mode "taille des icônes")
    final Rect firstIcon =
        Rect.fromCenter(center: centers.first, width: icon.width, height: icon.height);

    // Le widget déborde de h de chaque côté pour que les poignées, à
    // cheval sur les bords, reçoivent les clics (voir TextZoneWidget).
    return Positioned.fromRect(
      rect: frame.inflate(h),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(h),
              child: _buildBody(centers, icon),
            ),
          ),
          // Poignées du cadre (sélection simple)
          if (widget.isSelected && !widget.isEditing) ..._buildFrameHandles(),
          // Poignées de la 1re icône (mode taille des icônes). Décalées de
          // h : le repère du Stack commence h avant le cadre.
          if (widget.isEditing) ..._buildIconHandles(firstIcon.shift(Offset(h, h))),
        ],
      ),
    );
  }

  /// Le cadre et les icônes. Capte clic, double-clic, clic droit, glisser.
  Widget _buildBody(List<Offset> centers, Size icon) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double px = widget.uiScale; // 1 pixel d'écran
    final RatingImages? images = _images;

    final Border border = widget.isEditing
        ? Border.all(color: colors.tertiary, width: 2 * px)
        : widget.isSelected
            ? Border.all(color: colors.primary, width: 2 * px)
            : Border.all(color: Colors.grey.withValues(alpha: 0.6), width: px);

    return GestureDetector(
      onTap: widget.onSelect,
      onDoubleTap: widget.onStartIconResize,
      onSecondaryTapUp: _showContextMenu,
      // Pas de déplacement en mode "taille des icônes"
      onPanStart: widget.isEditing ? null : (_) => widget.onSelect(),
      onPanUpdate: widget.isEditing ? null : (d) => _move(d.delta),
      onPanEnd: widget.isEditing ? null : (_) => _commitFrame(),
      child: MouseRegion(
        cursor: widget.isSelected && !widget.isEditing
            ? SystemMouseCursors.move
            : SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            border: border,
            color: widget.isSelected ? colors.primary.withValues(alpha: 0.06) : null,
          ),
          child: images == null
              ? const SizedBox.expand()
              : Stack(
                  children: [
                    for (int i = 0; i < centers.length; i++)
                      Positioned(
                        left: centers[i].dx - icon.width / 2,
                        top: centers[i].dy - icon.height / 2,
                        width: icon.width,
                        height: icon.height,
                        child: Image.memory(
                          // Les [currentValue] premières sont pleines
                          i < widget.zone.currentValue ? images.full : images.empty,
                          fit: BoxFit.fill,
                          gaplessPlayback: true, // pas de clignotement
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Les 8 poignées du cadre : 4 coins + 4 milieux de bords.
  List<Widget> _buildFrameHandles() {
    const List<(int, int)> positions = [
      (-1, -1), (0, -1), (1, -1),
      (-1, 0),           (1, 0),
      (-1, 1),  (0, 1),  (1, 1),
    ];
    return [
      for (final (ax, ay) in positions)
        Positioned.fill(
          child: Align(
            alignment: Alignment(ax.toDouble(), ay.toDouble()),
            child: _buildHandle(
              cursor: _cursorFor(ax, ay),
              onUpdate: (delta) => _resizeFrame(ax, ay, delta),
              onEnd: _commitFrame,
            ),
          ),
        ),
    ];
  }

  /// Bordure + 4 poignées de coin autour de la 1re icône ([iconRect] est
  /// dans le repère du Stack extérieur).
  List<Widget> _buildIconHandles(Rect iconRect) {
    final double h = _handleHalf;
    final ColorScheme colors = Theme.of(context).colorScheme;
    const List<(int, int)> corners = [(-1, -1), (1, -1), (-1, 1), (1, 1)];

    return [
      // Bordure de la 1re icône (ne capte pas les clics)
      Positioned.fromRect(
        rect: iconRect,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colors.tertiary, width: 2 * widget.uiScale),
            ),
          ),
        ),
      ),
      for (final (ax, ay) in corners)
        Positioned(
          // Coin de l'icône (ax, ay), poignée centrée dessus
          left: (ax == -1 ? iconRect.left : iconRect.right) - h,
          top: (ay == -1 ? iconRect.top : iconRect.bottom) - h,
          child: _buildHandle(
            cursor: _cursorFor(ax, ay),
            onUpdate: (delta) => _resizeIcon(ax, ay, delta),
            onEnd: _commitIcon,
          ),
        ),
    ];
  }

  /// Une poignée : petit carré blanc bordé.
  Widget _buildHandle({
    required MouseCursor cursor,
    required ValueChanged<Offset> onUpdate,
    required VoidCallback onEnd,
  }) {
    final double size = 2 * _handleHalf;
    return GestureDetector(
      onPanUpdate: (d) => onUpdate(d.delta),
      onPanEnd: (_) => onEnd(),
      child: MouseRegion(
        cursor: cursor,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: widget.uiScale,
            ),
          ),
        ),
      ),
    );
  }

  /// Curseur de redimensionnement selon la poignée.
  MouseCursor _cursorFor(int ax, int ay) {
    if (ax == 0) return SystemMouseCursors.resizeUpDown;
    if (ay == 0) return SystemMouseCursors.resizeLeftRight;
    return ax == ay
        ? SystemMouseCursors.resizeUpLeftDownRight
        : SystemMouseCursors.resizeUpRightDownLeft;
  }
}
