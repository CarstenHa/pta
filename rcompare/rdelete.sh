#!/bin/bash

datumjetzt=`date +%Y%m%d_%H%M%S`
exec &> >(tee ./backup/${datumjetzt}_rdelete.log)

echo "***** Löschung einer Route aus pta (GTFS und .cfg-Datei) *****"
cd ..
./start.sh -L
cd - &>/dev/null
read -p "Welches Depot soll bearbeitet werden? " depotnr
if [ ! -e "../config/ptarea${depotnr}/real_bus_stops.cfg" ]; then
 [ ! -d "../config/ptarea${depotnr}" ] && echo "Ordner ../config/ptarea${depotnr} existiert nicht. Skript wird abgebrochen!" && exit 1
 echo "real_bus_stops.cfg im Ordner ../config/ptarea${depotnr} existiert nicht. Skript wird abgebrochen!"
 exit 1
fi

rbscfgfile="../config/ptarea${depotnr}/real_bus_stops.cfg"
invcfgfile="../config/ptarea${depotnr}/invalidroutes.cfg"

echo "Es kann nach [R]elationsID oder [S]hapeID ausgewertet werden."
while true; do
 read -p "Wie soll ausgewertet werden? " relshapeausw
  case "$relshapeausw" in
   r|R) read -p "RelationID: " relanswer
        break
     ;;
   s|S) read -p "ShapeID: " shapeanswer
        break
     ;;
     *) echo "Fehlerhafte Eingabe."
  esac
done

if [ -n "$relanswer" ]; then
 anzrelid="$(grep -c "^${relanswer} " "$rbscfgfile")"
 if [ ! "$anzrelid" == 1 ]; then
  echo "${anzrelid} RelationID gefunden. Skript wird abgebrochen!"
  exit 1
 else
  relid="$relanswer"
  cfgroutelinenr="$(grep -n "^${relid} " "$rbscfgfile" | grep -o '^[[:digit:]]*')"
  shapeid="$(sed -n "${cfgroutelinenr}p" "$rbscfgfile" | cut -f5 -d" ")"
 fi
fi

if [ -n "$shapeanswer" ]; then
 anzshapeid="$(cut -f5 -d" " "$rbscfgfile" | grep -c "${shapeanswer}")"
 if [ ! "$anzshapeid" == 1 ]; then
  echo "${anzshapeid} ShapeID gefunden. Skript wird abgebrochen!"
  exit 1
 else
  shapeid="$shapeanswer"
  cfgroutelinenr="$(cut -f5 -d" " "$rbscfgfile" | grep -n "$shapeid" | grep -o '^[[:digit:]]*')"
  relid="$(sed -n "${cfgroutelinenr}p" "$rbscfgfile" | cut -f1 -d" ")"
 fi
fi

# Kommentarzeile in real_bus_stops.cfg
cfgroutecommentline=$(("$cfgroutelinenr" - 1))
commentline="$(sed -n "${cfgroutecommentline}p" "$rbscfgfile")"
cfgrouteline="$(sed -n "${cfgroutelinenr}p" "$rbscfgfile")"
cfgrouteref="$(echo "$cfgrouteline" | cut -f4 -d" ")"

echo -e "Erstellungsdatum: $(date +%Y-%m-%d) um $(date +%H:%M) Uhr.\nGelöschte RelationID: ${relid}\nRoute: ${cfgrouteref}\nShapeID: ${shapeid}" >./"${datumjetzt}_README"
tarfile="./backup/zipfiles/${datumjetzt}_deleteroute.tar"
tar -cf "$tarfile" ./"${datumjetzt}_README" && rm -f ./"${datumjetzt}_README"

echo -e "\n*** 1. Sicherung aller relevanten Dateien ***"
# Sicherung von OSM-Rohdaten
[ ! -d ./backup ] && echo "Ordner ./backup existiert nicht. Skript wird abgebrochen!" && exit 1
echo "OSM-Rohdaten der Route werden gesichert ..."
dattempts=0
osmfilepath="./backup/${datumjetzt}_route${cfgrouteref}_${relid}.osm"
osmfile="$(basename ${osmfilepath})"
while [ ! "$dexitstatus" == 0 -a "$dattempts" -lt 5 ]; do
 wget -O "$osmfilepath" "http://overpass-api.de/api/interpreter?data=(relation(${relid})[\"type\"=\"route\"][\"route\"=\"bus\"];>>;);out meta;"
 dexitstatus=$?
 let dattempts++
