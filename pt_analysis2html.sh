#!/bin/bash

# License: GNU Lesser General Public License v3.0
# See: http://www.gnu.org/licenses/lgpl-3.0.html
# Written by Carsten Jacob
# Please feel free to contact me coding@langstreckentouren.de
# https://github.com/CarstenHa

# Abfrage für JOSM:
# type:relation and type=route and (route=bus or route=ferry or route=light_rail or route=train or route=tram or route=subway)

ptdatumjetzt=`date +%Y%m%d_%H%M`
backupordner="./backup"

if [ -z "$1" ]; then
 echo "Es muss dem Skript ein Argument übergeben werden. Bitte neu starten. Skript wird abgebrochen." && exit 2
fi

usage() {
cat <<EOU

Programm zur Auswertung von OSM-Daten.

Syntax: $0 [option] [param]
        $0 pfad/zur/datei.osm

Beschreibung der Optionen:

   -h

	ruft diese Hilfe auf.

   -d [relationid]

	Löschen einer Route(nvariante). Falls keine Routenvariante mehr in einer entsprechenden Masterroute
	vorhanden ist, kann auch diese optional gelöscht werden. Dann sollte man auch daran denken, diese
	Route(n) ggf. aus den Rohdaten bei Openstreetmap.org zu löschen, wenn diese Routen real nicht mehr
	existieren.
	Benötigt ein Argument in Form einer gültigen Routen-RalationID (keine Masterrouten-RalationID).

   -s [relationid]

	Komplettieren von Routendaten, die neu in eine real_bus_stops.cfg aufgenommen worden ist.
	Routen in den OSM-Daten werden immer ausgewertet, auch wenn diese noch nicht in den diversen
	.cfg-Dateien aufgenommen worden sind. Will man schnell eine neu eingetragene Route (real_bus_stops.cfg)
	in der bestehenden osmroutes.html vollständig auswerten, ohne eine komplette Auswertung der gesamten
	OSM-Rohdaten vornehmen zu müssen, ist diese Option relevant.
	Wichtig! Es werden keine komplett neuen Routen ausgewertet. Hierfür muss eine komplette Auswertung
	durchgeführt werden.
	Es wird ein Argument in Form einer RelationID benötigt.

EOU
}
singlecheck() {
 ./start.sh -L
 read -p "Welches Depot soll bearbeitet werden? Bitte Nr angeben: " depotnr
 if [ ! -e "./config/ptarea${depotnr}/real_bus_stops.cfg" ]; then
  [ ! -d "./config/ptarea${depotnr}" ] && echo "Ordner ./config/ptarea${depotnr} existiert nicht. Skript wird abgebrochen!" && exit 1
  echo "real_bus_stops.cfg im Ordner ./config/ptarea${depotnr} existiert nicht. Skript wird abgebrochen!"
  exit 1
 fi
 rbscfgfile="./config/ptarea${depotnr}/real_bus_stops.cfg"
 relid="$(grep "^${OPTARG} " "$rbscfgfile" | cut -f1 -d" ")"
 [ -z "$relid" ] && echo "RelationID existiert nicht in cfg-file. Skript wird abgebrochen!" && exit 1
 htmlname="./htmlfiles/osmroutes.html"
 echo "Datei ${htmlname} wird gesichert ..."
 cp "$htmlname" "$backupordner"/`date +%Y%m%d_%H%M`_"$(basename $htmlname)"
 echo "${htmlname} wird bearbeitet ..."
}

