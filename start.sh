#!/bin/bash

# License: GNU Lesser General Public License v3.0
# See: http://www.gnu.org/licenses/lgpl-3.0.html
# Written by Carsten Jacob
# Please feel free to contact me coding@langstreckentouren.de
# https://github.com/CarstenHa

# Hinweise zu diesem Skript: Das Herunterladen mit wget und der Option -t 0 lieferte zum Teil fehlerhafte Ergebnisse. Deswegen werden die .osm-Dateien in einer Schleife auf eine Minimalgröße untersucht. Deswegen sollte der Test der while-Schleifen von Zeit zu Zeit überprüft werden (find-Befehl mit Option -size).

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

while getopts abd:hlt opt
do
   case $opt in
       a) # automatisierter Prozess ohne Abfragen.
          selectosmdata="a"
          autoprocess="yes"
       ;;
       b) wget -O "$backupordner/`date +%Y%m%d`_takst_sjaelland_bus.osm" "http://overpass-api.de/api/interpreter?data=(relation(10002530);>>;);out meta;"
          exit
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
          echo "    Automatischer Prozess ohne weitere Abfragen. Ist identisch bei Auswahl [a],"
          echo "    wenn dieses Skript ohne weitere Optionen ausgeführt wird."
          echo "-b"
          echo "    Downloading Takst-Sjælland - Bus-Relation (incl. Multipoygone)."
          echo "-d [NUM]"
          echo "    Löscht alle Dateien im Backup-Ordner, die älter als [NUM] Tage sind."
          echo "-h"
          echo "    Zeigt Hilfe an."
          echo "-t"
          echo "    Downloading Takst-Sjælland - Tog-Relation (incl. Multipoygone)."
          echo ""
          exit
       ;;
       t) wget -O "$backupordner/`date +%Y%m%d`_takst_sjaelland_tog.osm" "http://overpass-api.de/api/interpreter?data=(relation(10002529);>>;);out meta;"
          exit
       ;;
       ?) exit 1
       ;;
    esac
done

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
echo "[1] - Download bus routes in \"Takst Sjælland\"-area (takst_bus.osm)"
echo "[2] - Download train routes in \"Takst Sjælland\"-area (route_train.osm)"
echo "[3] - Download light-rail routes in \"Takst Sjælland\"-area (takst_light_rail.osm)"
echo "[4] - Download subway routes in \"Takst Sjælland\"-area (takst_subway.osm)"
echo "[5] - Download monorail routes in \"Takst Sjælland\"-area (takst_monorail.osm)"
echo "[6] - Download tram routes in \"Takst Sjælland\"-area (takst_tram.osm)"
echo "[7] - Download trolleybus routes in \"Takst Sjælland\"-area (takst_trolleybus.osm)"
echo "[8] - Download ferry routes in \"Takst Sjælland\"-area (takst_ferry.osm)"
echo "[9] - Download stop-areas in \"Takst Sjælland\"-area (stop_area_bbox.osm)"
echo "[10] - Download stop-area-groups in \"Takst Sjælland\"-area (stop_area_groups.osm)"
echo "[11] - Download stop-areas in \"Takst Sjælland stoppested\"-Relation (takst_stoppested.osm)"
echo "[12] - Download bus routes in \"Takst Sjælland - Bus\"-Relation (takst_busrelation.osm)"
echo "[13] - Download master routes in \"Takst Sjælland\"-area (route_master_bus.osm)"
echo "[a] - Download all OSM-files and start HTML generation."
echo "[n] - Download nothing. Start HTML generation."
echo "[q] - Quit"
echo ""
}

# Hinweis: http: ... ;>;);out meta; Ein > und Multipolygone werden NICHT vollständig heruntergeladen.

