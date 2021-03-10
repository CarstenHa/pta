#!/bin/bash

# License: GNU Lesser General Public License v3.0
# See: http://www.gnu.org/licenses/lgpl-3.0.html
# Written by Carsten Jacob
# Please feel free to contact me coding@langstreckentouren.de
# https://github.com/CarstenHa

# Hier werden die Routen in ein besser auswertbares Format geschrieben.
# Die Datei relmem_bus_takst.lst wird später bei der Auswertung der stop_areas benötigt. Dort werden die Routen ermittelt.
echo "Routen werden mit relmemberlist.sh in ein besser auswertbares Format umgeschrieben ..."
./relmemberlist.sh -d ./osmdata/takst.osm >./relmem_bus_takst.lst
./relmemberlist.sh -d ./osmdata/takst_train.osm >./relmem_train_takst.lst
./relmemberlist.sh -d ./osmdata/takst_light_rail.osm >./relmem_light_rail_takst.lst
./relmemberlist.sh -d ./osmdata/takst_subway.osm >./relmem_subway_takst.lst
./relmemberlist.sh -d ./osmdata/takst_monorail.osm >./relmem_monorail_takst.lst
./relmemberlist.sh -d ./osmdata/takst_tram.osm >./relmem_tram_takst.lst
./relmemberlist.sh -d ./osmdata/takst_trolleybus.osm >./relmem_trolleybus_takst.lst
./relmemberlist.sh -d ./osmdata/takst_ferry.osm >./relmem_ferry_takst.lst
echo "Bearbeitung mit relmemberlist.sh beendet."

if [ ! -e ./relmem_bus_takst.lst ]; then
 echo "Die Datei relmem_bus_takst.lst ist nicht vorhanden und muss erst durch das Skript relmemberlist.sh erstellt werden. Skript wird abgebrochen!" && exit 2
fi
if [ ! -e ./relmem_train_takst.lst ]; then
 echo "Die Datei relmem_train_takst.lst ist nicht vorhanden und muss erst durch das Skript relmemberlist.sh erstellt werden. Skript wird abgebrochen!" && exit 2
fi
if [ ! -e ./relmem_light_rail_takst.lst ]; then
 echo "Die Datei relmem_light_rail_takst.lst ist nicht vorhanden und muss erst durch das Skript relmemberlist.sh erstellt werden. Skript wird abgebrochen!" && exit 2
fi
if [ ! -e ./relmem_subway_takst.lst ]; then
 echo "Die Datei relmem_subway_takst.lst ist nicht vorhanden und muss erst durch das Skript relmemberlist.sh erstellt werden. Skript wird abgebrochen!" && exit 2
fi
if [ ! -e ./relmem_monorail_takst.lst ]; then
 echo "Die Datei relmem_monorail_takst.lst ist nicht vorhanden und muss erst durch das Skript relmemberlist.sh erstellt werden. Skript wird abgebrochen!" && exit 2
fi
if [ ! -e ./relmem_tram_takst.lst ]; then
 echo "Die Datei relmem_tram_takst.lst ist nicht vorhanden und muss erst durch das Skript relmemberlist.sh erstellt werden. Skript wird abgebrochen!" && exit 2
fi
if [ ! -e ./relmem_trolleybus_takst.lst ]; then
 echo "Die Datei relmem_trolleybus_takst.lst ist nicht vorhanden und muss erst durch das Skript relmemberlist.sh erstellt werden. Skript wird abgebrochen!" && exit 2
fi
if [ ! -e ./relmem_ferry_takst.lst ]; then
 echo "Die Datei relmem_ferry_takst.lst ist nicht vorhanden und muss erst durch das Skript relmemberlist.sh erstellt werden. Skript wird abgebrochen!" && exit 2
fi

backupordner="./backup"
htmlname="htmlfiles/stop_areas.html"

echo "Beginn der Erstellung der HTML-Seite $htmlname durch $0. Der Vorgang kann einige Minuten dauern ..."

# Backup der aktuellen HTML-Datei anlegen.
if [ -e ./"$htmlname" ]; then
 cp ./"$htmlname" "$backupordner"/`date +%Y%m%d_%H%M`_"$(basename $htmlname)"
fi

