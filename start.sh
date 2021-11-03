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

# *** Variablen definieren ***

backupordner="./backup"
zeitpunktbegin=`date +%s`

# Das exportieren dieser Variable ist wichtig, damit pt_analysis2html.sh weiss, ob es relmemberlist.sh ausführen muss oder nicht.
# Bei kompletter Erstellung mit start.sh, kann dann auf die Datei zurückgegriffen werden, die mit stopareaanalysis2html.sh erstellt wurde.
# Bei seperater Ausführung von pt_analysis2html.sh muss die Datei relmem_bus_takst.lst erst noch erstellt erstellt werden.
export whichprocess="all"

while getopts ac:d:hlp: opt
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
       d) find "$backupordner"/ -maxdepth 1 -type f \( -name "*.osm" -or -name "*.html" -or -name "*.lst" -or -name "*.log" \) -mtime +"$OPTARG" -execdir rm -f {} \;
          exit
       ;;
       h) echo ""
          echo "Synopsis:"
          echo ""
          echo "./start.sh [Option]"
          echo ""
          echo "Options:"
          echo ""
          echo "-a"
          echo ""
          echo "    Automatischer Prozess ohne weitere Abfragen. Ist identisch bei Auswahl [a],"
          echo "    wenn dieses Skript ohne weitere Optionen ausgeführt wird."
          echo ""
          echo "-d [NUM]"
          echo ""
          echo "    Löscht alle Dateien im Backup-Ordner, die älter als [NUM] Tage sind."
          echo ""
          echo "-h"
          echo ""
          echo "    Zeigt Hilfe an."
          echo ""
          echo "-l"
          echo ""
          echo "   listet das zur Zeit aktive Verkehrsgebiet auf."
          echo ""
          echo "-p [list|pull]"
          echo ""
          echo "    Download/Auflisten von optionalen Relationen."
          echo "    Benötigt ein weiteres Argument:"
          echo "    Mit \"list\" werden die optionalen Relationen aufgelistet."
          echo "    Mit \"pull\" werden die optionalen Relationen runtergeladen."
          echo ""
          exit
       ;;
       l) # Listet das aktuell aktive Verkehrsgebiet auf
          showtparea="yes"
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
 [ ! "$changeptarea" == "yes" ] && read -p "Bitte Gebiet angeben: " areaarg
 ptareacfgfile="$(egrep -H '^ptareashort=["'\'']*'"$areaarg"'["'\'']*$' ./config/ptarea*/ptarea.cfg | cut -f1 -d:)"
 if [ "$(echo "$ptareacfgfile" | sed '/^$/d' | wc -l)" == 1 ]; then
  echo -e "Verarbeitung wird vorbereitet.\nLöschen der alten config-Dateien:"
  rm -vf ./config/*.cfg
  ptareadir="$(dirname "$ptareacfgfile")"
  echo "Kopieren der neuen config-Dateien:"
  cp -vf "${ptareadir}"/*.cfg ./config/
 else
  echo "Kein passendes Verkehrsgebiet gefunden. Mögliche Bezeichnungen sind:"
  sed -n 's/^ptareashort=["'\'']*\([[:alnum:]]*\)["'\'']*$/\1/p' ./config/ptarea*/ptarea.cfg
  exit 1
 fi
fi

source ./config/ptarea.cfg

if [ "$showtparea" == "yes" ]; then
 echo "Aktuelles Verkehrsgebiet: ${ptarealong}"
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
echo "[1] - Download bus routes in ${ptarealong}-area (route_bus_raw.osm)"
echo "[2] - Download train routes in ${ptarealong}-area (route_train_raw.osm)"
echo "[3] - Download light-rail routes in ${ptarealong}-area (route_light_rail.osm)"
echo "[4] - Download subway routes in ${ptarealong}-area (route_subway.osm)"
echo "[5] - Download monorail routes in ${ptarealong}-area (route_monorail.osm)"
echo "[6] - Download tram routes in ${ptarealong}-area (route_tram.osm)"
echo "[7] - Download trolleybus routes in ${ptarealong}-area (route_trolleybus.osm)"
echo "[8] - Download ferry routes in ${ptarealong}-area (route_ferry.osm)"
echo "[9] - Download stop-areas in ${ptarealong}-area (stop_area_bbox.osm)"
echo "[10] - Download stop-area-groups in ${ptarealong}-area (stop_area_groups.osm)"
echo "[11] - Download stop-areas in ${ptarealong}-stoprelation (stoprelation.osm)"
echo "[12] - Download bus routes in ${ptarealong}-bus-relation (route_busrelation.osm)"
echo "[13] - Download master routes in ${ptarealong}-area (route_master_bus.osm)"
echo "[a] - Download all OSM-files and start HTML generation."
echo "[n] - Download nothing. Start HTML generation."
echo "[q] - Quit"
echo ""
}