takstbus() {
echo "*** Processing takst_bus.osm/takst.osm ***"
wget -O ./osmdata/takst_bus.osm "http://overpass-api.de/api/interpreter?data=(relation(54.54,10.86,56.15,12.82)[\"type\"=\"route\"][\"route\"=\"bus\"];>;);out meta;"
# Wichtig, das osmconvert VOR der Bearbeitung mit sed ausgeführt wird. Ansonsten wird die Syntax wieder in Gänsefüsschen umgeschrieben.
tools/osmconvert/osmconvert -v ./osmdata/takst_bus.osm --complex-ways --complete-ways -B=tools/poly/takst.poly -o=./osmdata/takst.osm
# Für Skript pt_analysis2html muss Datei noch wie folgt bearbeitet werden (damit die Datei konform mit JOSM-Api-Abfrage-Datei ist):
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/takst.osm
}

taksttrain() {
echo "*** Processing route_train.osm/takst_train.osm ***"
wget -O ./osmdata/route_train.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"56.068972 11.618036 56.218926 12.326655 56.065906 12.628779 55.964577 12.664487 55.824432 12.708432 55.626447 12.895200 55.414986 12.601316 54.822845 12.771604 54.447687 11.997068 54.735723 10.843503 55.125510 11.041257 55.408750 10.972592 55.739483 10.761106 56.044433 11.123654 56.068972 11.618036\")[\"type\"=\"route\"][\"route\"=\"train\"];>;);out meta;"
# Wichtig, das osmconvert VOR der Bearbeitung mit sed ausgeführt wird. Ansonsten wird die Syntax wieder in Gänsefüsschen umgeschrieben.
tools/osmconvert/osmconvert -v ./osmdata/route_train.osm --complex-ways --complete-ways -B=tools/poly/takst.poly -o=./osmdata/takst_train.osm
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/takst_train.osm
}

takstlightrail() {
echo "*** Processing takst_light_rail.osm ***"
wget -O ./osmdata/takst_light_rail.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"56.068972 11.618036 56.218926 12.326655 56.065906 12.628779 55.964577 12.664487 55.824432 12.708432 55.626447 12.895200 55.414986 12.601316 54.822845 12.771604 54.447687 11.997068 54.735723 10.843503 55.125510 11.041257 55.408750 10.972592 55.739483 10.761106 56.044433 11.123654 56.068972 11.618036\")[\"type\"=\"route\"][\"route\"=\"light_rail\"];>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/takst_light_rail.osm
}

takstsubway() {
echo "*** Processing takst_subway.osm ***"
wget -O ./osmdata/takst_subway.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"56.068972 11.618036 56.218926 12.326655 56.065906 12.628779 55.964577 12.664487 55.824432 12.708432 55.626447 12.895200 55.414986 12.601316 54.822845 12.771604 54.447687 11.997068 54.735723 10.843503 55.125510 11.041257 55.408750 10.972592 55.739483 10.761106 56.044433 11.123654 56.068972 11.618036\")[\"type\"=\"route\"][\"route\"=\"subway\"];>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/takst_subway.osm
}

takstmonorail() {
echo "*** Processing takst_monorail.osm ***"
wget -O ./osmdata/takst_monorail.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"56.068972 11.618036 56.218926 12.326655 56.065906 12.628779 55.964577 12.664487 55.824432 12.708432 55.626447 12.895200 55.414986 12.601316 54.822845 12.771604 54.447687 11.997068 54.735723 10.843503 55.125510 11.041257 55.408750 10.972592 55.739483 10.761106 56.044433 11.123654 56.068972 11.618036\")[\"type\"=\"route\"][\"route\"=\"monorail\"];>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/takst_monorail.osm
}

taksttram() {
echo "*** Processing takst_tram.osm ***"
wget -O ./osmdata/takst_tram.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"56.068972 11.618036 56.218926 12.326655 56.065906 12.628779 55.964577 12.664487 55.824432 12.708432 55.626447 12.895200 55.414986 12.601316 54.822845 12.771604 54.447687 11.997068 54.735723 10.843503 55.125510 11.041257 55.408750 10.972592 55.739483 10.761106 56.044433 11.123654 56.068972 11.618036\")[\"type\"=\"route\"][\"route\"=\"tram\"];>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/takst_tram.osm
}

