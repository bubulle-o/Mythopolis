# 🏛️ Mythopolis

*La cité des mythes : une application pour bâtir et organiser tes univers fictifs.*

Le nom vient du grec *mythos* (récit) + *polis* (cité).

---

## 1. C'est quoi ?

Mythopolis est une application **Flutter/Dart** pour organiser un univers de jeu de rôle ou de fiction. Elle est développée par Élise (IMT Atlantique), en apprentissage. Cible : **Windows d'abord, mobile ensuite**.

Tu y ranges quatre types de contenus :

| Élément | Rôle |
|---|---|
| 📁 **Dossier** | Range les autres éléments, avec des dossiers dans des dossiers |
| 📝 **Note** | Texte riche (gras, polices, images, liens internes, bannière) |
| 🧾 **Fiche** | Fiche de personnage remplie à partir d'un template |
| 🧩 **Template** | Modèle de fiche réutilisable (pages avec zones de texte, photo, jauges) |

Les éléments peuvent être reliés entre eux par des **liens internes** (par exemple, un lien dans une note vers un dossier).

---

## 2. Technologies utilisées

| Besoin | Outil | Pourquoi |
|---|---|---|
| Interface | Flutter / Dart | Une seule base de code pour Windows et mobile |
| Base de données | `sqflite` + `sqflite_common_ffi` | SQLite local ; la version `ffi` est obligatoire sur Windows |
| Gestion d'état | `provider` | Les écrans se redessinent quand les données changent |
| Éditeur de texte riche | `flutter_quill` (+ extensions) | Éditeur WYSIWYG, le texte est stocké en JSON (format *Delta*) |
| Images | `image_picker`, `path_provider` | Choisir une image, puis la copier dans le dossier de l'app |
| Boutons d'action | `flutter_speed_dial` | Plusieurs actions sur un seul bouton |

---

## 3. Comment le code est organisé

Chaque type d'élément suit le même chemin, en 4 couches :

```
Modèle  →  Service  →  Provider  →  Écran
(données)  (base SQL)  (mémoire + notifications)  (affichage)
```

- **Modèle** : la forme d'un objet (`Folder`, `Note`...) et sa conversion vers/depuis une `Map`.
- **Service** : le seul endroit qui parle à SQLite (créer, lire, modifier, supprimer).
- **Provider** : garde les données en mémoire et prévient les écrans quand elles changent.
- **Écran** : affiche et réagit aux clics.

```
lib/
├── models/      folder.dart, note.dart
├── services/    database_helper.dart, folder_service.dart, note_service.dart
├── providers/   folder_provider.dart, note_provider.dart, settings_provider.dart
├── screens/     home_screen, folder_screen, folder_search_delegate,
│                note_read_screen, note_edit_screen
│   └── widgets/ quill_toolbar.dart (barre d'outils de texte, réutilisable)
└── utils/       enum.dart (BannerAlignment, AppTheme)
```

---

## 4. Données

### Base de données
- `folders` : `id, name, parentFolder, iconPath`
- `notes` : `id, name, parentFolder, iconPath, content, bookmarks, bannerPath, bannerAlignment`
- Les liens parent → enfant utilisent `ON DELETE CASCADE` : **supprimer un dossier supprime tout son contenu**.
- `PRAGMA foreign_keys = ON` est activé à chaque ouverture, sinon SQLite ignore les clés étrangères.
- Format des IDs : `folder_00001`, `note_00001`...

### Fichiers sur le disque
- Les images (bannières, plus tard fonds et icônes) sont **copiées** dans `<AppDocumentsDirectory>`.
- Ainsi l'app ne dépend plus du fichier d'origine, qui peut être déplacé ou supprimé.

---

## 5. Où j'en suis

### 📁 Dossiers : ✅ terminé (sauf le visuel)
- Créer, renommer, déplacer, supprimer (avec cascade).
- Navigation, recherche par nom, menu clic droit.
- Déplacement via un arbre indenté, qui exclut le dossier lui-même et ses descendants.
- 4 onglets : Tout / Dossiers / Notes / Fiches.
- **À faire** : icônes personnalisables, affichage en cartes au lieu d'une liste.

