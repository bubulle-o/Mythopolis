# Mythopolis

*La cité des mythes — une application pour bâtir et organiser tes univers fictifs.*

## Introduction

Mythopolis est une application Flutter/Dart de gestion de fiches de personnages pour jeux de rôle, développée en apprentissage par Élise (étudiante à IMT Atlantique). Le nom vient du grec *mythos* (récit) + *polis* (cité), littéralement "la cité des mythes". L'application cible Windows d'abord puis le mobile, et permet à l'utilisateur d'organiser librement ses univers fictifs à travers des dossiers, des notes richement formatées, des fiches de personnages basées sur des templates personnalisables, et des liens internes entre ces éléments.

### Stack technique

- **Framework** : Flutter / Dart
- **Base de données** : SQLite via `sqflite` + `sqflite_common_ffi` (obligatoire pour Windows)
- **Gestion d'état** : Provider (`provider`)
- **Navigation** : `Navigator.push()` classique
- **Éditeur de texte riche** : `flutter_quill` + `flutter_quill_extensions` (WYSIWYG, stockage en Delta JSON)
- **Sélection d'images** : `image_picker`
- **Stockage local** : `path_provider` pour les images de bannières
- **UI** : `flutter_speed_dial` pour les boutons d'action multiples

### Architecture

```
lib/
├── models/
│   ├── folder.dart       # Folder(id, name, parentFolder?, iconPath?)
│   └── note.dart         # Note(id, name, parentFolder, iconPath?, content?, bookmarks?, bannerPath?, bannerAlignment)
├── services/
│   ├── database_helper.dart  # Singleton SQLite partagé
│   ├── folder_service.dart   # CRUD dossiers
│   └── note_service.dart     # CRUD notes + gestion des bannières
├── providers/
│   ├── folder_provider.dart  # ChangeNotifier dossiers
│   ├── note_provider.dart    # ChangeNotifier notes
│   └── settings_provider.dart # Préférences globales
├── screens/
│   ├── home_screen.dart           # Écran principal, dossiers racine
│   ├── folder_screen.dart         # Contenu d'un dossier (4 onglets)
│   ├── folder_search_delegate.dart # Recherche par nom
│   ├── note_read_screen.dart      # Mode lecture d'une note
│   └── note_edit_screen.dart      # Mode édition WYSIWYG
└── utils/
    └── enum.dart         # BannerAlignment, AppTheme + extension toFlutterAlignment()
```

### Base de données

- Table `folders` : `id TEXT PRIMARY KEY, name TEXT, parentFolder TEXT, iconPath TEXT` avec `FOREIGN KEY CASCADE`
- Table `notes` : `id TEXT PRIMARY KEY, name TEXT NOT NULL, parentFolder TEXT NOT NULL, iconPath TEXT, content TEXT, bookmarks TEXT, bannerPath TEXT, bannerAlignment TEXT` avec `FOREIGN KEY CASCADE`
- IDs format : `folder_00001`, `note_00001`
- `PRAGMA foreign_keys = ON` activé à chaque ouverture

### Stockage physique

- Bannières des notes : `<AppDocumentsDirectory>/banners/<noteId>.jpg`
- Copie de l'image originale via `File.copy()` — l'app est indépendante du fichier source

### Préférences pédagogiques

- Aucun code n'est fourni sans demande explicite
- Chaque ligne expliquée précisément pour pouvoir être reproduite
- Questions plutôt que solutions toutes faites
- Coups de pouce uniquement en cas de blocage
- Apprentissage avant rapidité
- L'utilisatrice apprécie les emojis et la franchise (pas de félicitations gratuites)

---

## Fonctionnalités

### Fichier (dossier)

**Fait :**
- CRUD complet : créer, renommer, déplacer, supprimer (avec cascade sur le contenu)
- Navigation hiérarchique entre dossiers
- Recherche par nom dans le dossier courant
- Menu contextuel clic droit (renommer, déplacer, supprimer)
- Dialog de déplacement avec arborescence indentée (exclut le dossier et ses descendants)
- Quatre onglets dans `FolderScreen` : Tout / Dossiers / Notes / Fiches
- Onglet "Tout" mélange dossiers et notes via `List<Object>` et test de type `is`
- Widgets réutilisables `_buildFolderTile` et `_buildNoteTile`