# Hinweis: http: ... ;>;);out meta; Ein > und Multipolygone werden NICHT vollständig heruntergeladen.

areabus() {
echo "*** Processing route_bus_raw.osm/route_bus.osm ***"

wget -O ./osmdata/route_bus_raw.osm "http://overpass-api.de/api/interpreter?data=(relation(${ptareabbox}) [\"type\"=\"route\"][\"route\"=\"bus\"];>;);out meta;"
# Wichtig, das osmconvert VOR der Bearbeitung mit sed ausgeführt wird. Ansonsten wird die Syntax wieder in Gänsefüsschen umgeschrieben.
tools/osmconvert/osmconvert -v ./osmdata/route_bus_raw.osm --complex-ways --complete-ways -B="tools/poly/${areapolyfile}" -o=./osmdata/route_bus.osm
# Für Skript pt_analysis2html muss Datei noch wie folgt bearbeitet werden (damit die Datei konform mit JOSM-Api-Abfrage-Datei ist):
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/route_bus.osm
}

areatrain() {
echo "*** Processing route_train_raw.osm/route_train.osm ***"
wget -O ./osmdata/route_train_raw.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"train\"];>;);out meta;"
# Wichtig, das osmconvert VOR der Bearbeitung mit sed ausgeführt wird. Ansonsten wird die Syntax wieder in Gänsefüsschen umgeschrieben.
tools/osmconvert/osmconvert -v ./osmdata/route_train_raw.osm --complex-ways --complete-ways -B="tools/poly/${areapolyfile}" -o=./osmdata/route_train.osm
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/route_train.osm
}

arealightrail() {
echo "*** Processing route_light_rail.osm ***"
wget -O ./osmdata/route_light_rail.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"light_rail\"];>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/route_light_rail.osm
}

areasubway() {
echo "*** Processing route_subway.osm ***"
wget -O ./osmdata/route_subway.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"subway\"];>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/route_subway.osm
}

areamonorail() {
echo "*** Processing route_monorail.osm ***"
wget -O ./osmdata/route_monorail.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"monorail\"];>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/route_monorail.osm
}

areatram() {
echo "*** Processing route_tram.osm ***"
wget -O ./osmdata/route_tram.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"tram\"];>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/route_tram.osm
}

areatrolleybus() {
echo "*** Processing route_trolleybus.osm ***"
wget -O ./osmdata/route_trolleybus.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"trolleybus\"];>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/route_trolleybus.osm
}

areaferry() {
echo "*** Processing route_ferry.osm ***"
wget -O ./osmdata/route_ferry.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"ferry\"];>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/route_ferry.osm
}

stopareas() {
echo "*** Processing stop_area_bbox/stop_areas.osm ***"
wget -O ./osmdata/stop_area_bbox.osm "http://overpass-api.de/api/interpreter?data=(relation(${ptareabbox})[\"public_transport\"=\"stop_area\"];>>;);out meta;"
# Wichtig, das osmconvert VOR der Bearbeitung mit sed ausgeführt wird. Ansonsten wird die Syntax wieder in Gänsefüsschen umgeschrieben.
tools/osmconvert/osmconvert -v ./osmdata/stop_area_bbox.osm --complex-ways --complete-ways -B="tools/poly/${areapolyfile}" -o=./osmdata/stop_areas.osm
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/stop_areas.osm
}

stopareagroups() {
echo "*** Processing stop_area_groups.osm ***"
wget -O ./osmdata/stop_area_groups.osm "http://overpass-api.de/api/interpreter?data=(relation(${ptareabbox})[\"public_transport\"=\"stop_area\"];<<;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/stop_area_groups.osm
}

areastoprelation() {
echo "*** Processing stoprelation.osm ***"
wget -O ./osmdata/stoprelation.osm "http://overpass-api.de/api/interpreter?data=(relation(${ptareastoprelid});>>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/stoprelation.osm
}

areabusrelation() {
echo "*** Processing route_busrelation.osm ***"
wget -O ./osmdata/route_busrelation.osm "http://overpass-api.de/api/interpreter?data=(relation(${ptareabusrelid});>>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/route_busrelation.osm
}