# ID-Liste wird ermittelt.
stopareaidlist="$(sed -n '/<relation/,/<\/relation>/p' ./osmdata/stop_areas.osm | grep -o '<relation id='\''[[:digit:]]*'\''' | grep -o '[[:digit:]]*')"

echo -n >./stop_area_analysis.lst

# Der passende Name wird zur ID ermittelt. Dann wird eine Analyse-Datei mit Namen und der dazugehörigen ID erstellt.
anzrel="$(echo "$stopareaidlist" | wc -l)"
for ((a=1 ; a<=(("$anzrel")) ; a++)); do
stopareaname="$(sed -n '/<relation id='\'''$(echo "$stopareaidlist" | sed -n ''"$a"'p')''\''/,/<\/relation>/p' ./osmdata/stop_areas.osm | grep '<tag k='\''name'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/')"
relid="$(echo "$stopareaidlist" | sed -n "$a"p)"
echo "$stopareaname $relid" >>./stop_area_analysis.lst
done

# Weitere Variablen definieren.
# Liste wird nach Namen alphabetisch nach dänischem Alphabet sortiert. (Variable und Datei)
sortierteliste="$(cat ./stop_area_analysis.lst | LANG=da_DK.UTF-8 sort)"
echo "$sortierteliste" >./stop_area_analysis_sort.lst
# Reine RelationsID-Liste nach Sortierung.
stopareaidlistsort="$(sed 's/.* \([[:digit:]]*$\)/\1/' ./stop_area_analysis_sort.lst)"
# Anzahl der gefundenen Stop-area-Relationen (ohne die Multipoligone (platform), die auch mit in der .osm-Datei sind)
anzstopareaids="$(sed -n '/<relation/,/<\/relation>/p' ./osmdata/stop_areas.osm | grep -o 'v='\''stop_area'\''' | wc -l)"

# Hier wird die stop_area_group-Liste erstellt. Diese wird später ausgewertet um herauszufinden, welche stop_areas als Mitglieder in einer stop_area_group sind.
echo -n >./stop_area_group.lst
stopareagridlist="$(sed -n '/<relation/,/<\/relation>/p' ./osmdata/stop_area_groups.osm | grep -o '<relation id='\''[[:digit:]]*'\''' | grep -o '[[:digit:]]*')"
anzstopareagrrel="$(echo "$stopareagridlist" | wc -l)"
for ((m=1 ; m<=(("$anzstopareagrrel")) ; m++)); do
 relstopareagrnumber="$(echo "$stopareagridlist" | sed -n ''"$m"'p')"
 relstopareagrbereich="$(sed -n '/<relation.*id='\'''"$relstopareagrnumber"''\''/,/<\/relation>/p' ./osmdata/stop_area_groups.osm)"
 if [ "$(echo "$relstopareagrbereich" | grep 'v='\''stop_area_group'\''' | wc -l)" -gt "0" ]; then
  echo "rel$m $(echo "$relstopareagrbereich" | grep -o 'id='\'''"$relstopareagrnumber"''\''' | sed 's/id='\''\(.*\)'\''/\1/')" >>./stop_area_group.lst
  echo "$relstopareagrbereich" | grep '<member' | grep -o 'ref='\''[[:digit:]]*'\''' | sed 's/ref='\''\(.*\)'\''/mem'"$m"' \1/' >>./stop_area_group.lst
 fi
done

# Erster Teil der HTML-Seite wird erstellt.
echo "<!DOCTYPE html>" >./"$htmlname"

