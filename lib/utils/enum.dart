// Modes d'affichage d'une note
import 'package:flutter/widgets.dart';

enum NoteMode {
  reading,   // lecture seule
  writing    // édition WYSIWYG
}

// Thèmes de l'application
enum AppTheme {
  light,
  dark
}


// Allignement de la banière des notes
enum BannerAlignment {
  topLeft, topCenter, topRight,
  centerLeft, center, centerRight,
  bottomLeft, bottomCenter, bottomRight,
}

extension BannerAlignmentExtension on BannerAlignment {
  Alignment toFlutterAlignment() {
    switch (this) {
      case BannerAlignment.topLeft: return Alignment.topLeft;
      case BannerAlignment.topCenter: return Alignment.topCenter;
      case BannerAlignment.topRight: return Alignment.topRight;
      case BannerAlignment.centerLeft: return Alignment.centerLeft;
      case BannerAlignment. center: return Alignment. center;
      case BannerAlignment.centerRight: return Alignment.centerRight;
      case BannerAlignment.bottomLeft: return Alignment.topLeft;
      case BannerAlignment.bottomCenter: return Alignment.bottomCenter;
      case BannerAlignment.bottomRight: return Alignment.bottomRight;
    }
  }
}

// Tailles de canvas prédéfinies, exprimées en portrait.
// L'orientation paysage s'obtient en permutant width et height.
enum CanvasFormat {
  a4(1240, 1754, 'A4'),
  a5(874, 1240, 'A5'),
  cardTCG(750, 1050, 'Carte TCG'),
  card(651, 995, 'Carte classique'),
  tarot(825, 1425, 'Carte Tarot'),
  tq_2k(1536, 2048, '3:4'),
  ns_2K( 1080, 1920, '9:16'),
  square(1240, 1240, 'Carré'),
  square_2k(2048, 2048, 'Carré');


  const CanvasFormat(this.width, this.height, this.label);
  final int width;
  final int height;
  final String label;
}
