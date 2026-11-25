import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mythopolis/models/photo_zone.dart';
import 'package:mythopolis/utils/shape_catalog.dart';


//////////////////////////////////////////////////////
//              WIDGET RÉUTILISABLE                 //
//////////////////////////////////////////////////////

/// Une zone photo posée sur la page d'une template.
///
/// Même principe que TextZoneWidget : à placer dans un Stack de la
/// taille du canvas ; coordonnées stockées en fractions de la page.
///
/// Comportement :
/// - clic        → sélectionne la zone (bordure + 4 poignées de coin)
/// - glisser     → déplace la zone
/// - poignées    → redimensionne en GARDANT LES PROPORTIONS de la forme
/// - clic droit  → menu Supprimer
///
/// Dans la template, la forme est affichée en gris opaque avec une icône photo :
/// la vraie photo sera choisie dans la fiche.
class PhotoZoneWidget extends StatefulWidget {
  final PhotoZone zone;

  /// Taille du canvas en pixels (ex. 1240 × 1754 pour un A4).
  final Size canvasSize;

  /// Nombre de pixels du canvas pour 1 pixel d'écran (voir TextZoneWidget).
  final double uiScale;

  final bool isSelected;
  final VoidCallback onSelect;
  /// Fin d'un déplacement / redimensionnement, en fractions de la page.
  final ValueChanged<Rect> onRectChanged;
  final VoidCallback onDelete;

  const PhotoZoneWidget({
    super.key,
    required this.zone,
    required this.canvasSize,
    required this.uiScale,
    required this.isSelected,
    required this.onSelect,
    required this.onRectChanged,
    required this.onDelete,
  });

  @override
  State<PhotoZoneWidget> createState() => _PhotoZoneWidgetState();
}

class _PhotoZoneWidgetState extends State<PhotoZoneWidget> {

  // Rectangle (pixels du canvas) pendant un geste en cours.
  // null = pas de geste : on affiche la position enregistrée.
  Rect? _gestureRect;

  // Forme à afficher (chargée et recadrée par ShapeCatalog)
  Future<ShapeInfo>? _shape;