htmlkopf() {
echo "<html lang=\"de\">"
echo "<head>"
echo "  <meta content=\"text/html; charset=utf-8\" http-equiv=\"content-type\">"
echo "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
echo "  <meta name=\"robots\" content=\"nofollow\">"
echo "  <link rel=\"stylesheet\" href=\"css/fonts.css\">"
echo "  <link rel=\"stylesheet\" href=\"css/font-awesome.css\">"
echo "  <link rel=\"stylesheet\" href=\"css/style.css\">"
echo "</head>"
echo "<body>"
echo " <div class=\"stopareas\"></div>"
echo "<header>"
echo "<h1>Stop_areas - Sjælland, Lolland, Falster und Møn</h1>"
echo " <h2 style=\"text-align: center;\">(in alphabetical order)</h2>"
echo "  <div class=\"headerallg\">"
echo "   <p>"
echo "    <img id=\"ptaroutelogo\" src=\"images/ptaroute.svg\"><span>OSM</span><a href=\"takst_sjaelland.html\">pta routes analysis</a><br>"
echo "    <img id=\"ptagtfslogo\" src=\"images/gtfs.svg\"><span>GTFS</span><a href=\"gtfsroutes.html\">pta gtfs analysis</a>"
echo "    <a href=\"../index.html\"><img id=\"logo\" src=\"images/logo.svg\"></a>"
echo "   </p>"
echo "   <hr>"
echo "   <p><img class=\"routeicontrain\" src=\"images/rail-24.svg\" alt=\"Train\" title=\"Train\">Train</p>"
echo "   <p><img class=\"routeiconlightrail\" src=\"images/light_rail-24.svg\" alt=\"Light Rail\" title=\"Light Rail\">Light Rail</p>"
echo "   <p><img class=\"routeiconsubway\" src=\"images/subway-24.svg\" alt=\"Subway\" title=\"Subway\">Subway</p>"
echo "   <p><img class=\"routeiconmonorail\" src=\"images/monorail-24.svg\" alt=\"Monorail\" title=\"Monorail\">Monorail</p>"
echo "   <p><img class=\"routeicontram\" src=\"images/tram-24.svg\" alt=\"Tram\" title=\"Tram\">Tram</p>"
echo "   <p><img class=\"routeiconbus\" src=\"images/bus-24.svg\" alt=\"Bus\" title=\"Bus\">Bus</p>"
echo "   <p><img class=\"routeicontrolleybus\" src=\"images/trolleybus-24.svg\" alt=\"Trolleybus\" title=\"Trolleybus\">Trolleybus</p>"
echo "   <p><img class=\"routeiconferry\" src=\"images/ferry-24.svg\" alt=\"Ferry\" title=\"Ferry\">Ferry</p>"
echo "  </div>"
echo " <h2>1. Stop_areas:</h2>"
echo " <p>Result of the found Stop areas: $anzstopareaids</p>"
echo "</header>"
echo "<main>"
}

htmlkopf >>./"$htmlname"