taksttrolleybus() {
echo "*** Processing takst_trolleybus.osm ***"
wget -O ./osmdata/takst_trolleybus.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"56.068972 11.618036 56.218926 12.326655 56.065906 12.628779 55.964577 12.664487 55.824432 12.708432 55.626447 12.895200 55.414986 12.601316 54.822845 12.771604 54.447687 11.997068 54.735723 10.843503 55.125510 11.041257 55.408750 10.972592 55.739483 10.761106 56.044433 11.123654 56.068972 11.618036\")[\"type\"=\"route\"][\"route\"=\"trolleybus\"];>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/takst_trolleybus.osm
}

takstferry() {
echo "*** Processing takst_ferry.osm ***"
wget -O ./osmdata/takst_ferry.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"56.068972 11.618036 56.218926 12.326655 56.065906 12.628779 55.964577 12.664487 55.824432 12.708432 55.626447 12.895200 55.414986 12.601316 54.822845 12.771604 54.447687 11.997068 54.735723 10.843503 55.125510 11.041257 55.408750 10.972592 55.739483 10.761106 56.044433 11.123654 56.068972 11.618036\")[\"type\"=\"route\"][\"route\"=\"ferry\"];>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/takst_ferry.osm
}

stopareas() {
echo "*** Processing stop_area_bbox/stop_areas.osm ***"
wget -O ./osmdata/stop_area_bbox.osm "http://overpass-api.de/api/interpreter?data=(relation(54.54,10.86,56.15,12.82)[\"public_transport\"=\"stop_area\"];>>;);out meta;"
# Wichtig, das osmconvert VOR der Bearbeitung mit sed ausgeführt wird. Ansonsten wird die Syntax wieder in Gänsefüsschen umgeschrieben.
tools/osmconvert/osmconvert -v ./osmdata/stop_area_bbox.osm --complex-ways --complete-ways -B=tools/poly/takst.poly -o=./osmdata/stop_areas.osm
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/stop_areas.osm
}

stopareagroups() {
echo "*** Processing stop_area_groups.osm ***"
wget -O ./osmdata/stop_area_groups.osm "http://overpass-api.de/api/interpreter?data=(relation(54.54,10.86,56.15,12.82)[\"public_transport\"=\"stop_area\"];<<;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/stop_area_groups.osm
}

takststoppested() {
echo "*** Processing takst_stoppested.osm ***"
wget -O ./osmdata/takst_stoppested.osm "http://overpass-api.de/api/interpreter?data=(relation(10020275);>>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/takst_stoppested.osm
}

takstbusrelation() {
echo "*** Processing takst_busrelation.osm ***"
wget -O ./osmdata/takst_busrelation.osm "http://overpass-api.de/api/interpreter?data=(relation(10002530);>>;);out meta;"
# Hochkommas werden geändert und html-Code wird am Ende von Zeilen umgeschrieben.
sed -i 's/"/'\''/g;s/\/>/ \/>/g' ./osmdata/takst_busrelation.osm
}