  //////////////////////////////////////////////////////
  //                 INITIALISATION                   //
  //////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();
    _loadShape();
  }

  @override
  void didUpdateWidget(covariant PhotoZoneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nouvelle version venue de la base : le geste est terminé
    if (!identical(oldWidget.zone, widget.zone)) _gestureRect = null;
    if (oldWidget.zone.shapePath != widget.zone.shapePath) _loadShape();
  }

  void _loadShape() {
    final String? path = widget.zone.shapePath;
    _shape = path == null ? null : ShapeCatalog.load(path);
  }


  //////////////////////////////////////////////////////
  //                   GÉOMÉTRIE                      //
  //////////////////////////////////////////////////////

  /// Position enregistrée, convertie de fractions en pixels du canvas.
  Rect get _savedRect => Rect.fromLTWH(
        widget.zone.topLeftCornerX * widget.canvasSize.width,
        widget.zone.topLeftCornerY * widget.canvasSize.height,
        widget.zone.width * widget.canvasSize.width,
        widget.zone.height * widget.canvasSize.height,
      );

  /// Rectangle affiché : celui du geste en cours, sinon l'enregistré.
  Rect get _rect => _gestureRect ?? _savedRect;

  /// Proportions à conserver (largeur / hauteur), prises sur la position
  /// enregistrée : elles ne dérivent pas pendant le geste.
  double get _ratio => _savedRect.width / _savedRect.height;

  /// Demi-taille d'une poignée, en pixels du canvas (≈ 6 px à l'écran).
  double get _handleHalf => 6 * widget.uiScale;

  /// Taille minimale du plus petit côté (≈ 24 px à l'écran).
  double get _minSize => 24 * widget.uiScale;

  /// Déplace la zone sans la faire sortir de la page.
  void _move(Offset delta) {
    final Rect r = _rect;
    setState(() {
      _gestureRect = Rect.fromLTWH(
        (r.left + delta.dx).clamp(0, widget.canvasSize.width - r.width),
        (r.top + delta.dy).clamp(0, widget.canvasSize.height - r.height),
        r.width,
        r.height,
      );
    });
  }

  /// Redimensionne depuis le coin (ax, ay) — ax/ay valent -1 ou 1 —
  /// en gardant les proportions. Le coin opposé ne bouge pas.
  void _resize(int ax, int ay, Offset delta) {
    final Rect r = _rect;
    final double ratio = _ratio;
    final double pageW = widget.canvasSize.width;
    final double pageH = widget.canvasSize.height;

    // Coin fixe : l'opposé de celui qu'on tire
    final Offset anchor = Offset(
      ax == 1 ? r.left : r.right,
      ay == 1 ? r.top : r.bottom,
    );

    // Largeur voulue : moyenne de ce que demandent le mouvement
    // horizontal et le mouvement vertical (converti en largeur)
    final double widthFromX = r.width + ax * delta.dx;
    final double widthFromY = (r.height + ay * delta.dy) * ratio;
    double width = (widthFromX + widthFromY) / 2;

    // Limites : rester dans la page (depuis le coin fixe) et ne pas
    // devenir trop petit (aucun côté sous _minSize)
    final double spaceX = ax == 1 ? pageW - anchor.dx : anchor.dx;
    final double spaceY = ay == 1 ? pageH - anchor.dy : anchor.dy;
    final double maxWidth = math.min(spaceX, spaceY * ratio);
    final double minWidth = math.min(math.max(_minSize, _minSize * ratio), maxWidth);
    width = width.clamp(minWidth, maxWidth);
    final double height = width / ratio;

    setState(() {
      _gestureRect = Rect.fromLTWH(
        ax == 1 ? anchor.dx : anchor.dx - width,
        ay == 1 ? anchor.dy : anchor.dy - height,
        width,
        height,
      );
    });
  }

  /// Fin d'un geste : on remonte la nouvelle position en fractions.
  void _commitGesture() {
    final Rect? r = _gestureRect;
    if (r == null) return;
    final Size c = widget.canvasSize;
    widget.onRectChanged(Rect.fromLTWH(
      r.left / c.width,
      r.top / c.height,
      r.width / c.width,
      r.height / c.height,
    ));
  }

  /// Menu du clic droit, ouvert à la position de la souris.
  void _showContextMenu(TapUpDetails details) {
    widget.onSelect();
    final Offset p = details.globalPosition;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(p.dx, p.dy, p.dx, p.dy),
      items: const [
        PopupMenuItem(value: 'delete', child: Text('Supprimer')),
      ],
    ).then((value) {
      if (value == 'delete') widget.onDelete();
    });
  }


  //////////////////////////////////////////////////////
  //                     BUILD                        //
  //////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final double h = _handleHalf;

    // Le widget déborde de h de chaque côté pour que les poignées, à
    // cheval sur la bordure, reçoivent les clics (voir TextZoneWidget).
    return Positioned.fromRect(
      rect: _rect.inflate(h),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(h),
              child: _buildBody(),
            ),
          ),
          if (widget.isSelected) ..._buildHandles(),
        ],
      ),
    );
  }

  /// Couleur de la forme dans la template : gris neutre, opaque.
  static const Color _shapeColor = Color(0xFF9E9E9E); // = Colors.grey

  /// La forme en gris + icône photo, avec bordure si sélectionnée.
  Widget _buildBody() {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onSelect,
      onSecondaryTapUp: _showContextMenu,
      onPanStart: (_) => widget.onSelect(),
      onPanUpdate: (d) => _move(d.delta),
      onPanEnd: (_) => _commitGesture(),
      child: MouseRegion(
        cursor: widget.isSelected ? SystemMouseCursors.move : SystemMouseCursors.click,
        child: Container(
          decoration: widget.isSelected
              ? BoxDecoration(
                  border: Border.all(color: colors.primary, width: 2 * widget.uiScale),
                )
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // La forme : un masque PNG colorié en gris opaque
              FutureBuilder<ShapeInfo>(
                future: _shape,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const ColoredBox(color: _shapeColor);
                  }
                  return Image.memory(
                    snapshot.data!.bytes,
                    fit: BoxFit.fill,
                    color: _shapeColor,
                    colorBlendMode: BlendMode.srcIn,
                    gaplessPlayback: true, // pas de clignotement au rebuild
                  );
                },
              ),
              // Icône au centre, proportionnelle à la zone
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.3,
                  heightFactor: 0.3,
                  child: FittedBox(
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Les 4 poignées de coin (pas de bords : les proportions sont fixes).
  List<Widget> _buildHandles() {
    const List<(int, int)> corners = [(-1, -1), (1, -1), (-1, 1), (1, 1)];
    return [
      for (final (ax, ay) in corners)
        Positioned.fill(
          child: Align(
            alignment: Alignment(ax.toDouble(), ay.toDouble()),
            child: _buildHandle(ax, ay),
          ),
        ),
    ];
  }

  /// Une poignée : petit carré blanc bordé, avec le curseur adapté.
  Widget _buildHandle(int ax, int ay) {
    final double size = 2 * _handleHalf;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onPanUpdate: (d) => _resize(ax, ay, d.delta),
      onPanEnd: (_) => _commitGesture(),
      child: MouseRegion(
        // Haut-gauche/bas-droite ou haut-droite/bas-gauche
        cursor: ax == ay
            ? SystemMouseCursors.resizeUpLeftDownRight
            : SystemMouseCursors.resizeUpRightDownLeft,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: colors.primary, width: widget.uiScale),
          ),
        ),
      ),
    );
  }
}
