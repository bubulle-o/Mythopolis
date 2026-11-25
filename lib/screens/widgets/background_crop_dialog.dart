import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mythopolis/models/crop_area.dart';


//////////////////////////////////////////////////////
//                 WIDGET PRINCIPAL                 //
//////////////////////////////////////////////////////

/// Outil de recadrage d'une image de fond.
///
/// Affiche l'image derrière un cadre aux proportions de la page
/// ([targetWidth] × [targetHeight]) ; l'extérieur du cadre est grisé.
/// On déplace l'image (glisser) et on zoome (molette, pinch ou slider).
/// L'image couvre TOUJOURS tout le cadre : zoom minimum et déplacement
/// sont bloqués en conséquence.
///
/// Retourne la zone choisie en pixels de l'image ORIGINALE, ou null si
/// annulé. Aucune compression ici : elle est faite ensuite par le service.
class BackgroundCropDialog extends StatefulWidget {
  final String imagePath;
  final int targetWidth;
  final int targetHeight;

  const BackgroundCropDialog({
    super.key,
    required this.imagePath,
    required this.targetWidth,
    required this.targetHeight,
  });

  /// Ouvre l'outil et attend le résultat.
  static Future<CropArea?> show(
    BuildContext context, {
    required String imagePath,
    required int targetWidth,
    required int targetHeight,
  }) {
    return showDialog<CropArea>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackgroundCropDialog(
        imagePath: imagePath,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      ),
    );
  }

  @override
  State<BackgroundCropDialog> createState() => _BackgroundCropDialogState();
}

class _BackgroundCropDialogState extends State<BackgroundCropDialog> {

  // Zoom max = 8× le zoom minimum (celui où l'image couvre juste le cadre)
  static const double _maxZoom = 8;

  // Image affichée : éventuellement décodée en plus petit pour l'écran.
  // Les calculs se font toujours dans les dimensions ORIGINALES.
  ui.Image? _displayImage;
  late double _imageWidth;   // largeur originale (px)
  late double _imageHeight;  // hauteur originale (px)
  String? _error;

  // ── État du recadrage ─────────────────────────────
  // Indépendant de la taille de la fenêtre : si on la redimensionne,
  // la zone choisie ne bouge pas.
  /// Multiplicateur du zoom minimum (1 = l'image couvre juste le cadre).
  double _zoom = 1;
  /// Point de l'image (px originaux) situé au centre du cadre.
  Offset _center = Offset.zero;

  // Cadre courant (coordonnées de la zone d'affichage), recalculé à
  // chaque layout. Sert aux gestes, qui arrivent entre deux builds.
  Rect _frame = Rect.zero;

  // Pour le pinch : dernière valeur de details.scale
  double _lastGestureScale = 1;


