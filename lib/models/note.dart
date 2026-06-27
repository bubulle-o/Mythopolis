class Note{
    
    String name ;
    String parentFolder ;
    String id;
    String? iconPath ;
    String? content;
    String? bookmarks;
    

    
    Note( this.id, this.name, this.parentFolder, this.iconPath, this.content, this.bookmarks){
/*
        Initialise un nouveau note
        
        Args:
            name: Nom de note
            iconPath: Chemin vers l'icône (optionnel)
            parentFolder: Nom du note parent (optionnel)
            id: Identifiant unique du note
        
*/        

    }


    Map<String, dynamic> toMap(){
/*
        Convertit le note en dictionnaire pour sauvegarder en JSON
        
        Returns:
            dict: Toutes les infos du note
*/

        return {
            "id" : id,
            "name": name,
            "parentFolder" : parentFolder ,
            "iconPath": iconPath,
            "content" : content,
            "bookmarks" : bookmarks
          };
      }




    static Note fromMap(Map<String, dynamic> data){
/*
        Crée un objet Note depuis un dictionnaire
            
        Args:
            data: Dictionnaire contenant les infos du note
            
        Returns:
            Note: Un nouvel objet Note
*/

        Note note = Note(data["id"], data["name"],  data["parentFolder"], data["iconPath"], data["content"], data["bookmarks"] 
        );
        return note;
    }

}