while getopts hd:s: opt
do
  case $opt in
   h) # Hilfe
   usage
   exit
   ;;
   d) # Route löschen

      singlecheck

      echo "************* Löschung einer Route aus pta (OSM) *************"

      if [ ! -e "${htmlname}" ]; then
       echo "${htmlname} existiert nicht. Skript wird abgebrochen."
       exit 1
      fi
      if [ -z "$(grep -o '<table id="'"$relid"'' "${htmlname}")" ]; then
       echo "RelationID ${relid} existiert nicht in ${htmlname}. Skript wird abgebrochen."
       exit 1
      fi

      # Variablen definieren
      refnumber="$(grep "^${relid} " "$rbscfgfile" | cut -d" " -f4)"
      oldagencyroutes="$(sed -n '/in OSM data:/s/.*in OSM data: \([[:digit:]]*\).*/\1/p' "${htmlname}")"
      newagencyroutes=$(("$oldagencyroutes" - 1))
      newanzmissingroutes="$(grep 'gtfsid[12]tab' ./htmlfiles/gtfsroutes.html | wc -l)"

      # Erster Teil der Tabelle löschen
      echo "Routenvariante (RelationID: ${relid}) wird gelöscht ..."
      sed -i '/<table id="'"$relid"'/,/<\/table>/d' "${htmlname}"
      # Zweiter Teil der Tabelle löschen
      sed -i '/<table id="sec'"$relid"'/,/<\/table>/d' "${htmlname}"
      rtbereich="$(sed -n '/<div id="rt'"$relid"'" class="routetab">/,/<\/div>/p' "${htmlname}")"
      # routetab-Element wird gelöscht
      sed -i '/<div id="rt'"$relid"'" class="routetab">/,/<\/div>/d' "${htmlname}"

      # Masterroute wird angepasst
      # Das <h3>-Element ist wichtig, damit nicht die entsprechende Route mit einer Route, die
      # nicht zum Verkehrsgebiet gehört, verwechselt werden kann.
      anzmroutes="$(grep -c '<a class="masterueber" href="#route'"$refnumber"'"><h3>' "${htmlname}")"
      if [ "$anzmroutes" == 1 ]; then
       masterrelbereich="$(sed -n '/<a class="masterueber" href="#route'"$refnumber"'"><h3>/,/^ <\/div>/p' "${htmlname}")"
       masterrelnumber="$(echo "$masterrelbereich" | sed -n 's/^.*<td class="small">RelationID: \([[:digit:]]*\)<\/td>.*$/\1/p')"
       # Wichtige Verzweigung (beachte das eingerückte <div>-Element!)
       # Der erste Bereich ist für Routen mit einer festen Masterroute als Eltern-Relation.
       # Der zweite Bereich ist für Routen, die keine Masterroute als Eltern-Relation haben (z.b. wenn es nur eine Routenvariante gibt).
       if [ -n "$masterrelnumber" ]; then
        anzroutesinmaster="$(sed -n 's/^.*<td id="anzmr'"$masterrelnumber"'">\([[:digit:]]*\) routes in master route.<\/td>.*$/\1/p' "${htmlname}")"
        newanzroutesinmaster=$(("$anzroutesinmaster" - 1))
       else
        sed -i '/<a class="masterueber" href="#route'"$refnumber"'"><h3>/,/^ <\/div>/d' "${htmlname}"
        anzmroutes=0
        newanzroutesinmaster="keine"
       fi
      fi

      if [ "$newanzroutesinmaster" == 0 ]; then

       masterchild="no"
       echo "Keine Routenvariante mehr in Masterroute (RelationID: ${masterrelnumber})."

       if [ "$anzmroutes" == 1 ]; then

        while true; do
         read -p "Soll ${anzmroutes} Masterroute aus ${htmlname} gelöscht werden? (j/n) " delmaster
         case "$delmaster" in
          j|J) anzmroutes=0
               # Zuerst wird das innen liegende <div ...class="masterroute"> bis zum abschliessenden
               # </div> mit der CSS-Klasse class="mastertabhg" gelöscht.
               sed -i '/<div id="route'"$refnumber"'" class="masterroute">/,/<\/div>/d' "${htmlname}"
               # Dann wird der Rest von <a class="masterueber" bis zum abschliessenden
               # </div> der CSS-Kasse class="masterroute" gelöscht.
               sed -i '/<a class="masterueber" href="#route'"$refnumber"'"><h3>/,/<\/div>/d' "${htmlname}"
               echo "HINWEIS: Nicht vergessen die Masterroute ${masterrelnumber} ggf. aus den OSM-Rohdaten zu löschen."
               break
          ;;
          n|N) echo "Masterroute bleibt in ${htmlname} erhalten."
               break
          ;;
            *) echo "Fehlerhafte Eingabe."
          ;;
         esac
        done

       fi

      else

       echo "${newanzroutesinmaster} weitere Routenvariante(n) in Route ${refnumber}."

      fi

      if [ "$anzmroutes" == 1 ]; then
       # Anzahl der Masterrouten wird in osmroutes.html angepasst
       echo "Masterroute ${masterrelnumber} wird angepasst ..."
       echo "Anzahl der Routen in Masterroute wird in ${htmlname} von ${anzroutesinmaster} auf ${newanzroutesinmaster} geändert."
       if [ "$masterchild" == "no" ]; then
        sed -i 's/\(^.*<td \)\(id="anzmr'"$masterrelnumber"'">\)[[:digit:]]*\( routes in master route.<\/td>.*$\)/\1class="red" \2'"$newanzroutesinmaster"'\3/' "${htmlname}"
       else
        sed -i 's/\(^.*<td id="anzmr'"$masterrelnumber"'">\)[[:digit:]]*\( routes in master route.<\/td>.*$\)/\1'"$newanzroutesinmaster"'\2/' "${htmlname}"
       fi
      else
       echo "${anzmroutes} Masterrouten der Linie ${refnumber} in osmroutes.html."
      fi

      # Löschen der OSM-Haltestellendatei (.html)
      echo "./htmlfiles/osm/${relid}.html wird gelöscht ..."
      rm -f "./htmlfiles/osm/${relid}.html"

      # Statistik wird angepasst (Anzahl der Busrouten).
      mroutesline="$(grep -ni 'id="stat_aar"' "${htmlname}" | grep -o '^[[:digit:]]*')"
      # Zusätzliche Überprüfung, falls mehrere identische Zeilen in osmroutes.html gefunden wurden.
      if [ "$(echo "$mroutesline" | wc -l)" -gt "1" ]; then
       echo "Statistikzeile konnte nicht eindeutig identifiziert werden.("$mroutesline")"
      else
       echo "Zeile ${mroutesline}: Statistik wird angepasst ..."
       sed -i ''"$mroutesline"'s/\(in OSM data: \)[[:digit:]]*/\1'"$newagencyroutes"'/' "${htmlname}"
      fi

      # Statistik wird angepasst (Anzahl der Busrouten in Prozent).
      oldmissroutesperc="$(sed -n '/are created in whole or in part/s/.* \([[:digit:]]*\)% .*/\1/p' "${htmlname}")"
      newmissroutesperc=$((100*${newagencyroutes}/${newanzmissingroutes}))
      routespercline="$(grep -ni 'are created in whole or in part' "${htmlname}" | grep -o '^[[:digit:]]*')"
      # Zusätzliche Überprüfung, falls mehrere identische Zeilen in osmroutes.html gefunden wurden.
      if [ "$(echo "$routespercline" | wc -l)" -gt "1" ]; then
       echo "Statistikzeile konnte nicht eindeutig identifiziert werden.("$routespercline")"
      else
       echo "Zeile ${routespercline}: Statistik wird angepasst ..."
       sed -i ''"$routespercline"'s/[[:digit:]]*%/'"$newmissroutesperc"'%/' "${htmlname}"
      fi

      # Hier werden die einzelnen Tabellen neu durchnummeriert. Der Platzhalter wird durch die neue Zeichenkette ersetzt.
      # Busrelationen
      echo "Busrouten werden in ${htmlname} neu durchnummeriert ..."
      sed -i 's/\(<h4 id=\"h4[[:digit:]]*\">\)Bus route [0-9]*\.[0-9]*\(.*<\/h4>\)/\1placeholder_pta_bus\2/' "${htmlname}"
      anzallroutes="$(grep -c '<h4.*>placeholder_pta_bus.*</h4>' "${htmlname}")"
      for ((u=1 ; u<=(("$anzallroutes")) ; u++)); do
       zeilennummer="$(grep -n '<h4.*>placeholder_pta_bus.*</h4>' "${htmlname}" | sed -n '1p' | grep -o '^[[:digit:]]*')"
       sed -i "${zeilennummer}s/placeholder_pta_bus/Bus route 1.${u}/" "${htmlname}"
      done

      # Änderungsdatum wird eingetragen/aktualisiert.
      moddateline="$(grep -n 'id="createdate"' "${htmlname}" | grep -o '^[[:digit:]]*')"
      echo "Zeile ${moddateline}: Datum der Änderung wird in HTML-Seitenfuss eingetragen ..."
      # Evtl. alte Zeile mit Änderungsdatum wird aus HTML-Seite gelöscht.
      sed -i '/id="moddate"/d' "${htmlname}"
      # Neue Zeile mit letztem Änderungsdatum wird eingefügt.
      sed -i '/id="createdate"/s/\(.*\)/\1\n  <p id="moddate">Letzte Änderung: '"$(date +%d.%m.%Y)"' um '"$(date +%H:%M)"' Uhr durch '"$(basename $0)"'<\/p>/' "${htmlname}"

      # Wenn das Depot eines aktiven Verkehrsgebietes geändert wurde, werden hier die Dateien aktualisiert.
      echo "Depot (./config/ptarea${depotnr}/*.cfg) wird mit dem Arbeitsverzeichnis (./config/*.cfg) abgeglichen ..."
      ./start.sh -l
      echo "Löschung der RelationID ${relid} aus pta-Dateien (OSM-Bereich) beendet."
      echo "HINWEIS: Nicht vergessen, ggf. die Relation ${relid} aus den OSM-Rohdaten zu löschen."

      exit

   ;;
   s) # Komplettieren einer neu aufgenommenen Route

      singlecheck
      
      # Variablen definieren
      realbusstop="$(grep "^${relid} " "$rbscfgfile" | cut -d" " -f2)"
      gtfsid="$(grep "^${relid} " "$rbscfgfile" | cut -f5 -d" ")"
      [ -z "$gtfsid" ] && echo "GTFSID existiert nicht in cfg-file. Skript wird abgebrochen!" && exit 1
      unspecstopline="$(grep -n "unspec${relid}stop" "${htmlname}")"
      unspecplatline="$(grep -n "unspec${relid}plat" "${htmlname}")"
      unspecrbsline="$(grep -n "unspec${relid}rbs" "${htmlname}")"
      unspecgtfsline="$(grep -n "unspec${relid}gtfs" "${htmlname}")"
      stoplinenr="$(echo "$unspecstopline" | grep -o '^[[:digit:]]*')"
      platlinenr="$(echo "$unspecplatline" | grep -o '^[[:digit:]]*')"
      rbslinenr="$(echo "$unspecrbsline" | grep -o '^[[:digit:]]*')"
      gtfslinenr="$(echo "$unspecgtfsline" | grep -o '^[[:digit:]]*')"
      
      if [ -e "./htmlfiles/osm/${relid}.html" -a -e "${htmlname}" ]; then

       # Statistik wird angepasst (Anzahl der Busrouten).
       oldagencyroutes="$(sed -n '/in OSM data:/s/.*in OSM data: \([[:digit:]]*\).*/\1/p' "${htmlname}")"
       newagencyroutes="$(cat ./config/real_bus_stops.cfg | sed '/^#/d' | sed '/^$/d' | wc -l)"
       newanzmissingroutes="$(grep 'gtfsid[12]tab' ./htmlfiles/gtfsroutes.html | wc -l)"
       if [ ! "$oldagencyroutes" == "$newagencyroutes" ]; then
        mroutesline="$(grep -ni 'id="stat_aar"' "${htmlname}" | grep -o '^[[:digit:]]*')"
        # Zusätzliche Überprüfung, falls mehrere identische Zeilen in osmroutes.html gefunden wurden.
        if [ "$(echo "$mroutesline" | wc -l)" -gt "1" ]; then
         echo "Statistikzeile konnte nicht eindeutig identifiziert werden.("$mroutesline")"
        else
         echo "Zeile ${mroutesline}: Statistik wird angepasst ..."
         sed -i ''"$mroutesline"'s/\(in OSM data: \)[[:digit:]]*/\1'"$newagencyroutes"'/' "${htmlname}"
         modified="yes"
        fi
       fi

       # Statistik wird angepasst (Anzahl der Busrouten in Prozent).
       oldmissroutesperc="$(sed -n '/are created in whole or in part/s/.* \([[:digit:]]*\)% .*/\1/p' "${htmlname}")"
       newmissroutesperc=$((100*${newagencyroutes}/${newanzmissingroutes}))
       if [ ! "$oldmissroutesperc" == "$newmissroutesperc" ]; then
        routespercline="$(grep -ni 'are created in whole or in part' "${htmlname}" | grep -o '^[[:digit:]]*')"
        # Zusätzliche Überprüfung, falls mehrere identische Zeilen in osmroutes.html gefunden wurden.
        if [ "$(echo "$routespercline" | wc -l)" -gt "1" ]; then
         echo "Statistikzeile konnte nicht eindeutig identifiziert werden.("$routespercline")"
        else
         echo "Zeile ${routespercline}: Statistik wird angepasst ..."
         sed -i ''"$routespercline"'s/[[:digit:]]*%/'"$newmissroutesperc"'%/' "${htmlname}"
         modified="yes"
        fi
       fi

       echo "Route mit der RelationID ${relid} wird bearbeitet ..."
       # Tabellenzelle mit OSM-Stops wird bearbeitet.
       anzosmstop="$(grep 'Stop [[:digit:]]*:</th>' "./htmlfiles/osm/${relid}.html" | wc -l)"
       [ -n "$unspecstopline" ] && echo "Zeile ${stoplinenr}: Die Anzahl der OSM-stops (${anzosmstop}) wird angepasst ..."
       if [ -n "$unspecstopline" -a "$anzosmstop" == "$realbusstop" ]; then
        sed -i ''"$stoplinenr"'s/^.*$/   <td class="small withcolour">Stops in OSM-route: '"${anzosmstop}"' (100%)<\/td>/' "${htmlname}"
        modified="yes"
       elif [ -n "$unspecstopline" -a ! "$anzosmstop" == "$realbusstop" ]; then
        sed -i ''"$stoplinenr"'s/^.*$/   <td class="small yellow">Stops in OSM-route: '"${anzosmstop}"' ('"$((100*$anzosmstop/$realbusstop))"'%)<\/td>/' "${htmlname}"
        modified="yes"
       fi

       # Tabellenzelle mit OSM-Platforms wird bearbeitet.
       anzosmplat="$(grep 'Platform [[:digit:]]*:</th>' "./htmlfiles/osm/${relid}.html" | wc -l)"
       [ -n "$unspecplatline" ] && echo "Zeile ${platlinenr}: Die Anzahl der OSM-platforms (${anzosmplat}) wird angepasst ..."
       if [ -n "$unspecplatline" -a "$anzosmplat" == "$realbusstop" ]; then
        sed -i ''"$platlinenr"'s/^.*$/   <td class="small withcolour">Platforms in OSM-route: '"${anzosmplat}"' (100%)<\/td>/' "${htmlname}"
        modified="yes"
       elif [ -n "$unspecplatline" -a ! "$anzosmplat" == "$realbusstop" ]; then
        sed -i ''"$platlinenr"'s/^.*$/   <td class="small yellow">Platforms in OSM-route: '"${anzosmplat}"' ('"$((100*$anzosmplat/$realbusstop))"'%)<\/td>/' "${htmlname}"
        modified="yes"
       fi

       # Tabellenzelle mit tatsächlichen Haltestellen wird bearbeitet.
       if [ -n "$unspecrbsline" ]; then
        echo "Zeile ${rbslinenr}: Die tatsächliche Anzahl der Haltestellen (${realbusstop}) wird angepasst ..."
        sed -i ''"$rbslinenr"'s/^.*$/    <td class="withcolour"><i class="fa-td fa fa-arrow-circle-o-left fa-1x"><\/i>Number of real bus stops¹ : '"$realbusstop"'<\/td>/' "${htmlname}"
        modified="yes"
       fi
       
       # Tabellenzelle mit GTFS-Verlinkungen wird bearbeitet.
       if [ -n "$unspecgtfsline" ]; then
        echo "Zeile ${gtfslinenr}: Verlinkungen werden erstellt ..."
        sed -i ''"$gtfslinenr"'s/^.*$/   <td class="osmtabgtfs"><a title="GTFS list" href="gtfs\/'"${gtfsid}"'.html#st_ar2"><i class="fa-td fa fa-list fa-1x"><\/i><\/a><a title="GTFS route (shape) on map" href="gtfs\/maps\/'"${gtfsid}"'.html"><i class="fa-td fa fa-map fa-1x"><\/i><\/a><\/td>/' "${htmlname}"
        modified="yes"
       fi

       # Änderungsdatum wird angepasst.
       if [ "$modified" == "yes" ]; then
        moddateline="$(grep -n 'id="createdate"' "${htmlname}" | grep -o '^[[:digit:]]*')"
        echo "Zeile ${moddateline}: Datum der Änderung wird in HTML-Seitenfuss eingetragen ..."
        # Evtl. alte Zeile mit Änderungsdatum wird aus HTML-Seite gelöscht.
        sed -i '/id="moddate"/d' "${htmlname}"
        # Neue Zeile mit letztem Änderungsdatum wird eingefügt.
        sed -i '/id="createdate"/s/\(.*\)/\1\n  <p id="moddate">Letzte Änderung: '"$(date +%d.%m.%Y)"' um '"$(date +%H:%M)"' Uhr durch '"$(basename $0)"'<\/p>/' "${htmlname}"
       fi

       # Wenn das Depot eines aktiven Verkehrsgebietes geändert wurde, werden hier die Dateien aktualisiert.
       echo "Depot (./config/ptarea${depotnr}/*.cfg) wird mit dem Arbeitsverzeichnis (./config/*.cfg) abgeglichen ..."
       ./start.sh -l

      else

       [ ! -e "./htmlfiles/osm/${relid}.html" ] && echo "Datei ./htmlfiles/osm/${relid}.html existiert nicht."
       [ ! -e "${htmlname}" ] && echo "Datei ${htmlname} existiert nicht."
       echo "Skript wird abgebrochen!"
       exit 1

      fi
      echo "Fertig."
      
      exit
   ;;
   *) usage
      exit 1
   ;;
  esac
done

if [ ! -e ./relmemberlist.sh ]; then
 echo "Für die Erstellung ist das Skript ./relmemberlist.sh notwendig. Skript ist nicht im Verzeichnis $PWD vorhanden. Skript wird abgebrochen!" && exit 2
fi

# Bei seperater Ausführung dieses Skriptes, muss erst noch relmem_bus_takst.lst erstellt werden (siehe auch Kommentare zur export-Variablen in start.sh).
if [ "$whichprocess" != "all" ]; then
 echo "Routen werden mit relmemberlist.sh in ein besser auswertbares Format umgeschrieben ..."
 ./relmemberlist.sh -d ./osmdata/route_bus.osm >./relmem_bus_takst.lst
 echo "Bearbeitung mit relmemberlist.sh beendet."

 # config-Dateien in Arbeitsordner kopieren
 if [ ! -e ./config/ptarea.cfg ]; then
  read -p "Bitte Gebiet angeben: " areaarg
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
   exit 1
  fi
 fi

fi

source ./config/ptarea.cfg