  //////////////////////////////////////////////////////
  //                 INITIALISATION                   //
  //////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _displayImage?.dispose();
    super.dispose();
  }

  /// Lit les dimensions originales SANS décoder l'image entière, puis
  /// décode une version d'au plus 2048 px de côté pour l'affichage
  /// (une photo de 6000 px pèserait ~100 Mo en mémoire pour rien).
  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);

      final int width = descriptor.width;
      final int height = descriptor.height;
      const int maxDisplaySide = 2048;
      final double ratio = math.min(1, maxDisplaySide / math.max(width, height));

      final codec = await descriptor.instantiateCodec(
        targetWidth: (width * ratio).round(),
        targetHeight: (height * ratio).round(),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();

      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _displayImage = frame.image;
        _imageWidth = width.toDouble();
        _imageHeight = height.toDouble();
        _center = Offset(_imageWidth / 2, _imageHeight / 2);
      });
    } catch (e) {
      if (mounted) setState(() => _error = "Impossible de lire l'image : $e");
    }
  }


  //////////////////////////////////////////////////////
  //                     CALCULS                      //
  //////////////////////////////////////////////////////

  /// Plus grand cadre aux proportions de la page qui tient dans [viewport],
  /// avec une marge pour voir l'image autour.
  Rect _computeFrame(Size viewport) {
    const double margin = 40;
    final double availableW = math.max(1, viewport.width - 2 * margin);
    final double availableH = math.max(1, viewport.height - 2 * margin);
    final double targetRatio = widget.targetWidth / widget.targetHeight;

    double frameW = availableW;
    double frameH = frameW / targetRatio;
    if (frameH > availableH) {
      frameH = availableH;
      frameW = frameH * targetRatio;
    }
    return Rect.fromCenter(
      center: viewport.center(Offset.zero),
      width: frameW,
      height: frameH,
    );
  }

  /// Zoom minimum : pixels écran par pixel image pour que l'image
  /// couvre exactement le cadre (comme BoxFit.cover).
  double get _minScale => math.max(
        _frame.width / _imageWidth,
        _frame.height / _imageHeight,
      );

  /// Échelle réelle : pixels écran par pixel image.
  double get _scale => _minScale * _zoom;

  /// Empêche le cadre de sortir de l'image (pas de vide dans le cadre).
  Offset _clampCenter(Offset center, double scale) {
    final double halfW = _frame.width / (2 * scale);
    final double halfH = _frame.height / (2 * scale);
    return Offset(
      center.dx.clamp(halfW, math.max(halfW, _imageWidth - halfW)),
      center.dy.clamp(halfH, math.max(halfH, _imageHeight - halfH)),
    );
  }

  /// Zoome en gardant fixe le point de l'image situé sous [focal]
  /// (la souris, les doigts, ou le centre du cadre pour le slider).
  void _zoomAround(double newZoom, Offset focal) {
    newZoom = newZoom.clamp(1.0, _maxZoom);
    final double oldScale = _scale;
    final double newScale = _minScale * newZoom;

    // Point de l'image actuellement sous le focal…
    final Offset fromFrameCenter = focal - _frame.center;
    final Offset imagePoint = _center + fromFrameCenter / oldScale;
    // …qui doit y rester après le zoom.
    final Offset newCenter = imagePoint - fromFrameCenter / newScale;

    setState(() {
      _zoom = newZoom;
      _center = _clampCenter(newCenter, newScale);
    });
  }

  /// Déplace l'image de [delta] pixels écran.
  void _pan(Offset delta) {
    setState(() {
      // Glisser l'image vers la droite = le cadre voit plus à gauche
      _center = _clampCenter(_center - delta / _scale, _scale);
    });
  }

  /// Zone retenue, convertie en pixels de l'image originale.
  CropArea _computeCropArea() {
    final double w = _frame.width / _scale;
    final double h = _frame.height / _scale;
    final int x = (_center.dx - w / 2).round().clamp(0, _imageWidth.toInt() - 1);
    final int y = (_center.dy - h / 2).round().clamp(0, _imageHeight.toInt() - 1);
    return (
      x: x,
      y: y,
      width: w.round().clamp(1, _imageWidth.toInt() - x),
      height: h.round().clamp(1, _imageHeight.toInt() - y),
    );
  }


  //////////////////////////////////////////////////////
  //                     BUILD                        //
  //////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: math.min(screen.width * 0.9, 1100),
        height: screen.height * 0.85,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "Recadrer l'image de fond",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: _buildCropArea()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  /// Zone de travail : image transformée + voile gris autour du cadre.
  Widget _buildCropArea() {
    if (_error != null) return Center(child: Text(_error!));
    final ui.Image? image = _displayImage;
    if (image == null) return const Center(child: CircularProgressIndicator());

    return ClipRect(
      child: ColoredBox(
        color: Colors.grey.shade900,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _frame = _computeFrame(constraints.biggest);
            // La fenêtre a pu changer de taille : on revalide la position
            _center = _clampCenter(_center, _scale);

            final double scale = _scale;
            final Offset topLeft = _frame.center - _center * scale;

            return Listener(
              // Molette de la souris → zoom autour du pointeur
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  final double factor = math.exp(-event.scrollDelta.dy / 400);
                  _zoomAround(_zoom * factor, event.localPosition);
                }
              },
              child: GestureDetector(
                // onScale gère à la fois le glisser (1 doigt / souris)
                // et le pinch (2 doigts)
                onScaleStart: (_) => _lastGestureScale = 1,
                onScaleUpdate: (details) {
                  if (details.scale != _lastGestureScale) {
                    _zoomAround(
                      _zoom * details.scale / _lastGestureScale,
                      details.localFocalPoint,
                    );
                    _lastGestureScale = details.scale;
                  }
                  _pan(details.focalPointDelta);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Stack(
                    children: [
                      Positioned(
                        left: topLeft.dx,
                        top: topLeft.dy,
                        width: _imageWidth * scale,
                        height: _imageHeight * scale,
                        child: RawImage(
                          image: image,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      // Voile + bordure du cadre ; ne capte pas les gestes
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _FrameOverlayPainter(_frame)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Slider de zoom, bouton Recentrer, Annuler / Valider.
  Widget _buildControls() {
    final bool ready = _displayImage != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.zoom_out),
              SizedBox(
                width: 220,
                child: Slider(
                  min: 1,
                  max: _maxZoom,
                  value: _zoom,
                  onChanged: ready ? (v) => _zoomAround(v, _frame.center) : null,
                ),
              ),
              const Icon(Icons.zoom_in),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Recentrer'),
                onPressed: ready
                    ? () => setState(() {
                          _zoom = 1;
                          _center = Offset(_imageWidth / 2, _imageHeight / 2);
                        })
                    : null,
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: ready
                    ? () => Navigator.pop(context, _computeCropArea())
                    : null,
                child: const Text('Valider'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


//////////////////////////////////////////////////////
//                  VOILE DU CADRE                  //
//////////////////////////////////////////////////////

/// Grise tout sauf [frame], et dessine une bordure autour du cadre.
class _FrameOverlayPainter extends CustomPainter {
  final Rect frame;

  _FrameOverlayPainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    // evenOdd : le rectangle du cadre "perce" le grand rectangle
    final Path veil = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(veil, Paint()..color = Colors.black.withValues(alpha: 0.6));

    canvas.drawRect(
      frame,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FrameOverlayPainter oldDelegate) => oldDelegate.frame != frame;
}