routemasterbus() {
echo "*** Processing route_master_bus.osm ***"
wget -O ./osmdata/route_master_bus.osm "http://overpass-api.de/api/interpreter?data=(relation(poly:\"56.068972 11.618036 56.218926 12.326655 56.065906 12.628779 55.964577 12.664487 55.824432 12.708432 55.626447 12.895200 55.414986 12.601316 54.822845 12.771604 54.447687 11.997068 54.735723 10.843503 55.125510 11.041257 55.408750 10.972592 55.739483 10.761106 56.044433 11.123654 56.068972 11.618036\")[\"type\"=\"route\"][\"route\"=\"bus\"];<<;);out meta;"
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
      1) rm -f ./osmdata/takst_bus.osm
         while [ "$(find ./osmdata/takst_bus.osm -maxdepth 1 -size -25M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_bus.osm ]; do takstbus; done
          ;;
      2) rm -f ./osmdata/route_train.osm
         while [ "$(find ./osmdata/route_train.osm -maxdepth 1 -size -10M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_train.osm ]; do taksttrain; done
          ;;
      3) rm -f ./osmdata/takst_light_rail.osm
         while [ "$(find ./osmdata/takst_light_rail.osm -maxdepth 1 -size -2M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_light_rail.osm ]; do takstlightrail; done
          ;;
      4) rm -f ./osmdata/takst_subway.osm
         while [ "$(find ./osmdata/takst_subway.osm -maxdepth 1 -size -200k 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_subway.osm ]; do takstsubway; done
          ;;
      5) rm -f ./osmdata/takst_monorail.osm
         while [ ! -e ./osmdata/takst_monorail.osm ]; do takstmonorail; done
          ;;
      6) rm -f ./osmdata/takst_tram.osm
         while [ ! -e ./osmdata/takst_tram.osm ]; do taksttram; done
          ;;
      7) rm -f ./osmdata/takst_trolleybus.osm
         while [ ! -e ./osmdata/takst_trolleybus.osm ]; do taksttrolleybus; done
          ;;
      8) rm -f ./osmdata/takst_ferry.osm
         while [ "$(find ./osmdata/takst_ferry.osm -maxdepth 1 -size -100k 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_ferry.osm ]; do takstferry; done
          ;;
      9) rm -f ./osmdata/stop_area_bbox.osm
         while [ "$(find ./osmdata/stop_area_bbox.osm -maxdepth 1 -size -1M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stop_area_bbox.osm ]; do stopareas; done
          ;;
      10) rm -f ./osmdata/stop_area_groups.osm
         while [ "$(find ./osmdata/stop_area_groups.osm -maxdepth 1 -size -100k 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stop_area_groups.osm ]; do stopareagroups; done
          ;;
      11) rm -f ./osmdata/takst_stoppested.osm
         while [ "$(find ./osmdata/takst_stoppested.osm -maxdepth 1 -size -150k 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_stoppested.osm ]; do takststoppested; done
         stoppesteddownload="1"
          ;;
      12) rm -f ./osmdata/takst_busrelation.osm
         while [ "$(find ./osmdata/takst_busrelation.osm -maxdepth 1 -size -2M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_busrelation.osm ]; do takstbusrelation; done
         busrelationdownload="1"
          ;;
      13) rm -f ./osmdata/route_master_bus.osm
         while [ "$(find ./osmdata/route_master_bus.osm -maxdepth 1 -size -3M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_master_bus.osm ]; do routemasterbus; done
          ;;
      a) rm -f ./osmdata/takst_bus.osm
         rm -f ./osmdata/route_train.osm
         rm -f ./osmdata/takst_light_rail.osm
         rm -f ./osmdata/takst_subway.osm
         rm -f ./osmdata/takst_monorail.osm
         rm -f ./osmdata/takst_tram.osm
         rm -f ./osmdata/takst_trolleybus.osm
         rm -f ./osmdata/takst_ferry.osm
         rm -f ./osmdata/stop_area_bbox.osm
         rm -f ./osmdata/stop_area_groups.osm
         rm -f ./osmdata/takst_stoppested.osm
         rm -f ./osmdata/takst_busrelation.osm
         rm -f ./osmdata/route_master_bus.osm

         # ***** Hier wird die Anzahl der maximalen Downloadversuche definiert *****
         maxattempt="25" 

         downloadcounter="0"
         while [ "$(find ./osmdata/takst_bus.osm -maxdepth 1 -size -25M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_bus.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (takst_bus.osm) überschritten."
           killthisscript="yes"
           kindofosm="takst_bus.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          takstbus
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/route_train.osm -maxdepth 1 -size -10M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_train.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (route_train.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, route_train.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          taksttrain
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/takst_light_rail.osm -maxdepth 1 -size -2M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_light_rail.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (takst_light_rail.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, takst_light_rail.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          takstlightrail
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/takst_subway.osm -maxdepth 1 -size -200k 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_subway.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (takst_subway.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, takst_subway.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          takstsubway
          let downloadcounter++
         done

         downloadcounter="0"
         while [ ! -e ./osmdata/takst_monorail.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (takst_monorail.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, takst_monorail.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          takstmonorail
          let downloadcounter++
         done

         downloadcounter="0"
         while [ ! -e ./osmdata/takst_tram.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (takst_tram.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, takst_tram.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          taksttram
          let downloadcounter++
         done

         downloadcounter="0"
         while [ ! -e ./osmdata/takst_trolleybus.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (takst_trolleybus.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, takst_trolleybus.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          taksttrolleybus
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/takst_ferry.osm -maxdepth 1 -size -100k 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_ferry.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (takst_ferry.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, takst_ferry.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          takstferry
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/stop_area_bbox.osm -maxdepth 1 -size -1M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stop_area_bbox.osm ]; do
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
         while [ "$(find ./osmdata/stop_area_groups.osm -maxdepth 1 -size -100k 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stop_area_groups.osm ]; do
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
         while [ "$(find ./osmdata/takst_stoppested.osm -maxdepth 1 -size -150k 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_stoppested.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (takst_stoppested.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, takst_stoppested.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          takststoppested
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/takst_busrelation.osm -maxdepth 1 -size -2M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_busrelation.osm ]; do
          if [ "$downloadcounter" -ge "$maxattempt" ]; then
           echo "Anzahl von maximal ${maxattempt} Download-Versuchen (takst_busrelation.osm) überschritten."
           killthisscript="yes"
           kindofosm="${kindofosm}, takst_busrelation.osm"
           break
          fi
          echo -n "Downloadversuch $(($downloadcounter + 1)) "
          takstbusrelation
          let downloadcounter++
         done

         downloadcounter="0"
         while [ "$(find ./osmdata/route_master_bus.osm -maxdepth 1 -size -3M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/route_master_bus.osm ]; do
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
while [ "$(find ./osmdata/takst.osm -maxdepth 1 -size -5M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst.osm ]; do takstbus; done
while [ "$(find ./osmdata/stop_areas.osm -maxdepth 1 -size -500k 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/stop_areas.osm ]; do stopareas; done
while [ "$(find ./osmdata/takst_train.osm -maxdepth 1 -size -3M 2>/dev/null | wc -l)" -gt "0" -o ! -e ./osmdata/takst_train.osm ]; do taksttrain; done

if [ "$stoppesteddownload" == "1" ]; then
 cp ./osmdata/takst_stoppested.osm "$backupordner"/`date +%Y%m%d_%H%M`_takst_stoppested.osm
fi
if [ "$busrelationdownload" == "1" ]; then
 cp ./osmdata/takst_busrelation.osm "$backupordner"/`date +%Y%m%d_%H%M`_takst_busrelation.osm
fi

#Fehlererkennung durch osmconvert
if [ $(sed -e :a -e '$q;N;3,$D;ba;' ./osmdata/takst.osm | grep '<relation id' | wc -l) -gt "0" ]; then
 echo "Fehler am Ende von takst.osm. Bitte manuell bereinigen und pt_analysis2html.sh ausführen."
 sed -e :a -e '$q;N;3,$D;ba;' ./osmdata/takst.osm && exit
fi

./stopareaanalysis2html.sh
./pt_analysis2html.sh ./osmdata/takst.osm

# *** Benachrichtigungen ***
# Zeitspanne des Erstellungsprozesses wird errechnet und angezeigt.
zeitdiff=$((`date +%s`-"$zeitpunktbegin"))

echo "Public Transport Analyseseiten sind fertig (`date +%d.%m.%Y` um `date +%H:%M` Uhr)."
printf 'Dauer des Erstellungsprozesses: %02dh:%02dm:%02ds\n' $(($zeitdiff/3600)) $(($zeitdiff%3600/60)) $(($zeitdiff%60))
notify-send -t 0 "Hinweis" "Public Transport-Analyseseiten sind fertig." 2>/dev/null
if [ -e "./tools/mail/sendamail" ]; then
 ./tools/mail/sendamail
fi

