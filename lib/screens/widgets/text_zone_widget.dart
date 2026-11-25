import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mythopolis/models/text_zone.dart';


//////////////////////////////////////////////////////
//              WIDGET RÉUTILISABLE                 //
//////////////////////////////////////////////////////

/// Une zone de texte posée sur la page d'une template.
///
/// À placer dans un Stack de la taille du canvas (pixels du canvas).
/// Les coordonnées de la zone sont stockées en FRACTIONS de la page
/// (0 → 1) : x = 0.5 veut dire "au milieu", quelle que soit la taille.
///
/// Comportement :
/// - clic          → sélectionne la zone (bordure + 8 poignées)
/// - glisser       → déplace la zone
/// - poignées      → redimensionne (coins = 2 côtés, bords = 1 côté)
/// - double-clic   → mode édition (voir ci-dessous)
/// - clic droit    → menu Supprimer
///
/// La zone reste toujours entièrement dans la page.
///
/// Deux sortes de zones, selon [TextZone.isLocked] :
/// - ZONE DE TEXTE (isLocked = false) : contient le placeholder, sera
///   remplie dans la fiche. En édition, on ne change que le STYLE, d'un
///   bloc pour tout le texte (la barre agit sur "tout sélectionné").
///   Au repos : bordure en pointillés.
/// - TEXTE FIXE (isLocked = true) : texte identique sur toutes les fiches.
///   En édition, on tape le contenu librement et on formate la sélection,
///   comme dans un traitement de texte. Au repos : bordure en trait plein.
class TextZoneWidget extends StatefulWidget {
  final TextZone zone;

  /// Taille du canvas en pixels (ex. 1240 × 1754 pour un A4).
  final Size canvasSize;

  /// Nombre de pixels du canvas pour 1 pixel d'écran. Le canvas est
  /// réduit pour tenir dans la fenêtre : sans ce facteur, les poignées
  /// et bordures deviendraient minuscules.
  final double uiScale;

  final bool isSelected;
  final bool isEditing;

  final VoidCallback onSelect;
  /// Double-clic : donne à l'écran le controller à brancher sur la barre.
  final ValueChanged<QuillController> onStartEditing;
  /// Fin d'un déplacement / redimensionnement, en fractions de la page.
  final ValueChanged<Rect> onRectChanged;
  /// Le style a changé : nouveau contenu en Delta JSON, à sauvegarder.
  final ValueChanged<String> onContentChanged;
  final VoidCallback onDelete;

  const TextZoneWidget({
    super.key,
    required this.zone,
    required this.canvasSize,
    required this.uiScale,
    required this.isSelected,
    required this.isEditing,
    required this.onSelect,
    required this.onStartEditing,
    required this.onRectChanged,
    required this.onContentChanged,
    required this.onDelete,
  });

  @override
  State<TextZoneWidget> createState() => _TextZoneWidgetState();
}

class _TextZoneWidgetState extends State<TextZoneWidget> {

  // Contrôleur Quill de la zone : sert à l'affichage ET au formatage.
  late QuillController _controller;
  StreamSubscription<DocChange>? _changesSubscription;

  // Focus et défilement de l'éditeur. Créés UNE fois ici : QuillEditor.basic
  // en recréerait de nouveaux à chaque build, et le focus serait perdu.
  final FocusNode _editorFocus = FocusNode();
  final ScrollController _editorScroll = ScrollController();

  // Rectangle (pixels du canvas) pendant un geste en cours.
  // null = pas de geste : on affiche la position enregistrée.
  // On ne sauvegarde qu'à la fin du geste, pas à chaque pixel.
  Rect? _gestureRect;


  //////////////////////////////////////////////////////
  //                 INITIALISATION                   //
  //////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(covariant TextZoneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Nouvelle version de la zone venue de la base (après sauvegarde) :
    // le geste est terminé, on reprend la position enregistrée.
    if (!identical(oldWidget.zone, widget.zone)) {
      _gestureRect = null;
    }

    // Contenu modifié ailleurs que par ce controller → on le recrée.
    // (Quand c'est NOUS qui avons sauvegardé, le contenu est identique.)
    // Jamais en mode format : le controller est branché sur la barre, et
    // certaines actions (ex. "effacer le format") font plusieurs
    // sauvegardes d'affilée → la base peut renvoyer un état intermédiaire.
    // Pendant l'édition, c'est le controller qui fait foi.
    if (!widget.isEditing &&
        !oldWidget.isEditing &&
        widget.zone.content != _currentContentJson()) {
      _disposeController();
      _createController();
    }

