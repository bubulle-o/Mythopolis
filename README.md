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
- **UI** : `flutter_speed_dial` pour les boutons d'action multiples

### Architecture

```
lib/
├── models/
│   ├── folder.dart       # Folder(id, name, parentFolder?, iconPath?)
│   └── note.dart         # Note(id, name, parentFolder, iconPath?, content?, bookmarks?)
├── services/
│   ├── database_helper.dart  # Singleton SQLite partagé
│   ├── folder_service.dart   # CRUD dossiers
│   └── note_service.dart     # CRUD notes
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
    └── enum.dart         # NoteMode, AppTheme
```

### Base de données

- Table `folders` : `id TEXT PRIMARY KEY, name TEXT, parentFolder TEXT, iconPath TEXT` avec `FOREIGN KEY CASCADE`
- Table `notes` : `id TEXT PRIMARY KEY, name TEXT NOT NULL, parentFolder TEXT NOT NULL, iconPath TEXT, content TEXT, bookmarks TEXT` avec `FOREIGN KEY CASCADE`
- IDs format : `folder_00001`, `note_00001`
- `PRAGMA foreign_keys = ON` activé à chaque ouverture

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
- CRUD complet identique aux dossiers
- Affichage dans l'onglet "Notes" de `FolderScreen`
- Menu contextuel clic droit
- Mode lecture par défaut à l'ouverture (`NoteReadScreen`)
- Mode édition WYSIWYG (`NoteEditScreen`) avec `flutter_quill`
- Barre d'outils complète : gras, italique, souligné, couleurs, alignement, listes, citations, code, sélection de police, taille
- 9 polices custom embarquées : Cardo, EB Garamond, Cinzel, MedievalSharp, UnifrakturMaguntia, Pirata One, Orbitron, Audiowide, Lexend
- Insertion d'images via `flutter_quill_extensions`
- Liens internes vers notes/fiches/dossiers via `onLaunchUrl` callback (préfixe `https://` + ID, parsing custom)
- Marges latérales pour aérer l'écriture
- Stockage Delta JSON dans la colonne `content`
- Sauvegarde manuelle via bouton Save
- Dialog "Voulez-vous enregistrer ?" au retour arrière (sort directement vers `FolderScreen`, saute `NoteReadScreen`)
- Ctrl+Z natif via `QuillController`

**À faire :**
- Bouton custom dans la toolbar pour sélectionner la cible d'un lien interne via arborescence (au lieu de taper l'URL manuellement)
- Format deux pages A4 côte à côte en mode lecture (façon livre)
- Fondu entre les pages via `AnimatedSwitcher`
- Sommaire généré automatiquement à partir des headers Delta + bouton de retour
- Marquepages avec ancrage texte (suivent le déplacement du contenu)
- Icône livre personnalisable pour la note
- Encadrés sur titres via `BoxDecoration` sur `DefaultTextBlockStyle`
- Export PDF via `vsc_quill_delta_to_html` puis conversion HTML→PDF

### Template

**Fait :**
- Concept hérité du prototype Python : structure de page A4 avec zones de texte, zones photo, titres
- Modèle `Template` avec `pages`, `add_page`, `add_text_zone`, `add_title`, `add_photo_zone`

**À faire :**
- Tout porter de Python vers Dart
- Modèle `Template` dans `models/`
- `TemplateService` (CRUD SQLite)
- `TemplateProvider`
- `TemplateScreen` (liste des templates)
- `ModifyTemplate` (éditeur de template avec canvas)
- Sélection d'image de fond ou A4 vierge
- Ajout/déplacement de zones de texte par drag & drop
- Ajout de titres
- Ajout de zones photo avec formes
- Multi-pages avec réordonnancement
- Stockage des images de fond dans `assets/backgrounds/`

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
- Mode d'écriture préféré par défaut (si on réintroduit plusieurs modes)
- Langue (éventuellement)
- Réinitialisation de la base de données (option dev)

---

## Graphismes

**Fait :**
- Polices embarquées dans `assets/fonts/` et déclarées dans `pubspec.yaml`
- Marges latérales dans `NoteReadScreen` et `NoteEditScreen` (64 horizontal, 24 vertical)
- Style Flutter Material par défaut

**À faire :**
- Thème global cohérent (couleurs, typographie de l'app elle-même)
- Mode sombre fonctionnel
- Cartes visuelles pour les dossiers et notes (au lieu de `ListTile`)
- Icône d'application personnalisée
- Animations de transition entre écrans
- Fond parchemin / ambiance médiévale en mode lecture des notes
- Logo Mythopolis