routemasterbus() {
echo "*** Processing route_master_bus.osm ***"
wget -O ./osmdata/route_master_bus.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"${ptareapoly}\")[\"type\"=\"route\"][\"route\"=\"bus\"];<<;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/route_master_bus.osm
}

# Die einzelnen Downloads können in einer Schleife so lange heruntergeldaen werden, bis n gewählt wird. Der komplette Download hat ein break am Ende.
while true; do

   if [ ! "$autoprocess" == "yes" ]; then
    osmdialog
    read -p "Welche Datei(en) soll(en) heruntergeladen werden? " selectosmdata
   fi

    case "$selectosmdata" in
      1) rm -f ./osmdata/route_bus_raw.osm
         while [ "$(find ./osmdata/route_bus_raw.osm -maxdepth 1 -size -${minsizebusraw} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_bus_raw.osm ]; do areabus; done
          ;;
      2) rm -f ./osmdata/route_train_raw.osm
         while [ "$(find ./osmdata/route_train_raw.osm -maxdepth 1 -size -${minsizetrainraw} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_train_raw.osm ]; do areatrain; done
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
      9) rm -f ./osmdata/stop_area_bbox.osm
         while [ "$(find ./osmdata/stop_area_bbox.osm -maxdepth 1 -size -${minsizestopareabbox} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stop_area_bbox.osm ]; do stopareas; done
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
      a) rm -f ./osmdata/route_bus_raw.osm
         rm -f ./osmdata/route_train_raw.osm
         rm -f ./osmdata/route_light_rail.osm
         rm -f ./osmdata/route_subway.osm
         rm -f ./osmdata/route_monorail.osm
         rm -f ./osmdata/route_tram.osm
         rm -f ./osmdata/route_trolleybus.osm
         rm -f ./osmdata/route_ferry.osm
         rm -f ./osmdata/stop_area_bbox.osm
         rm -f ./osmdata/stop_area_groups.osm
         rm -f ./osmdata/stoprelation.osm
         rm -f ./osmdata/route_busrelation.osm
         rm -f ./osmdata/route_master_bus.osm

         downloadcounter="0"
         while [ "$(find ./osmdata/route_bus_raw.osm -maxdepth 1 -size -${minsizebusraw} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_bus_raw.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_bus_raw.osm) überschritten."
           killthisscript="yes"
           kindofosm="route_bus_raw.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          areabus
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/route_train_raw.osm -maxdepth 1 -size -${minsizetrainraw} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_train_raw.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_train_raw.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, route_train_raw.osm"
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
         while [ "$(find ./osmdata/stop_area_bbox.osm -maxdepth 1 -size -${minsizestopareabbox} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stop_area_bbox.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (stop_area_bbox.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, stop_area_bbox.osm"
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
         echo "$(basename ${0}) wird ohne weitere Überprüfung der OSM-Daten beendet."
         exit 0
          ;;
      *) echo "Fehlerhafte Eingabe!"
          ;;
    esac

done

# Mit osmconvert bearbeitete Dateien werden geprüft.
while [ "$(find ./osmdata/route_bus.osm -maxdepth 1 -size -${minsizebus} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_bus.osm ]; do areabus; done
while [ "$(find ./osmdata/stop_areas.osm -maxdepth 1 -size -${minsizestoparea} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stop_areas.osm ]; do stopareas; done
while [ "$(find ./osmdata/route_train.osm -maxdepth 1 -size -${minsizetrain} 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_train.osm ]; do areatrain; done

if [ "$stoppesteddownload" == "1" ]; then
 cp ./osmdata/stoprelation.osm "$backupordner"/`date +%Y%m%d_%H%M`_stoprelation.osm
fi
if [ "$busrelationdownload" == "1" ]; then
 cp ./osmdata/route_busrelation.osm "$backupordner"/`date +%Y%m%d_%H%M`_route_busrelation.osm
fi

#Fehlererkennung durch osmconvert
if [ $(sed -e :a -e '$q;N;3,$D;ba;' ./osmdata/route_bus.osm | grep '<relation id' | wc -l) -gt "0" ]; then
 echo "Fehler am Ende von route_bus.osm. Bitte manuell bereinigen und pt_analysis2html.sh ausführen."
 sed -e :a -e '$q;N;3,$D;ba;' ./osmdata/route_bus.osm && exit
fi

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