if [ "$whichprocess" != "all" ]; then

 currentptareapath="$(grep -i '^ptarealong=["'\'']*'"$ptarealong"'["'\'']*' ./config/*/ptarea.cfg | cut -f1 -d:)"
 currentptareadir="$(dirname "$currentptareapath")"

 echo "Überprüfung der config-Dateien ..."
 diff <(cat ./config/*.cfg) <(cat "${currentptareadir}"/*.cfg)

 if [ ! "$?" == 0 ]; then
  echo "Unterschiedliche Versionen von cfg-Dateien gefunden. Dateien werden neu in den Arbeitsordner kopiert."
  echo "Alte config-Dateien werden gesichert ..."
  zip ./backup/${ptdatumjetzt}_configfiles.zip ./config/*.cfg
  echo "Alte config-Dateien werden gelöscht ..."
  rm -vf ./config/*.cfg
  echo "Neue config-Dateien werden in Arbeitsordner kopiert ..."
  cp -vf --preserve=timestamps "${currentptareadir}"/*.cfg ./config/
  echo "Fertig."
 else
  echo "Alle Dateien sind aktuell."
 fi

fi

# Code zum Definieren des Fahrplanzeitraums wird eingebunden.
source ./config/tt_period.cfg

# Belegung der Variablen
htmlname="htmlfiles/osmroutes.html"
invroutescfg="config/invalidroutes.cfg"
relationlist="$(egrep -o 'relation id='\''[^'\'']*'\''' "$1" | sed 's/relation id='\''\(.*\)'\''/\1/')"
anzbusrel="$(cat "$1" | grep '<tag k='\''route'\'' v='\''bus'\'' />' | wc -l)"

osmdatamaster="./osmdata/route_master_bus.osm"

echo "Beginn der Erstellung der HTML-Seiten $htmlname und der OSM-Haltestellendateien durch $0. Der Vorgang kann einige Minuten dauern ..."

# Relationsnummern der Masterrouten ermitteln.
echo "Relationsnummern der Masterrouten werden ermittelt ..."
echo -n >./relmasterlist.tmp
anzfindmasterrel="$(egrep -o '<relation id=' $osmdatamaster | wc -l)"
findmasterrelationlist="$(egrep -o 'relation id='\''[^'\'']*'\''' $osmdatamaster | sed 's/relation id='\''\(.*\)'\''/\1/')"
for ((m1=1 ; m1<=(("$anzfindmasterrel")) ; m1++)); do
unset findmasterrelnumber
unset findmasterrelbereich
findmasterrelnumber="$(echo "$findmasterrelationlist" | sed -n ''$m1'p')"
findmasterrelbereich="$(sed -n '/<relation id='\'''"$findmasterrelnumber"''\''/,/<\/relation>/p' "$osmdatamaster")"
 if [ "$(echo "$findmasterrelbereich" | egrep -o 'k='\''route_master'\''.*v='\''bus'\''' | wc -l)" -gt "0" ]; then
  echo "$findmasterrelnumber" >>./relmasterlist.tmp
 fi
done
echo "Relationsnummern der Masterrouten ermitteln erfolgreich beendet."

# Backup der aktuellen HTML-Dateien anlegen.
if [ -e ./"$htmlname" ]; then
 cp ./"$htmlname" "$backupordner"/`date +%Y%m%d_%H%M`_"$(basename $htmlname)"
fi
zip "$backupordner"/`date +%Y%m%d_%H%M`_stopplatform.zip ./htmlfiles/osm/*
rm -f ./htmlfiles/osm/*

# Erster Teil der HTML-Seiten wird erstellt.

htmlkopf() {
echo "<!DOCTYPE html>"
echo "<html lang=\"de\">"
echo "<head>"
echo "  <meta content=\"text/html; charset=utf-8\" http-equiv=\"content-type\">"
echo "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
echo "  <meta name=\"robots\" content=\"nofollow\">"
echo "  <link rel=\"stylesheet\" href=\"css/fonts.css\">"
echo "  <link rel=\"stylesheet\" href=\"css/font-awesome.css\">"
echo "  <link rel=\"stylesheet\" href=\"css/style.css\">"
echo "  <script src=\"script/showall.js\"></script>"
echo "  <script src=\"script/showhidestats.js\"></script>"
echo "</head>"
echo "<body>"
echo " <div class=\"routes\"></div>"
echo "<header>"
echo "<h1>${ptareadescription}</h1>"
echo " <h2 style=\"text-align: center;\">${secondheadline}</h2>"
echo "<div class=\"headerallg\">"
echo " <p>"
echo "  <img id=\"ptastoplogo\" src=\"images/ptastop.svg\"><span>OSM</span><a href=\"stop_areas.html\">pta stop area analysis</a><br>"
[ ! "$gtfsgen" == "no" ] && echo "  <img id=\"ptagtfslogo\" src=\"images/gtfs.svg\"><span>GTFS</span><a href=\"gtfsroutes.html\">pta gtfs analysis</a>"
echo "  <a href=\"../index.html\"><img id=\"logo\" src=\"images/logo.svg\"></a>"
echo " </p>"
echo " <hr>"
echo " <p><strong>General information:</strong></p>"
}
# Seitenkopf für OSM-Haltestellendateien
htmlkopf2() {
echo "<!DOCTYPE html>"
echo "<html lang=\"de\">"
echo "<head>"
echo "  <meta content=\"text/html; charset=utf-8\" http-equiv=\"content-type\">"
echo "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
echo "  <meta name=\"robots\" content=\"nofollow\">"
echo "  <link rel=\"stylesheet\" href=\"../css/fonts.css\">"
echo "  <link rel=\"stylesheet\" href=\"../css/font-awesome.css\">"
echo "  <link rel=\"stylesheet\" href=\"../css/style.css\">"
echo "</head>"
echo "<body>"
echo " <div class=\"routes\"></div>"
echo "<header class=\"osm\">"
echo " <h1>OSM Stop/Platform-Analysis</h1>"
echo " <a href=\"../../index.html\"><img id=\"logo\" src=\"../images/logo.svg\"></a>"
echo "</header>"
echo "<main>"
}

htmlkopf >./"$htmlname"

# Überprüfungen, ob Relationen in Daten existieren.
# Die anderen Relationen (bei Takst Sjaelland z.B. 10020275/10002530) brauchen hier nicht überprüft werden. Dies wird durch start.sh geregelt.
if [ -z "$ptareafirstlevelrelid" ]; then
 echo "Hinweis: Variable ptareafirstlevelrelid ist nicht belegt."
elif [ -n "$(grep '<relation.*id=['\''\"]'"$ptareafirstlevelrelid"'['\''\"]' ./osmdata/route_master_bus.osm)" ]; then
 echo " <p><a href=\"https://www.openstreetmap.org/relation/${ptareafirstlevelrelid}\">${ptareafirstleveldesc}</a>: ${ptareafirstlevelrelid}</p>" >>./"$htmlname"
else
 echo " <p>${ptareafirstleveldesc}: Relation not found</p>" >>./"$htmlname"
fi
if [ -z "$ptareasecondlevelrelid" ]; then
 echo "Hinweis: Variable ptareasecondlevelrelid ist nicht belegt."
elif [ -n "$(grep '<relation.*id=['\''\"]'"$ptareasecondlevelrelid"'['\''\"]' ./osmdata/route_master_bus.osm)" ]; then
 echo " <p><a href=\"https://www.openstreetmap.org/relation/${ptareasecondlevelrelid}\">${ptareasecondleveldesc}</a>: ${ptareasecondlevelrelid}</p>" >>./"$htmlname"
else
 echo " <p>${ptareasecondleveldesc}: Relation not found</p>" >>./"$htmlname"
fi
if [ -z "$ptareastoprelid" ]; then
 echo "Hinweis: Variable ptareastoprelid ist nicht belegt."
elif [ -n "$(grep '<relation.*id=['\''\"]'"$ptareastoprelid"'['\''\"]' ./osmdata/stoprelation.osm)" ]; then
 echo " <p><a href=\"https://www.openstreetmap.org/relation/${ptareastoprelid}\">${ptareastopreldesc}</a>: ${ptareastoprelid}</p>" >>./"$htmlname"
else
 echo " <p>${ptareastopreldesc}: Relation not found</p>" >>./"$htmlname"
fi
echo "</div>" >>./"$htmlname"
echo " <h2>1. Bus routes:</h2>" >>./"$htmlname"
echo " <p><a href=\"https://www.openstreetmap.org/relation/${ptareabusrelid}\">${ptareabusreldesc}</a>: ${ptareabusrelid}</p>" >>./"$htmlname"
echo "</header>" >>./"$htmlname"
echo "<main>" >>./"$htmlname"
echo "<div id=\"stat\" class=\"hide\">" >>./"$htmlname"
echo " <i id=\"on\" class=\"fa-div fa fa-plus fa-1x\"></i>" >>./"$htmlname"
echo " <i id=\"off\" class=\"fa-div fa fa-minus fa-1x\"></i>" >>./"$htmlname"
echo " <h4>Statistics</h4>" >>./"$htmlname"
echo " <p>Name of the evaluated file: "$1"<br>" >>./"$htmlname"
echo "    Evaluated bus routes: ${anzbusrel}</p>" >>./"$htmlname"
if [ -e "./htmlfiles/gtfsroutes.html" -a ! "$gtfsgen" == "no" ]; then
 agencyroutes="$(cat ./config/real_bus_stops.cfg | sed '/^#/d' | sed '/^$/d' | wc -l)"
 # Folgende Zeile wird ggf. mit der Option -s geändert.
 echo " <p id=\"stat_aar\">Bus routes (${ptagencyname}) in OSM data: ${agencyroutes}<br>" >>./"$htmlname"
 anzmissingroutes="$(grep 'gtfsid[12]tab' ./htmlfiles/gtfsroutes.html | wc -l)"
 # Folgende Zeile wird ggf. mit der Option -s geändert.
 echo "    Ca. $((100*${agencyroutes}/${anzmissingroutes}))% of bus routes (${ptagencyname}) are created in whole or in part.</p>" >>./"$htmlname"
 echo " <p>Which routes are missing, see:<br>" >>./"$htmlname"
 echo "    List of <a href=\"gtfsroutes.html\">GTFS routes</a> (shapes).</p>" >>./"$htmlname"
fi
echo " <hr>" >>./"$htmlname"
echo " <p>The ten oldest routes (with check_date tag):</p>" >>./"$htmlname"
# Die zehn ältesten Routen (mit check_date-Tag) werden herausgefiltert.
echo " <p>" >>./"$htmlname"
# sortiert nach dem numerischen Inhalt (-n) des 4. Feldes (-k4). Anschliessend werden nicht benötigte Zeilen gelöscht und dann die ersten 10 Zeilen extrahiert.
oldestcheck_date="$(sort -k4 -n -t: ./relmem_bus_takst.lst | cut -d: -f1,4 | sed '/^$/d;/no_check_date/d;/^[[:alpha:]]/d' | sed 10q)"
# Datumformat wird wieder nach ISO-Standard umgeschrieben (YYYY-MM-DD).
changedateformat="$(echo "$oldestcheck_date" | sed 's/\(^.*\):\(....\)\(..\)\(..\)/\1:\2-\3-\4/')"
# Ausgabe
echo "$(echo "$changedateformat" | sed 's/\(.*\):\(.*\)/    <a href=\"https:\/\/www.openstreetmap.org\/relation\/\1\">\1<\/a> (\2)<br>/')" >>./"$htmlname"
echo " </p>" >>./"$htmlname"

echo "</div>" >>./"$htmlname"
echo "<hr>" >>./"$htmlname"
echo "<div class=\"navi\">" >>./"$htmlname"
echo " <button id=\"button\">Show all</button>" >>./"$htmlname"
echo " <a class=\"neuladen\" href=\"osmroutes.html\">Hide all</a>" >>./"$htmlname"
echo "</div>" >>./"$htmlname"
# Achtung beim Generieren neuer Zeilen nach der vorherigen Zeile. Den folgenden Kommentar beachten! Der definiert die spätere Löschung des ersten Schluss-Tags (</div>) der Klasse .masterroute. (Siehe ca. Zeilen 153 ff. und 843 ff.)
echo "<!--@ptalinedelete-->" >>./"$htmlname"

anzrel="$(echo "$relationlist" | wc -l)"

# *** Relationsliste sortieren ***

# Liste zum Sortieren. Sortiert wird nach ref-Tag. Dazu werden die RelationsID und der ref-Wert benötigt.
# Nach der Sortierung wird das in der sortierten Liste nicht mehr benötigte ref-Tag gelöscht. (Deswegen wird die zum Erkennen benötigte Zeichenkette RelID eingefügt)
# Neue Datei sortlist.tmp wird erstellt.
echo -n >./sortlist.tmp
for ((a=1 ; a<=(("$anzrel")) ; a++)); do
  unset relsortnumber
  unset relsortbereich
  relsortnumber="$(echo "$relationlist" | sed -n ''$a'p')"
  relsortbereich="$(sed -n '/<relation id='\'''"$relsortnumber"'/,/<\/relation>/p' "$1")"
  # Hier könnte man noch einbauen: Wenn ref leer, dann Namen verwenden.
  echo "$(echo "$relsortbereich" | grep '<tag k='\''ref'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/') RelID"$relsortnumber"" >>./sortlist.tmp
done
# relationlist wird neu belegt. Ist jetzt sortiert nach ref.
unset relationlist
if [ "$defrefpos" == "left" ]; then
 relationlist="$(sort -V ./sortlist.tmp | sed 's/^.*RelID\(.*$\)/\1/')"
else
 relationlist="$(sort -g ./sortlist.tmp | sed 's/^.*RelID\(.*$\)/\1/')"
fi
echo "$relationlist" >./checksortlist_"${ptareashort}".tmp
# Nächsten zwei Zeilen sind eigentlich überflüssig:
unset anzrel
anzrel="$(echo "$relationlist" | wc -l)"

for ((i=1 ; i<=(("$anzrel")) ; i++)); do

  echo "Route ${i}/${anzrel} wird analysiert ..."
  routebegin=`date +%s`

  unset relnumber
  unset relbereich
  unset routecolour
  unset refnumber
  unset networkrow
  unset extagency
  relnumber=$(echo "$relationlist" | sed -n ""$i"p")
  relbereich=$(sed -n "/<relation id=."$relnumber"/,/<\/relation>/p" "$1")
  routecolour="$(echo "$relbereich" | grep '<tag k='\''colour'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/')"
  refnumber="$(echo "$relbereich" | grep '<tag k='\''ref'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/')"
  networkrow="$(echo "$relbereich" | grep 'tag k='\''network'\''')"
  # Variable (no_ts_tag), um Verkehrsunternehmen zu lokalisieren, die nicht dem Verkehrsverbund zugehören.
  no_ts_tag=0
  for searchextagency in ${extagencies[@]}; do
   no_ts_count="$(echo "$relbereich" | egrep -ic 'tag k='\''network'\'' v='\''.*'"${searchextagency}"'.*'\''')"
   if [ "$no_ts_count" -gt "0" ]; then
    let no_ts_tag++
    [ "$no_ts_tag" == 1 ] && extagency="$searchextagency"
   fi
  done
  # Namen der OSM-Haltestellenseiten werden definiert
  htmlname2="htmlfiles/osm/${relnumber}.html"

  # *** Busrelationen werden analysiert. Zweiter Teil der HTML-Seite ($htmlname) wird erstellt. ***

  if [ $(echo "$relbereich" | grep '<tag k='\''route'\'' v='\''bus'\'' />' | wc -l) == "1" ]; then

   # Toggle-Anweisungen und Tabelle für Route-Master wird in HTML-Seite geschrieben.
   if [ ! "$refnumber" == "$busueber" ]; then
    # Hier wird das End-Tag des ersten div-Elements mit der Klasse masterroute eingefügt. Ist am einfachsten. Am Ende des Skripts wird einfach das erste End-Tag gelöscht und das allerletzte hinzugefügt.
    echo " </div>" >>./"$htmlname"
    export busueber="$refnumber"
    # Überschrift wird aus ref der normalen Route ermittelt, nicht aus ref der Masterroute.
    # Wenn nicht zum Verbund dazugehöriges Verkehrsunternehmen gefunden wird, wird der Hintergrund von h3 hell (1/3)
     if [ "$no_ts_tag" -gt "0" ]; then
      echo " <a class=\"masterueber\" href=\"#route$refnumber\"><h3 class=\"bgueberhell\">Bus $busueber<i class=\"fa-h3 fa fa-chevron-down fa-1x\"></i></h3></a>" >>./"$htmlname"
     else echo " <a class=\"masterueber\" href=\"#route$refnumber\"><h3>Bus $busueber<i class=\"fa-h3 fa fa-chevron-down fa-1x\"></i></h3></a>" >>./"$htmlname"
     fi

    echo " <div id=\"route$refnumber\" class=\"masterroute\">" >>./"$htmlname"

     # Wenn nicht zum Verbund dazugehöriges Verkehrsunternehmen gefunden wird, wird der Hintergrund von p hell (2/3)
     if [ "$no_ts_tag" -gt "0" ]; then
      echo "  <p class=\"pfeillinks bgueberhell\"><i class=\"fa-p fa fa-chevron-left fa-1x\"></i></p>" >>./"$htmlname"
     else echo "  <p class=\"pfeillinks\"><i class=\"fa-p fa fa-chevron-left fa-1x\"></i></p>" >>./"$htmlname"
     fi

     # Wenn nicht zum Verbund dazugehöriges Verkehrsunternehmen gefunden wird, wird der Hintergrund von div.mastertabhg hell (3/3)
     if [ "$no_ts_tag" -gt "0" ]; then
      echo " <div class=\"mastertabhg bgueberhell\">" >>./"$htmlname"
     else echo " <div class=\"mastertabhg\">" >>./"$htmlname"
     fi

    anzmasterrel="$(cat ./relmasterlist.tmp | wc -l)"
    # Wichtig!
    unset masterbearbeitet
    for ((m2=1 ; m2<=(("$anzmasterrel")) ; m2++)); do
      unset masterrelnumber
      unset masterrelbereich
      masterrelnumber="$(cat ./relmasterlist.tmp | sed -n ''$m2'p')"
      masterrelbereich="$(sed -n '/<relation id='\'''"$masterrelnumber"'/,/<\/relation>/p' "$osmdatamaster")"
      if [ "$(echo "$masterrelbereich" | grep -o "$relnumber" | wc -l)" == "1" -a "$masterbearbeitet" == "1" ]; then
       echo "WICHTIGER HINWEIS! Die Routen-Relation mit der ID $relnumber ist in mehreren Masterrouten vorhanden. Dies könnte ein Hinweis auf einen Fehler sein. Bitte überprüfen! (OSM-Datei: $osmdatamaster)"
      fi
      if [ "$(echo "$masterrelbereich" | grep -o "$relnumber" | wc -l)" == "1" -a ! "$masterbearbeitet" == "1" ]; then
       echo " <table class=\"mastertab\">" >>./"$htmlname"
       echo "  <tr>" >>./"$htmlname"
       echo "   <th>Master route (Bus $busueber):</th>" >>./"$htmlname"
       echo "   <td class=\"small\">RelationID: $masterrelnumber</td>" >>./"$htmlname"
       echo "   <td class=\"small\">Show on OSM: <a class=\"onlyprint\" href=\"https://www.openstreetmap.org/relation/$masterrelnumber\">https://www.openstreetmap.org/relation/$masterrelnumber</a><a href=\"https://www.openstreetmap.org/relation/$masterrelnumber\"><i class=\"fa-td fa fa-map fa-1x\"></i></a></td>" >>./"$htmlname"
       echo "   <td id=\"anzmr${masterrelnumber}\">$(echo "$masterrelbereich" | grep -o '<member type='\''relation'\''' | wc -l) routes in master route.</td>" >>./"$htmlname"
       echo "  </tr>" >>./"$htmlname"
       echo " </table>" >>./"$htmlname"
       masterbearbeitet="1"
      fi
    done

    echo " </div>" >>./"$htmlname"

   fi
   # Toggle Ende

   echo " <div id=\"rt${relnumber}\" class=\"routetab\">" >>./"$htmlname"
   echo "  <h4 id=\"h4${relnumber}\">placeholder_pta_bus<a href=\"${geofabroutesuri}\">OSMI</a>&nbsp;&nbsp;&nbsp;<a href=\"javascript:history.back()\">back</a></h4>" >>./"$htmlname"
   echo " <table id=\"$relnumber\" class=\"first\">" >>./"$htmlname"
   echo "  <tr>" >>./"$htmlname"
   echo "   <th>RelationID:</th>" >>./"$htmlname"
   echo "   <td>"$relnumber"</td>" >>./"$htmlname"
   echo "  </tr>" >>./"$htmlname"
   echo "  <tr>" >>./"$htmlname"
   if [ -n "$ptareabusrelid" ]; then
    echo "   <th>Name <span style=\"font-weight: normal;\">(green: integrated in Relation ${ptareabusrelid})</span>:</th>" >>./"$htmlname"
   else
    echo "   <th>Name:</th>" >>./"$htmlname"
   fi
   if [ "$(grep 'id='\'''"$relnumber"''\''' ./osmdata/route_busrelation.osm | wc -l)" -gt "0" ]; then
    echo "   <td class=\"withcolour\">$(echo "$relbereich" | grep '<tag k='\''name'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/' | sed 's/=&gt\;/=>/')</td>" >>./"$htmlname"
   else echo "   <td>$(echo "$relbereich" | grep '<tag k='\''name'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/' | sed 's/=&gt\;/=>/')</td>" >>./"$htmlname"
   fi
   echo "  </tr>" >>./"$htmlname"
   echo "  <tr>" >>./"$htmlname"
   echo "   <th>ref:</th>" >>./"$htmlname"
   echo "   <td>$refnumber</td>" >>./"$htmlname"
   echo "  </tr>" >>./"$htmlname"
   echo "  <tr>" >>./"$htmlname"
   echo "   <th>URL:</th>" >>./"$htmlname"
   echo "   <td><a href=\"https://www.openstreetmap.org/relation/${relnumber}\">https://www.openstreetmap.org/relation/"$relnumber"</a></td>" >>./"$htmlname"
   echo "  </tr>" >>./"$htmlname"
   echo "  <tr>" >>./"$htmlname"
   echo "   <th>colour:</th>" >>./"$htmlname"

    if [ -z "$routecolour" ]; then
     echo "   <td> - </td>" >>./"$htmlname"
    else 

     if [ $(echo "$networkrow" | egrep -i 'v='\''.*\<'"$ckeyword1"'\>|\<'"$ckeyword2"'\>.*'\''' | wc -l) -gt "0" ]; then

       if [ "$defrefpos" == "left" ]; then
        defrefsign="$(echo "$refnumber" | sed 's/\(^.\).*$/\1/')"
       elif [ "$defrefpos" == "right" ]; then
        defrefsign="$(echo "$refnumber" | sed 's/.*\(.$\)/\1/')"
       fi

       poscolorcheck=0
       semicolorcheck=0
       for colorline in "${rcolor[@]}"; do

         colorref="$(echo "$colorline" | cut -f1 -d:)"
         colorname="$(echo "$colorline" | cut -f2 -d:)"
         colorhex="$(echo "$colorline" | cut -f3 -d:)"

         # Strings werden für Überprüfungen optimiert (alle Großbuchstaben in Kleinbuchstaben umgewandelt).
         # Das stellt sicher, das z.B auch rEd in red umgewandelt wird.
         defrefsignopt="${defrefsign,,}"
         routecolouropt="${routecolour,,}"
         colorrefopt="${colorref,,}"
         colorname="${colorname,,}"
         colorhex="${colorhex,,}"

         if [ "$defrefsignopt" == "$colorrefopt" ] && ([ "$routecolouropt" == "$colorname" ] || [ "$routecolouropt" == "$colorhex" ]); then
          let poscolorcheck++
          routecolouroptend="$routecolouropt"
         elif [ "$defrefsignopt" == "$colorrefopt" ] && ([ "$routecolouropt" != "$colorname" ] || [ "$routecolouropt" != "$colorhex" ]); then
          let semicolorcheck++
          routecolouroptend="$routecolouropt"
          colorrefend="$colorref"
          colornameend="$colorname"
          colorhexend="$colorhex"
         fi

       done

       if [ "$poscolorcheck" == 1 ]; then
        echo "   <td class=\"withcolour\"> $routecolour<span class=\"routecolour\" style=\"background-color: $routecolouroptend;\">&nbsp;</span></td>" >>./"$htmlname"
       elif [ "$semicolorcheck" == 1 ]; then
        echo "   <td>Colour-value is $routecolour<span class=\"routecolour\" style=\"background-color: $routecolouroptend;\">&nbsp;</span>. But the most used value for ${colorrefend}-buses is \"${colornameend}\" or \"${colorhexend}\".</td>" >>./"$htmlname"
       else
        echo "   <td> $routecolour<span class=\"routecolour\" style=\"background-color: $routecolour;\">&nbsp;</span></td>" >>./"$htmlname"
       fi

     else
      echo "   <td> $routecolour<span class=\"routecolour\" style=\"background-color: $routecolour;\">&nbsp;</span></td>" >>./"$htmlname"
     fi

    fi

   echo "  </tr>" >>./"$htmlname"
   echo " </table>" >>./"$htmlname"

   # Hinweis auf Route, die nicht dem Verkehrsverbund angehört.
   if [ "$no_ts_tag" == "1" ]; then
    echo "  <h4>&nbsp;Comment:</h4>" >>./"$htmlname"
    echo " <table class=\"second\">" >>./"$htmlname"
    echo "  <tr>" >>./"$htmlname"
    echo "   <th style=\"font-weight: normal;\">${extagency}</th>" >>./"$htmlname"
    echo "   <td>${extagency} is not part of ${ptarealong}.</td>" >>./"$htmlname"
    echo "  </tr>" >>./"$htmlname"
    echo " </table>" >>./"$htmlname"
    echo " </div>" >>./"$htmlname"
    
   # Hinweis auf Route, die nicht dem Verkehrsverbund angehört.
   elif [ "$no_ts_tag" -gt "1" ]; then
    echo "  <h4>&nbsp;Comment:</h4>" >>./"$htmlname"
    echo " <table class=\"second\">" >>./"$htmlname"
    echo "  <tr>" >>./"$htmlname"
    echo "   <th style=\"font-weight: normal;\">Various</th>" >>./"$htmlname"
    echo "   <td>This route is not part of ${ptarealong}.</td>" >>./"$htmlname"
    echo "  </tr>" >>./"$htmlname"
    echo " </table>" >>./"$htmlname"
    echo " </div>" >>./"$htmlname"

   else

    # Hier wird der zweite Teil der Tabelle (Summary) generiert.
    echo "  <h4>&nbsp;Summary:</h4>" >>./"$htmlname"
    echo " <table id=\"sec${relnumber}\" class=\"second\">" >>./"$htmlname"

    # Zeile 1 der zweiten Tabelle:
    echo "  <tr>" >>./"$htmlname"
    echo "   <th style=\"font-weight: normal;\">Generally:</th>" >>./"$htmlname"

    if [ $(echo "$networkrow" | grep -i 'v='\''.*\<'"$ptarealong"'\>.*'\''' | wc -l) -gt "0" ]; then
     echo "   <td class=\"small withcolour\">Network: $(echo "$networkrow" | sed 's/.*v='\''\(.*\)'\''.*/\1/')</td>" >>./"$htmlname"
    elif [ $(echo "$networkrow" | grep 'tag k='\''network'\'' v='\''.*'\''' | wc -l) -gt "0" ]; then
     echo "   <td>Network: $(echo "$networkrow" | sed 's/.*v='\''\(.*\)'\''.*/\1/')</td>" >>./"$htmlname"
    else echo "   <td class=\"small yellow\">No Network-Tag</td>" >>./"$htmlname"
    fi

    if [ $(echo "$relbereich" | grep 'tag k='\''public_transport:version'\'' v='\''1'\''' | wc -l) -gt "0" ]; then
     echo "   <td class=\"small yellow\">PTv: 1</td>" >>./"$htmlname"
    elif [ $(echo "$relbereich" | grep 'tag k='\''public_transport:version'\'' v='\''2'\''' | wc -l) -gt "0" ]; then
     echo "   <td class=\"small withcolour\">PTv: 2</td>" >>./"$htmlname"
    else echo "   <td class=\"small red\">PTv: Not specified</td>" >>./"$htmlname"
    fi
    
    if [ $(echo "$relbereich" | grep 'tag k='\''check_date'\''' | wc -l) -gt "0" ]; then
     checkdatevalue="$(echo "$relbereich" | grep 'tag k='\''check_date'\'' v='\''.*'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/')"
     # Zuerst wird auf richtiges Format geprüft, dann auf die aktuelle Fahrplanperiode (tt_period.cfg). Ansonsten wird grünes Licht gegeben ;)
     if [[ ! "$checkdatevalue" == 20[1-9][0-9]-[0-1][0-9]-[0-3][0-9] ]]; then
      echo "   <td class=\"yellow\">check_date: ${checkdatevalue} (Please use the date format YYYY-MM-DD)</td>" >>./"$htmlname"
     elif [ $(echo "$checkdatevalue" | sed 's/-//g') -lt $(echo "$tt_periodbegin" | sed 's/-//g') ]; then
      echo "   <td class=\"yellow\">check_date: ${checkdatevalue} (This route has not been checked for some time.)</td>" >>./"$htmlname"
     else echo "   <td class=\"withcolour\">check_date: ${checkdatevalue}</td>" >>./"$htmlname"
     fi
    else echo "   <td>check_date: -</td>" >>./"$htmlname"
    fi
    echo "  </tr>" >>./"$htmlname"

    # Zeile 2 der zweiten Tabelle:
    echo "  <tr>" >>./"$htmlname"
    echo "   <th style=\"font-weight: normal;\">Number of stops/platforms:</th>" >>./"$htmlname"
    unset realbusstop
    unset shapeid
    unset osmstop
    unset osmplatform
    unset osmstoplist
    unset osmplatformlist
    # Zeichenkette mit Datum
    realbusstop="$(grep "$relnumber" ./config/real_bus_stops.cfg | cut -d" " -f2)"
    shapeid="$(grep "$relnumber" ./config/real_bus_stops.cfg | cut -d" " -f5)"
    # Zeichenkette ohne Datum
    realbusstopnumber="${realbusstop% (*}"

    # Mit den folgenden Variablen werden die Werte aus der mit relmemberlist.sh erstellten Zeichenketten gewonnen.
    relmember="$(./relmemberlist.sh -p $relnumber $1)"
    relmemberstops="$(echo "$relmember" | grep ':public_transport=stop_position:')"
    relmemberplatforms="$(echo "$relmember" | grep ':public_transport=platform:')"
    # Elemente mit Rolle stop/platform, die nicht PTv2-konform sind, werden herausgefiltert.
    oppositelist="$(echo "$relmember" | grep ':other:')"
    relmemberhail_and_ride="$(echo "$oppositelist" | grep ':hail_and_ride:')"

    osmstop="$(echo "$relmemberstops" | wc -l)"
    osmplatform="$(echo "$relmemberplatforms" | wc -l)"
    osm_hail_and_ride="$(echo "$relmemberhail_and_ride" | sed '/^$/d' | wc -l)"

    # osmstoplist/osmplatformlist wird für die Analyse der stops in einer stop_area benötigt.
    osmstoplist="$(echo "$relmemberstops" | cut -d: -f2)"
    osmplatformlist="$(echo "$relmemberplatforms" | cut -d: -f2)"
    
    if [ -z "$relmemberstops" ]; then
     echo "   <td class=\"small yellow\">Stops in OSM-route: 0</td>" >>./"$htmlname"
    elif [ "$(echo "$realbusstop" | sed 's/\(^.*\) .*/\1/')" == "$osmstop" ]; then
     echo "   <td class=\"small withcolour\">Stops in OSM-route: ${osmstop} (100%)</td>" >>./"$htmlname"
    elif [ -z "$realbusstop" ]; then
     # Folgende Zeile wird ggf. später mit der Option -s geändert.
     echo "   <td class=\"small unspec${relnumber}stop\">Stops in OSM-route: ${osmstop}</td>" >>./"$htmlname"
    else echo "   <td class=\"small yellow\">Stops in OSM-route: ${osmstop} ($((100*$osmstop/$realbusstopnumber))%)</td>" >>./"$htmlname"
    fi

    if [ -z "$relmemberplatforms" ]; then
     echo "   <td class=\"small yellow\">Platforms in OSM-route: 0</td>" >>./"$htmlname"
    elif [ "$(echo "$realbusstop" | sed 's/\(^.*\) .*/\1/')" == "$osmplatform" ]; then
     echo "   <td class=\"small withcolour\">Platforms in OSM-route: ${osmplatform} (100%)</td>" >>./"$htmlname"
    elif [ -z "$realbusstop" ]; then
     # Folgende Zeile wird ggf. später mit der Option -s geändert.
     echo "   <td class=\"small unspec${relnumber}plat\">Platforms in OSM-route: ${osmplatform}</td>" >>./"$htmlname"
    else echo "   <td class=\"small yellow\">Platforms in OSM-route: ${osmplatform} ($((100*$osmplatform/$realbusstopnumber))%)</td>" >>./"$htmlname"
    fi

    if [ -n "$realbusstop" ]; then

      # Zuerst wird auf richtiges Format geprüft, dann auf die aktuelle Fahrplanperiode (tt_period.cfg). Ansonsten wird grünes Licht gegeben ;)
      realbusdate="$(grep "$relnumber" ./config/real_bus_stops.cfg | cut -d" " -f3)"
      if [[ ! "$realbusdate" == 20[1-9][0-9]-[0-1][0-9]-[0-3][0-9] ]]; then
       echo "   <td class=\"yellow\"><i class=\"fa-td fa fa-arrow-circle-o-left fa-1x\"></i>Number of real bus stops¹ : $realbusstop (Program error: Invalid date format in real_bus_stops.cfg)</td>" >>./"$htmlname"
       echo "Invalid date format in real_bus_stops.cfg line $(grep -ni "$relnumber" ./config/real_bus_stops.cfg)."
      elif [ $(echo "$realbusdate" | sed 's/-//g') -lt $(echo "$tt_periodbegin" | sed 's/-//g') ]; then
       echo "   <td class=\"yellow\"><i class=\"fa-td fa fa-arrow-circle-o-left fa-1x\"></i>Number of real bus stops¹ : "$realbusstop" (Data is out of date (${realbusdate}) and may be incorrect.)</td>" >>./"$htmlname"
      else echo "   <td class=\"withcolour\"><i class=\"fa-td fa fa-arrow-circle-o-left fa-1x\"></i>Number of real bus stops¹ : "$realbusstop"</td>" >>./"$htmlname"
      fi

    else
     # Folgende Zeile wird ggf. später mit der Option -s geändert.
     echo "   <td class=\"yellow unspec${relnumber}rbs\">Number of real bus stops: Not specified</td>" >>./"$htmlname"
    fi

    echo "  </tr>" >>./"$htmlname"
    echo "  <tr>" >>./"$htmlname"
    echo "   <th style=\"font-weight: normal;\">stop/platform-Analysis/GTFS:</th>" >>./"$htmlname"
    if [ -n "$osmstoplist" ]; then
     echo "   <td class=\"@stoperrorcheck${i} small\"><a href=\"osm/${relnumber}.html#st_ar1\">Stop-analysis</a></td>" >>./"$htmlname"
    else echo "   <td class=\"small\">No stops</td>" >>./"$htmlname"
    fi
    if [ -n "$osmplatformlist" ]; then
     echo "   <td class=\"@platformerrorcheck${i} small\"><a href=\"osm/${relnumber}.html#st_ar2\">Platform-analysis</a></td>" >>./"$htmlname"
    else echo "   <td class=\"small\">No platforms</td>" >>./"$htmlname"
    fi
    if [ -n "$shapeid" -a -e "./htmlfiles/gtfs/${shapeid}.html" ]; then

      if [ -e "./htmlfiles/gtfs/maps/${shapeid}.html" ]; then
       echo "   <td class=\"osmtabgtfs\"><a title=\"GTFS list\" href=\"gtfs/${shapeid}.html#st_ar2\"><i class=\"fa-td fa fa-list fa-1x\"></i></a><a title=\"GTFS route (shape) on map\" href=\"gtfs/maps/${shapeid}.html\"><i class=\"fa-td fa fa-map fa-1x\"></i></a></td>" >>./"$htmlname"
      else
       echo "   <td class=\"osmtabgtfs\"><a title=\"GTFS list\" href=\"gtfs/${shapeid}.html#st_ar2\"><i class=\"fa-td fa fa-list fa-1x\"></i></a></td>" >>./"$htmlname"
      fi

    else 
    
      invrouteline="$(grep '^'"$relnumber"'' "$invroutescfg")"
      if [ -n "$invrouteline" ]; then
      
       invstatus="$(echo "$invrouteline" | cut -d' ' -f4)"
       if [ "$invstatus" == "1" ]; then
        echo "   <td class=\"red\">Route doesn't exist</td>" >>./"$htmlname"
       elif [ "$invstatus" == "2" ]; then
        echo "   <td class=\"red\">Route variant doesn't exist</td>" >>./"$htmlname"
       else
        echo "   <td>No GTFS</td>" >>./"$htmlname"
        echo "Fehlender oder ungültiger Status in Datei ${invroutescfg} (RelationID: ${relnumber})."
       fi
      
      else
      
       # Folgende Zeile wird ggf. später mit der Option -s geändert.
       echo "   <td class=\"unspec${relnumber}gtfs\">No GTFS</td>" >>./"$htmlname"
       echo "Route ${refnumber} (RelationID: ${relnumber}) noch nicht (vollständig) in .cfg-Datei aufgenommen oder aktualisiert."
       
      fi
     
    fi
    echo "  </tr>" >>./"$htmlname"

    # Achtung! Hier wird bei weiteren Fehlerfunden evtl. später eine komplette Tabellenzeile hinzugefügt.
    echo "  <!--@othernotes3${i}-->" >>./"$htmlname"

    # Zeile 4 der zweiten Tabelle:
    openinghours="$(echo "$relbereich" | grep 'opening_hours' | sed 's/^.*v='\''\([^'\'']*\)'\''.*$/\1/')"
    interval="$(echo "$relbereich" | grep ''\''interval'\''' | sed 's/^.*v='\''\([^'\'']*\)'\''.*$/\1/')"
    intervalcon="$(echo "$relbereich" | grep ''\''interval:conditional'\''' | sed 's/^.*v='\''\([^'\'']*\)'\''.*$/\1/')"
    duration="$(echo "$relbereich" | grep 'duration' | sed 's/^.*v='\''\([^'\'']*\)'\''.*$/\1/')"
    echo "  <tr>" >>./"$htmlname"
    echo "   <th style=\"font-weight: normal;\">Time:</th>" >>./"$htmlname"
    if [ -z "$openinghours" ]; then
     echo "   <td class=\"small\">Opening Hours: -</td>" >>./"$htmlname"
    else echo "   <td class=\"small\">Opening Hours: $openinghours <a class=\"symbol\" href=\"https://openingh.openstreetmap.de/evaluation_tool/?EXP=$openinghours\"> <i class=\"fa-td fa fa-search-plus fa-1x\"></i></a></td>" >>./"$htmlname"
    fi
    if [ -z "$interval" ]; then
     echo "   <td class=\"small\">Interval: -</td>" >>./"$htmlname"
    else 
     if [ -z "$intervalcon" ]; then
      echo "   <td class=\"small\">Interval: $interval</td>" >>./"$htmlname"
     else echo "   <td class=\"small\">Interval: $interval<br>Interval:conditional: $intervalcon</td>" >>./"$htmlname"
     fi
    fi
    if [ -z "$duration" ]; then
     echo "   <td>Duration: -</td>" >>./"$htmlname"
    else echo "   <td>Duration: $duration</td>" >>./"$htmlname"
    fi
    echo "  </tr>" >>./"$htmlname"

  # **** Analyse der stops/platforms, und Überprüfung ob diese Mitglied in einer stop_area sind. Start der Erstellung von $htmlname2. ****

  # *** Stops ***
  echo " <div class=\"stopplat\">" >>"$htmlname2"
  
  # Überschrift
  if [ "$(echo "$relbereich" | grep '<tag k='\''name'\''' | wc -l)" -gt "0" ]; then
   echo " <h4>RelationID: $relnumber - $(echo "$relbereich" | grep '<tag k='\''name'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/' | sed 's/=&gt\;/=>/') - <a href=\"${geofabstopsuri}\">OSMI</a> - <a href=\"javascript:history.back()\">back</a></h4>" >>"$htmlname2"
  else echo " <h4>RelationID: $relnumber - <a href=\"${geofabstopsuri}\">OSMI</a> - <a href=\"javascript:history.back()\">back</a></h4>" >>"$htmlname2"
  fi
  echo " <h5 id=\"st_ar1\">Stop_positions:</h5>" >>"$htmlname2"

  if [ -n "$osmstoplist" ]; then

    echo "  <table class=\"stop_plat\">" >>"$htmlname2"
    echo "  <tr>" >>"$htmlname2"
    echo "   <th> </th>" >>"$htmlname2"
    if [ -n "$ptareastopreldesc" ]; then
     echo "   <td class=\"small grey\">StopID / Member in any stop_area (green: integrated in ${ptareastopreldesc}):</td>" >>"$htmlname2"
    else
     echo "   <td class=\"small grey\">StopID / Member in any stop_area:</td>" >>"$htmlname2"
    fi
    echo "   <td class=\"small grey\">Name stop_position (if available):</td>" >>"$htmlname2"
    echo "   <td class=\"small grey\">OSM-Element:</td>" >>"$htmlname2"
    echo "   <td class=\"grey\">Tag/Role-Check:</td>" >>"$htmlname2"
    echo "  </tr>" >>"$htmlname2"

    stoperrorrolecounter=0
    stoperrorelementcounter=0
    platformerrorrolecounter=0
    har_errorelementcounter=0

    for ((g=1 ; g<=(("$osmstop")) ; g++)); do

    # *** Variablen belegen ***
    osmstoprelid="$(echo "$osmstoplist" | sed -n ''$g'p')"
    # Ermittlung des OSM-Elements für Fund in stop_areas.osm
    osmstopelement="$(echo "$relmemberstops" | cut -d: -f3 | sed -n ''$g'p')"
    # Ermittlung des Namens und des Bereichs für Fund in stop_areas.osm
    # Außerdem wird hier ein eventuell im Namen vorkommender : wieder hergestellt, der zuvor mit relmemberlist.sh wg. der Feldtrenner umgewandelt worden war.
    osmstopname="$(echo "$relmemberstops" | cut -d: -f7 | sed -n ''$g'p' | sed 's/@relmem@/:/g')"
    # Hiermit wird später ein Element auf korrekte Rolle überprüft.
    tagcheckstop="$(echo "$relmemberstops" | cut -d: -f5 | sed -n ''$g'p')"
    # Weitere Überprüfung können definiert werden (bus=yes, weitere Haltestellen, die nicht die Rolle stop haben, usw.).

    echo "  <tr>" >>"$htmlname2"
    echo "   <th style=\"font-weight: normal;\">Stop $(echo "$g"):</th>" >>"$htmlname2"

     # Ist wahr, wenn Fund in stop_areas.osm gefunden wird.
     # Außerdem wird dann weiter auf ein Vorkommen in stoprelation.osm geprüft! Wenn hier ein Fund entdeckt wird, wird die ganze Zeile grün hinterlegt.
     if [ $(grep "$osmstoprelid" ./osmdata/stop_areas.osm | wc -l) -gt "0" ]; then

        # RelationsID und Vorkommen in Stop_area parent relation wird ermittelt.
        if [ "$(grep "$osmstoprelid" ./osmdata/stoprelation.osm | wc -l)" -gt "0" ]; then
        echo "   <td class=\"small withcolour\"><a href=\"https://www.openstreetmap.org/$osmstopelement/${osmstoprelid}\">${osmstoprelid}</a> / <span style=\"font-weight: bold\">Yes</span> See: <a href=\"../stop_areas.html#$osmstopelement$osmstoprelid\">Stop area</a></td>" >>"$htmlname2"
       else echo "   <td class=\"small\"><a href=\"https://www.openstreetmap.org/$osmstopelement/${osmstoprelid}\">${osmstoprelid}</a> / <span style=\"font-weight: bold\">Yes</span> See: <a href=\"../stop_areas.html#$osmstopelement$osmstoprelid\">Stop area</a></td>" >>"$htmlname2"
       fi

       # Name des stops wird ermittelt.
       # Klasse stn_f ist für Verarbeitung mit anderen Programmen.
       if [ "$(grep "$osmstoprelid" ./osmdata/stoprelation.osm | wc -l)" -gt "0" ]; then
        echo "   <td class=\"small withcolour stn_f\">${osmstopname}</td>" >>"$htmlname2"
       else echo "   <td class=\"small stn_f\">${osmstopname}</td>" >>"$htmlname2"
       fi

       # Art des OSM-Elements (node/way/relation) wird in Datei geschrieben, und wenn es kein node ist, wird Fehler ausgegeben.
       if [ "$osmstopelement" == "node" ]; then
        if [ "$(grep "$osmstoprelid" ./osmdata/stoprelation.osm | wc -l)" -gt "0" ]; then
         echo "   <td class=\"small withcolour\">${osmstopelement}</td>" >>"$htmlname2"
        else echo "   <td class=\"small\">${osmstopelement}</td>" >>"$htmlname2"
        fi
       else echo "   <td class=\"small red\">Wrong element (${osmstopelement})! It must be a node.</td>" >>"$htmlname2"
        let stoperrorelementcounter++
       fi

       # Tag-Check
       if [ -z "$tagcheckstop" ]; then
       echo "   <td class=\"small red\">Role is wrong or missing.</td>" >>"$htmlname2"
       let stoperrorrolecounter++
       else 
        if [ "$(grep "$osmstoprelid" ./osmdata/stoprelation.osm | wc -l)" -gt "0" ]; then
         echo "   <td class=\"small withcolour\">Ok</td>" >>"$htmlname2"
        else echo "   <td class=\"small\">Ok</td>" >>"$htmlname2"
        fi
       fi

     # Ist wahr, wenn KEIN Fund in stop_areas.osm gefunden wird.
     elif [ $(grep "$osmstoprelid" ./osmdata/stop_areas.osm | wc -l) == "0" ]; then

      echo "   <td class=\"small\"><a href =\"https://www.openstreetmap.org/$osmstopelement/${osmstoprelid}\">${osmstoprelid}</a> / No</td>" >>"$htmlname2"
      # Klasse stn_f ist für Verarbeitung mit anderen Programmen.
      echo "   <td class=\"small stn_f\">${osmstopname}</td>" >>"$htmlname2"
      if [ "$osmstopelement" == "node" ]; then
       echo "   <td class=\"small\">${osmstopelement}</td>" >>"$htmlname2"
      else echo "   <td class=\"small red\">Wrong element (${osmstopelement})! It must be a node.</td>" >>"$htmlname2"
        let stoperrorelementcounter++
      fi
      # Tag-Check
      if [ -z "$tagcheckstop" ]; then
       echo "   <td class=\"small red\">Role is wrong or missing.</td>" >>"$htmlname2"
       let stoperrorrolecounter++
      else echo "   <td class=\"small\">Ok</td>"  >>"$htmlname2"
      fi

     fi

     echo "  </tr>" >>"$htmlname2"

    # Ende der for-Schleife (g)
    done

  echo " </table>" >>"$htmlname2"

    # *** Ausgabe der stops-Fehler ***

    # Mit der folgenden Variable werden role=*stop* herausgefiltert, die kein public_transport=stop_position als Tag haben.
    anzstopnotptv2="$(echo "$oppositelist"  | cut -d: -f5 | grep 'stop' | wc -l)"
    if [ "$stoperrorrolecounter" -gt "0" -o "$stoperrorelementcounter" -gt "0" -o "$anzstopnotptv2" -gt "0" ]; then

      # Platzhalter wird, wenn irgendein Fehler auftritt, durch CSS-Klasse ersetzt (else gelöscht).
      sed -i 's/@stoperrorcheck'${i}'/red/' ./"$htmlname" && \

      echo "  <table class=\"third\">" >>"$htmlname2"
      echo "    <tr>" >>"$htmlname2"
      echo "     <th>Notes on the stops:</th>" >>"$htmlname2"
      echo "    </tr>" >>"$htmlname2"
      echo "    <tr>" >>"$htmlname2"
      echo "     <td class=\"red\">" >>"$htmlname2"
       if [ "$stoperrorrolecounter" -gt "0" ]; then
        echo "      - This route is missing $stoperrorrolecounter correct role(s).<br>" >>"$htmlname2"
       fi
       if [ "$stoperrorelementcounter" -gt "0" ]; then
        echo "      - $stoperrorelementcounter wrong element(s).<br>" >>"$htmlname2"
       fi
       if [ "$anzstopnotptv2" -gt "0" ]; then
        echo "      - $anzstopnotptv2 more stop-role(s) not PTv2 compatible ($(echo "$oppositelist" | cut -d: -f2,3,5 | grep 'stop' | sed 's/\(.*\):\(.*\):.*/<a href=\"https:\/\/www.openstreetmap.org\/\2\/\1\">\1<\/a>/')). Please check this in JOSM or another program." >>"$htmlname2"
       fi
      echo "     </td>" >>"$htmlname2"
      echo "    </tr>" >>"$htmlname2"
      echo "   </table>" >>"$htmlname2"

    else sed -i 's/@stoperrorcheck'${i}' //' ./"$htmlname"

    fi
        

  else echo "<p>No stop_position in route.</p>" >>"$htmlname2"
  fi

  # *** Platforms ***

  echo " <h5 id=\"st_ar2\">Platforms:</h5>" >>"$htmlname2"

  if [ -n "$osmplatformlist" ]; then

    echo "  <table class=\"stop_plat\">" >>"$htmlname2"
    echo "  <tr>" >>"$htmlname2"
    echo "   <th> </th>" >>"$htmlname2"
    if [ -n "$ptareastopreldesc" ]; then
     echo "   <td class=\"small grey\">PlatformID / Member in any stop_area (green: integrated in ${ptareastopreldesc}):</td>" >>"$htmlname2"
    else
     echo "   <td class=\"small grey\">PlatformID / Member in any stop_area:</td>" >>"$htmlname2"
    fi
    echo "   <td class=\"small grey\">Name platform (if available):</td>" >>"$htmlname2"
    echo "   <td class=\"small grey\">OSM-Element:</td>" >>"$htmlname2"
    echo "   <td class=\"grey\">Tag/Role-Check:</td>" >>"$htmlname2"
    echo "  </tr>" >>"$htmlname2"

    for ((h=1 ; h<=(("$osmplatform")) ; h++)); do

    # *** Variablen belegen ***
    osmplatformrelid="$(echo "$osmplatformlist" | sed -n ''$h'p')"
    # Ermittlung des OSM-Elements für Fund in stop_areas.osm
    osmplatformelement="$(echo "$relmemberplatforms" | cut -d: -f3 | sed -n ''$h'p')"
    # Ermittlung des Namens
    # Außerdem wird hier ein eventuell im Namen vorkommender : wieder hergestellt, der zuvor mit relmemberlist.sh wg. der Feldtrenner umgewandelt worden war.
    osmplatformname="$(echo "$relmemberplatforms" | cut -d: -f7 | sed -n ''$h'p' | sed 's/@relmem@/:/g')"
    # Hiermit wird später ein Element auf korrekte Rolle überprüft.
    tagcheckplatform="$(echo "$relmemberplatforms" | cut -d: -f5 | sed -n ''$h'p')"
    # Es wird überprüft, ob way-Element ein area=yes hat.
    unset areacheck
    if [ "$(echo "$relmemberplatforms" | cut -d: -f8 | sed -n ''$h'p')" == "yes" ]; then
     areacheck="yes"
    fi

    # Weitere Überprüfung können definiert werden (weitere Haltestellen, die nicht die Rolle platform haben, usw.).

     echo "  <tr>" >>"$htmlname2"
     echo "   <th style=\"font-weight: normal;\">Platform $(echo "$h"):</th>" >>"$htmlname2"

     # Ist wahr, wenn Fund in stop_areas.osm gefunden wird.

     if [ "$(grep "$osmplatformrelid" ./osmdata/stop_areas.osm | wc -l)" -gt "0" ]; then

       # RelationsID und Vorkommen in Stop_area parent relation wird ermittelt.
       if [ "$(grep "$osmplatformrelid" ./osmdata/stoprelation.osm | wc -l)" -gt "0" ]; then
        echo "   <td class=\"small withcolour\"><a href=\"https://www.openstreetmap.org/$osmplatformelement/${osmplatformrelid}\">${osmplatformrelid}</a> / <span style=\"font-weight: bold\">Yes</span> See: <a href=\"../stop_areas.html#$osmplatformelement$osmplatformrelid\">Stop area</a></td>" >>"$htmlname2"
       else echo "   <td class=\"small\"><a href=\"https://www.openstreetmap.org/$osmplatformelement/${osmplatformrelid}\">${osmplatformrelid}</a> / <span style=\"font-weight: bold\">Yes</span> See: <a href=\"../stop_areas.html#$osmplatformelement$osmplatformrelid\">Stop area</a></td>" >>"$htmlname2"
       fi

       # Name der platform wird ermittelt.
       # Klasse pln_f ist für Verarbeitung mit anderen Programmen.
       if [ "$(grep "$osmplatformrelid" ./osmdata/stoprelation.osm | wc -l)" -gt "0" ]; then
        echo "   <td class=\"small withcolour pln_f\">${osmplatformname}</td>" >>"$htmlname2"
       else echo "   <td class=\"small pln_f\">${osmplatformname}</td>" >>"$htmlname2"
       fi
 
       # Art des OSM-Elements (node/way/relation) wird in Datei geschrieben.
       if [ "$(grep "$osmplatformrelid" ./osmdata/stoprelation.osm | wc -l)" -gt "0" ]; then
          if [ "$osmplatformelement" == "way" -a "$areacheck" == "yes" ]; then
           echo "   <td class=\"small withcolour\">way + area=yes</td>" >>"$htmlname2"
          else echo "   <td class=\"small withcolour\">${osmplatformelement}</td>" >>"$htmlname2"
          fi
       else
          if [ "$osmplatformelement" == "way" -a "$areacheck" == "yes" ]; then
           echo "   <td class=\"small\">way + area=yes</td>" >>"$htmlname2"
          else echo "   <td class=\"small\">${osmplatformelement}</td>" >>"$htmlname2"
          fi
       fi

       # Tag-Check
       if [ -z "$tagcheckplatform" ]; then
        echo "   <td class=\"small red\">Role is wrong or missing.</td>" >>"$htmlname2"
        let platformerrorrolecounter++
       else
        if [ "$(grep "$osmplatformrelid" ./osmdata/stoprelation.osm | wc -l)" -gt "0" ]; then
         echo "   <td class=\"small withcolour\">Ok</td>" >>"$htmlname2"
        else echo "   <td class=\"small\">Ok</td>" >>"$htmlname2"
        fi
       fi


     # Ist wahr, wenn KEIN Fund in stop_areas.osm gefunden wird.
     elif [ "$(grep "$osmplatformrelid" ./osmdata/stop_areas.osm | wc -l)" == "0" ]; then


        echo "   <td class=\"small\"><a href =\"https://www.openstreetmap.org/$osmplatformelement/${osmplatformrelid}\">${osmplatformrelid}</a> / No</td>" >>"$htmlname2"
        # Klasse pln_f ist für Verarbeitung mit anderen Programmen.
        echo "   <td class=\"small pln_f\">${osmplatformname}</td>" >>"$htmlname2"
          if [ "$osmplatformelement" == "way" -a "$areacheck" == "yes" ]; then
           echo "   <td class=\"small\">way + area=yes</td>" >>"$htmlname2"
          else echo "   <td class=\"small\">${osmplatformelement}</td>" >>"$htmlname2"
          fi
        # Tag-Check
        if [ -z "$tagcheckplatform" ]; then
         echo "   <td class=\"small red\">Role is wrong or missing.</td>" >>"$htmlname2"
         let platformerrorrolecounter++
        else echo "   <td class=\"small\">Ok</td>"  >>"$htmlname2"
        fi

     fi

     echo "  </tr>" >>"$htmlname2"

    # Ende der for-Schleife (h)
    done

  echo " </table>" >>"$htmlname2"

    # *** Ausgabe der platforms-Fehler ***

    # Mit der folgenden Variable werden role=*platform* herausgefiltert, die kein public_transport=platform als Tag haben.
    anzplatformnotptv2="$(echo "$oppositelist"  | cut -d: -f6 | grep 'platform' | wc -l)"

    if [ "$platformerrorrolecounter" -gt "0" -o "$anzplatformnotptv2" -gt "0" ]; then

      # Platzhalter wird, wenn irgendein Fehler auftritt, durch CSS-Klasse ersetzt (else gelöscht).
      sed -i 's/@platformerrorcheck'${i}'/red/' ./"$htmlname" && \

      echo "  <table class=\"third\">" >>"$htmlname2"
      echo "    <tr>" >>"$htmlname2"
      echo "     <th>Notes on the platforms:</th>" >>"$htmlname2"
      echo "    </tr>" >>"$htmlname2"
      echo "    <tr>" >>"$htmlname2"
      echo "     <td class=\"red\">" >>"$htmlname2"
       if [ "$platformerrorrolecounter" -gt "0" ]; then
        echo "      - This route is missing $platformerrorrolecounter correct role(s).<br>"  >>"$htmlname2"
       fi
       if [ "$anzplatformnotptv2" -gt "0" ]; then
        echo "      - $anzplatformnotptv2 more platform-role(s) not PTv2 compatible ($(echo "$oppositelist" | cut -d: -f2,3,6 | grep 'platform' | sed 's/\(.*\):\(.*\):.*/<a href=\"https:\/\/www.openstreetmap.org\/\2\/\1\">\1<\/a>/')). Please check this in JOSM or another program." >>"$htmlname2"
       fi
      echo "     </td>" >>"$htmlname2"
      echo "    </tr>" >>"$htmlname2"
      echo "   </table>" >>"$htmlname2"

    else sed -i 's/@platformerrorcheck'${i}' //' ./"$htmlname"

    fi

  else echo "<p>No platform in route.</p>" >>"$htmlname2"

  fi

  # **** Analyse der stops/platforms die Mitglied in einer stop_area sind. - Ende ****

  if [ "$osm_hail_and_ride" -gt "0" ]; then

    # *** Analyse der Wege mit der Rolle hail_and_ride ***
  
    echo " <h5 id=\"st_ar3\">Ways with hail_and_ride:</h5>" >>"$htmlname2"

    echo "  <table class=\"stop_plat\">" >>"$htmlname2"
    echo "  <tr>" >>"$htmlname2"
    echo "   <th> </th>" >>"$htmlname2"
    echo "   <td class=\"small grey\">WayID:</td>" >>"$htmlname2"
    echo "   <td class=\"small grey\">Position in route-relation:</td>" >>"$htmlname2"
    echo "   <td class=\"grey\">OSM-Element:</td>" >>"$htmlname2"
    echo "  </tr>" >>"$htmlname2"

    for ((r=1 ; r<=(("$osm_hail_and_ride")) ; r++)); do
     pos_har_rel="$(echo "$relmemberhail_and_ride" | cut -d: -f1 | sed -n ''$r'p')"
     osm_har_relid="$(echo "$relmemberhail_and_ride" | cut -d: -f2 | sed -n ''$r'p')"
     osmhail_and_rideelement="$(echo "$relmemberhail_and_ride" | cut -d: -f3 | sed -n ''$r'p')"

     echo "  <tr>" >>"$htmlname2"
     echo "   <th style=\"font-weight: normal;\">Way with hail_and_ride $(echo "$r"):</th>" >>"$htmlname2"
     echo "   <td class=\"small\"><a href=\"https://www.openstreetmap.org/$osmhail_and_rideelement/$osm_har_relid\">$osm_har_relid</a></td>" >>"$htmlname2"
     echo "   <td class=\"small\">$pos_har_rel</td>" >>"$htmlname2"
     if [ "$osmhail_and_rideelement" == "way" ]; then
      echo "   <td>$osmhail_and_rideelement</td>" >>"$htmlname2"
     else
      echo "   <td class=\"red\"> This element ($osmhail_and_rideelement) has role hail_and_ride. Then it must be a way.</td>" >>"$htmlname2"
      let har_errorelementcounter++
     fi
     echo "  </tr>" >>"$htmlname2"

    done

    echo "  </table>" >>"$htmlname2"

   fi

   # *** Ausgabe der Fehler der Wege mit Rolle hail_and_ride und Sonstige. ***
   # Ist extra nicht in der vorherigen Verzweigung untergebracht, um die Fehlerauswertung frei von $emptyrolecheck zu halten.

   # Hier wird final nach Rollen in allen anderen Mitgliedern einer Relation gesucht, die leer sein sollten.
   # Wichtig ist die Löschung aller leeren Zeilen. Da relmemberlist.sh mit der Zeile egrep -v ... das Ergebnis invertiert, werden auch alle Leerzeilen mit ausgegeben. Diese müssen wieder gelöscht werden um das richtige Ergebnis zu bekommen.
   emptyrolecheck="$(echo "$oppositelist" | cut -d: -f8 | sed '/^$/d' | wc -l)"

   if [ "$har_errorelementcounter" -gt "0" -o "$emptyrolecheck" -gt "0" ]; then

     # Hier wird bei einem gefundenen Fehler ein Kommentar durch eine Tabellenzeile ersetzt.
     # Zelle erstreckt sich über die ersten beiden Spalten (colspan="2").
     sed -i 's/<!--@othernotes3'${i}'-->/<tr class="othernotes"><th style="font-weight: normal;">Other notes:<\/th><td class="small red" colspan="2"><a href="osm\/'"$(basename "$htmlname2")"'#othernotes3'${i}'">Other notes<\/a><\/td><\/tr>/' ./"$htmlname" && \

     echo "  <table id=\"othernotes3${i}\" class=\"third\">" >>"$htmlname2"
     echo "    <tr>" >>"$htmlname2"
     echo "     <th>Other notes:</th>" >>"$htmlname2"
     echo "    </tr>" >>"$htmlname2"
     echo "    <tr>" >>"$htmlname2"
     echo "     <td class=\"red\">" >>"$htmlname2"
      if [ "$har_errorelementcounter" -gt "0" ]; then
       echo "      - $har_errorelementcounter non-way element with role hail_and_ride.<br>"  >>"$htmlname2"
      fi
      if [ "$emptyrolecheck" -gt "0" ]; then
       noemptyrole="$(echo "$oppositelist" | sed '/^.*:.*:.*:.*:.*:.*:.*::.*$/d')"
       noemptyrolestring="$(echo "$noemptyrole" | cut -d: -f2,3 )"
       echo "      - Others: $emptyrolecheck unknown role(s) ($(echo "$noemptyrolestring" | sed 's/\(.*\):\(.*\)/<a href=\"https:\/\/www.openstreetmap.org\/\2\/\1\">\1<\/a>/')). This role(s) must be empty."  >>"$htmlname2"
      fi
      echo "     </td>" >>"$htmlname2"
      echo "    </tr>" >>"$htmlname2"
      echo "   </table>" >>"$htmlname2"

    fi

    # Schließt div <class="stopplat"> in $htmlname2
    echo " </div>" >>"$htmlname2"

    # ***** Ende der Auswertungen für die Seite $htmlname2 *****

    # Schließt <table class="second"> in $htmlname
    echo " </table>" >>./"$htmlname"
    # Schließt <div class="routetab"> in $htmlname
    echo " </div>" >>./"$htmlname"

   fi
  fi
  
  htmlfuss2() {
   echo "</main>"
   echo " <footer>"
   echo "  <p>Hinweise:</p>"
   echo "  <p>Abkürzung ${ptareaabbr}: ${ptarealong}</p>"
   echo "  <p>Stops: Only PTv2-stops (node; public_transport=stop_position).</p>"
   echo "  <p>Platforms: Only PTv2-platforms (node, way, relation; public_transport=platform).</p>"
   echo "  <p>Diese Analyse analysiert nicht alle Bestandteile des PTv2-Schemas und ist nur als Ergänzung zu anderen Analysetools zu sehen, wie zum Beispiel den <a href=\"${geofabroutesuri}\">OSM-Inspector</a>.</p>"
   echo "  <p>Das Analyseergebnis wurde aus den Daten des Openstreetmap-Projektes gewonnen. Die Openstreetmap-Daten stehen unter der <a href=\"https://opendatacommons.org/licenses/odbl/\">ODbL-Lizenz</a>.</p>"
   echo "  <p>© OpenStreetMap contributors <a href=\"https://www.openstreetmap.org/copyright\">https://www.openstreetmap.org/copyright</a></p>"
   echo "  <p>&nbsp;</p>"
   echo "  <p id=\"createdate\">Erstellungsdatum dieser Seite: `date +%d.%m.%Y` um `date +%H\:%M` Uhr durch $(basename $0)</p>"
   echo "  <p>The Code is available on <a href=\"https://github.com/CarstenHa/pta\">https://github.com/CarstenHa/pta</a></p>"
   echo " </footer>"
   echo "</body>"
   echo "</html>"
  }

  # Dieser kleine Umweg über folgende Variable ist vorteilhaft, wenn mal eine externe Datei ausgewertet wird,
  # werden weitere Relationen (Masterrouten, etc.) nicht berücksichtigt.
  # Ansonsten könnten unvollständige HTML-Seiten erstellt werden.
  htmlcheck="$(cat "$htmlname2" 2>/dev/null)"
  if [ -n "$htmlcheck" ]; then
   # *** OSM-Haltestellenseite wird generiert ***
   htmlkopf2 >"$htmlname2"
   echo "$htmlcheck" >>"$htmlname2"
   htmlfuss2 >>"$htmlname2"
  fi

  routezeitdiff=$((`date +%s`-"$routebegin"))
  printf "Route ${i}/${anzrel} analysiert nach %02dm:%02ds.\n" $(($routezeitdiff%3600/60)) $(($routezeitdiff%60))

# Ende der for-Schleife (i)
done

# Dritter und letzter Teil der HTML-Seite wird erstellt.

htmlfuss() {
echo "</main>"
echo " <footer>"
echo "  <p>Hinweise:</p>"
echo "  <p>Abkürzung PTv: Public Transport Version</p>"
echo "  <p>Stops: Only PTv2-stops (node; public_transport=stop_position).</p>"
echo "  <p>Platforms: Only PTv2-platforms (node, way, relation; public_transport=platform).</p>"
echo "  <p>¹) Anzahl der tatsächlichen Haltestellen einer Route. Ergebnis wird nicht aus der Analyse der OSM-Daten gewonnen. Datum ist Zeitpunkt der Datenerfassung.</p>"
echo "  <p>$(echo "${extagencies[@]/%/,}" | sed 's/,$//;s/\(^.*\),\(.*\)/\1 und\2/') ist nicht Teil von ${ptarealong} und ist nicht vollständig in der Analyse erfasst.</p>"
echo "  <p>Diese Analyse analysiert nicht alle Bestandteile des PTv2-Schemas und ist nur als Ergänzung zu anderen Analysetools zu sehen, wie zum Beispiel den <a href=\"${geofabroutesuri}\">OSM-Inspector</a>.</p>"
echo "  <p>Das Analyseergebnis wurde aus den Daten des Openstreetmap-Projektes gewonnen. Die Openstreetmap-Daten stehen unter der <a href=\"https://opendatacommons.org/licenses/odbl/\">ODbL-Lizenz</a>.</p>"
echo "  <p>© OpenStreetMap contributors <a href=\"https://www.openstreetmap.org/copyright\">https://www.openstreetmap.org/copyright</a></p>"
[ ! "$gtfsgen" == "no" ] && echo "  <p>GTFS is not part of Openstreetmap. For more Information, see <a href=\"${ptaweburi}\">${ptaweburi}</a></p>"
echo "  <p>&nbsp;</p>"
echo "  <p id=\"createdate\">Erstellungsdatum dieser Seite: `date +%d.%m.%Y` um `date +%H\:%M` Uhr durch $(basename $0)</p>"
echo "  <p>The Code is available on <a href=\"https://github.com/CarstenHa/pta\">https://github.com/CarstenHa/pta</a></p>"
echo " </footer>"
echo "</body>"
echo "</html>"
}

htmlfuss >>./"$htmlname"

# Hier werden die einzelnen Tabellen durchnummeriert. Der Platzhalter wird durch die neue Zeichenkette ersetzt.
# Busrelationen
for ((u=1 ; u<=(("$anzbusrel")) ; u++)); do
 unset zeilennummer
 zeilennummer="$(grep -n '<h4.*>placeholder_pta_bus.*</h4>' "$htmlname" | sed -n '1p' | grep -o '^[[:digit:]]*')"
 sed -i "${zeilennummer}s/placeholder_pta_bus/Bus route 1.${u}\&nbsp\;\&nbsp\;\&nbsp\;/" "$htmlname"
done

# Hier wird das erste div-Element rausgenommen und das letzte hinzugefügt, welche ansonsten für das toggeln der Tabellen benötigt werden.
# Da in der Schleife immer ZUERST ein </div> eingetragen wird, muss das erste herausgenommen werden, und das letzte hinzugefügt werden.
linedelete="$(grep -n '<!--@ptalinedelete-->' "$htmlname" | sed 's/\(^.*\):.*/\1/')"
sed -i ''$linedelete','$(($linedelete+1))'d' "$htmlname"
sed -i 's/<\/main>/<\/div>\n<\/main>/' "$htmlname"

# Aufräumen
rm -f ./sortlist.tmp
mv ./relmasterlist.tmp "$backupordner"/"$ptdatumjetzt"_relmasterlist.lst
mv ./relmem_bus_takst.lst "$backupordner"/"$ptdatumjetzt"_relmem_bus_takst.lst

# Es wird auf neue bzw. gelöschte Routen überprüft (Nur bei route_bus.osm).
# Es wird die letzte Version von checksortlist*.lst aus dem Backup-Ordner mit der aktuellen Version (.tmp) verglichen.
if [ "$1" == "./osmdata/route_bus.osm" -o "$1" == "osmdata/route_bus.osm" ]; then
 echo ""
 echo "*** Routenvergleich ***"
 echo ""
 if [ -z "$(ls -t "$backupordner"/*checksortlist_"${ptareashort}".lst 2>/dev/null | sed -n '1p')" ]; then
  echo "Hinweis: Es existiert keine Datei checksortlist_${ptareashort}.lst im Backup-Ordner, die mit der aktuellen Version verglichen werden könnte."
 else
 checkbackupfile="$(ls -t "$backupordner"/*checksortlist_"${ptareashort}".lst | sed -n '1p')"
  if [ -z "$(diff "$checkbackupfile" ./checksortlist_"${ptareashort}".tmp | sort | uniq -u -f 1 | sed -n '/^[<>]/p')" ]; then
   echo "Es befinden sich gegenüber der letzten Aktualisierung keine neuen Routen in der Zusammenstellung."
   echo ""
  else 
   echo "Es gibt eine unterschiedliche Anzahl von Routen gegenüber der letzten Aktualisierung. Eine log-Datei (${ptdatumjetzt}_diffchecksortlist_${ptareashort}.log) befindet sich im Backup-Ordner."
   echo "Namen der zu vergleichenden Dateien: $checkbackupfile ($(cat "$checkbackupfile" | wc -l) Routen) ./checksortlist_${ptareashort}.tmp (${ptdatumjetzt}_checksortlist_${ptareashort}.lst) ($(cat ./checksortlist_"${ptareashort}".tmp | wc -l) Routen)"
   echo ""
     if [ "$(diff "$checkbackupfile" ./checksortlist_"${ptareashort}".tmp | sort | uniq -u -f 1 | sed -n '/^</p' | wc -l)" -gt "0" ]; then
      echo "Folgende Relationen sind gelöscht worden oder haben andere Tags erhalten:"
      diff "$checkbackupfile" ./checksortlist_"${ptareashort}".tmp | sort | uniq -u -f 1 | sed -n '/^</p' | sed 's/^< /https:\/\/www.openstreetmap.org\/relation\//'
      echo ""
     fi
     if [ "$(diff "$checkbackupfile" ./checksortlist_"${ptareashort}".tmp | sort | uniq -u -f 1 | sed -n '/^>/p' | wc -l)" -gt "0" ]; then
      echo "Folgende Relationen sind neu hinzu gekommen:"
      diff "$checkbackupfile" ./checksortlist_"${ptareashort}".tmp | sort | uniq -u -f 1 | sed -n '/^>/p' | sed 's/^> /https:\/\/www.openstreetmap.org\/relation\//'
      echo ""
     fi
  fi | tee "$backupordner"/"$ptdatumjetzt"_diffchecksortlist_"${ptareashort}".log
 fi
 mv ./checksortlist_"${ptareashort}".tmp "$backupordner"/"$ptdatumjetzt"_checksortlist_"${ptareashort}".lst
else rm -f ./checksortlist_"${ptareashort}".tmp
fi

echo "Ende der Erstellung der HTML-Seiten $htmlname und der OSM-Haltestellendateien durch $(basename $0)."
 
