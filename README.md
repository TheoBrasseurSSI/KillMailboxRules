Auteur : Théo Brasseur | https://github.com/TheoBrasseurSSI | https://linkedin.com/in/tbrasseur

---

Outil PowerShell de révocation des sessions et tokens Microsoft 365. Il permet à un administrateur de déconnecter immédiatement un ou plusieurs utilisateurs de toutes leurs sessions actives et d'invalider leurs tokens de refresh.

---

⚠ La révocation est immédiate et forcera une reconnexion complète avec MFA pour les utilisateurs ciblés !

---

Prérequis

* Compte Microsoft 365 avec au moins l'un des rôles suivants :

* Global Administrator

* ou User Administrator

* ⚠ Ne pas exécuter dans PowerShell ISE

---

Périmètre de la révocation

* **Mode 1** : un seul utilisateur, saisi manuellement

* **Mode 2** : plusieurs utilisateurs, saisis un par un (ligne vide + ENTRÉE pour terminer)

* La révocation invalide :

* Toutes les sessions actives

* Les refresh tokens et tokens MFA

---

Authentification

* Le script utilise le Device Code Flow (flux OAuth2 standard Microsoft).

* À chaque lancement, un code est affiché dans la console. Il faut :

* Ouvrir le lien aafiché

* Saisir le code affiché

* Se connecter avec le compte admin souhaité

* ✅ Cette méthode permet de choisir librement le compte à chaque exécution, quel que soit le tenant ciblé.

* ✅ Aucune session n'est mise en cache — la connexion est isolée à la session PowerShell en cours.

* ⚠ Le compte utilisé doit avoir les droits suffisants sur le tenant ciblé.

---

Saisie utilisateur

Lors de l'exécution, le script demande :

* Le mode de révocation (1 ou 2)

* L'adresse email de l'utilisateur ciblé (ou plusieurs selon le mode)

---

Lancement

* Créez un raccourci de Launcher.bat → clic-droit → Créer un raccourci.

* Le fichier .bat :

* applique une ExecutionPolicy Bypass (temporaire, pour la session uniquement)

* exécute ensuite le script RevokeSession.ps1

* ⚠ Le fichier Launcher.bat et le fichier RevokeSession.ps1 doivent rester dans le même dossier.

* Un fichier .ico est fourni pour l'icône de votre raccourci.

---

Exécution manuelle

Le script peut aussi être lancé directement depuis PowerShell :
powershell.exe -ep Bypass -File .\RevokeSession.ps1
Le bypass est temporaire et n'applique aucune modification permanente sur le poste.

---

Logs

* Un fichier de log est automatiquement généré à chaque exécution.

* Le dossier logs\ est créé automatiquement au premier lancement, aucune action manuelle nécessaire.

* Les logs sont stockés dans le dossier logs\ à la racine du projet.

* Chaque fichier est nommé avec le timestamp de la session : Revoke_2026-06-10_15-01.log

* Le log contient : compte admin utilisé, utilisateurs ciblés, résultat par utilisateur (succès/échec), bilan final.

* ⚠ Le dossier logs\ est exclu du dépôt Git (.gitignore) — vos logs restent locaux.