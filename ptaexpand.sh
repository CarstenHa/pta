#!/bin/bash

startdat=`date +%Y%m%d_%H%M`
exec &> >(tee ./backup/${startdat}_ptaexpand.log)

echo -e "
Dieses Programm erweitert pta für ein weiteres Verkehrsgebiet. Der Ordnername kann frei gewählt werden.
Neue(r) Ordnernamen werden automatisch erstellt. In den neuen Ordner werden Symlinks aller
wichtigen Programme und Dateien erstellt. Nach Beendigung dieses Programms kann alles, wie bei pta gewohnt,
genutzt werden.
Nicht vergessen, ggf. die entsprechenden GTFS-Dateien in die Ordner rcompare/gtfsdata und
rcompare/oldgtfsdata zu legen.
"
read -p "Weiter mit [Enter]. Abbruch mit [STRG]+[C]"

while [ -z "$(echo "$newptarea" | grep '^/')" ]; do
 read -p "Bitte einen Ordnernamen angeben (inkl. absoluten Pfad): " newptarea
done
ptarea="${newptarea%/}"

if [ ! -d "$ptarea" ]; then
 mkdir -vp "$ptarea"
 mkdirexit="$?"
fi
[ "$mkdirexit" != 0 ] && echo "Skript wird abgebrochen!" && exit 1

# Gesamte Verzeichnisstruktur erstellen
echo -e "\n***** 1. Verzeichnisstruktur erstellen *****\n"
find . -path './.git' -prune -o -type d -print -exec mkdir -v "${ptarea}"/{} \;

# Symlink von Dateien im Hauptverzeichnis erstellen.
echo -e "\n***** 2. Symlinks der Dateien des Hauptverzeichnisses erstellen *****\n"
cp -vs "${PWD}"/* "${ptarea}"/
rm -f "${ptarea}"/ptaexpand.sh

# Ordner config
echo -e "\n***** 3. Symlinks der Dateien des config-Ordners erstellen *****\n"
find config/ptarea[0-9] -iname "*.cfg" -exec cp -vs "${PWD}"/{} "${ptarea}"/{} \;

# Ordner htmlfiles
echo -e "\n***** 4. Symlinks der Dateien des Ordners htmlfiles erstellen *****\n"
cp -vs "${PWD}"/htmlfiles/css/*.css "${ptarea}"/htmlfiles/css/
cp -vs "${PWD}"/htmlfiles/fonts/* "${ptarea}"/htmlfiles/fonts/
cp -vs "${PWD}"/htmlfiles/images/* "${ptarea}"/htmlfiles/images/
cp -vs "${PWD}"/htmlfiles/script/* "${ptarea}"/htmlfiles/script/

# Ordner rcompare
echo -e "\n***** 5. Symlinks der Dateien des Ordners rcompare erstellen *****\n"
find rcompare -path 'rcompare/backup' -prune -o -path 'rcompare/results' -prune -o -path 'rcompare/gtfsdata' -prune -o -path 'rcompare/oldgtfsdata' -prune -o -type f -print -exec cp -vs "${PWD}"/{} "${ptarea}"/{} \;

# Ordner tools
echo -e "\n***** 6. Symlinks der Dateien des Ordners tools erstellen *****\n"
find tools -path 'tools/osmconvert' -prune -o -type f -print -exec cp -vs "${PWD}"/{} "${ptarea}"/{} \;
cp -vs "${PWD}"/tools/osmconvert/osmconvert "${ptarea}"/tools/osmconvert/

echo -e "\n***** 7. Verkehrsgebiet auswählen *****\n"

while true; do
 read -p "Soll ein bestehendes Verkehrsgebiet [k]opiert, oder ein [n]eues Gebiet erstellt, werden? " oldornew
 case "$oldornew" in
  k|K) echo -e "\n*** Auflistung der Verkehrsgebiete aus $PWD ***"
       ./start.sh -L

       echo "**** Bitte neues Verkehrsgebiet für ${ptarea} auswählen *****"
       cd "${ptarea}"
       ./start.sh -L
       cd -

       rm -rf "${ptarea}"/config/{ptarea[0-9],template}
       mkdir "${ptarea}"/config/ptarea1
       mv "${ptarea}"/config/*.cfg "${ptarea}"/config/ptarea1
       cp -vs "${ptarea}"/config/ptarea1/*.cfg "${ptarea}"/config/
    break
  ;;
  n|N) rm -rf "${ptarea}"/config/{ptarea[0-9],template}
       mkdir "${ptarea}"/config/ptarea1
       cp -v "${PWD}"/config/template/*.cfg "${ptarea}"/config/ptarea1
       echo -e "\nVorlagendateien liegen im Ordner ${ptarea}/config/ptarea1"
    break
  ;;
    *) echo "Fehlerhafte Eingabe!"
  ;;
 esac
done

echo "$0 beendet am `date +%d.%m.%Y` um `date +%H:%M` Uhr."
# Logdatei anpassen.
sed -i 's/.\[1;32m//g;s/.\[0m//g' ./backup/${startdat}_ptaexpand.log