# Zweiter Teil der HTML-Seite wird erstellt.
anzsortrel="$(echo "$stopareaidlistsort" | wc -l)"
for ((b=1 ; b<=(("$anzsortrel")) ; b++)); do
 unset relsortnumber
 unset relsortbereich
 unset relsortname
 relsortnumber="$(echo "$stopareaidlistsort" | sed -n ''"$b"'p')"
 relsortbereich="$(sed -n '/<relation.*id='\'''"$relsortnumber"''\''/,/<\/relation>/p' ./osmdata/stop_areas.osm)"

  # Wichtige Programmverzweigung. Hier werden nur die stop_areas abgearbeitet (also ohne Multipoligone (platform)).
  if [ "$(echo "$relsortbereich" | grep 'stop_area' | wc -l)" == "0" ]; then

   echo "Hinweis: Gefundene Relation $relsortnumber ist keine stop_area."

  else

   # Erster Teil der Tabelle wird erstellt.
   echo " <div class=\"stopareatab\">" >>./"$htmlname"
   echo "  <h4 id=\"$relsortnumber\">Stop area placeholder_staa2html<a href=\"#$relsortnumber\">Permalink</a>&nbsp;&nbsp;&nbsp;<a href=\"https://tools.geofabrik.de/osmi/?view=pubtrans_stops&lon=11.76892&lat=55.42372&zoom=8&overlays=stops_,stops_positions,stops_classic,stops_positions_not_on_ways,platforms_,platforms_nodes,platforms_ways\">OSMI</a>&nbsp;&nbsp;&nbsp;<a href=\"javascript:history.back()\">back</a></h4>" >>./"$htmlname"
 relsortname="$(echo "$relsortbereich" | grep '<tag k='\''name'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/')"
   echo " <table class=\"first\">" >>./"$htmlname"
   echo "  <tr>" >>./"$htmlname"
   echo "   <th>RelationID:</th>" >>./"$htmlname"
   echo "   <td>$relsortnumber</td>" >>./"$htmlname"
   echo "  </tr>" >>./"$htmlname"
   echo "  <tr>" >>./"$htmlname"
   echo "   <th>Name <span style=\"font-weight: normal;\">(green: integrated in TS-Stoppested-Relation)</span>:</th>" >>./"$htmlname"
   if [ -z "$relsortname" ]; then
    echo "   <td class=\"yellow\">(Name is missing.)</td>" >>./"$htmlname"
   elif [ "$(grep '<relation.*id='\'''"$relsortnumber"''\''' ./osmdata/takst_stoppested.osm | wc -l)" -gt "0" ]; then
    echo "   <td class=\"withcolour\" style=\"font-weight: bold;\">$relsortname</td>" >>./"$htmlname"
   else echo "   <td style=\"font-weight: bold;\">$relsortname</td>" >>./"$htmlname"
   fi
   echo "  </tr>" >>./"$htmlname"
   echo "  <tr>" >>./"$htmlname"
   echo "   <th>URL:</th>" >>./"$htmlname"
   echo "   <td><a href=\"https://www.openstreetmap.org/relation/$relsortnumber\">https://www.openstreetmap.org/relation/$relsortnumber</a></td>" >>./"$htmlname"
   echo "  </tr>" >>./"$htmlname"
   echo "  <tr>" >>./"$htmlname"
   echo "   <th>Member in a stop_area_group:</th>" >>./"$htmlname"
   if [ "$(cat ./stop_area_group.lst | grep "$relsortnumber" | wc -l)" -gt "0" ]; then
    identrelid="$(cat ./stop_area_group.lst | grep "$relsortnumber" | sed 's/mem\(.*\) .*$/rel\1/')"
    starrelid="$(grep "$identrelid" ./stop_area_group.lst | sed 's/'"$identrelid"' \(.*$\)/\1/')"
    echo "    <td class=\"small\"><span style=\"font-weight: bold;\">Yes</span> <a href =\"https://www.openstreetmap.org/relation/$starrelid\">$starrelid</a></td>" >>./"$htmlname"
   else echo "    <td class=\"small\">No</td>" >>./"$htmlname"
   fi
   echo "  </tr>" >>./"$htmlname"

   echo " </table>" >>./"$htmlname"

   # Zweiter Teil der Tabelle wird erstellt.
   echo "  <h4>&nbsp;Analysis results:</h4>" >>./"$htmlname"
   echo " <table class=\"second\">" >>./"$htmlname"
   echo "  <tr>" >>./"$htmlname"
   echo "   <th>Members:</th>" >>./"$htmlname"
   echo "    <td class=\"small grey\">ID:</td>" >>./"$htmlname"
   echo "    <td class=\"small grey\">OSM-Element:</td>" >>./"$htmlname"
   echo "    <td class=\"small grey\">PT-Value:</td>" >>./"$htmlname"
   echo "    <td class=\"small grey\">Role:</td>" >>./"$htmlname"
   echo "    <td class=\"grey\">Routes:</td>" >>./"$htmlname"
   echo "  </tr>" >>./"$htmlname"
   stopcounter=0
   platformcounter=0
   stationcounter=0
   incstoprolecounter=0
   incplatformrolecounter=0
   incstationrolecounter=0
   anzmember="$(echo "$relsortbereich" | grep '<member' | wc -l)"
   for ((c=1 ; c<=(("$anzmember")) ; c++)); do
    stopareamember="$(echo "$relsortbereich" | grep '<member' | sed -n ''"$c"'p')"
    stopareamemberid="$(echo "$stopareamember" | sed 's/^.*ref='\''\([^'\'']*\)'\''.*$/\1/')"
    osmelement="$(echo "$stopareamember" | sed 's/^.*type='\''\([^'\'']*\)'\''.*$/\1/')"
    osmrole="$(echo "$stopareamember" | sed 's/^.*role='\''\([^'\'']*\)'\''.*$/\1/')"
    ptvalue="$(cat osmdata/stop_areas.osm | sed -n '/<'"$osmelement"'.*id='\'''"$stopareamemberid"'/,/<\/'"$osmelement"'>/p' | grep 'k='\''public_transport'\''' | sed 's/^.*k='\''public_transport'\'' v='\''\([^'\'']*\)'\''.*$/\1/')"
    echo "  <tr id=\"$osmelement$stopareamemberid\">" >>./"$htmlname"
    echo "   <td class=\"small\"> </td>" >>./"$htmlname"
    if [ "$osmelement" == "node" ]; then
     echo "   <td class=\"small\"><a href =\"https://www.openstreetmap.org/node/$stopareamemberid\">$stopareamemberid</a></td>" >>./"$htmlname"
    elif [ "$osmelement" == "way" ]; then
     echo "   <td class=\"small\"><a href =\"https://www.openstreetmap.org/way/$stopareamemberid\">$stopareamemberid</a></td>" >>./"$htmlname"
    elif [ "$osmelement" == "relation" ]; then
     echo "   <td class=\"small\"><a href =\"https://www.openstreetmap.org/relation/$stopareamemberid\">$stopareamemberid</a></td>" >>./"$htmlname"
    fi
     # Es wird überprüft, ob ein way/relation-Element ein area=yes hat.
     unset areacheck2
     if [ "$osmelement" == "way" ]; then
      checkarea="$(cat osmdata/stop_areas.osm | sed -n '/<way.*id='\'''"$stopareamemberid"'/,/<\/way>/p' | grep 'k='\''area'\'' v='\''yes'\''' | wc -l)"
       if [ "$checkarea" -gt "0" ]; then
        areacheck2="yes"
       fi
     fi
     if [ "$osmelement" == "way" -a "$areacheck2" == "yes" ]; then
      echo "   <td class=\"small\">way + area=yes</td>" >>./"$htmlname"
     else echo "   <td class=\"small\">$osmelement</td>" >>./"$htmlname"
     fi

    if [ "$ptvalue" == "stop_position" -a "$osmrole" == "stop" ]; then
     echo "   <td class=\"small withcolour\">$ptvalue</td>" >>./"$htmlname"
     echo "   <td class=\"small withcolour\">$osmrole</td>" >>./"$htmlname"
     let stopcounter++
    elif [ "$ptvalue" == "stop_position" -a ! "$osmrole" == "stop" ]; then
     echo "   <td class=\"small withcolour\">$ptvalue</td>" >>./"$htmlname"
     echo "   <td class=\"small red\">$osmrole</td>" >>./"$htmlname"
     let incstoprolecounter++
    elif [ ! "$ptvalue" == "stop_position" -a "$osmrole" == "stop" ]; then
      if [ "$ptvalue" == "station" ]; then
       echo "   <td class=\"small withcolour\">$ptvalue</td>" >>./"$htmlname"
      else echo "   <td class=\"small\">$ptvalue</td>" >>./"$htmlname"
      fi
     echo "   <td class=\"small red\">$osmrole</td>" >>./"$htmlname"
     let incstoprolecounter++
    elif [ "$ptvalue" == "platform" -a "$osmrole" == "platform" ]; then
     echo "   <td class=\"small withcolour\">$ptvalue</td>" >>./"$htmlname"
     echo "   <td class=\"small withcolour\">$osmrole</td>" >>./"$htmlname"
     let platformcounter++
    elif [ "$ptvalue" == "platform" -a ! "$osmrole" == "platform" ]; then
     echo "   <td class=\"small withcolour\">$ptvalue</td>" >>./"$htmlname"
     echo "   <td class=\"small red\">$osmrole</td>" >>./"$htmlname"
     let incplatformrolecounter++
    elif [ ! "$ptvalue" == "platform" -a "$osmrole" == "platform" ]; then
      if [ "$ptvalue" == "station" ]; then
       echo "   <td class=\"small withcolour\">$ptvalue</td>" >>./"$htmlname"
      else echo "   <td class=\"small\">$ptvalue</td>" >>./"$htmlname"
      fi
     echo "   <td class=\"small red\">$osmrole</td>" >>./"$htmlname"
     let incplatformrolecounter++
    elif [ "$ptvalue" == "station" -a -z "$osmrole" ]; then
     echo "   <td class=\"small withcolour\">$ptvalue</td>" >>./"$htmlname"
     echo "   <td class=\"small withcolour\">$osmrole</td>" >>./"$htmlname"
     let stationcounter++
    elif [ "$ptvalue" == "station" -a ! -z "$osmrole" ]; then
     echo "   <td class=\"small withcolour\">$ptvalue</td>" >>./"$htmlname"
     echo "   <td class=\"small red\">$osmrole</td>" >>./"$htmlname"
     let incstationrolecounter++
    else 
     echo "   <td class=\"small\">$ptvalue</td>" >>./"$htmlname"
     echo "   <td class=\"small\">$osmrole</td>" >>./"$htmlname"
    fi

    # Hier wird die Datei ausgewertet, die mit relmemberlist.sh erstellt wurde.
    # Linien werden ermittelt und Link zur Hauptseite/Openstreetmap erstellt. Achtung bei Variablen routenumber*: Diese sollten "in einem Rutsch" definiert werden. Sonst wird's zu unübersichtlich ;)
    echo "   <td>" >>./"$htmlname"
    if [ "$(grep "$stopareamemberid" ./relmem_train_takst.lst | wc -l)" -gt "0" ]; then
     routenumber_train="$(grep "$stopareamemberid" ./relmem_train_takst.lst | cut -d':' -f1,2,3 | sort | uniq | sed 's/\(^.*\)[^:]*:\(.*\)[^:]*:\(.*$\)/    <div class=\"route\">\2<a href=\"https:\/\/www.openstreetmap.org\/relation\/\1\"><img class=\"routeicontrain\" src=\"images\/rail-24.svg\" alt=\"Train \/ \3 \/ (\1)\" title=\"Train \/ \3 \/ (\1)\"><\/a><\/div>/')"
     echo "$routenumber_train" >>./"$htmlname"
    fi
    if [ "$(grep "$stopareamemberid" ./relmem_light_rail_takst.lst | wc -l)" -gt "0" ]; then
     routenumber_light_rail="$(grep "$stopareamemberid" ./relmem_light_rail_takst.lst | cut -d':' -f1,2,3 | sort | uniq | sed 's/\(^.*\)[^:]*:\(.*\)[^:]*:\(.*$\)/    <div class=\"route\">\2<a href=\"https:\/\/www.openstreetmap.org\/relation\/\1\"><img class=\"routeiconlightrail\" src=\"images\/light_rail-24.svg\" alt=\"Light Rail \/ \3 \/ (\1)\" title=\"Light Rail \/ \3 \/ (\1)\"><\/a><\/div>/')"
     echo "$routenumber_light_rail" >>./"$htmlname"
    fi
    if [ "$(grep "$stopareamemberid" ./relmem_subway_takst.lst | wc -l)" -gt "0" ]; then
     routenumber_subway="$(grep "$stopareamemberid" ./relmem_subway_takst.lst | cut -d':' -f1,2,3 | sort | uniq | sed 's/\(^.*\)[^:]*:\(.*\)[^:]*:\(.*$\)/    <div class=\"route\">\2<a href=\"https:\/\/www.openstreetmap.org\/relation\/\1\"><img class=\"routeiconsubway\" src=\"images\/subway-24.svg\" alt=\"Subway \/ \3 \/ (\1)\" title=\"Subway \/ \3 \/ (\1)\"><\/a><\/div>/')"
     echo "$routenumber_subway" >>./"$htmlname"
    fi
    if [ "$(grep "$stopareamemberid" ./relmem_bus_takst.lst | wc -l)" -gt "0" ]; then
     routenumber_bus="$(grep "$stopareamemberid" ./relmem_bus_takst.lst | cut -d':' -f1,2,3 | sort | uniq | sed 's/\(^.*\)[^:]*:\(.*\)[^:]*:\(.*$\)/    <div class=\"route\"><a href=\"takst_sjaelland.html#route\2\">\2<\/a><a href=\"https:\/\/www.openstreetmap.org\/relation\/\1\"><img class=\"routeiconbus\" src=\"images\/bus-24.svg\" alt=\"Bus \/ \3 \/ (\1)\" title=\"Bus \/ \3 \/ (\1)\"><\/a><\/div>/')"
     echo "$routenumber_bus" >>./"$htmlname"
    fi
    if [ "$(grep "$stopareamemberid" ./relmem_monorail_takst.lst | wc -l)" -gt "0" ]; then
     routenumber_monorail="$(grep "$stopareamemberid" ./relmem_monorail_takst.lst | cut -d':' -f1,2,3 | sort | uniq | sed 's/\(^.*\)[^:]*:\(.*\)[^:]*:\(.*$\)/    <div class=\"route\">\2<a href=\"https:\/\/www.openstreetmap.org\/relation\/\1\"><img class=\"routeiconmonorail\" src=\"images/monorail-24.svg\" alt=\"Monorail \/ \3 \/ (\1)\" title=\"Monorail \/ \3 \/ (\1)\"><\/a><\/div>/')"
     echo "$routenumber_monorail" >>./"$htmlname"
    fi
    if [ "$(grep "$stopareamemberid" ./relmem_tram_takst.lst | wc -l)" -gt "0" ]; then
     routenumber_tram="$(grep "$stopareamemberid" ./relmem_tram_takst.lst | cut -d':' -f1,2,3 | sort | uniq | sed 's/\(^.*\):\(.*$\)/    <div class=\"route\">\2<a href=\"https:\/\/www.openstreetmap.org\/relation\/\1\"><img class=\"routeicontram\" src=\"images\/tram-24.svg\" alt=\"Tram \/ \3 \/ (\1)\" title=\"Tram \/ \3 \/ (\1)\"><\/a><\/div>/')"
     echo "$routenumber_tram" >>./"$htmlname"
    fi
    if [ "$(grep "$stopareamemberid" ./relmem_trolleybus_takst.lst | wc -l)" -gt "0" ]; then
     routenumber_trolleybus="$(grep "$stopareamemberid" ./relmem_trolleybus_takst.lst | cut -d':' -f1,2,3 | sort | uniq | sed 's/\(^.*\)[^:]*:\(.*\)[^:]*:\(.*$\)/    <div class=\"route\">\2<a href=\"https:\/\/www.openstreetmap.org\/relation\/\1\"><img class=\"routeicontrolleybus\" src=\"images\/trolleybus-24.svg\" alt=\"Trolleybus \/ \3 \/ (\1)\" title=\"Trolleybus \/ \3 \/ (\1)\"><\/a><\/div>/')"
     echo "$routenumber_trolleybus" >>./"$htmlname"
    fi
    if [ "$(grep "$stopareamemberid" ./relmem_ferry_takst.lst | wc -l)" -gt "0" ]; then
     routenumber_ferry="$(grep "$stopareamemberid" ./relmem_ferry_takst.lst | cut -d':' -f1,2,3 | sort | uniq | sed 's/\(^.*\)[^:]*:\(.*\)[^:]*:\(.*$\)/    <div class=\"route\">\2<a href=\"https:\/\/www.openstreetmap.org\/relation\/\1\"><img class=\"routeiconferry\" src=\"images\/ferry-24.svg\" alt=\"Ferry \/ \3 \/ (\1)\" title=\"Ferry \/ \3 \/ (\1)\"><\/a><\/div>/')"
     echo "$routenumber_ferry" >>./"$htmlname"
    fi
    echo "   </td>" >>./"$htmlname"

    echo "  </tr>" >>./"$htmlname"

   done


   echo " </table>" >>./"$htmlname"

   # Dritter Teil der Tabelle wird erstellt.
   echo " <table class=\"third\">" >>./"$htmlname"
   echo "  <tr>" >>./"$htmlname"
   echo "   <th>Summary:</th>" >>./"$htmlname"

   echo "    <td class=\"small withcolour\">Correct stops/platforms/station: $(echo $stopcounter)/$(echo $platformcounter)/$(echo $stationcounter)</td>" >>./"$htmlname"

   if [ "$incstoprolecounter" == "0" -a "$incplatformrolecounter" == "0" -a "$incstationrolecounter" == "0" ]; then
    echo "    <td class=\"small withcolour\">Incorrect roles: - </td>" >>./"$htmlname"
   else echo "    <td class=\"small red\">Incorrect roles: $(($incstoprolecounter+$incplatformrolecounter+$incstationrolecounter))</td>" >>./"$htmlname"
   fi

   if [ "$(grep '<relation.*id='\'''"$relsortnumber"''\''' ./osmdata/takst_stoppested.osm | wc -l)" -gt "0" ]; then
    echo "    <td class=\"withcolour\">TS integrated: <span style=\"font-weight: bold;\">Yes</span></td>" >>./"$htmlname"
   else echo "    <td class=\"yellow\">TS integrated: No</td>" >>./"$htmlname"
   fi

   echo "  </tr>" >>./"$htmlname"
   echo " </table>" >>./"$htmlname"
   echo " </div>" >>./"$htmlname"

 fi