    // Sortie du mode édition : on enlève la sélection et le curseur.
    if (oldWidget.isEditing && !widget.isEditing) {
      _editorFocus.unfocus();
      _controller.updateSelection(
        const TextSelection.collapsed(offset: 0),
        ChangeSource.local,
      );
    }
  }

  @override
  void dispose() {
    _disposeController();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  /// Texte fixe : contenu modifiable dans la template.
  bool get _isFixedText => widget.zone.isLocked;

  /// Vrai quand on peut taper dans la zone (texte fixe en édition).
  bool get _isTyping => widget.isEditing && _isFixedText;

  /// Crée le controller à partir du contenu stocké (Delta JSON).
  void _createController() {
    final String? content = widget.zone.content;
    final Document document = (content != null && content.isNotEmpty)
        ? Document.fromJson(jsonDecode(content))
        : Document();

    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      // Zone de texte : refuse toute modification du TEXTE (frappe,
      // collage, suppression). Le formatage passe par formatText, qui
      // n'est pas concerné. Texte fixe : pas de blocage (null).
      onReplaceText: _isFixedText ? null : (index, length, data) => false,
    );

    // Chaque changement (style, ou texte tapé pour un texte fixe) est
    // remonté pour être sauvegardé
    _changesSubscription = _controller.document.changes.listen((_) {
      widget.onContentChanged(_currentContentJson());
    });
  }

  void _disposeController() {
    _changesSubscription?.cancel();
    _controller.dispose();
  }

  /// Contenu actuel du controller, au format stocké en base.
  String _currentContentJson() =>
      jsonEncode(_controller.document.toDelta().toJson());


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

  /// Demi-taille d'une poignée, en pixels du canvas (≈ 6 px à l'écran).
  double get _handleHalf => 6 * widget.uiScale;

  /// Taille minimale d'une zone (≈ 24 px à l'écran).
  double get _minSize => 24 * widget.uiScale;

  /// Déplace la zone sans la faire sortir de la page.
  void _move(Offset delta) {
    final Rect r = _rect;
    final double maxLeft = widget.canvasSize.width - r.width;
    final double maxTop = widget.canvasSize.height - r.height;
    setState(() {
      _gestureRect = Rect.fromLTWH(
        (r.left + delta.dx).clamp(0, maxLeft),
        (r.top + delta.dy).clamp(0, maxTop),
        r.width,
        r.height,
      );
    });
  }

  /// Redimensionne depuis la poignée (ax, ay) :
  /// ax = -1 bord gauche, 1 bord droit, 0 aucun ; idem ay pour haut/bas.
  /// Le bord opposé ne bouge pas. Taille minimale et bords de page respectés.
  void _resize(int ax, int ay, Offset delta) {
    final Rect r = _rect;
    double left = r.left, top = r.top, right = r.right, bottom = r.bottom;
    final double maxW = widget.canvasSize.width;
    final double maxH = widget.canvasSize.height;

    if (ax == -1) left = (left + delta.dx).clamp(0, right - _minSize);
    if (ax == 1) right = (right + delta.dx).clamp(left + _minSize, maxW);
    if (ay == -1) top = (top + delta.dy).clamp(0, bottom - _minSize);
    if (ay == 1) bottom = (bottom + delta.dy).clamp(top + _minSize, maxH);

    setState(() => _gestureRect = Rect.fromLTRB(left, top, right, bottom));
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


  //////////////////////////////////////////////////////
  //                     ACTIONS                      //
  //////////////////////////////////////////////////////

  /// Double-clic : sélectionne tout le texte, puis donne le controller à
  /// l'écran, qui branche la barre Quill dessus.
  /// - zone de texte : la sélection reste "tout", la barre agit sur toute la zone ;
  /// - texte fixe : l'éditeur prend le focus ; taper remplace le texte
  ///   sélectionné, et on peut ensuite sélectionner librement.
  void _startEditing() {
    widget.onSelect();
    _controller.updateSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: _controller.document.length - 1,
      ),
      ChangeSource.local,
    );
    widget.onStartEditing(_controller);

    if (_isFixedText) {
      // L'éditeur ne devient cliquable qu'au prochain build (isEditing) :
      // on attend la fin de l'image en cours pour lui donner le focus.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editorFocus.requestFocus();
      });
    }
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

    // Le widget déborde de la zone de h de chaque côté : les poignées
    // sont à cheval sur la bordure, et Flutter ne détecte les clics QUE
    // dans les limites d'un widget.
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
          if (widget.isSelected && !widget.isEditing) ..._buildHandles(),
        ],
      ),
    );
  }

  /// Le texte + la bordure. Capte clic, double-clic, clic droit et glisser.
  /// Pendant la saisie d'un texte fixe, ces gestes sont coupés : les clics
  /// vont à l'éditeur (placer le curseur, sélectionner du texte).
  Widget _buildBody() {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double px = widget.uiScale; // 1 pixel d'écran

    // Bordure pleine : colorée si sélectionnée, autre couleur en édition.
    // Au repos : trait gris pour un texte fixe ; pour une zone de texte,
    // pas de bordure ici, ce sont les pointillés dessinés plus bas.
    final Border? border = widget.isEditing
        ? Border.all(color: colors.tertiary, width: 2 * px)
        : widget.isSelected
            ? Border.all(color: colors.primary, width: 2 * px)
            : _isFixedText
                ? Border.all(color: Colors.grey.withValues(alpha: 0.6), width: px)
                : null;
    final bool showDashedBorder = border == null;

    // En saisie : aucun geste ici (null), tout va à l'éditeur
    final bool gesturesOn = !_isTyping;

    return GestureDetector(
      onTap: gesturesOn ? widget.onSelect : null,
      onDoubleTap: gesturesOn ? _startEditing : null,
      onSecondaryTapUp: gesturesOn ? _showContextMenu : null,
      // Pas de déplacement en mode édition (on règle le style / le texte)
      onPanStart: widget.isEditing ? null : (_) => widget.onSelect(),
      onPanUpdate: widget.isEditing ? null : (d) => _move(d.delta),
      onPanEnd: widget.isEditing ? null : (_) => _commitGesture(),
      child: MouseRegion(
        cursor: _isTyping
            ? SystemMouseCursors.text
            : widget.isSelected && !widget.isEditing
                ? SystemMouseCursors.move
                : SystemMouseCursors.click,
        child: CustomPaint(
          // Pointillés par-dessus le texte (zone de texte au repos)
          foregroundPainter: showDashedBorder
              ? _DashedBorderPainter(
                  color: Colors.grey.withValues(alpha: 0.8),
                  strokeWidth: px,
                  dashLength: 6 * px,
                )
              : null,
          child: Container(
            decoration: BoxDecoration(
              border: border,
              color: widget.isSelected
                  ? colors.primary.withValues(alpha: 0.06)
                  : null,
            ),
            // ClipRect : le texte qui dépasse de la zone est coupé.
            // IgnorePointer : hors saisie, l'éditeur ne prend ni clic ni
            // focus → impossible de taper ou de perdre la sélection.
            child: ClipRect(
              child: IgnorePointer(
                ignoring: !_isTyping,
                child: QuillEditor.basic(
                  controller: _controller,
                  focusNode: _editorFocus,
                  scrollController: _editorScroll,
                  config: QuillEditorConfig(
                    showCursor: _isTyping,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Les 8 poignées : 4 coins + 4 milieux de bords.
  List<Widget> _buildHandles() {
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
        cursor: _cursorFor(ax, ay),
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

  /// Curseur de redimensionnement selon la poignée.
  MouseCursor _cursorFor(int ax, int ay) {
    if (ax == 0) return SystemMouseCursors.resizeUpDown;
    if (ay == 0) return SystemMouseCursors.resizeLeftRight;
    // Coins : haut-gauche/bas-droite ou haut-droite/bas-gauche
    return ax == ay
        ? SystemMouseCursors.resizeUpLeftDownRight
        : SystemMouseCursors.resizeUpRightDownLeft;
  }
}


//////////////////////////////////////////////////////
//               BORDURE EN POINTILLÉS              //
//////////////////////////////////////////////////////

/// Dessine un rectangle en pointillés sur tout le widget.
/// (Flutter n'a pas de bordure pointillée toute faite.)
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength; // longueur d'un tiret = longueur d'un espace

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Les 4 côtés, parcourus dans le sens des aiguilles d'une montre
    final List<(Offset, Offset)> sides = [
      (Offset.zero, Offset(size.width, 0)),
      (Offset(size.width, 0), Offset(size.width, size.height)),
      (Offset(size.width, size.height), Offset(0, size.height)),
      (Offset(0, size.height), Offset.zero),
    ];

    for (final (start, end) in sides) {
      final double length = (end - start).distance;
      final Offset direction = (end - start) / length;
      // Un tiret, un espace, un tiret… jusqu'au bout du côté
      for (double d = 0; d < length; d += 2 * dashLength) {
        final double dashEnd = (d + dashLength).clamp(0, length);
        canvas.drawLine(start + direction * d, start + direction * dashEnd, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength;
}
