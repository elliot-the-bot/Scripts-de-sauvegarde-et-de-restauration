#!/bin/sh


# DECLARATION DE VARIABLES

## Répertoire de destination pour les sauvegardes (présent sur le serveur de stockage)
backup_dir="/home/mugen/backup"

## Marqueurs de temps
jour=`date "+%d"`
semaine=`date "+%W"`
# week_number=$(date +%W)
# timestamp=$(date ...+%Y-%m-%d-Hour%H")

## Nom du répertoire de sauvegarde complète avec le numéro de la semaine
full_backup_dir="$backup_dir/full_backup_week-$semaine"

## Obtention du numéro de la semaine précédente (semaine -1)
previous_week_number=$(expr $semaine - 01)

## Ajout d'un zéro devant le numéro de la semaine -1 si nécessaire
previous_week_number=$(printf "%02d" $previous_week_number)

## Nom du répertoire de sauvegarde complète avec le numéro de la semaine -1
previous_full_backup_dir="$backup_dir/full_backup_week-$previous_week_number/"


# Affichage de variables à des fins de test et de vérification
# echo $jour
# echo $semaine
# echo $full_backup_dir
# echo $previous_week_number
# echo $previous_full_backup_dir


# PREMIERE CONDITION
## Le script va procéder à une vérification, celle de l existence de la sauvegarde complète pour la semaine -1
## Ce dossier indique qu'une sauvegarde complète a été effectuée à la semaine -1
## Si ce répertoire existe, alors les sauvegardes (la complète et les incrémentielles) associées à cette semaine -1 vont être déplacées pour archivage
if ssh mugen@192.168.99.135 "[ -d $previous_full_backup_dir ]"; then
    echo "Déplacement de la sauvegarde complète ($previous_full_backup_dir) et de toutes les sauvegardes incrémentielles de la semaine précédente pour archivage."

    ## Ici on rajoute un / à la fin du chemin de la source car il s agit d un dossier
    ssh mugen@192.168.99.135 "mv $previous_full_backup_dir/ /home/mugen/archives/"
    ssh mugen@192.168.99.135 "mv $backup_dir/incremental_backup-$previous_week_number-*/  /home/mugen/archives/"
fi


# DEUXIEME CONDITION
## Le script va procéder à une vérification, celle de l'existence de la sauvegarde complète pour la semaine en cours
## Si ce répertoire existe, alors il exécute une sauvegarde incrémentielle
if ssh mugen@192.168.99.135 "[ -d $full_backup_dir ]"; then
    echo "La sauvegarde complète de la semaine $semaine a déjà été effectuée. Exécution de la sauvegarde incrémentielle."


    # Sauvegarde incrémentielle

    ## Chaque ligne rsync contient les dossiers qu'on souhaite sauvegarder
    backup_path="$backup_dir/incremental_backup-$semaine-$jour"
    rsync -av --delete --delete-excluded --link-dest=$backup_dir/current /home/b2d mugen@192.168.99.135:"$backup_path"
    rsync -av --delete --delete-excluded --link-dest=$backup_dir/current /home/jin mugen@192.168.99.135:"$backup_path"
    rsync -av --delete --delete-excluded --link-dest=$backup_dir/current /etc/nginx mugen@192.168.99.135:"$backup_path"
    rsync -av --delete --delete-excluded --link-dest=$backup_dir/current /var/www/html/wordpress mugen@192.168.99.135:"$backup_path"

    ## Si la sauvegarde incrémentielle s est bien déroulée,
    ## l'ancien lien symbolique créé à la fin de la sauvegarde précédente (et qui pointe sur le dossier de la sauvegarde précédente) est supprimé,
    ## et remplacé par un nouveau qui pointe directement sur la dernière sauvegarde incrémentielle créée,
    ## ainsi, cette dernière sauvegarde incrémentielle servira de point de référence afin de ne sauvegarder que les données différentes par rapport à elle
    ## (rajouter -f devant $backup_dir/current en cas d erreur)
    if [ $? -eq 0 ]; then
        ssh mugen@192.168.99.135 "rm $backup_dir/current"
        ssh mugen@192.168.99.135 "ln -s $backup_path $backup_dir/current"
    fi

    echo "La sauvegarde incrémentielle est terminée !"



## Si le script ne trouve aucune trace de l'existence de la sauvegarde complète de la semaine en cours,
## il va procéder à une sauvegarde complète de la semaine en cours
else
    echo "La sauvegarde complète de la semaine $semaine n'a pas encore été effectuée. Exécution de la sauvegarde complète."


    # Sauvegarde complète

    ## Récupération de la base de données du site WordPress grâce à mysqldump
    ## L'option --databases permet de recréer automatiquement la base de données avant de réimporter les données
    ## L'option --add-drop-database permet de supprimer la base de données existante pour qu elle soit recréée lors de la restauration
    database_dump=$(mysqldump -u root --password=password --databases wordpress_db --add-drop-database)
    path="/home/b2d"
    database="wordpress_db.sql"

    ## Création du répertoire /home/b2d si il n'existe pas
    ## Ce dossier est l'endroit où est stockée la base de données exportée
    if [ ! -d "$path" ]; then
        mkdir -p "$path"
    fi

    echo "$database_dump" > "$path/$database"


    ## Chaque ligne rsync contient un dossier que l'on souhaite sauvegarder sur le serveur de stockage
    rsync -av --delete --delete-excluded /home/b2d mugen@192.168.99.135:"$full_backup_dir"
    rsync -av --delete --delete-excluded /home/jin mugen@192.168.99.135:"$full_backup_dir"
    rsync -av --delete --delete-excluded /etc/nginx mugen@192.168.99.135:"$full_backup_dir"
    rsync -av --delete --delete-excluded /var/www/html/wordpress mugen@192.168.99.135:"$full_backup_dir"


    ## La première ligne ssh non commentée va retourner un message d'erreur sans gravité au premier lancement,
    ## mais il est nécessaire de la laisser, sinon la première sauvegarde complète de chaque semaine ne supprimera pas l'ancien lien symbolique
    ## La seconde ligne ssh non commentée va permettre de créer un lien symbolique qui pointe sur la sauvegarde complète créée,
    ## ainsi, elle va servir de point de référence, et la sauvegarde incrémentielle ne sauvegardera que les données différentes par rapport à elle
    if [ $? -eq 0 ]; then
#        ssh mugen@192.168.99.135 ...mkdir -p $full_backup_dir"
        ssh mugen@192.168.99.135 "rm $backup_dir/current"
        ssh mugen@192.168.99.135 "ln -s $full_backup_dir $backup_dir/current"
    fi

    echo "La sauvegarde complète de la semaine $semaine est terminée !"
fi