done

# Letzter Teil der HTML-Seite wird erstellt.
htmlfuss() {
echo "</main>"
echo "<footer>"
echo "  <p>Hinweise:</p>"
echo "  <p>Abkürzung TS: Takst Sjælland</p>"
echo "  <p>Das Analyseergebnis wurde aus den Daten des Openstreetmap-Projektes gewonnen. Die Openstreetmap-Daten stehen unter der <a href=\"https://opendatacommons.org/licenses/odbl/\">ODbL-Lizenz</a>.</p>"
echo "  <p>© OpenStreetMap contributors <a href=\"https://www.openstreetmap.org/copyright\">https://www.openstreetmap.org/copyright</a></p>"
echo "  <p>&nbsp;</p>"
echo "  <p><a href=\"https://carstenha.github.io/pta/\">Repository-Website</a></p>"
echo "  <p>The Code is available on <a href=\"https://github.com/CarstenHa/pta\">https://github.com/CarstenHa/pta</a></p>"
echo "  <p>&nbsp;</p>"
echo "  <p>Erstellungsdatum dieser Seite: `date +%d.%m.%Y` um `date +%H\:%M` Uhr durch $(basename $0)</p>"
echo "</footer>"
echo "</body>"
echo "</html>"
}

htmlfuss >>./"$htmlname"