**À faire :**
- Icônes personnalisables pour les dossiers (image custom ou sélection prédéfinie)
- Affichage en grille style cartes (au lieu de la liste actuelle)

### Note

**Fait :**

*Base :*
- CRUD complet identique aux dossiers
- Affichage dans l'onglet "Notes" de `FolderScreen`
- Menu contextuel clic droit
- Stockage Delta JSON dans la colonne `content`

*Navigation lecture / édition :*
- Mode lecture par défaut à l'ouverture (`NoteReadScreen`)
- Mode édition WYSIWYG (`NoteEditScreen`) avec `flutter_quill`
- Boutons dédiés pour basculer entre les deux modes
- `Navigator.pushReplacement` avec rechargement de la note depuis la base — évite les problèmes de cache

*Édition riche :*
- Barre d'outils complète : gras, italique, souligné, couleurs, alignement, listes, citations, code
- 9 polices custom embarquées : Cardo, EB Garamond, Cinzel, MedievalSharp, UnifrakturMaguntia, Pirata One, Orbitron, Audiowide, Lexend
- Sélection de police et taille dans la toolbar
- Insertion d'images via `flutter_quill_extensions`
- Ctrl+Z natif via `QuillController`

*Liens internes :*
- Callback `onLaunchUrl` détecte les préfixes `note_` et `folder_` (format `https://<id>`)
- Bouton custom `link_rounded` dans la toolbar de `NoteEditScreen`
- Dialog `_showLinkPicker` : champ pour le nom affiché + arbre navigable des dossiers/notes
- Insertion via `QuillController.replaceText` + `formatText` avec `LinkAttribute`
- Le bouton de lien natif Quill est conservé pour les URLs externes

*Bannière :*
- Bouton `PopupMenuButton` avec image dans l'AppBar
- Ajouter (via `image_picker`) / Supprimer / Recadrer
- Stockage physique dans `<AppDocumentsDirectory>/banners/`
- Remplacement d'une bannière : suppression de l'ancienne image, copie de la nouvelle
- Alignement de l'image dans son bandeau : 9 positions (`BannerAlignment.topLeft` → `bottomRight`)
- Enum `BannerAlignment` en base, extension `toFlutterAlignment()` pour la conversion vers `Alignment` Flutter
- Dialog de recadrage : deux `RadioGroup` (horizontal/vertical) avec `StatefulBuilder` pour la sélection
- `ValueKey(DateTime.now().millisecondsSinceEpoch)` sur `Image.file` pour forcer le rebuild
- `imageCache.clear()` + `imageCache.clearLiveImages()` pour éviter l'ancien cache

*Sauvegarde :*
- Bouton Save explicite avec `SnackBar` de confirmation "Note sauvegardée"
- `PopScope` intercepte le retour arrière → dialog "Voulez-vous enregistrer ?"
- Sortie directe vers `FolderScreen` (double `Navigator.pop` pour sauter `NoteReadScreen`)

*Pattern interne :*
- Copie locale `_currentNote` initialisée depuis `widget.note`
- Rechargement systématique depuis la base après chaque modification pour rafraîchir l'affichage
- `dialogSetState` renommé dans les StatefulBuilder pour éviter la collision avec `setState` de l'écran

**À faire :**
- Icône livre personnalisable pour la note (image custom ou sélection prédéfinie)
- Export PDF via `vsc_quill_delta_to_html` puis conversion HTML→PDF
- Support des liens vers les fiches (préfixe `sheet_`) une fois le module fiches implémenté
- Faire des encadré (rectangle de couleur) dans lequel on peut écrire (comme sur WorldAnvil)


### Template

Un template est un modèle de fiche réutilisable, composé d'une ou plusieurs pages contenant des zones de texte, des zones photo et des jauges. Les templates ne vivent **pas** dans les dossiers : ils constituent une zone à part, accessible depuis `HomeScreen` (deux zones : Dossiers — affichée par défaut — et Templates).

#### Décisions de conception