### 📝 Notes : ✅ bien avancé
- CRUD complet, stockage du contenu en Delta JSON.
- **Deux modes** : lecture (par défaut) et édition. On bascule avec des boutons.
- **Édition riche** : barre d'outils complète, 9 polices embarquées, images, annuler avec Ctrl+Z.
- **Barre d'outils séparée** : elle vit dans `widgets/quill_toolbar.dart` et se branche sur n'importe quel `QuillController`. On pourra donc la réutiliser pour les fiches et les zones de texte des templates.
- **Liens internes** : un lien dont l'adresse commence par `note_` ou `folder_` ouvre l'élément correspondant. Un sélecteur permet de choisir la cible dans l'arbre.
- **Bannière** : ajouter, supprimer, recadrer (9 positions d'alignement).
- **Sauvegarde** : bouton Save, et une confirmation si on quitte avec des modifications.
- **À faire** : icône de note, export PDF, liens vers les fiches (`sheet_`), encadrés colorés dans lesquels on écrit.

### 🧩 Templates : 📐 conçu, pas encore codé
Seule la conception est faite (voir section 6).

- **Phase 1** : modèles, tables SQLite, service, provider, liste des templates sur l'accueil, dialog de création (A4 vierge, image de fond ou duplication).
- **Phase 2 (éditeur)** : afficher une page, créer des zones à la souris, les déplacer et redimensionner par glisser-déposer, gérer les pages.
- **Phase 3** : zones photo, jauges, export JPG.

### 🧾 Fiches : ⏳ à faire
- Modèle, service, provider, onglet « Fiches ».
- Créer une fiche en choisissant un template, puis remplir ses zones.
- Modifier un template **ne doit pas** changer les fiches déjà remplies.
- Mode lecture / édition, comme pour les notes.

### ⚙️ Paramètres : 🔸 début
- Fait : `SettingsProvider` avec le thème clair/sombre.
- À faire : écran de réglages, sauvegarde avec `shared_preferences`, thème effectif dans toute l'app.

### 🎨 Graphismes
- Fait : polices, marges des notes, bannières.
- À faire : thème global cohérent, mode sombre, cartes visuelles, icône et logo de l'app, ambiance parchemin.

---

## 6. Templates : les décisions de conception et leurs raisons

**Pourquoi des pourcentages et pas des pixels ?**
Chaque zone est positionnée en pourcentage de la page (0.0 à 1.0). La page peut alors s'afficher à n'importe quelle taille d'écran, et l'export JPG se fait à la taille réelle, sans jamais modifier les données.

**Taille de la page**
- Toutes les pages d'un template ont la même taille.
- A4 vierge : environ 1240 × 1754 px (A4 à 150 dpi).
- Avec une image de fond : la taille de l'image, sans déformation.

**Types de zones**
- **Texte** : un titre fixe est simplement une zone de texte *verrouillée*. Une zone non verrouillée peut avoir un **placeholder** (texte d'exemple stylé) visible seulement en édition, tant que la zone est vide. Si le texte dépasse, il est **coupé à l'affichage** (`ClipRect`) mais jamais supprimé en base.
- **Photo** : rectangles uniquement en v1.
- **Jauge** : un nombre d'icônes (pleine / vide), la fiche ne stocke qu'un entier. Cliquer sur la Nᵉ icône met la valeur à N, recliquer sur la 1ʳᵉ à 1 remet à 0.

**Empilement**
Ordre fixe : jauges au-dessus, puis texte, puis photos. Limite acceptée en v1 : pas de photo par-dessus un texte.

**Affichage**
On utilise `Stack` + `Positioned` plutôt que `CustomPainter` : chaque zone est un vrai widget, donc cliquable, déplaçable, et peut contenir un éditeur Quill.

**Duplication**
Copier un template copie aussi physiquement ses images de fond, pour que supprimer l'un n'abîme jamais l'autre.

**Tables prévues** : `templates`, `template_pages`, `template_text_zones`, `template_photo_zones`, `template_gauge_zones`, `gauge_icons` (toutes liées en cascade).

---

## 7. Historique

Le projet est né d'un prototype **Python/Tkinter** (un fichier JSON par objet). Il a été réécrit en Flutter/SQLite, d'où l'héritage du concept des templates (pages, zones de texte, zones photo, titres).

---

## 8. Façon de travailler

- Aucun code fourni sans demande explicite.
- Chaque ligne expliquée précisément, pour pouvoir la refaire seule.
- Des questions plutôt que des solutions toutes faites, des coups de pouce seulement en cas de blocage.
- Apprentissage avant rapidité, avec de la franchise et des emojis.