Clear-Host
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$WarningPreference = "SilentlyContinue"

$banner = @"                                                                                                                                                            
##    ## #### ##       ##       ##     ##    ###    #### ##       ########   #######  ##     ## ########  ##     ## ##       ########  ######  
##   ##   ##  ##       ##       ###   ###   ## ##    ##  ##       ##     ## ##     ##  ##   ##  ##     ## ##     ## ##       ##       ##    ## 
##  ##    ##  ##       ##       #### ####  ##   ##   ##  ##       ##     ## ##     ##   ## ##   ##     ## ##     ## ##       ##       ##       
#####     ##  ##       ##       ## ### ## ##     ##  ##  ##       ########  ##     ##    ###    ########  ##     ## ##       ######    ######  
##  ##    ##  ##       ##       ##     ## #########  ##  ##       ##     ## ##     ##   ## ##   ##   ##   ##     ## ##       ##             ## 
##   ##   ##  ##       ##       ##     ## ##     ##  ##  ##       ##     ## ##     ##  ##   ##  ##    ##  ##     ## ##       ##       ##    ## 
##    ## #### ######## ######## ##     ## ##     ## #### ######## ########   #######  ##     ## ##     ##  #######  ######## ########  ######                                                                                                                                                                                                              
"@

Write-Host $banner -ForegroundColor Cyan
Write-Host "[Exchange Online - Audit et suppression des regles de messagerie]" -ForegroundColor DarkGray
Write-Host ""

# =========================
# Preparation environnement
# =========================
Write-Host "Preparation de l'environnement PowerShell..." -ForegroundColor Yellow

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "Installation du fournisseur NuGet..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Installation du module ExchangeOnlineManagement..."
    Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
}

Import-Module ExchangeOnlineManagement

# =========================
# Connexion
# =========================
Write-Host "Connexion a Exchange Online..." -ForegroundColor Yellow

try {
    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
}
catch {
    Write-Host "Erreur : impossible de se connecter. Verifiez vos droits." -ForegroundColor Red
    Write-Host ""
    Write-Host "Appuyez sur ESPACE pour quitter"
    do { $key = [System.Console]::ReadKey($true) } until ($key.Key -eq "Spacebar")
    exit
}

# =========================
# Initialisation log
# =========================
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir    = Join-Path $scriptDir "..\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
$logFile = Join-Path $logDir "KMR_$timestamp.log"