done
if [ ! "$dexitstatus" == 0 ]; then
 echo "Route konnte nicht zur Sicherung heruntergeladen werden."
else
 tar -vrf "$tarfile" "${osmfilepath}" && rm -f "${osmfilepath}"
fi

echo "HTML-Seiten werden gesichert ..."
tar -vrf "$tarfile" \
         "../htmlfiles/gtfsroutes.html" \
         "../htmlfiles/gtfs/${shapeid}.html" \
         "../htmlfiles/gtfs/maps/${shapeid}.html" \
         "../htmlfiles/gtfs/maps/${shapeid}.js" \
         "../htmlfiles/gtfs/maps/${shapeid}.gpx"

echo "config-Dateien werden gesichert ..."
tar -vrf "$tarfile" "$rbscfgfile" "$invcfgfile"

gzip "$tarfile" && echo "Sicherung befindet sich im Ordner ${tarfile}.gz"

echo -e "\n*** 2. Löschung aller relevanten Daten und Dateien ***"

echo "HTML-Seiten werden gelöscht ..."
rm -fv "../htmlfiles/gtfs/${shapeid}.html" "../htmlfiles/gtfs/maps/${shapeid}.html" "../htmlfiles/gtfs/maps/${shapeid}.js" "../htmlfiles/gtfs/maps/${shapeid}.gpx"

echo "Löschung der Route aus ../htmlfiles/gtfsroutes.html"
sed -i '/id="gtfsid3tab'"$shapeid"'"/d' ../htmlfiles/gtfsroutes.html

echo "Löschung der Daten aus real_bus_stops.cfg ..."
sed -i "${cfgroutelinenr}d" "$rbscfgfile"
sed -i "${cfgroutecommentline}d" "$rbscfgfile"

echo -e "\n*** 3. Dateien aktualisieren ***"

# Änderungsdatum wird eingetragen/aktualisiert.
moddateline="$(grep -n 'id="createdate"' ../htmlfiles/gtfsroutes.html | grep -o '^[[:digit:]]*')"
if [ -n "$moddateline" ]; then
 echo "Zeile ${moddateline}: Datum der Änderung wird in HTML-Seitenfuss von gtfsroutes.html eingetragen ..."
 # Evtl. alte Zeile mit Änderungsdatum wird aus HTML-Seite gelöscht.
 sed -i '/id="moddate"/d' ../htmlfiles/gtfsroutes.html
 # Neue Zeile mit letztem Änderungsdatum wird eingefügt.
 sed -i '/id="createdate"/s/\(.*\)/\1\n  <p id="moddate">Modified '"$(date +%Y-%m-%d)"' at '"$(date +%H:%M)"' with '"$(basename $0)"'.<\/p>/' ../htmlfiles/gtfsroutes.html
else
 echo "Änderungsdatum konnte nicht in gtfsroutes.html eingetragen werden."
fi

echo "Eintragen der gelöschten Route in ${invcfgfile}"
echo "Mögliche Optionen sind:"
echo "0 = In OSM-Daten und in PTA gelöscht."
echo "1 = Route existiert noch in OSM aber nicht in PTA"
echo "2 = Routenvariante existiert noch in OSM aber nicht in PTA"
read -p "Welchen Status soll die gelöschte Route erhalten? " rstatus
while [ ! "$rstatus" -lt 3 ]; do
 read -p "Ungültiger Status. Neue Eingabe: " rstatus
done
invcheck="$(grep "^${relid} " "$invcfgfile")"
if [ -n "$invcheck" ]; then
 echo "RelationID existiert bereits in der Datei ${invcfgfile}:"
 echo "$invcheck"
 read -p "Bitte überprüfen. Weiter mit [ENTER]"
else
 echo "Neuer Eintrag in ${invcfgfile}:"
 echo "$commentline" | tee -a "$invcfgfile"
 echo "${relid} $(date +%Y-%m-%d) ${cfgrouteref} ${rstatus}" | tee -a "$invcfgfile"
 sed -i '/^$/d' "$invcfgfile"
fi

echo -e "\n*** 4. config-Dateien werden aktualisiert ***"
cd ..
./start.sh -l
cd -

echo -e "\nRoute ${relid} wurde gelöscht mit $(basename $0).\nLogdatei: ./backup/${datumjetzt}_rdelete.log"
# Logdatei wird bereinigt.
sed -i 's/.\[1;32m//g;s/.\[0m//g' ./backup/${datumjetzt}_rdelete.log
