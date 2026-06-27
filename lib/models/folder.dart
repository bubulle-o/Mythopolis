/// Représente un dossier de fiches
class Folder{
    
    String name ;
    String? parentFolder ;
    String id;
    String? iconPath ;
    

    
    Folder( this.id, this.name, this.parentFolder, this.iconPath){
/*
        Initialise un nouveau dossier
        
        Args:
            name: Nom du dossier
            iconPath: Chemin vers l'icône (optionnel)
            parentFolder: Nom du dossier parent (optionnel)
            id: Identifiant unique du dossier
        
*/        

    }


    Map<String, dynamic> toMap(){
/*
        Convertit le dossier en dictionnaire pour sauvegarder en JSON
        
        Returns:
            dict: Toutes les infos du dossier
*/

        return {
            "id" : id,
            "name": name,
            "iconPath": iconPath,
            "parentFolder" : parentFolder ,
          };
      }




    static Folder fromMap(Map<String, dynamic> data){
/*
        Crée un objet Folder depuis un dictionnaire
            
        Args:
            data: Dictionnaire contenant les infos du dossier
            
        Returns:
            Folder: Un nouvel objet Folder
*/

        Folder folder = Folder(data["id"], data["name"],  data["parentFolder"], data["iconPath"] 
        );
        return folder;
    }

}