#!/bin/bash

# License: GNU Lesser General Public License v3.0
# See: http://www.gnu.org/licenses/lgpl-3.0.html
# Written by Carsten Jacob
# Please feel free to contact me coding@langstreckentouren.de
# https://github.com/CarstenHa

backupordner="./backup"
relationid="10020274"

# ID-Liste wird ermittelt.
stoplist="$(sed -n '/<relation id='\'''"$relationid"''\''/,/<\/relation>/p' ./osmdata/takst_stoppested.osm | grep -o 'ref=.[[:digit:]]*.' | grep -o '[[:digit:]]*')"
echo -n >./stop_area.lst
echo -n >./osmfilemiddle.txt

# Der passende Name wird zur ID ermittelt. Dann wird eine Datei mit Namen und der dazugehörigen ID erstellt.
anzrel="$(echo "$stoplist" | wc -l)"
for ((a=1 ; a<=(("$anzrel")) ; a++)); do
stopareaname="$(sed -n '/<relation id='\'''$(echo "$stoplist" | sed -n ''"$a"'p')''\''/,/<\/relation>/p' ./osmdata/takst_stoppested.osm | grep '<tag k='\''name'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/')"
relid="$(echo "$stoplist" | sed -n "$a"p)"
echo "$stopareaname $relid" >>./stop_area.lst
done

# Liste wird nach Namen alphabetisch nach dänischem Alphabet sortiert. (Variable und Datei)
sortierteliste="$(cat ./stop_area.lst | LANG=da_DK.UTF-8 sort)"
echo "$sortierteliste" >./stop_area_sort.lst

# Die nun sortierten IDs werden in XML-Code geschrieben.
anzzeilen="$(echo "$sortierteliste" | wc -l)"
for ((b=1 ; b<=(("$anzzeilen")) ; b++)); do
echo "   <member type='relation' ref='$(echo "$sortierteliste" | sed -n ''"$b"'p' | grep -o '[[:digit:]]*')' role='' />" >>./osmfilemiddle.txt
done

# Der obere und untere UNGEÄNDERTE Teil der OSM-Datei wird ermittelt.
echo "$(sed -n '1,/<relation id='\'''"$relationid"''\''/p' ./osmdata/takst_stoppested.osm)" >./osmfilehead.txt
echo "$(sed -n '/<relation id='\'''"$relationid"''\''/,$p' ./osmdata/takst_stoppested.osm)" >./osmfilefoot.txt

# Die alten Mitglieder der Relation werden aus dem Fussteil gelöscht.
sed -i '1d' ./osmfilefoot.txt
while [ -n "$(sed -n '1p' ./osmfilefoot.txt | grep '<member ')" ]; do
 sed -i '1d' ./osmfilefoot.txt
done

# Neue Datei mit sortierter Relation wird erstellt.
cat ./osmfilehead.txt ./osmfilemiddle.txt ./osmfilefoot.txt >./osmdata/takst_stoppested_sort.osm

# Falls die Relation noch nicht auf action='modify' gesetzt ist, wird dieses nun gemacht. Jetzt kann die Datei mit JOSM hochgeladen werden.
if [ -z "$(grep 'relation id='\'''"$relationid"''\''.*action=.modify.' ./osmdata/takst_stoppested_sort.osm)" ]; then
 sed -i 's/relation id='\'''"$relationid"''\''/relation id='\'''"$relationid"''\'' action='\''modify'\''/' ./osmdata/takst_stoppested_sort.osm
fi

# Diff wird angezeigt.
echo ""
echo "Vorgenommene Änderungen:"
echo ""
diff ./osmdata/takst_stoppested.osm ./osmdata/takst_stoppested_sort.osm | tee "$backupordner"/`date +%Y%m%d_%H.%M`_takst_stoppested_diff.lst
echo ""
echo "$(sed -n '/<relation id='\'''"$relationid"''\''/,/<\/relation>/p' ./osmdata/takst_stoppested.osm | grep '<member' | wc -l) Mitglieder in takst_stoppested.osm"
echo "$(sed -n '/<relation id='\'''"$relationid"''\''/,/<\/relation>/p' ./osmdata/takst_stoppested_sort.osm | grep '<member' | wc -l) Mitglieder in takst_stoppested_sort.osm"
echo ""

# aufräumen
rm -f ./osmfilehead.txt ./osmfilemiddle.txt ./osmfilefoot.txt
mv ./stop_area.lst "$backupordner"/`date +%Y%m%d_%H.%M`_stop_area.lst
mv ./stop_area_sort.lst "$backupordner"/`date +%Y%m%d_%H.%M`_stop_area_sort.lst
