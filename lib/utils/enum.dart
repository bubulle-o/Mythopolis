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