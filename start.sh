#!/bin/bash

# License: GNU Lesser General Public License v3.0
# See: http://www.gnu.org/licenses/lgpl-3.0.html
# Written by Carsten Jacob
# Please feel free to contact me coding@langstreckentouren.de
# https://github.com/CarstenHa

# Hinweise zu diesem Skript: Das Herunterladen mit wget und der Option -t 0 lieferte zum Teil fehlerhafte Ergebnisse. Deswegen werden die .osm-Dateien in einer Schleife auf eine Minimalgröße untersucht. Deswegen sollte der Test der while-Schleifen von Zeit zu Zeit überprüft werden (find-Befehl mit Option -size).

startdatum=`date +%Y%m%d_%H%M`
exec &> >(tee ./backup/${startdatum}_ptanalysis.log)
# Verhindert, das die Eingabeaufforderung vor weiteren Ausgaben ausgegeben wird.
sleep 1

if [ ! -e "./tools/osmconvert/osmconvert" ]; then
 echo "Das Programm osmconvert fehlt im Ordner tools/osmconvert/"
 echo "Skript wird abgebrochen!"
 exit 1
fi

rm -f ./osmdata/*.tmp

# *** Variablen definieren ***

backupordner="./backup"
zeitpunktbegin=`date +%s`

# Das exportieren dieser Variable ist wichtig, damit pt_analysis2html.sh weiss, ob es relmemberlist.sh ausführen muss oder nicht.
# Bei kompletter Erstellung mit start.sh, kann dann auf die Datei zurückgegriffen werden, die mit stopareaanalysis2html.sh erstellt wurde.
# Bei seperater Ausführung von pt_analysis2html.sh muss die Datei relmem_bus_takst.lst erst noch erstellt erstellt werden.
export whichprocess="all"

startusage() {
cat <<EOU

Synopsis:

./start.sh [Option]

Options:

-a

    Automatischer Prozess ohne weitere Abfragen. Ist identisch bei Auswahl [a],
    wenn dieses Skript ohne weitere Optionen ausgeführt wird.

-c [ptarea_shortname]

    Wechselt das Verkehrsgebiet. Benötigt ein weiteres Argument für das Verkehrsgebiet.
    Dieser kann mit der Option -L ermittelt werden (Short name).

-d [NUM]

    Löscht alle Dateien im Backup-Ordner, die älter als [NUM] Tage sind.

-h

    Zeigt Hilfe an.

-l

    listet das zur Zeit aktive Verkehrsgebiet auf.
   
-L

    listet alle Verkehrsgebiete auf, die in den Depots eingebunden sind.
    Das aktive Gebiet ist mit einem Sternchen * gekennzeichnet.

-p [list|pull]

    Download/Auflisten von optionalen Relationen.
    Benötigt ein weiteres Argument:
    Mit \"list\" werden die optionalen Relationen aufgelistet.
    Mit \"pull\" werden die optionalen Relationen runtergeladen.

EOU
}

while getopts ac:d:hlLp: opt
do
   case $opt in
       a) # automatisierter Prozess ohne Abfragen.
          selectosmdata="a"
          autoprocess="yes"
       ;;
       c) # Wechseln des Verkehrsgebietes
          changeptarea="yes"
          areaarg="$OPTARG"
       ;;
       # Löscht alle Dateien im Backup-Ordner, die älter als * Tage sind.
       d) find "$backupordner"/ -maxdepth 1 -type f \( -name "*.osm" -or -name "*.html" -or -name "*.lst" -or -name "*.log" -or -name "*.zip" \) -mtime +"$OPTARG" -execdir rm -f {} \;
          exit
       ;;
       h) startusage
          exit
       ;;
       l) # Listet das aktuell aktive Verkehrsgebiet auf
          showtparea="yes"
       ;;
       L) # Listet das aktuell aktive Verkehrsgebiet auf
          showtparealong="yes"
       ;;
       p) # Download/Anzeigen von optionalen Relationen
          if [ "$OPTARG" == "pull" ]; then
           pkind="pull"
          elif [ "$OPTARG" == "list" ]; then
           pkind="list"
          else
           echo "Ungültige Option!"
           exit 1
          fi
       ;;
       ?) exit 1
       ;;
    esac
done

# config-Dateien in Arbeitsordner kopieren
if [ ! -e ./config/ptarea.cfg -o "$changeptarea" == "yes" ]; then
 [ ! -e ./config/ptarea.cfg ] && echo "Keine ptarea.cfg gefunden. Kein Gebiet für weitere Bearbeitung ausgewählt."
 [ ! "$changeptarea" == "yes" ] && read -p "Bitte Gebiet angeben: " areaarg
 ptareacfgfile="$(egrep -H '^ptareashort=["'\'']*'"$areaarg"'["'\'']*$' ./config/ptarea*/ptarea.cfg | cut -f1 -d:)"
 if [ "$(echo "$ptareacfgfile" | sed '/^$/d' | wc -l)" == 1 ]; then
  echo -e "Verarbeitung wird vorbereitet.\nLöschen der alten config-Dateien:"
  rm -vf ./config/*.cfg
  ptareadir="$(dirname "$ptareacfgfile")"
  echo "Kopieren der neuen config-Dateien:"
  cp -vf --preserve=timestamps "${ptareadir}"/*.cfg ./config/
 else
  echo "Kein passendes Verkehrsgebiet gefunden. Mögliche Bezeichnungen sind:"
  sed -n 's/^ptareashort=["'\'']*\([[:alnum:]]*\)["'\'']*$/\1/p' ./config/ptarea*/ptarea.cfg
  if [ -e "./tools/mail/sendamail" ]; then
   ./tools/mail/sendamail -e
  fi
  exit 1
 fi