*Géométrie :*
- Toutes les pages d'un template ont la **même taille réelle en pixels**, stockée sur le template (`canvasWidth`, `canvasHeight`).
- A4 vierge → taille par défaut fixée par convention (A4 à 150 dpi ≈ 1240 × 1754 px).
- Fond importé → la taille du canvas est celle, en pixels, de l'image importée. Pas de déformation ni de recadrage.
- Toutes les positions et tailles de zones sont exprimées en **pourcentage de la page** (0.0 → 1.0), jamais en pixels. À l'affichage : `LayoutBuilder` donne la place disponible, la page s'y inscrit en respectant son ratio, et les pourcentages sont convertis en pixels par un facteur d'échelle unique.
- Conséquence : l'export en JPG se fait à la taille native (rendu de la page à `canvasWidth` × `canvasHeight`), l'affichage écran à n'importe quelle taille, sans jamais toucher aux données.

*Superposition :*
- Ordre d'empilement fixe par type : **jauges** au-dessus, puis **zones de texte**, puis **zones photo**.
- Chaque type possède son propre champ `order` interne (ordre au sein du type).
- Limite acceptée en v1 : impossible de poser une photo par-dessus une zone de texte. Contournement : importer une image contenant déjà le texte.

*Zones de texte :*
- Le titre fixe n'est pas un type à part : c'est une **zone de texte verrouillée** (`isLocked = true`), dont le contenu est défini dans le template et non modifiable dans la fiche.
- Une zone non verrouillée contient un **placeholder** : un Delta Quill complet (mis en forme : police, taille, alignement) qui n'est visible qu'en **mode édition** de la fiche, uniquement si la zone est vide, et qui disparaît dès la première frappe **en conservant son style**.
- Même barre d'outils Quill que pour les notes.
- Pas de limite de saisie : l'utilisateur peut écrire plus que la zone ne peut afficher. Le débordement est **découpé visuellement** (`ClipRect`), jamais tronqué en base — réduire la police fait réapparaître le texte.

*Zones photo :*
- Rectangles uniquement en v1. Les formes personnalisées (cercle, PNG masque) sont reportées.

*Jauges :*
- Le template définit : l'icône pleine, l'icône vide, la **valeur maximale**, une **valeur par défaut**, la taille d'icône et la largeur de la zone.
- La hauteur de la zone est **déduite** du nombre d'icônes, de leur taille et de la largeur disponible (passage à la ligne automatique, type `Wrap`).
- La fiche ne stocke qu'un entier (la valeur courante). Pas de demi-valeurs.
- Édition dans la fiche : clic direct sur la Nᵉ icône → valeur = N. Recliquer sur la 1ʳᵉ icône quand la valeur vaut déjà 1 → retour à 0.
- Aucune jauge n'est verrouillable.
- Les icônes proviennent d'une **bibliothèque réutilisable** : un jeu fourni dans `assets/gauges/` + import d'images personnelles par l'utilisateur.

*Duplication :*
- Créer un template à partir d'un template existant (copie intégrale : pages, zones, fonds).
- Ajouter une page à un template en dupliquant une page existante du même template.
- La copie duplique aussi **physiquement** les fichiers image de fond (nouvel identifiant), pour que la suppression d'un template n'affecte jamais l'autre.

#### Base de données

- `templates` : `id TEXT PK, name TEXT NOT NULL, canvasWidth INTEGER, canvasHeight INTEGER, iconPath TEXT`
- `template_pages` : `id TEXT PK, templateId TEXT, pageOrder INTEGER, backgroundPath TEXT` — FK CASCADE
- `template_text_zones` : `id TEXT PK, pageId TEXT, x REAL, y REAL, width REAL, height REAL, isLocked INTEGER, content TEXT (Delta JSON), zoneOrder INTEGER` — FK CASCADE
- `template_photo_zones` : `id TEXT PK, pageId TEXT, x REAL, y REAL, width REAL, height REAL, shape TEXT, zoneOrder INTEGER` — FK CASCADE
- `template_gauge_zones` : `id TEXT PK, pageId TEXT, x REAL, y REAL, width REAL, iconSize REAL, fullIconId TEXT, emptyIconId TEXT, maxValue INTEGER, defaultValue INTEGER, zoneOrder INTEGER` — FK CASCADE
- `gauge_icons` : `id TEXT PK, name TEXT, path TEXT, isBuiltIn INTEGER`
- IDs format : `template_00001`, `page_00001`, `zone_00001`, `gauge_00001`

