#!/bin/bash

# Written by Carsten Jacob coding@langstreckentouren.de
# Script is CC0 1.0 Universell (CC0 1.0) https://creativecommons.org/publicdomain/zero/1.0/deed.de

# Ausgabe auf Standardausgabe.
# Wichtig für echo-Ausgaben. Diese müssen immer mit einem # am Zeilenanfang beginnen, wenn bei der Auswertung Zeilen gezählt werden müssen, werden alle Kommentare vorher gelöscht. Ansonsten gibt es verfälschte Ergebnisse!

# Wird nur ausgeführt, wenn Option(en) angegeben sind. Anschliessend exit. Wenn Skript ohne Optionen ausgeführt wird, wird nur der untere Teil dieses Skriptes abgearbeitet.

while getopts spd opt
do
   case "$opt" in
       s) # Überprüfungen
          if [ ! -e "$3" ]; then 
           echo "Datei $3 existiert nicht. Skript wird abgebrochen!" && exit 2
          fi
          if [ "$(grep '<relation id='\'''$2''\''' "$3" | wc -l)" == "0" ]; then 
           echo "Relation $2 existiert nicht in Datei $3. Skript wird abgebrochen!" && exit 2
          fi
          # Alle Kommentare müssen mit einem # am Zeilenanfang beginnen, damit Sie später gelöscht werden können.
          echo "# stop_positions werden aus Relation $2 ausgelesen."
          relbereich="$(sed -n '/<relation.*id='\'''"$2"''\''/,/<\/relation>/p' $3)"
          relationmemberlist="$(echo "$relbereich" | grep '<member' | sed 's/^.*ref='\''\([^'\'']*\)'\''.*$/\1/')"

          anzrelmember="$(echo "$relationmemberlist" | wc -l)"
          for ((b=1 ; b<=(("$anzrelmember")) ; b++)); do
           relationmemberlistid="$(echo "$relationmemberlist" | sed -n ''$b'p')"
           memberbereich="$(sed -n '/<.*id='\'''$relationmemberlistid''\''/,/<\/node>\|<\/way>\|<\/relation>/p' $3)"
 

          done
       ;;

       p) # Überprüfungen
          if [ ! -e "$3" ]; then 
           echo "Datei $3 existiert nicht. Skript wird abgebrochen!" && exit 2
          fi
          if [ "$(grep '<relation id='\'''$2''\''' "$3" | wc -l)" == "0" ]; then 
           echo "Relation $2 existiert nicht in Datei $3. Skript wird abgebrochen!" && exit 2
          fi
          # Alle Kommentare müssen mit einem # am Zeilenanfang beginnen, damit Sie später gelöscht werden können.
          echo "# platforms werden aus Relation $2 ausgelesen."
          relbereich="$(sed -n '/<relation.*id='\'''"$2"''\''/,/<\/relation>/p' $3)"
          relationmemberlist="$(echo "$relbereich" | grep '<member' | sed 's/^.*ref='\''\([^'\'']*\)'\''.*$/\1/')"

          anzrelmember="$(echo "$relationmemberlist" | wc -l)"
          for ((p=1 ; p<=(("$anzrelmember")) ; p++)); do
           relationmemberlistid="$(echo "$relationmemberlist" | sed -n ''$p'p')"
           memberbereich="$(sed -n '/<.*id='\'''$relationmemberlistid''\''/,/<\/node>\|<\/way>\|<\/relation>/p' $3)"
           member="$(echo "$relbereich" | grep '<member' | sed -n ''$p'p')"

           # Haltestellen (stop_position) werden ausgewertet.
           if [ "$(echo "$memberbereich" | grep -o 'k='\''public_transport'\'' v='\''stop_position'\''' | wc -l)" -gt "0" ]; then
             osmelement="$(echo "$memberbereich" | sed -n '1p' | sed 's/.*<\(node\|way\|relation\).*/\1/')"
             # Wichtig ist die Anweisung: sed -n ''$b'p', wenn eine Haltestelle doppelt in einer Route vorkommt wird genau diese Zeile gecheckt.
             stoprole="$(echo "$member" | egrep 'ref='\'''$relationmemberlistid''\''.*role='\''(stop|stop_entry_only|stop_exit_only)'\''' | sed 's/^.*role='\''\([^'\'']*\)'\''.*$/\1/')"
             kind="$(echo "$memberbereich" | egrep 'k='\''(train|light_rail|subway|tram|monorail|bus|trolleybus|aerialway|ferry)'\''' | sed 's/^.*k='\''\(.*\)'\'' v='\''yes'\''.*$/\1/')"
             # Achtung! Es wird nach Doppelpunkt im Namen gesucht und durch alternative Zeichenkette ersetzt. 
             # Das muss bei weiterer Verwendung wieder zurück umgewandelt werden!
             stopname="$(echo "$memberbereich" | grep '<tag k='\''name'\''' | sed 's/^.*k='\''name'\'' v='\''\(.*\)'\''.*$/\1/;s/:/@relmem@/g')"
             # Ausgabe ist:
             # 1. Position-number in relation
             # 2. Relation ID
             # 3. node/way/relation
             # 4. public_transport=stop_position
             # 5. role
             # 6. bus/train/tram etc.
             # 7. Value of name-tag
             echo "${p}:${relationmemberlistid}:${osmelement}:public_transport=stop_position:${stoprole}:${kind}:${stopname}:"

           # Haltestellen (platforms) werden ausgewertet.
           elif [ "$(echo "$memberbereich" | grep -o 'k='\''public_transport'\'' v='\''platform'\''' | wc -l)" -gt "0" ]; then
             osmelement="$(echo "$memberbereich" | sed -n '1p' | sed 's/.*<\(node\|way\|relation\).*/\1/')"
             # Wichtig ist die Anweisung: sed -n ''$p'p', wenn eine Haltestelle doppelt in einer Route vorkommt wird genau diese Zeile gecheckt.
             platformrole="$(echo "$member" | egrep 'ref='\'''$relationmemberlistid''\''.*role='\''(platform|platform_entry_only|platform_exit_only)'\''' | sed 's/^.*role='\''\([^'\'']*\)'\''.*$/\1/')"
              kind="$(echo "$memberbereich" | egrep 'k='\''(train|light_rail|subway|tram|monorail|bus|trolleybus|aerialway|ferry)'\''' | sed 's/^.*k='\''\(.*\)'\'' v='\''yes'\''.*$/\1/')"
             # Achtung! Es wird nach Doppelpunkt im Namen gesucht und durch alternative Zeichenkette ersetzt. 
             # Das muss bei weiterer Verwendung wieder zurück umgewandelt werden!
             platformname="$(echo "$memberbereich" | grep '<tag k='\''name'\''' | sed 's/^.*k='\''name'\'' v='\''\(.*\)'\''.*$/\1/;s/:/@relmem@/g')"
             platformarea="$(echo "$memberbereich" | grep '<tag k='\''area'\''' | sed 's/^.*k='\''area'\'' v='\''\(.*\)'\''.*$/\1/')"
             # Ausgabe ist:
             # 1. Position-number in relation
             # 2. Relation ID
             # 3. node/way/relation
             # 4. public_transport=platform
             # 5. role
             # 6. bus/train/tram etc.
             # 7. Value of name-tag
             # 8. Value of area-tag
             echo "${p}:${relationmemberlistid}:${osmelement}:public_transport=platform:${platformrole}:${kind}:${platformname}:${platformarea}:"

            else 
             # Ausgabe ist:
             # 1. Position-number in relation
             # 2. Relation ID
             # 3. node/way/relation
             # 4. other
             # 5. stop-role
             # 6. platform-role
             # 7. hail_and_ride-role
             # 8. otherrole
             otherosmelement="$(echo "$memberbereich" | sed -n '1p' | sed 's/.*<\(node\|way\|relation\).*/\1/')"
             otherstoprole="$(echo "$member" | egrep 'ref='\'''$relationmemberlistid''\''.*role='\''(stop|stop_entry_only|stop_exit_only)'\''' | sed 's/^.*role='\''\([^'\'']*\)'\''.*$/\1/')"
             otherplatformrole="$(echo "$member" | egrep 'ref='\'''$relationmemberlistid''\''.*role='\''(platform|platform_entry_only|platform_exit_only)'\''' | sed 's/^.*role='\''\([^'\'']*\)'\''.*$/\1/')"
             hail_and_ride_role="$(echo "$member" | egrep 'ref='\'''$relationmemberlistid''\''.*role='\''hail_and_ride'\''' | sed 's/^.*role='\''\([^'\'']*\)'\''.*$/\1/')"
             # egrep -v invertiert die Suche, also alles außer ...
             otherrole="$(echo "$member" | egrep 'ref='\'''$relationmemberlistid''\''' | egrep -v 'role='\''(stop|stop_entry_only|stop_exit_only|platform|platform_entry_only|platform_exit_only|hail_and_ride)'\''' | sed 's/^.*role='\''\([^'\'']*\)'\''.*$/\1/')"
             echo "${p}:${relationmemberlistid}:${otherosmelement}:other:${otherstoprole}:${otherplatformrole}:${hail_and_ride_role}:${otherrole}:"

           fi
          done
       ;;

       d) # Hier werden die Routen in ein besser auswertbares Format umgeschrieben (für stopareaanalysis2html.sh).
          # Kann für mehrere Zwecke verwendet werden. 
          # Format ist: RelationsID:ref_der Route:Member:Member:Member:usw.

          if [ -z "$1" ]; then
           echo "Es muss ein Argument mit Ziel einer auswertbaren OSM-Datei angegeben werden. Skript wird abgebrochen!" && exit 2
          fi

          echo ""
          echo "Relationen aus Datei $2 werden umgeschrieben ..."
          echo ""

          # RelationsID-Liste wird ermittelt.
          relationidlist="$(sed -n '/<relation/,/<\/relation>/p' "$2" | grep -o '<relation id='\''[[:digit:]]*'\''' | grep -o '[[:digit:]]*')"

          anzrel="$(echo "$relationidlist" | wc -l)"

          for ((a=1 ; a<=(("$anzrel")) ; a++)); do
          relbereich="$(sed -n '/<relation.*id='\'''$(echo "$relationidlist" | sed -n ''$a'p')''\''/,/<\/relation>/p' $2)"
          relationid="$(echo "$relbereich" | grep -o '<relation id='\''[[:digit:]]*'\''' | grep -o '[[:digit:]]*')"
          locateref="$(echo "$relbereich" | grep '<tag k='\''ref'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/' | sed 's/:/_/g')"
          # Beachte letzte beide sed-Befehle: Doppelpunkt wird entfernt (ist ja der Trenner) und Entity wird durch Pfeil rechts ersetzt.
          locatename="$(echo "$relbereich" | grep '<tag k='\''name'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/' | sed 's/://g' | sed 's/=&#62\;/=>/g')"
          locatemem="$(echo "$relbereich"  | grep '<member' | grep -o 'ref='\''[[:digit:]]*'\''' | sed 's/.*ref='\''\([[:digit:]]*\)'\''.*/\1/')"
          locatedate="$(echo "$relbereich" | grep 'tag k='\''check_date'\'' v='\''.*'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/')"

          # Leere Variablen werden mit einem Alternativtext belegt.
          if [ -z "$locateref" ]; then
           locateref="no_ref"
          fi
          if [ -z "$locatename" ]; then
           locatename="no_name"
          fi
          if [[ ! "$locatedate" == 20[1-9][0-9]-[0-1][0-9]-[0-3][0-9] ]]; then
           locatedate="no_check_date"
          # Wenn das Datumformat dem ISO-Standard entspricht, wird es umgeschrieben um es für die Statistik besser auswerten zu können.
          else locatedate="$(echo "$locatedate" | sed 's/-//g')"
          fi

          # Wichtig: Nicht quoten! Ausgabe soll einzeilig erfolgen!
          memberedit=$(echo $locatemem | sed 's/ /:/g')
          echo "$relationid#relmem#$locateref#relmem#$locatename#relmem#$locatedate#relmem#$memberedit" | sed 's/#relmem#/:/g'

          done

          echo ""
          echo "relmemberlist.sh beendet."
          echo ""
       ;;

   esac
done




