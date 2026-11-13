<!-- #!/usr/bin/env markdown
-*- coding: utf-8 -*-
region header
Copyright Torben Sickert (info["~at~"]tsickert.com) 16.12.2012

License
-------

This library written by Torben Sickert stands under a creative commons naming
4.0 international license.
See https://creativecommons.org/licenses/by/4.0/deed.de
endregion -->

<!--|deDE:Projektstatus-->
<!--|frFR:Statut du projet-->
Project Status
--------------

[![npm](https://img.shields.io/npm/v/archinstall?color=%23d55e5d&label=npm%20package%20version&logoColor=%23d55e5d&style=for-the-badge)](https://www.npmjs.com/package/archinstall)
[![npm downloads](https://img.shields.io/npm/dy/archinstall.svg?style=for-the-badge)](https://www.npmjs.com/package/archinstall)

[![build push package](https://img.shields.io/github/actions/workflow/status/thaibault/archinstall/build-package-and-push.yaml?label=build%20push%20package&style=for-the-badge)](https://github.com/thaibault/archinstall/actions/workflows/build-package-and-push.yaml)

[![lint](https://img.shields.io/github/actions/workflow/status/thaibault/archinstall/lint.yaml?label=lint&style=for-the-badge)](https://github.com/thaibault/archinstall/actions/workflows/lint.yaml)
[![test](https://img.shields.io/github/actions/workflow/status/thaibault/archinstall/test.yaml?label=test&style=for-the-badge)](https://github.com/thaibault/archinstall/actions/workflows/test.yaml)

[![deploy web documentation](https://img.shields.io/github/actions/workflow/status/thaibault/archinstall/deploy-web-documentation.yaml?label=deploy%20web%20documentation&style=for-the-badge)](https://github.com/thaibault/archinstall/actions/workflows/deploy-web-documentation.yaml)
[![web documentation](https://img.shields.io/website-up-down-green-red/https/tsickert.com/archinstall.svg?label=web-documentation&style=for-the-badge)](https://tsickert.com/archinstall)

<!--|deDE:Einsatzmöglichkeiten-->
<!--|frFR:Cas d'utilisation-->
Use case
--------

Install Arch Linux unattended with a single Bash script: into a folder, onto
a partition or onto a whole disk including partitioning, from any Linux
system. Everything the script needs and does not get via command line is
asked for once at the start, afterwards the installation runs on its own.
Downloaded packages are cached, so further installations also work offline.
Sourced as a library, its functions are the base for own installers.
<!--deDE:
    Installieren Sie Arch Linux unbeaufsichtigt mit einem einzigen
    Bash-Skript: in einen Ordner, auf eine Partition oder auf eine ganze
    Festplatte einschließlich Partitionierung, von jedem Linux-System aus.
    Alles, was das Skript braucht und nicht über die Kommandozeile erhält,
    wird einmal zu Beginn abgefragt, danach läuft die Installation
    selbstständig. Heruntergeladene Pakete werden zwischengespeichert, sodass
    weitere Installationen auch offline funktionieren. Als Bibliothek
    eingebunden, bilden seine Funktionen die Basis für eigene Installer.
-->
<!--frFR:
    Installez Arch Linux sans surveillance avec un seul script Bash: dans un
    dossier, sur une partition ou sur un disque entier partitionnement
    compris, depuis n'importe quel système Linux. Tout ce dont le script a
    besoin et qu'il ne reçoit pas en ligne de commande est demandé une seule
    fois au début, ensuite l'installation se déroule seule. Les paquets
    téléchargés sont mis en cache, de sorte que les installations suivantes
    fonctionnent aussi hors ligne. Chargé comme bibliothèque, ses fonctions
    servent de base à vos propres installateurs.
-->

Not to be confused with the guided installer "archinstall" shipped by Arch
Linux itself.
<!--deDE:
    Nicht zu verwechseln mit dem geführten Installer "archinstall", den Arch
    Linux selbst mitliefert.
-->
<!--frFR:
    À ne pas confondre avec l'installateur guidé "archinstall" fourni par
    Arch Linux lui-même.
-->

<div class="wd-table-of-contents">
    <h2 id="content">Content<!--deDE:Inhalt--><!--frFR:Contenu--></h2>
    <!--wd-table-of-contents-->
</div>

<!--|deDE:Schnellstart-->
<!--|frFR:Démarrage rapide-->
Quick start
-----------

Download the script, it fetches its only library
[bashlink](https://tsickert.com/bashlink) by itself:
<!--deDE:
    Laden Sie das Skript herunter, seine einzige Bibliothek
    [bashlink](https://tsickert.com/bashlink) holt es sich selbst:
-->
<!--frFR:
    Téléchargez le script, il récupère lui-même sa seule bibliothèque
    [bashlink](https://tsickert.com/bashlink):
-->

```bash
curl \
    --output archinstall.sh \
    https://raw.githubusercontent.com/thaibault/archinstall/main/archinstall.sh
chmod +x archinstall.sh
```

Alternatively install it via "npm install archinstall". Then run it as
root, e.g. from the Arch Linux live system:
<!--deDE:
    Alternativ installieren Sie es über "npm install archinstall". Führen Sie
    es dann als root aus, z. B. aus dem Live-System von Arch Linux:
-->
<!--frFR:
    Vous pouvez aussi l'installer via "npm install archinstall". Exécutez-le
    ensuite en tant que root, par exemple depuis le système live d'Arch
    Linux:
-->

```bash
./archinstall.sh --host-name my-system --target /dev/sdb --auto-partitioning
```

Without "--verbose" only problems are reported, "--debug" additionally shows
the output of all used tools. "--help" lists all options with their current
defaults.
<!--deDE:
    Ohne "--verbose" werden nur Probleme gemeldet, "--debug" zeigt zusätzlich
    die Ausgaben aller verwendeten Werkzeuge. "--help" listet alle Optionen
    mit ihren aktuellen Standardwerten.
-->
<!--frFR:
    Sans "--verbose", seuls les problèmes sont signalés, "--debug" affiche en
    plus la sortie de tous les outils utilisés. "--help" liste toutes les
    options avec leurs valeurs par défaut actuelles.
-->

<!--|deDE:Ziele-->
<!--|frFR:Cibles-->
Targets
-------

"--target" decides where the new system goes, "archInstall" in the current
folder by default:
<!--deDE:
    "--target" bestimmt, wohin das neue System kommt, standardmäßig
    "archInstall" im aktuellen Ordner:
-->
<!--frFR:
    "--target" détermine où va le nouveau système, par défaut "archInstall"
    dans le dossier courant:
-->

- A folder, e.g. "--target /tmp/system": Installs a complete system into it,
  useful to prepare or modify an image before using it.<!--deDE:Ein Ordner, z. B. "--target /tmp/system": Installiert ein vollständiges System hinein, nützlich, um ein Abbild vorzubereiten oder anzupassen, bevor es verwendet wird.--><!--frFR:Un dossier, par exemple "--target /tmp/system": Y installe un système complet, utile pour préparer ou modifier une image avant de l'utiliser.-->
- A whole disk, e.g. "--target /dev/sdb": With "--auto-partitioning" a 2
  GB UEFI boot partition and a system partition using the rest are created.
  Without, you partition yourself: the first partition becomes boot, the
  second the system.<!--deDE:Eine ganze Festplatte, z. B. "--target /dev/sdb": Mit "--auto-partitioning" werden eine 2 GB große UEFI-Boot-Partition und eine Systempartition mit dem restlichen Platz angelegt. Ohne partitionieren Sie selbst: Die erste Partition wird zur Boot-, die zweite zur Systempartition.--><!--frFR:Un disque entier, par exemple "--target /dev/sdb": Avec "--auto-partitioning", une partition de démarrage UEFI de 2 Go et une partition système utilisant le reste sont créées. Sans, vous partitionnez vous-même: la première partition devient la partition de démarrage, la seconde la partition système.-->
- A single partition, e.g. "--target /dev/sdb2": Installs only the system,
  e.g. next to an existing one.<!--deDE:Eine einzelne Partition, z. B. "--target /dev/sdb2": Installiert nur das System, z. B. neben ein bestehendes.--><!--frFR:Une seule partition, par exemple "--target /dev/sdb2": N'installe que le système, par exemple à côté d'un système existant.-->

The system partition is formatted with Btrfs (subvolume "root"), the boot
partition with FAT32. systemd-boot is installed and registered in the
firmware as boot entry "archLinux" (see "--boot-entry-label"), so the new
system boots without further steps. "--boot-partition-label" and
"--system-partition-label" change the partition labels. "--encrypt" encrypts
the system partition with the password given via "--password". It is
unlocked automatically on boot via a key file on the boot partition.
<!--deDE:
    Die Systempartition wird mit Btrfs formatiert (Subvolume "root"), die
    Bootpartition mit FAT32. systemd-boot wird installiert und in der
    Firmware als Booteintrag "archLinux" eingetragen (siehe
    "--boot-entry-label"), sodass das neue System ohne weitere Schritte
    startet. "--boot-partition-label" und
    "--system-partition-label" ändern die Partitionsbezeichnungen.
    "--encrypt" verschlüsselt die Systempartition mit dem über "--password"
    angegebenen Passwort. Sie wird beim Start automatisch über eine
    Schlüsseldatei auf der Bootpartition entsperrt.
-->
<!--frFR:
    La partition système est formatée en Btrfs (sous-volume "root"), la
    partition de démarrage en FAT32. systemd-boot est installé et inscrit
    dans le firmware comme entrée de démarrage "archLinux" (voir
    "--boot-entry-label"), de sorte que le nouveau système démarre sans autre
    étape. "--boot-partition-label" et
    "--system-partition-label" modifient les libellés des partitions.
    "--encrypt" chiffre la partition système avec le mot de passe indiqué via
    "--password". Elle est déverrouillée automatiquement au démarrage via un
    fichier de clé sur la partition de démarrage.
-->

<!--|deDE:Konfiguration-->
<!--|frFR:Configuration-->
Configuration
-------------

The new system is configured completely: keyboard layout, time zone, time
synchronization, host name, users, network services, package signatures and
mirrors. Every option also has a short form, e.g. "-n" for "--host-name":
<!--deDE:
    Das neue System wird vollständig eingerichtet: Tastaturlayout, Zeitzone,
    Zeitsynchronisation, Hostname, Benutzer, Netzwerkdienste,
    Paketsignaturen und Mirrors. Jede Option hat auch eine Kurzform, z. B.
    "-n" für "--host-name":
-->
<!--frFR:
    Le nouveau système est entièrement configuré: disposition du clavier,
    fuseau horaire, synchronisation de l'heure, nom d'hôte, utilisateurs,
    services réseau, signatures des paquets et miroirs. Chaque option a aussi
    une forme courte, par exemple "-n" pour "--host-name":
-->

```bash
./archinstall.sh \
    --additional-packages vim openssh \
    --country-with-mirrors Germany \
    --host-name my-system \
    --keyboard-layout de-latin1 \
    --local-time Europe/Berlin \
    --needed-services sshd \
    --target /dev/sdb \
    --auto-partitioning \
    --user-names alice bob
```

- Users get their name as initial password, root gets "root" or the value
  of "--password". Change them after the first login.<!--deDE:Benutzer erhalten ihren Namen als Anfangspasswort, root erhält "root" bzw. den Wert von "--password". Ändern Sie sie nach der ersten Anmeldung.--><!--frFR:Les utilisateurs reçoivent leur nom comme mot de passe initial, root reçoit "root" ou la valeur de "--password". Changez-les après la première connexion.-->
- "--add-common-additional-packages" adds "base-devel", "python" and
  "sudo". Options with several values can also be repeated.<!--deDE:"--add-common-additional-packages" ergänzt "base-devel", "python" und "sudo". Optionen mit mehreren Werten lassen sich auch wiederholen.--><!--frFR:"--add-common-additional-packages" ajoute "base-devel", "python" et "sudo". Les options à plusieurs valeurs peuvent aussi être répétées.-->
- "--prevent-using-existing-pacman" installs with a freshly downloaded pacman
  instead of the host's one, e.g. if the host uses custom repositories.<!--deDE:"--prevent-using-existing-pacman" installiert mit einem frisch heruntergeladenen pacman statt dem des Hosts, z. B. wenn der Host eigene Repositories nutzt.--><!--frFR:"--prevent-using-existing-pacman" installe avec un pacman fraîchement téléchargé au lieu de celui de l'hôte, par exemple si l'hôte utilise ses propres dépôts.-->
- "-A /dev/sdb" is short for "--auto-partitioning --debug --host-name
  archlinux --target /dev/sdb".<!--deDE:"-A /dev/sdb" ist die Kurzform von "--auto-partitioning --debug --host-name archlinux --target /dev/sdb".--><!--frFR:"-A /dev/sdb" est la forme courte de "--auto-partitioning --debug --host-name archlinux --target /dev/sdb".-->

<!--|deDE:Offline installieren-->
<!--|frFR:Installer hors ligne-->
### Installing offline

Every installation stores the downloaded packages in "archInstallCache"
(or the folder given via "--cache-path"). Further installations with this
cache work without network, e.g. from a USB stick carrying script and cache.
Additional packages have to be in the cache as well. On a live system the
current folder lives in memory, so point "--cache-path" to real storage.
<!--deDE:
    Jede Installation legt die heruntergeladenen Pakete in
    "archInstallCache" ab (oder in dem über "--cache-path" angegebenen
    Ordner). Weitere Installationen mit diesem Cache funktionieren ohne
    Netzwerk, z. B. von einem USB-Stick mit Skript und Cache. Zusätzliche
    Pakete müssen ebenfalls im Cache liegen. Auf einem Live-System liegt der
    aktuelle Ordner im Arbeitsspeicher, richten Sie "--cache-path" daher auf
    echten Speicher.
-->
<!--frFR:
    Chaque installation enregistre les paquets téléchargés dans
    "archInstallCache" (ou dans le dossier indiqué via "--cache-path"). Les
    installations suivantes avec ce cache fonctionnent sans réseau, par
    exemple depuis une clé USB contenant script et cache. Les paquets
    supplémentaires doivent aussi se trouver dans le cache. Sur un système
    live, le dossier courant réside en mémoire, faites donc pointer
    "--cache-path" vers un vrai support de stockage.
-->

<!--|deDE:Ohne root-Rechte-->
<!--|frFR:Sans droits root-->
### Without root permissions

With "fakeroot" and "fakechroot" installed, an existing folder can be used
as target without root permissions. File ownership can not be set this way,
so the result is packed into a tar archive which has to be extracted as root
before use.
<!--deDE:
    Sind "fakeroot" und "fakechroot" installiert, kann ein bestehender Ordner
    ohne root-Rechte als Ziel dienen. Dateibesitzer lassen sich so nicht
    setzen, daher wird das Ergebnis in ein tar-Archiv gepackt, das vor der
    Verwendung als root entpackt werden muss.
-->
<!--frFR:
    Si "fakeroot" et "fakechroot" sont installés, un dossier existant peut
    servir de cible sans droits root. Les propriétaires des fichiers ne
    peuvent pas être définis ainsi, le résultat est donc empaqueté dans une
    archive tar qui doit être extraite en tant que root avant utilisation.
-->

<!--|deDE:Als Bibliothek-->
<!--|frFR:Comme bibliothèque-->
Use as library
--------------

Sourced instead of executed, the script only defines its variables and
functions (prefixed with "ai_" and "AI_"). Own installers can adjust them
and run the installation via "ai_main":
<!--deDE:
    Eingebunden statt ausgeführt, definiert das Skript nur seine Variablen
    und Funktionen (mit den Präfixen "ai_" und "AI_"). Eigene Installer
    können diese anpassen und die Installation über "ai_main" starten:
-->
<!--frFR:
    Chargé au lieu d'être exécuté, le script ne définit que ses variables et
    fonctions (préfixées par "ai_" et "AI_"). Vos propres installateurs
    peuvent les adapter et lancer l'installation via "ai_main":
-->

```bash
#!/usr/bin/env bash
source archinstall.sh

AI_NEEDED_SERVICES+=(sshd)
ai_main --additional-packages openssh "$@"
```

The API documentation describes all functions.
<!--deDE:Die API-Dokumentation beschreibt alle Funktionen.-->
<!--frFR:La documentation de l'API décrit toutes les fonctions.-->

<!--|deDE:Eigene Installationsmedien-->
<!--|frFR:Supports d'installation personnalisés-->
Custom installation media
-------------------------

"pack-into-archiso" builds an Arch Linux ISO image which contains
archinstall (and bashlink if installed) in its live system, so it is
available offline right after booting as "archinstall.sh" or via the
shortcut "install". The boot configuration of the original image is kept. It
needs root permissions, "xorriso" ("libisoburn") and "squashfs-tools":
<!--deDE:
    "pack-into-archiso" erstellt ein Arch-Linux-ISO-Abbild, das archinstall
    (und bashlink, falls installiert) in seinem Live-System enthält, sodass
    es direkt nach dem Booten auch offline als "archinstall.sh" oder über die
    Abkürzung "install" verfügbar ist. Die Bootkonfiguration des
    ursprünglichen Abbilds bleibt erhalten. Es benötigt root-Rechte,
    "xorriso" ("libisoburn") und "squashfs-tools":
-->
<!--frFR:
    "pack-into-archiso" construit une image ISO d'Arch Linux qui contient
    archinstall (et bashlink s'il est installé) dans son système live, de
    sorte qu'il est disponible hors ligne dès le démarrage sous
    "archinstall.sh" ou via le raccourci "install". La configuration de
    démarrage de l'image d'origine est conservée. Il nécessite les droits
    root, "xorriso" ("libisoburn") et "squashfs-tools":
-->

```bash
./pack-into-archiso.sh \
    ./archlinux-x86_64.iso \
    ./archlinux-with-archinstall.iso \
    --keyboard-layout us
```

"--keyboard-layout" sets the console keyboard layout of the live system,
"--squash-filesystem-compressor" the compression of its file system ("gzip"
by default).
<!--deDE:
    "--keyboard-layout" setzt das Konsolen-Tastaturlayout des Live-Systems,
    "--squash-filesystem-compressor" die Kompression seines Dateisystems
    (standardmäßig "gzip").
-->
<!--frFR:
    "--keyboard-layout" définit la disposition du clavier de la console du
    système live, "--squash-filesystem-compressor" la compression de son
    système de fichiers ("gzip" par défaut).
-->

<!--|deDE:Entwicklung-->
<!--|frFR:Développement-->
Development
-----------

```bash
yarn install
yarn lint
yarn test
```