#### Stockage physique

- Fonds de page : `<AppDocumentsDirectory>/backgrounds/<pageId>.jpg` — copie de l'original via `File.copy()`, même principe que les bannières de notes.
- Icônes de jauge importées : `<AppDocumentsDirectory>/gauge_icons/<iconId>.png`.

#### Rendu

- `Stack` + `Positioned` (et non `CustomPainter`) : chaque zone est un vrai widget, ce qui rend triviaux le `GestureDetector` (drag & drop), le menu contextuel et l'insertion d'un `QuillEditor` dans une zone côté fiche.
- Enveloppé dans un `LayoutBuilder` pour convertir les pourcentages en pixels.
- Export JPG : `RepaintBoundary` + `toImage(pixelRatio: …)` puis encodage via le package `image`.

#### État d'avancement

**Fait :**
- Concept et cahier des charges hérités du prototype Python (structure page / zones de texte / zones photo / titres)

**À faire — phase 1 (terrain connu) :**
- Modèles `Template`, `TemplatePage`, `TextZone`, `PhotoZone`, `GaugeZone`, `GaugeIcon` dans `models/`
- Tables SQLite et migration du `DatabaseHelper`
- `TemplateService` (CRUD + duplication de template et de page)
- `TemplateProvider`
- Zone Templates sur `HomeScreen` + `TemplateScreen` (liste plate, menu contextuel renommer/dupliquer/supprimer)
- Dialog de création : nom + choix A4 vierge / image de fond / duplication d'un template existant

**À faire — phase 2 (l'éditeur) :**
- `ModifyTemplateScreen` : rendu d'une page (fond + zones) en `Stack` / `Positioned` / `LayoutBuilder`
- Création d'une zone de texte par sélection à la souris
- Déplacement et redimensionnement par drag & drop
- Paramètres d'une zone (clic droit) : verrouillage, contenu du placeholder, style Quill
- Gestionnaire de pages : navigation, ajout (vierge ou dupliquée), réordonnancement, suppression

**À faire — phase 3 (images et jauges) :**
- Zones photo rectangulaires
- Bibliothèque d'icônes de jauge (jeu fourni + import)
- Zones jauge dans l'éditeur
- Export d'une page en JPG
- Plus tard : formes de zones photo autres que le rectangle, zoom/recadrage de l'image insérée dans une zone


### Fiche

**Fait :**
- Concept hérité du prototype Python : instance d'un template rempli par l'utilisateur

**À faire :**
- Modèle `Sheet` dans `models/`
- `SheetService` (CRUD SQLite)
- `SheetProvider`
- Onglet "Fiches" de `FolderScreen` (actuellement placeholder)
- Création d'une fiche : choix du template parent
- Édition d'une fiche : remplir les zones de texte définies par le template
- Quand on édite une template, on ne change pas ce qui a déjà été fait pour la fiche
- Insertion de photos dans les zones photo prévues
- Mode lecture / mode édition (similaire aux notes)
- Liens internes vers fiches depuis les notes (préfixe `sheet_`)

### Settings

**Fait :**
- `SettingsProvider` créé avec `appTheme` (light/dark)
- Méthode `setTheme(AppTheme theme)` avec `notifyListeners`

**À faire :**
- Écran `SettingsScreen` accessible depuis `HomeScreen` et `FolderScreen`
- Persistance des préférences via `shared_preferences`
- Choix du thème clair / sombre (effectif dans toute l'app)
- Taille des icônes des dossiers/notes
- Langue (éventuellement)
- Réinitialisation de la base de données (option dev)

---

## Graphismes

**Fait :**
- Polices embarquées dans `assets/fonts/` et déclarées dans `pubspec.yaml`
- Marges latérales dans `NoteReadScreen` et `NoteEditScreen` (64 horizontal, 24 vertical)
- Bannières de note avec choix d'alignement (9 positions)
- Style Flutter Material par défaut

**À faire :**
- Thème global cohérent (couleurs, typographie de l'app elle-même)
- Mode sombre fonctionnel
- Cartes visuelles pour les dossiers et notes (au lieu de `ListTile`)
- Icône d'application personnalisée
- Animations de transition entre écrans
- Fond parchemin / ambiance médiévale en mode lecture des notes
- Logo Mythopolis