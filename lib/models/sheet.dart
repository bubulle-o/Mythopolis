class Sheet {
  String id;
  String name;
  String parentFolder; // toujours rattachée à un dossier
  String? iconPath;
  String? content;   // Delta JSON produit par flutter_quill

  

  Sheet(this.id, this.name, this.parentFolder, this.iconPath, this.content);



}