fi

source ./config/ptarea.cfg

currentptareapath="$(grep -i '^ptarealong=["'\'']*'"$ptarealong"'["'\'']*' ./config/*/ptarea.cfg | cut -f1 -d:)"
currentptareadir="$(dirname "$currentptareapath")"

if [ "$(echo "$currentptareadir" | wc -l)" -gt "1" ]; then
 echo "Es gibt mehrere identische Verkehrsgebiete des aktiven Verkehrsgebietes. Skript wird abgebrochen!"
 echo "${currentptareapath}"
 exit 1
fi

echo "Überprüfung der config-Dateien ..."
diff <(cat ./config/*.cfg) <(cat "${currentptareadir}"/*.cfg)
if [ ! "$?" == 0 ]; then
 echo "Unterschiedliche Versionen von cfg-Dateien gefunden. Dateien werden neu in den Arbeitsordner kopiert."
 echo "Alte config-Dateien werden gesichert ..."
 zip ./backup/${startdatum}_configfiles.zip ./config/*.cfg
 echo "Alte config-Dateien werden gelöscht ..."
 rm -vf ./config/*.cfg
 echo "Neue config-Dateien werden in Arbeitsordner kopiert ..."
 cp -vf --preserve=timestamps "${currentptareadir}"/*.cfg ./config/
 echo "Fertig."
else
 echo "Alle Dateien sind aktuell."
fi

if [ "$showtparea" == "yes" ]; then
 echo "Aktuelles Verkehrsgebiet: ${ptarealong} aus Verzeichnis ${currentptareadir}"
 exit
fi

if [ "$showtparealong" == "yes" ]; then
  echo -e "\nAuflistung aller eingebundenen Verkehrsgebiete:"
  echo -e "\e[1;32mNr\e[0m Directory                     Full name           \e[1;32mShort name\e[0m        Description"
  echo "----------------------------------------------------------------------------------------------------------------------------"
 for cfgfile in ./config/ptarea*/ptarea.cfg; do
  if [ "$currentptareapath" == "$cfgfile" ]; then
   ptsign='*'
  else 
   ptsign=""
  fi
  ptareanr="$(echo "$cfgfile" | sed 's/.\/config\/ptarea\([0-9]*\)\/ptarea.cfg/\1/')"
  cfgareashort="$(sed -n 's/^ptareashort=['\''"]\(.*\)['\''"]/\1/p' "$cfgfile")"
  cfgarealong="$(sed -n 's/^ptarealong=['\''"]\(.*\)['\''"]/\1/p' "$cfgfile")"
  cfgareadesc="$(sed -n 's/^ptareadescription=['\''"]\(.*\)['\''"]/\1/p' "$cfgfile")"
  printf '\e[1;32m%2s\e[0m %-29s %-20s \e[1;32m%-17s\e[0m %-50s\n' "$ptareanr" "$cfgfile" "$cfgarealong" "${cfgareashort} ${ptsign}" "$cfgareadesc"
 done
 echo ""
 exit
fi

# Auflisten/Downloaden von optionalen Relationen
if [ "$pkind" == "pull" -o "$pkind" == "list" ]; then

 if [ -n "$optrelid" ]; then

   if [ "$pkind" == "pull" ]; then
    echo "Download von optionalen Relationen:"
    for line in "${optrelid[@]}"; do
     linerelid="${line%:*}"
     linedesc="${line#*:}"
     echo "Download ${linedesc}:"
     wget -O "$backupordner/`date +%Y%m%d`_${linedesc}.osm" "http://overpass-api.de/api/interpreter?data=(relation(${linerelid});>>;);out meta;"
    done
    echo "Datei(en) befinden sich im Ordner ${backupordner}"
   elif [ "$pkind" == "list" ]; then
    echo "Auflistung der optionalen Relationen:"
    for line in "${optrelid[@]}"; do
     linerelid="${line%:*}"
     linedesc="${line#*:}"
     printf '%-20d %30s\n' "$linerelid" "$linedesc"
    done
   fi
   
 else
 
  echo "Keine optionalen RelationIDs in ptarea.cfg gefunden."
  
 fi
  
 exit
 
fi

echo -e "\nAktuelles Verkehrsgebiet: ${ptarealong}"
echo -e "${ptareadescription}\n"

# *** Erreichbarkeit von overpass-api.de überprüfen ***

pingcounter="1"
echo "Versuche overpass-api.de zu erreichen. Versuch ${pingcounter} ..."
ping -c 1 overpass-api.de

while [ ! "$?" == "0" ]; do
 echo "Verbindung konnte nicht hergestellt werden."
 let pingcounter++
  if [ "$pingcounter" -gt "3" ]; then
   echo "Kann overpass-api.de nicht erreichen. Skript wird abgebrochen."
   if [ -e "./tools/mail/sendamail" ]; then
    ./tools/mail/sendamail -p
   fi
   exit 1
  fi
 sleep 20
 echo "Versuche erneut overpass-api.de zu erreichen. Versuch ${pingcounter} ..."
 ping -c 1 overpass-api.de
done

echo "overpass-api.de ist erreichbar."

# *** Funktionen definieren ***
# Dialog für dass Herunterladen der OSM-Daten von der Overpass Api.
osmdialog() {
echo ""
echo "Auswahl der .osm-Dateien:"
echo ""
echo "[1] - Download bus routes in ${ptarealong}-area (route_bus.osm)"
echo "[2] - Download train routes in ${ptarealong}-area (route_train.osm)"
echo "[3] - Download light-rail routes in ${ptarealong}-area (route_light_rail.osm)"
echo "[4] - Download subway routes in ${ptarealong}-area (route_subway.osm)"
echo "[5] - Download monorail routes in ${ptarealong}-area (route_monorail.osm)"
echo "[6] - Download tram routes in ${ptarealong}-area (route_tram.osm)"
echo "[7] - Download trolleybus routes in ${ptarealong}-area (route_trolleybus.osm)"
echo "[8] - Download ferry routes in ${ptarealong}-area (route_ferry.osm)"
echo "[9] - Download stop-areas in ${ptarealong}-area (stop_areas.osm)"
echo "[10] - Download stop-area-groups in ${ptarealong}-area (stop_area_groups.osm)"
echo "[11] - Download stop-areas in ${ptarealong}-stoprelation (stoprelation.osm)"
echo "[12] - Download bus routes in ${ptarealong}-bus-relation (route_busrelation.osm)"
echo "[13] - Download master routes in ${ptarealong}-area (route_master_bus.osm)"
echo "[a] - Download all OSM-files and start HTML generation."
echo "[n] - Download nothing. Start HTML generation."
echo "[q] - Quit"
echo ""
}

# Ausschneiden der .osm-Daten mit Polyfile durch osmconvert
# Kann durch ptarea.cfg für die einzelnen Verkehrsmittel gesteuert werden.
cuttingosmfile() {
# Wichtig, das osmconvert VOR der Bearbeitung mit sed (s/"/'\''/g;s/\/>/ \/>/g) ausgeführt wird. Ansonsten wird die Syntax wieder in Gänsefüsschen umgeschrieben.
tools/osmconvert/osmconvert -v "$osmname" --complex-ways --complete-ways -B="tools/poly/${areapolyfile}" -o="${osmname}.tmp"
rm "${osmname}"
mv "${osmname}.tmp" "$osmname"
if [ "$(find "$osmname" -maxdepth 1 -size -${kindofsize} 2>/dev/null | wc -l)" -gt "0" -o ! -e "$osmname" ]; then
 echo "Fehler nach Bearbeitung von ${osmname} mit osmconvert!"
 rm -f "${osmname}" "${osmname}.tmp"
fi
#Fehlererkennung durch osmconvert
if [ $(sed -e :a -e '$q;N;3,$D;ba;' "$osmname" | grep '<relation id' | wc -l) -gt "0" ]; then
 echo "Fehler am Ende von ${osmname}."
 sed -e :a -e '$q;N;3,$D;ba;' "$osmname"
 rm -f "${osmname}" "${osmname}.tmp"
fi
}

# Hinweis zur Overpass-Syntax (wget): http: ... ;>;);out meta; Ein > und Multipolygone werden NICHT vollständig heruntergeladen.
areabus() {
echo "*** Processing route_bus.osm ***"
osmname="./osmdata/route_bus.osm"
kindofsize="$minsizebus"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(${ptareabbox}) [\"type\"=\"route\"][\"route\"=\"bus\"];>;);out meta;"
[ "$cutbus" == "yes" ] && cuttingosmfile
# Für Skript pt_analysis2html muss Datei noch wie folgt bearbeitet werden (damit die Datei konform mit JOSM-Api-Abfrage-Datei ist):
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

areatrain() {
echo "*** Processing route_train.osm ***"
osmname="./osmdata/route_train.osm"
kindofsize="minsizetrain"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"train\"];>;);out meta;"
[ "$cuttrain" == "yes" ] && cuttingosmfile
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

arealightrail() {
echo "*** Processing route_light_rail.osm ***"
osmname="./osmdata/route_light_rail.osm"
kindofsize="$minsizelightrail"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"light_rail\"];>;);out meta;"
[ "$cutlightrail" == "yes" ] && cuttingosmfile
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

areasubway() {
echo "*** Processing route_subway.osm ***"
osmname="./osmdata/route_subway.osm"
kindofsize="$minsizesubway"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"subway\"];>;);out meta;"
[ "$cutsubway" == "yes" ] && cuttingosmfile
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

areamonorail() {
echo "*** Processing route_monorail.osm ***"
osmname="./osmdata/route_monorail.osm"
kindofsize="$minsizemonorail"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"monorail\"];>;);out meta;"
[ "$cutmonorail" == "yes" ] && cuttingosmfile
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

areatram() {
echo "*** Processing route_tram.osm ***"
osmname="./osmdata/route_tram.osm"
kindofsize="$minsizetram"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"tram\"];>;);out meta;"
[ "$cuttram" == "yes" ] && cuttingosmfile
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

areatrolleybus() {
echo "*** Processing route_trolleybus.osm ***"
osmname="./osmdata/route_trolleybus.osm"
kindofsize="$minsizetrolleybus"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"trolleybus\"];>;);out meta;"
[ "$cuttrolleybus" == "yes" ] && cuttingosmfile
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

areaferry() {
echo "*** Processing route_ferry.osm ***"
osmname="./osmdata/route_ferry.osm"
kindofsize="$minsizeferry"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"ferry\"];>;);out meta;"
[ "$cutferry" == "yes" ] && cuttingosmfile
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

stopareas() {
echo "*** Processing stop_areas.osm ***"
osmname="./osmdata/stop_areas.osm"
kindofsize="$minsizestoparea"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(${ptareabbox})[\"public_transport\"=\"stop_area\"];>>;);out meta;"
[ "$cutstoparea" == "yes" ] && cuttingosmfile
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

stopareagroups() {
echo "*** Processing stop_area_groups.osm ***"
osmname="./osmdata/stop_area_groups.osm"
kindofsize="$minsizestopareagroups"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(${ptareabbox})[\"public_transport\"=\"stop_area\"];<<;);out meta;"
[ "$cutstopareagroups" == "yes" ] && cuttingosmfile
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

areastoprelation() {
echo "*** Processing stoprelation.osm ***"
osmname="./osmdata/stoprelation.osm"
kindofsize="$minsizestoprelation"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(${ptareastoprelid});>>;);out meta;"
[ "$cutstoprelation" == "yes" ] && cuttingosmfile
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

areabusrelation() {
echo "*** Processing route_busrelation.osm ***"
osmname="./osmdata/route_busrelation.osm"
kindofsize="$minsizebusrelation"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(${ptareabusrelid});>>;);out meta;"
[ "$cutbusrelation" == "yes" ] && cuttingosmfile
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

routemasterbus() {
echo "*** Processing route_master_bus.osm ***"
osmname="./osmdata/route_master_bus.osm"
kindofsize="$minsizeroutemasterbus"
wget -O "$osmname" "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"bus\"];<<;);out meta;"
[ "$cutroutemasterbus" == "yes" ] && cuttingosmfile
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' "$osmname"
}

# Die einzelnen Downloads können in einer Schleife so lange heruntergeldaen werden, bis n gewählt wird. Der komplette Download hat ein break am Ende.
while true; do

   if [ ! "$autoprocess" == "yes" ]; then
    osmdialog
    read -p "Welche Datei(en) soll(en) heruntergeladen werden? " selectosmdata
   fi

    case "$selectosmdata" in
      1) rm -f ./osmdata/route_bus.osm
         while [ "$(find ./osmdata/route_bus.osm -maxdepth 1 -size -${minsizebus} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_bus.osm ]; do areabus; done
          ;;
      2) rm -f ./osmdata/route_train.osm
         while [ "$(find ./osmdata/route_train.osm -maxdepth 1 -size -${minsizetrain} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_train.osm ]; do areatrain; done
          ;;
      3) rm -f ./osmdata/route_light_rail.osm
         while [ "$(find ./osmdata/route_light_rail.osm -maxdepth 1 -size -${minsizelightrail} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_light_rail.osm ]; do arealightrail; done
          ;;
      4) rm -f ./osmdata/route_subway.osm
         while [ "$(find ./osmdata/route_subway.osm -maxdepth 1 -size -${minsizesubway} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_subway.osm ]; do areasubway; done
          ;;
      5) rm -f ./osmdata/route_monorail.osm
         while [ "$(find ./osmdata/route_monorail.osm -maxdepth 1 -size -${minsizemonorail} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_monorail.osm ]; do areamonorail; done
          ;;
      6) rm -f ./osmdata/route_tram.osm
         while [ "$(find ./osmdata/route_tram.osm -maxdepth 1 -size -${minsizetram} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_tram.osm ]; do areatram; done
          ;;
      7) rm -f ./osmdata/route_trolleybus.osm
         while [ "$(find ./osmdata/route_trolleybus.osm -maxdepth 1 -size -${minsizetrolleybus} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_trolleybus.osm ]; do areatrolleybus; done
          ;;
      8) rm -f ./osmdata/route_ferry.osm
         while [ "$(find ./osmdata/route_ferry.osm -maxdepth 1 -size -${minsizeferry} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_ferry.osm ]; do areaferry; done
          ;;
      9) rm -f ./osmdata/stop_areas.osm
         while [ "$(find ./osmdata/stop_areas.osm -maxdepth 1 -size -${minsizestoparea} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stop_areas.osm ]; do stopareas; done
          ;;
      10) rm -f ./osmdata/stop_area_groups.osm
         while [ "$(find ./osmdata/stop_area_groups.osm -maxdepth 1 -size -${minsizestopareagroups} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stop_area_groups.osm ]; do stopareagroups; done
          ;;
      11) rm -f ./osmdata/stoprelation.osm
         while [ "$(find ./osmdata/stoprelation.osm -maxdepth 1 -size -${minsizestoprelation} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stoprelation.osm ]; do areastoprelation; done
         stoppesteddownload="1"
          ;;
      12) rm -f ./osmdata/route_busrelation.osm
         while [ "$(find ./osmdata/route_busrelation.osm -maxdepth 1 -size -${minsizebusrelation} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_busrelation.osm ]; do areabusrelation; done
         busrelationdownload="1"
          ;;
      13) rm -f ./osmdata/route_master_bus.osm
         while [ "$(find ./osmdata/route_master_bus.osm -maxdepth 1 -size -${minsizeroutemasterbus} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_master_bus.osm ]; do routemasterbus; done
          ;;
      a) rm -f ./osmdata/route_bus.osm
         rm -f ./osmdata/route_train.osm
         rm -f ./osmdata/route_light_rail.osm
         rm -f ./osmdata/route_subway.osm
         rm -f ./osmdata/route_monorail.osm
         rm -f ./osmdata/route_tram.osm
         rm -f ./osmdata/route_trolleybus.osm
         rm -f ./osmdata/route_ferry.osm
         rm -f ./osmdata/stop_areas.osm
         rm -f ./osmdata/stop_area_groups.osm
         rm -f ./osmdata/stoprelation.osm
         rm -f ./osmdata/route_busrelation.osm
         rm -f ./osmdata/route_master_bus.osm

         downloadcounter="0"
         while [ "$(find ./osmdata/route_bus.osm -maxdepth 1 -size -${minsizebus} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_bus.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_bus.osm) überschritten."
           killthisscript="yes"
           kindofosm="route_bus.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          areabus
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/route_train.osm -maxdepth 1 -size -${minsizetrain} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_train.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_train.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, route_train.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          areatrain
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/route_light_rail.osm -maxdepth 1 -size -${minsizelightrail} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_light_rail.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_light_rail.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, route_light_rail.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          arealightrail
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/route_subway.osm -maxdepth 1 -size -${minsizesubway} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_subway.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_subway.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, route_subway.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          areasubway
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/route_monorail.osm -maxdepth 1 -size -${minsizemonorail} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_monorail.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_monorail.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, route_monorail.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          areamonorail
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/route_tram.osm -maxdepth 1 -size -${minsizetram} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_tram.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_tram.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, route_tram.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          areatram
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/route_trolleybus.osm -maxdepth 1 -size -${minsizetrolleybus} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_trolleybus.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_trolleybus.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, route_trolleybus.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          areatrolleybus
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/route_ferry.osm -maxdepth 1 -size -${minsizeferry} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_ferry.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_ferry.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, route_ferry.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          areaferry
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/stop_areas.osm -maxdepth 1 -size -${minsizestoparea} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stop_areas.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (stop_areas.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, stop_areas.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          stopareas
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/stop_area_groups.osm -maxdepth 1 -size -${minsizestopareagroups} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stop_area_groups.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (stop_area_groups.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, stop_area_groups.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          stopareagroups
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/stoprelation.osm -maxdepth 1 -size -${minsizestoprelation} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stoprelation.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (stoprelation.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, stoprelation.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          areastoprelation
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/route_busrelation.osm -maxdepth 1 -size -${minsizebusrelation} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_busrelation.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_busrelation.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, route_busrelation.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          areabusrelation
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/route_master_bus.osm -maxdepth 1 -size -${minsizeroutemasterbus} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_master_bus.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_master_bus.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, route_master_bus.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          routemasterbus
          let downloadcounter++
         done

         stoppesteddownload="1"
         busrelationdownload="1"

         if [ "$killthisscript" == "yes" ]; then
          echo "Es konnten nicht alle OSM-Daten vollständig heruntergeladen werden. Skript wird abgebrochen."
          echo "Folgende Dateien sind unter anderem betroffen: $(echo "${kindofosm}" | sed 's/^, //')"
          if [ -e "./tools/mail/sendamail" ]; then
           ./tools/mail/sendamail -d
          fi
          exit 1
         fi

         break
          ;;
      n) break
          ;;
      q) # Programm wird ohne Erstellung von HTML-Seiten beendet.
         echo "$(basename ${0}) beendet."
         exit 0
          ;;
      *) echo "Fehlerhafte Eingabe!"
          ;;
    esac

done

if [ "$stoppesteddownload" == "1" ]; then
 cp ./osmdata/stoprelation.osm "$backupordner"/`date +%Y%m%d_%H%M`_stoprelation.osm
fi
if [ "$busrelationdownload" == "1" ]; then
 cp ./osmdata/route_busrelation.osm "$backupordner"/`date +%Y%m%d_%H%M`_route_busrelation.osm
fi

rm -f ./osmdata/*.tmp

# *** HTML-Seitenerstellung ***
./"$stopareascript"
./"$ptroutescript" ./"$osmanalysisfile"

# *** Benachrichtigungen ***
# Zeitspanne des Erstellungsprozesses wird errechnet und angezeigt.
zeitdiff=$((`date +%s`-"$zeitpunktbegin"))

echo "Public Transport Analyseseiten sind fertig (`date +%d.%m.%Y` um `date +%H:%M` Uhr)."
printf 'Dauer des Erstellungsprozesses: %02dh:%02dm:%02ds\n' $(($zeitdiff/3600)) $(($zeitdiff%3600/60)) $(($zeitdiff%60))
notify-send -t 0 "Hinweis" "Public Transport-Analyseseiten sind fertig." 2>/dev/null
if [ -e "./tools/mail/sendamail" ]; then
 ./tools/mail/sendamail
fi