function Write-Log {
    param([string]$message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $message"
    Add-Content -Path $script:logFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

Write-Log "=== Nouvelle session KillMailboxRules ==="
Write-Log "Compte admin : $($env:USERNAME)"

# =========================
# Boucle menu principal
# =========================
while ($true) {

    Write-Host ""
    Write-Host "Mode d'audit :" -ForegroundColor Yellow
    Write-Host "  [1] Toutes les regles d'une adresse mail"
    Write-Host "  [2] Recherche d'une regle par nom sur tout le tenant"
    Write-Host "  [Q] Quitter"
    Write-Host ""
    $mode = Read-Host "Votre choix"

    if ($mode -eq "Q" -or $mode -eq "q") {
        break
    }

    # =========================
    # MODE 1 : regles d'une adresse
    # =========================
    elseif ($mode -eq "1") {

        $mailbox = Read-Host "Entrez l'adresse email"
        if ([string]::IsNullOrWhiteSpace($mailbox)) {
            Write-Host "Adresse non valide." -ForegroundColor Red
            continue
        }

        Write-Log "Mode : Audit adresse | Cible : $mailbox"
        Write-Host "Recherche des regles pour $mailbox" -NoNewline

        try {
            $regles = Get-InboxRule -Mailbox $mailbox -ErrorAction Stop
        }
        catch {
            Write-Host ""
            Write-Host "Erreur : impossible de recuperer les regles." -ForegroundColor Red
            Write-Log "ERREUR : $($_.Exception.Message)"
            continue
        }

        Write-Host ""

        if (-not $regles -or $regles.Count -eq 0) {
            Write-Host "Aucune regle trouvee pour cette adresse." -ForegroundColor Yellow
            Write-Log "Aucune regle trouvee pour $mailbox"
            $retour = Read-Host "Retour au menu ? (OUI pour continuer, toute autre valeur pour quitter)"
            if ($retour -eq "OUI") { continue } else { break }
        }

        Write-Host "Regles trouvees : $($regles.Count)" -ForegroundColor Cyan
        Write-Host ""

        $i = 1
        foreach ($regle in $regles) {
            Write-Host "  [$i] Nom       : $($regle.Name)" -ForegroundColor White
            Write-Host "      Activee   : $($regle.Enabled)"
            Write-Host "      Transfert : $($regle.ForwardTo)"
            Write-Host "      Rediriger : $($regle.RedirectTo)"
            Write-Host "      Supprimer : $($regle.DeleteMessage)"
            Write-Host ""
            Write-Log "Regle $i : Nom=$($regle.Name) | Activee=$($regle.Enabled) | Transfert=$($regle.ForwardTo) | Redirection=$($regle.RedirectTo) | Suppression=$($regle.DeleteMessage)"
            $i++
        }

        $supprimer = Read-Host "Voulez-vous supprimer une regle ? (OUI pour continuer, NON pour retourner au menu, toute autre valeur pour quitter)"
        if ($supprimer -eq "NON") { continue }
        if ($supprimer -ne "OUI") { break }

        $nomRegle = Read-Host "Entrez le nom exact de la regle a supprimer"
        if ([string]::IsNullOrWhiteSpace($nomRegle)) {
            Write-Host "Nom invalide." -ForegroundColor Red
            continue
        }

        Write-Host ""
        Write-Host "ATTENTION : La regle '$nomRegle' va etre supprimee de la boite $mailbox." -ForegroundColor Red
        Write-Host "Cette action est IRREVERSIBLE." -ForegroundColor Red
        Write-Host ""
        $confirm = Read-Host "Confirmer la suppression ? (OUI pour confirmer, toute autre valeur pour annuler)"
        if ($confirm -ne "OUI") {
            Write-Host "Suppression annulee." -ForegroundColor Yellow
            Write-Log "Suppression annulee par l'operateur"
            continue
        }

        try {
            Remove-InboxRule -Mailbox $mailbox -Identity $nomRegle -Confirm:$false -ErrorAction Stop
            Write-Host "Regle '$nomRegle' supprimee avec succes." -ForegroundColor Green
            Write-Log "Succes : regle '$nomRegle' supprimee de $mailbox"
        }
        catch {
            Write-Host "Erreur lors de la suppression." -ForegroundColor Red
            Write-Log "ERREUR suppression : $($_.Exception.Message)"
        }
    }

    # =========================
    # MODE 2 : recherche par nom sur tout le tenant
    # =========================
    elseif ($mode -eq "2") {

        $nomRegle = Read-Host "Entrez le nom de la regle a rechercher"
        if ([string]::IsNullOrWhiteSpace($nomRegle)) {
            Write-Host "Nom non valide." -ForegroundColor Red
            continue
        }

        Write-Log "Mode : Recherche par nom | Regle : $nomRegle"
        Write-Host "Recuperation de toutes les boites du tenant" -NoNewline

        try {
            $boites = Get-Mailbox -ResultSize Unlimited -ErrorAction Stop -WarningAction SilentlyContinue
        }
        catch {
            Write-Host ""
            Write-Host "Erreur : impossible de recuperer les boites." -ForegroundColor Red
            Write-Log "ERREUR recuperation boites : $($_.Exception.Message)"
            continue
        }

        Write-Host ""
        Write-Host "Scan en cours" -NoNewline

        $trouvees = @()

        foreach ($boite in $boites) {
            Write-Host "." -NoNewline
            try {
                $regles = Get-InboxRule -Mailbox $boite.PrimarySmtpAddress -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                $match  = $regles | Where-Object { $_.Name -eq $nomRegle }
                if ($match) { $trouvees += $boite.PrimarySmtpAddress }
            }
            catch {}
        }

        Write-Host ""

        if ($trouvees.Count -eq 0) {
            Write-Host "Aucune boite trouvee avec une regle nommee '$nomRegle'." -ForegroundColor Yellow
            Write-Log "Aucune boite trouvee avec la regle '$nomRegle'"
            $retour = Read-Host "Retour au menu ? (OUI pour continuer, toute autre valeur pour quitter)"
            if ($retour -eq "OUI") { continue } else { break }
        }

        Write-Host "Boites avec la regle '$nomRegle' : $($trouvees.Count)" -ForegroundColor Cyan
        Write-Host ""
        $idx = 1
        foreach ($adresse in $trouvees) {
            Write-Host "  [$idx] $adresse" -ForegroundColor White
            $idx++
        }
        Write-Host ""
        Write-Log "Boites trouvees ($($trouvees.Count)) : $($trouvees -join ', ')"

        Write-Host "Entrez les numeros des boites a traiter separes par des virgules (ex: 1,3)" -ForegroundColor DarkGray
        $choix = Read-Host "ou TOUT pour toutes, NON pour retourner au menu, toute autre valeur pour quitter"

        if ($choix -eq "NON") { continue }
        if ([string]::IsNullOrWhiteSpace($choix)) { break }

        if ($choix -eq "TOUT") {
            $cibles = $trouvees
        }
        else {
            try {
                $indices = $choix -split "," | ForEach-Object { [int]$_.Trim() - 1 }
                $cibles  = $indices | ForEach-Object { $trouvees[$_] }
            }
            catch {
                Write-Host "Choix invalide." -ForegroundColor Red
                continue
            }
        }

        Write-Host ""
        Write-Host "ATTENTION : La regle '$nomRegle' va etre supprimee de $($cibles.Count) boite(s)." -ForegroundColor Red
        Write-Host "Cette action est IRREVERSIBLE." -ForegroundColor Red
        Write-Host ""
        $confirm = Read-Host "Confirmer ? (OUI pour confirmer, toute autre valeur pour annuler)"
        if ($confirm -ne "OUI") {
            Write-Host "Suppression annulee." -ForegroundColor Yellow
            Write-Log "Suppression annulee par l'operateur"
            continue
        }

        Write-Log "Suppression confirmee par l'operateur"

        $succes = 0
        $echecs = 0

        foreach ($adresse in $cibles) {
            try {
                Remove-InboxRule -Mailbox $adresse -Identity $nomRegle -Confirm:$false -ErrorAction Stop
                Write-Host "  $adresse - OK" -ForegroundColor Green
                Write-Log "Succes : regle '$nomRegle' supprimee de $adresse"
                $succes++
            }
            catch {
                Write-Host "  $adresse - ECHEC" -ForegroundColor Red
                Write-Log "ECHEC : $adresse - $($_.Exception.Message)"
                $echecs++
            }
        }

        Write-Host ""
        Write-Host "Suppression terminee" -ForegroundColor Green
        Write-Host "  Succes : $succes" -ForegroundColor Green
        if ($echecs -gt 0) {
            Write-Host "  Echecs : $echecs" -ForegroundColor Red
        }
        Write-Log "Bilan - Succes : $succes | Echecs : $echecs"
    }

    else {
        Write-Host "Choix invalide." -ForegroundColor Red
    }
}

Write-Log "=== Fin de session ==="
Write-Host ""
Write-Host "Appuyez sur ESPACE pour quitter"

do {
    $key = [System.Console]::ReadKey($true)
} until ($key.Key -eq "Spacebar")

exit