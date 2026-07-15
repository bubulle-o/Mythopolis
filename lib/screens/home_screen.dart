import 'package:flutter/material.dart';
import 'package:mythopolis/screens/folder_screen.dart';
import 'package:mythopolis/screens/folder_search_delegate.dart';
import 'package:mythopolis/screens/widgets/create_template_dialog.dart';
import 'package:mythopolis/utils/enum.dart';
import 'package:provider/provider.dart';
import '../providers/folder_provider.dart';
import 'package:mythopolis/models/folder.dart';
import 'package:mythopolis/providers/template_provider.dart';
import 'package:mythopolis/models/template.dart';


//////////////////////////////////////////////////////
//                 WIDGET PRINCIPAL                 //
//////////////////////////////////////////////////////

/// Écran d'accueil — affiche les dossiers à la racine (parentFolder = null).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;

  //////////////////////////////////////////////////////
  //                 INITIALISATION                   //
  //////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      context.read<FolderProvider>().loadFolders(null);
      context.read<TemplateProvider>().loadTemplates();
    });
  }


  //////////////////////////////////////////////////////
  //                     BUILD                        //
  //////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final folderProvider = context.watch<FolderProvider>();
    final templateProvider = context.watch<TemplateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Mythopolis'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Dossiers'),
            Tab(text: 'Templates'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: FolderSearchDelegate(null),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Onglet Dossiers
          ListView.builder(
            itemCount: folderProvider.getFolders(null).length,
            itemBuilder: (context, index) {
              final folder = folderProvider.getFolders(null)[index];
              return _buildFolderTile(context, folder);
            },
          ),
          // Onglet Templates
          ListView.builder(
            itemCount: templateProvider.getTemplates().length,
            itemBuilder: (context, index) {
              final template = templateProvider.getTemplates()[index];
              return _buildTemplateTile(context, template);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMenu(context),
        child: Icon(Icons.add),
      ),
    );
  }


  /// Tuile d'un dossier, avec icône et menu contextuel.
  Widget _buildFolderTile(BuildContext context, Folder folder) {
    return GestureDetector(
      onSecondaryTapUp: (details) => _showContextMenu(
        context,
        details.globalPosition,
        onRename: () => _showRenameDialog(context, folder),
        onMove: () => _showMoveDialog(context, folder),
        onDelete: () => _showDeleteDialog(context, folder),
      ),
      child: ListTile(
        leading: Icon(Icons.folder),
        title: Text(folder.name),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FolderScreen(folder: folder)),
        ).then((_) => context.read<FolderProvider>().loadFolders(null)),
      ),
    );
  }

  /// Tuile d'un template. Le clic ouvrira l'éditeur (à venir).
  Widget _buildTemplateTile(BuildContext context, Template template) {
    return GestureDetector(
      onSecondaryTapUp: (details) => _showContextMenu(
        context,
        details.globalPosition,
        onRename: () {},   // TODO
        onMove: null,      // un template ne se déplace pas
        onDelete: () {},   // TODO
      ),
      child: ListTile(
        leading: Icon(Icons.description),
        title: Text(template.name),
        subtitle: Text('${template.canvasWidth} × ${template.canvasHeight} px'),
        onTap: () {
          // TODO : ouvrir ModifyTemplateScreen
        },
      ),
    );
  }



  /// Affiche le menu contextuel à la position du clic droit.
  /// Une entrée dont la callback est null n'est pas affichée.
  void _showContextMenu(
    BuildContext context,
    Offset position, {
    VoidCallback? onRename,
    VoidCallback? onMove,
    VoidCallback? onDelete,
  }) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy,
      ),
      items: [
        if (onRename != null)
          PopupMenuItem(value: 'rename', child: Text('Renommer')),
        if (onMove != null)
          PopupMenuItem(value: 'move', child: Text('Déplacer')),
        if (onDelete != null)
          PopupMenuItem(value: 'delete', child: Text('Supprimer')),
      ],
    ).then((value) {
      if (value == 'rename') onRename?.call();
      if (value == 'move') onMove?.call();
      if (value == 'delete') onDelete?.call();
    });
  }



  /// Demande à l'utilisateur ce qu'il veut créer.
  void _showCreateMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.folder),
              title: Text('Nouveau dossier'),
              onTap: () {
                Navigator.pop(context);
                _showCreateFolderDialog(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.description),
              title: Text('Nouvelle template'),
              onTap: () {
                Navigator.pop(context);
                _showCreateTemplateDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////
  //                   DIALOGUES                      //
  //////////////////////////////////////////////////////
  
  /// Demande le nom du template, puis ouvre le dialog de choix du format.
  void _showCreateTemplateDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nouvelle template'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Nom de la template'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context); // ferme la popup du nom
                showDialog(
                  context: context,
                  builder: (_) => CreateTemplateDialog(name: controller.text),
                );
              }
            },
            child: Text('Suivant'),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nouveau dossier'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Nom du dossier'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await context.read<FolderProvider>().createFolder(
                    controller.text,
                    null,
                    null,
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Folder folder) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Renommer'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Nom du dossier'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await context.read<FolderProvider>().changeFolder(
                    folder.id,
                    controller.text,
                    folder.parentFolder,
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: Text('Renommer'),
          ),
        ],
      ),
    );
  }

  void _showMoveDialog(BuildContext context, Folder folder) async {
    List<Folder> allFolders = await context.read<FolderProvider>().getAllFolders();
    List<Map<String, dynamic>> tree = _buildFolderTree(allFolders, null, 0, folder.id);
    String? selectedId = folder.parentFolder;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Déplacer vers...'),
          content: SizedBox(
            width: 300,
            height: 400,
            child: ListView(
              children: [
                ListTile(
                  leading: Icon(Icons.home),
                  title: Text('Bureau'),
                  selected: selectedId == null,
                  onTap: () => setState(() => selectedId = null),
                ),
                ...tree.map((item) {
                  Folder f = item['folder'];
                  int depth = item['depth'];
                  return ListTile(
                    contentPadding: EdgeInsets.only(left: 16.0 + depth * 20),
                    leading: Icon(Icons.folder),
                    title: Text(f.name),
                    selected: selectedId == f.id,
                    onTap: () => setState(() => selectedId = f.id),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await context.read<FolderProvider>().changeFolder(
                    folder.id,
                    null,
                    selectedId,
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: Text('Déplacer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Folder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Si vous supprimer ce dossier, tout son contenu le sera également.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await context.read<FolderProvider>().deleteFolder(
                  folder.id,
                  folder.parentFolder,
                );
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }


  void createTemplateDialog(BuildContext dialogContext){


    showDialog(context: dialogContext, 
    builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          content: SizedBox(
            width: 400,
            child: Column(


            )
          )
        )
      )
    );
  }

  //////////////////////////////////////////////////////
  //                   UTILITAIRES                    //
  //////////////////////////////////////////////////////

  /// Construit récursivement l'arbre de dossiers pour le dialogue de déplacement.
  /// excludeId : le dossier qu'on déplace (ne doit pas apparaître comme destination).
  List<Map<String, dynamic>> _buildFolderTree(
      List<Folder> allFolders, String? parentId, int depth, String excludeId) {
    List<Map<String, dynamic>> result = [];
    for (Folder folder in allFolders) {
      if (folder.parentFolder == parentId && folder.id != excludeId) {
        print('${folder.name} - depth: $depth - parent: ${folder.parentFolder}');
        result.add({'folder': folder, 'depth': depth});
        result.addAll(_buildFolderTree(allFolders, folder.id, depth + 1, excludeId));
      }
    }
    return result;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}