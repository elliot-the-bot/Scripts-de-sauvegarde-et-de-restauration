#!/bin/sh

# Ce script permet de restaurer les données des sauvegardes complètes
# Il est très important de le placer dans /home/mugen/archives car c est l endroit où sont stockées toutes les anciennes sauvegardes

# Nom du répertoire où sont stockées toutes les anciennes sauvegardes
backup_dir="/home/mugen/archives"

# Obtention du numéro de la semaine à restaurer auprès de l'utilisateur
echo "Merci d'indiquer le numéro (exemple : "06","12","18") de la semaine que vous souhaitez restaurer : "
read restore_week_nbr

# Affichage de variable à des fins de test et de vérification
# echo $restore_week_nbr

# Nom du répertoire de sauvegarde complète correspondant à la semaine spécifiée
restore_dir="$backup_dir/full_backup_week-$restore_week_nbr"

# Affichage de variable à des fins de test et de vérification
# echo $restore_dir

# Vérifie si le répertoire de sauvegarde complet existe
if [ -d "$restore_dir" ]; then
    echo "Le répertoire de sauvegarde complète pour la semaine $restore_week_nbr a été trouvé."

    # Demande de confirmation pour la restauration
    echo "Êtes-vous sûr de vouloir restaurer à partir de cette sauvegarde ? Merci de répondre par "Oui" ou "Non" : "
    read confirmation

    if [ "$confirmation" = "Oui" ]; then
        # Restauration
        echo "Restauration en cours..."

        # Restauration de la sauvegarde complète
        rsync -av --delete --delete-excluded "$restore_dir/b2d/" jin@192.168.99.134:/home/b2d
        rsync -av --delete --delete-excluded "$restore_dir/jin/" jin@192.168.99.134:/home/jin
        rsync -av --delete --delete-excluded "$restore_dir/nginx/" jin@192.168.99.134:/etc/nginx
        rsync -av --delete --delete-excluded "$restore_dir/wordpress/" jin@192.168.99.134:/var/www/html/wordpress

        echo "La restauration complète est terminée !"
    else
        echo "Restauration annulée."
    fi
else
    echo "Le répertoire de sauvegarde complète pour la semaine $restore_week_number n'a pas été trouvé."
    echo "La restauration ne peut pas être effectuée."
fi