# Hier werden die einzelnen Tabellen durchnummeriert. Der Platzhalter wird durch die neue Zeichenkette ersetzt.
for ((u=1 ; u<=(("$anzstopareaids")) ; u++)); do
 unset zeilennummer
 zeilennummer="$(grep -n '<h4.*>.*placeholder_staa2html.*</h4>' "$htmlname" | sed -n '1p' | grep -o '^[[:digit:]]*')"
 sed -i ""$zeilennummer"s/placeholder_staa2html/1."$u"\&nbsp\;\&nbsp\;\&nbsp\;/" "$htmlname"
done

# aufräumen
rm -f ./stop_area_group.lst
rm -f ./stop_area_analysis.lst
mv ./stop_area_analysis_sort.lst "$backupordner"/`date +%Y%m%d_%H%M`_stop_area_analysis_sort.lst
# Bei seperater Ausführung dieses Skriptes wird relmem_bus_takst.lst in den Backupordner verschoben. Ansonsten bleibt die Datei im Verzeichnis und wird von pt_analysis2html.sh weiter genutzt und dann später in den Backupordner verschoben.
if [ "$whichprocess" != "all" ]; then
 mv ./relmem_bus_takst.lst "$backupordner"/`date +%Y%m%d_%H%M`_relmem_bus_takst.lst
fi
mv ./relmem_train_takst.lst "$backupordner"/`date +%Y%m%d_%H%M`_relmem_train_takst.lst
mv ./relmem_light_rail_takst.lst "$backupordner"/`date +%Y%m%d_%H%M`_relmem_light_rail_takst.lst
mv ./relmem_subway_takst.lst "$backupordner"/`date +%Y%m%d_%H%M`_relmem_subway_takst.lst
mv ./relmem_monorail_takst.lst "$backupordner"/`date +%Y%m%d_%H%M`_relmem_monorail_takst.lst
mv ./relmem_tram_takst.lst "$backupordner"/`date +%Y%m%d_%H%M`_relmem_tram_takst.lst
mv ./relmem_trolleybus_takst.lst "$backupordner"/`date +%Y%m%d_%H%M`_relmem_trolleybus_takst.lst
mv ./relmem_ferry_takst.lst "$backupordner"/`date +%Y%m%d_%H%M`_relmem_ferry_takst.lst

echo "Ende der Erstellung der HTML-Seite $htmlname durch $(basename $0)."

