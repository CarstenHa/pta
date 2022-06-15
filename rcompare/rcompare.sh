#!/bin/bash

# License: GNU Lesser General Public License v3.0
# See: http://www.gnu.org/licenses/lgpl-3.0.html
# Written by Carsten Jacob
# Please feel free to contact me coding@langstreckentouren.de
# https://github.com/CarstenHa

# Anmerkungen zur Option -g
# Grundsätzlich werden die Routen anhand ihrer identischen Start-/Endhaltestellen und der Anzahl der Stops durch die shapetable ausgewertet (In shapetable yes|no@yes|no)
# Die shapetable ist eine virtuelle Tabelle, in welcher die Auswertungsergebnisse der entsprechenden Route mit allen Routenvarianten eingetragen werden.
# Der Inhalt der Shapetable wird auch später in formatierter Form auf der Ausgabe sichtbar.
# Zur besseren Nachvollziehbarkeit sind die einzelnen Schritte der Auswertung gekennzeichnet, die hier kurz beschrieben werden:
# Vorgang A1: Einfachste Form der Auswertung.
#			  Einfacher Fund mit Übereinstimmung der Start- und Endhaltestelle.
# Vorgang A2: Wenn beim Vorgang A1 keine dauerhaften Verkehrstage ermittelt wurden,
#			  werden hier zunächst alle Start-/Endhaltestellen der shapetable mit der Levenshtein-Methode
#			  auf Ähnlichkeiten zu den alten Haltestellennamen gecheckt.
#			  danach werden (bei einem positiven Fund) die anderen Haltestellennamen, die Anzahl der Haltestellen sowie 
#			  auf dauerhafte Verkehrstage gecheckt und ggf. Angaben geändert.
#			  Hier wird nicht wie zum Beispiel beim Vorgang L1 (no@yes) die Prozentuale Änderung
#			  sowie die Mindestanzahl der Zwischenhalte berücksichtigt.
# Vorgang B1: Zweit-einfachste Form der Auswertung
#			  Mehrere yes@*-Funde und ein yes@yes-Fund.
#			  Haltestellennamen stimmen überein und dauerhafte Verkehrstage wurden ermittelt.
# Vorgang R1: (Bei einer gefundenen yes@yes-Zeile)
#			  Haltestellennamen stimmen überein aber es gibt keine dauerhaften Verkehrstage.
#			  Die gesamte shapetable-Tabelle wird nach EINEM! Fund von dauerhaften Verkehrstagen analysiert.
#			  Haltestellenänderungen (Anzahl) werden berücksichtigt, da die gesamte shapetable analysiert wird und ggf. angepasst.
# Vorgang T1: (Bei einer gefundenen yes@yes-Zeile)
#			  Wenn Haltestellennamen nicht übereinstimmen, wird nach indentischem trip_headsign in den alten und neuen GTFS-Daten gesucht.
#			  Es werden alle shapetable-Zeilen analysiert und bei EINEM Fund von trip_headsign geändert.
#			  Haltestellenänderungen (Anzahl) werden berücksichtigt und ggf. angepasst.
# Vorgang T2: Wenn es mehrere Funde von trip_headsign gibt, wird die ursprüglich gefundene yes@yes Zeile geändert, wenn:
#			  - dauerhafte Verkehrstage ermittelt wurden
#			  - und die yes@yes-ShapeID das gleiche trip_headsign wie die alte Route hat.
#			  Haltestellenänderungen (Anzahl) werden nicht berücksichtigt (da yes@yes).
# Vorgang V1: Ist eine weitere Überprüfung, wenn T2 keine dauerhaften Verkehrstage hat.
#			  Dann wird die Route mit gleichem trip_headsign und dauerhaften Verkehrstagen (bei nur einer gefundenen Übereinstimmung) genommen.
#			  Hier wird auch wieder die evtl. unterschiedliche Anzahl der Haltestellen berücksichtigt.
#			  Bei mehreren gefundenen yes@yes-Zeilen:
# Vorgang H1: Es werden nur Zeilen geändert, wenn EIN Fund mit gleichnamigen Haltestellen und dauerhaften Verkehrstagen gefunden wurde.
# Vorgang HM: danach werden Zeilen geändert, wenn es mehrere Funde mit gleichnamigen Haltestellen und EINEN Fund mit dauerhaften Verkehrstagen gefunden wurde.
# Vorgang HU: danach werden Zeilen geändert mit unterschiedlichen Haltestellennamen und dauerhaften Verkehrstagen
# sonst greift
# Vorgang N1:
#			  Die gesamte shapetable-Tabelle wird nach EINEM! Fund von dauerhaften Verkehrstagen analysiert.
#			  Haltestellenänderungen (Anzahl) werden berücksichtigt, da die gesamte shapetable analysiert wird und ggf. angepasst.
# Vorgang M1: (Bei mehreren gefundenen yes@no-Zeilen)
#			  Da Haltestellennamen nicht übereinstimmen können und wenn dann nicht eindeutig ein Fund mit dauerhaften Verkehrstagen ermittelt werden konnte, wird
#			  die gesamte shapetable auf EINEN Fund mit gleichem trip_headsign untersucht (alte <=> neue GTFS-Daten)
#			  Haltestellenänderungen (Anzahl) werden berücksichtigt und ggf. angepasst.
# Vorgang L1: (bei gefundenen no@yes-Zeilen)
#			  Die Haltestellennamen der Start-/Endhaltestelle werden nach der Levenshtein-Methode auf Ähnlichkeiten geprüft.
#			  Es werden bei gewisser Ähnlichkeit nur Treffer mit dauerhaften Verkehrstagen geändert.
#			  Anzahl der Haltestellen wird nicht geändert, da no@yes

# Weitere Ideen:
# gtfsanalyzer-logdateien auf fehlermeldung durchsuchen (Wenn z.B. ShapeID nicht mehr existiert.
# fehlerdatei in $0 -s einbauen (Überprüfung auf doppelte shape_id usw.)
# Hilfe vervollständigen
# -a Backup der Dateien (mit touch; lernen eintragen; zipordner nicht vergessen zu erstellen.)
# errorcode bei Option -s ???
# Option -g: Existenz der Dateien im Ordner oldgtfs prüfen
# Option -g: Ist mail schon eingebaut?

if [ -z "$(type -p gtfsanalyzer)" ]; then
 echo "Das Programm gtfsanalyzer ist nicht installiert. Skript wird abgebrochen!"
 exit 1
fi

# ***** Funktion -h *****
usage() {
cat <<EOH
 
Skript zur Analyse und Auswertung einer .cfg-Datei (real_bus_stops.cfg) inklusive OSM- und GTFS-Routenvergleich.
Außerdem werden GTFS-Daten ausgewertet und durch entsprechende HTML-Dateien visualisiert.
Dieses Programm ist eine Erweiterung von pta (https://github.com/carstenha/pta)

Syntax:

	$0 [option]
	$0 [option] [NUM]
	
Beispiel (für einen kompletten Durchlauf):
	
	$0 -dga -m no 1
	
Mit den Optionen -dga -m no [NUM] startet man einen kompletten Durchlauf zur Aktualisierung einer config-Datei.
Es sind zwischen den einzelnen Arbeitsschritten "Sollbruchstellen" eingebaut. Bei Fehlerfunden wird die weitere
Bearbeitung abgebrochen. Wichtig ist zu Beginn das Löschen der Arbeitsordner, damit nicht eventuell auf veraltete
Analysedateien zurückgegriffen werden kann.
Die meisten Optionen (a,g,l,m,s) benötigen am Ende der Syntax eine Nummer für einen config-Ordner
(1 für ../config/ptarea1, 2 für ../config/ptarea2, usw.). Siehe Beispiel oben.
Es wird immer die config-Datei im jeweiligen Depot (../config/ptarea1, ../config/ptarea2, usw.) bearbeitet
und nicht im Arbeitsverzeichnis (../config).
Die config-Datei muss auch nicht zusätzlich manuell in den Arbeitsordner (../config) kopiert werden.
Dies übernehmen später die jeweiligen Skripte (pt_analysis2html.sh, usw.) selbstständig.
Zur Zeit existieren folgende config-Ordner und eingebundene Gebiete:

NUM:  Ordner:             Gebiete:
$(for gebiete in ../config/ptarea[0-9]; do echo "$(echo "$gebiete" | grep -o '[[:digit:]]*$')     $gebiete   $(sed -n 's/^ptarealong=["'\'']*\([^"'\'']*\)["'\'']*$/\1/p' "${gebiete}/ptarea.cfg" 2>/dev/null)"; done)

Beschreibung der einzelnen Optionen:

   -a [NUM]

	Wertet eine komplette cfg-Datei aus. Die gefundenen Fehler werden in eine globale Datei geschrieben.
	Weitere Analysedateien befinden sich im Unterordner ./results (Auch die Analysedateien von gtfsanalyzer).
	Bei allen Routen mit übereinstimmender Haltestellenanzahl (OSM <=> GTFS) wird das Datum in der cfg-Datei aktualisiert.
	Bei ungleicher Haltestellenanzahl wird jeweils eine GPX-Datei erstellt (OSM und GTFS). 
	Diese Dateien befinden sich ebenfalls im Unterordner ./results.
	Ansonsten wird nur für die GTFS-Daten eine GPX-Datei erstellt, die für den HTML-Gebrauch noch angepasst wird.

   -d

	löscht den Inhalt der Arbeitsordner:
	./results/*.*
	./gtfsdata/gpx/*.*
	./gtfsdata/results/*.*

   -g [NUM]

	Mit der Option -g werden die ShapeIDs (GTFS) aus der .cfg-Datei ausgewertet und ggf. aktualisiert. 
	Außerdem wird, wenn nur eine passende ShapeID gefunden wurde, ggf. die Anzahl der Haltestellen geändert.
	Alle anderen Inhalte in der .cfg-Datei bleiben unberührt.
	Diese Option ist dafür gedacht, wenn neue GTFS-Daten vorliegen. Anschließend muss dann dieses Skript noch 
	mit der Option -a ausgeführt werden.

   -l [NUM]

	listet RelationIDs auf, die noch nicht in cfg-Datei erfasst sind.

   -m [all|no|NUM|check] [NUM]

	erstellt eine Liste der GTFS-Routen (shapes). Eine kurze Beschreibung der Parameter:
	[all] - listet alle Routenvarianten in Form einer detaillierten Tabelle auf.
	        Diese werden mit einer Liste der Haltestellen und einer Mapansicht komplettiert.
	[no]  - listet alle Routenvarianten in einer einfachen Auflistung ohne Liste der Haltestellen
	        und einer Mapansicht auf.
	[NUM] - Wird eine Zahl angegeben, werden die ersten [NUM] Routenvarianten
	        in einer detaillierten Liste, und alle weiteren Routen in einer einfachen Liste aufgeführt.
	[check] vergleicht die HTML-Seite gtfsroutes.html mit .cfg-Datei und checkt auf neue Routen
	        in cfg-Datei. Dieser Schritt wird auch automatisch nach $0 -s all ausgeführt.
	Als letzte Tabelle werden jeweils die GTFS-Routenvarianten mit einer ähnlichen Route in
	Openstreetmap aufgelistet.
	Es werden nur Routenvarianten aufgelistet, die dauerhafte Verkehrstage haben.
	Eine Analysedatei befindet sich im Ordner results

   -s [OPTARG] [NUM]

	Wertet eine bestimmte Zeile der cfg-Datei aus.
	Es kann entweder nach einer bestimmten shape_id ausgewertet werden, oder nach einer RelationID.
	Die gefundenen Fehler und die diff-Auswertung der beiden Routen werden in eine Datei geschrieben.
	Auch die Analysedateien von gtfsanalyzer befinden sich im Unterordner ./results.

	Diese Option benötigt einen weiteren Parameter: [all] oder [diff]
	Bei all wird immer eine GPX-Datei (OSM und GTFS) erstellt und die HTML-Seiten werden neu erstellt.
	Das Datum der cfg-Datei wird aktualisiert und die Überschrift wird angepasst.
	Bei diff wird nur ein diff durchgeführt und angezeigt.
	Das Datum der cfg-Datei bleibt unangetastet und wird NICHT aktualisiert.
	Bei beiden Optionen wird die ShapeID sowie die Anzahl der Haltestellen nicht verändert.
	Dies wird über Option -g geregelt.

   -h

	ruft diese Hilfe auf.
 
EOH
}
cfgfilecheck() {
if [ ! -e "$cfgfile" ]; then
 echo -e "Bitte eine Zahl für einen gefüllten config-Ordner im letzten Argument angeben. (z.B. 1 für Ordner ptarea1)\nSkript wird abgebrochen!"
 exit 1
fi
}

# Aufräumen
rm -f ./gtfs.txt
rm -f ./htmlstop.txt
rm -f ./htmlplatform.txt
rm -f ./gtfstohtml.txt
rm -f ./gtfstohtml.tmp
rm -f ./gtfstohtml_fuss.txt
rm -f ./gtfstohtml_kopf.txt
rm -f ./addgtfstohtml_kopf0.txt
rm -f ./addgtfstohtml_kopf1.txt
rm -f ./addgtfstohtml_kopf2.txt
rm -f ./addgtfstohtml_kopf3.txt
rm -f ./addgtfstohtml.txt
rm -f ./addgtfstohtml2.txt
rm -f ./addgtfstohtml3.txt
rm -f ./sortaddgtfstohtml.txt
rm -f ./sortaddgtfstohtml2.txt
rm -f ./sortaddgtfstohtml3.txt
rm -f ./addgtfstohtml_fuss.txt
rm -f ./newgtfsfile.tmp
rm -f ./*errorvar.tmp

datumjetzt=`date +%Y%m%d_%H%M%S`
# ${!#} gibt den Wert des letzten Arguments aus.
cfgfile="../config/ptarea${!#}/real_bus_stops.cfg"
pathtogtfsdata="./gtfsdata"
pathtooldgtfsdata="./oldgtfsdata"
pathtoresults="./results"
pathtogtfsresults=./gtfsdata/results/
pathtogtfsgpx=./gtfsdata/gpx/
pathtoosmdata="../osmdata"

if [ "$(sed -n '6p' "$pathtogtfsdata"/agency.txt | grep '^221,' | wc -l)" == "0" ]; then
 echo "gtfsanalyzer-Einstellungen haben sich geändert. Bitte Variable agencynumber überprüfen!"
 exit 1
else
 agencynumber="5"
fi
 

gtfsdatatohtml() {
# ****** HTML-Seitenerstellung ******

# Seitenkopf wird erstellt.
echo "<!DOCTYPE html>" >./gtfstohtml_kopf.txt
echo "<html lang=\"de\">" >>./gtfstohtml_kopf.txt
echo "<head>" >>./gtfstohtml_kopf.txt
echo "  <meta content=\"text/html; charset=utf-8\" http-equiv=\"content-type\">" >>./gtfstohtml_kopf.txt
echo "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">" >>./gtfstohtml_kopf.txt
echo "  <meta name=\"robots\" content=\"nofollow\">" >>./gtfstohtml_kopf.txt
echo "  <link rel=\"stylesheet\" href=\"../css/fonts.css\">" >>./gtfstohtml_kopf.txt
echo "  <link rel=\"stylesheet\" href=\"../css/font-awesome.css\">" >>./gtfstohtml_kopf.txt
echo "  <link rel=\"stylesheet\" href=\"../css/style.css\">" >>./gtfstohtml_kopf.txt
echo "</head>" >>./gtfstohtml_kopf.txt
echo "<body>" >>./gtfstohtml_kopf.txt
echo " <div class=\"gtfsshapes\"></div>" >>./gtfstohtml_kopf.txt
echo " <header class=\"gtfs\">" >>./gtfstohtml_kopf.txt
echo "  <h1>GTFS data extract</h1>" >>./gtfstohtml_kopf.txt
echo "  <h2 style=\"text-align: center;\">Data from rejseplanen.dk (CC-BY-ND 3.0)</h2>" >>./gtfstohtml_kopf.txt
echo "  <a href=\"../../index.html\"><img id=\"logo\" src=\"../images/logo.svg\"></a>" >>./gtfstohtml_kopf.txt
echo " </header>" >>./gtfstohtml_kopf.txt
echo "<main>" >>./gtfstohtml_kopf.txt
echo " <div class=\"gtfs\">" >>./gtfstohtml_kopf.txt
echo " <h4>Route: ${busnumber} @from => @to - ShapeID: ${gtfsshapeid} - <a href=\"maps/${gtfsshapeid}.html\">Map</a> - <a href=\"javascript:history.back()\">back</a></h4>" >>./gtfstohtml_kopf.txt
echo " <h5>Trip example:</h5>" >>./gtfstohtml_kopf.txt
echo "  <table>" >>./gtfstohtml_kopf.txt
echo "   <tr><th>TripID:</th><td>${evaluatedid}</td></tr>" >>./gtfstohtml_kopf.txt
echo "   <tr><th>Time of departure/arrival:</th><td>${triptime}</td></tr>" >>./gtfstohtml_kopf.txt
echo "   <tr><th>Service days (mo-su):</th><td>${servicedays}</td></tr>" >>./gtfstohtml_kopf.txt
if [ -n "$adddate" ]; then
 echo "   <tr><th>Additional days of service:</th><td>${adddate}</td></tr>" >>./gtfstohtml_kopf.txt
fi
if [ -n "$rmdate" ]; then
 echo "   <tr><th>Doesn't drive on these days:</th><td>${rmdate}</td></tr>" >>./gtfstohtml_kopf.txt
fi
echo "   <tr><th>Service interval (start/end day included):</th><td>${serviceinterval}</td></tr>" >>./gtfstohtml_kopf.txt
echo "  </table>" >>./gtfstohtml_kopf.txt
echo " <h5 id=\"st_ar2\">Stop list:</h5>" >>./gtfstohtml_kopf.txt
echo "  <table>" >>./gtfstohtml_kopf.txt

# *** Hier wird zusätzlich die Kartenseite erstellt. ***
# Dummies werden kopiert und entsprechend angepasst.
cp ./dummy/index.html ../htmlfiles/gtfs/maps/${gtfsshapeid}.html
cp ./dummy/ol/newproject.js ../htmlfiles/gtfs/maps/${gtfsshapeid}.js
gtfsmapfile="../htmlfiles/gtfs/maps/${gtfsshapeid}.html"
gtfsjsfile="../htmlfiles/gtfs/maps/${gtfsshapeid}.js"
sed -i 's/gpxdummy.gpx/'"${gtfsshapeid}"'.gpx/' "$gtfsjsfile"

unset startstop
unset endstop

# Tabelleninhalt wird erstellt.
# Für die erste und letzte Haltestelle wird Name in Variable geschrieben für Überschrift in maps-Seite.
for i in $(seq 1 "$anzgtfsstops"); do
 if [ "$i" == "1" ]; then
  startstop="$(sed -n ''$i'p' ./gtfstohtml.tmp)"
 fi
 sed -n ''$i'p' ./gtfstohtml.tmp  | sed 's/\(^.*$\)/   <tr><th>Stop '"$i"':<\/th><td>\1<\/td><\/tr>/' >>./gtfstohtml.txt
 if [ "$i" == "$anzgtfsstops" ]; then
  endstop="$(sed -n ''$i'p' ./gtfstohtml.tmp)"
 fi
done

# HTML der Haltestellenliste wird komplettiert.
sed -i '
        s/@from/'"$startstop"'/
        s/@to/'"$endstop"'/
       ' ./gtfstohtml_kopf.txt

# HTML der Kartenseite wird komplettiert.
sed -i '
        s/@routeid/'"$busnumber"'/
        s/@from/'"$startstop"'/
        s/@to/'"$endstop"'/
        s/@shapeid /ShapeID: '"$gtfsshapeid"' /
        s/@shapeid2.html/'"$gtfsshapeid"'.html/
        s/src="newproject.js"/src="'"$gtfsshapeid"'.js"/
        s/@created/Page created on '`date +%Y-%m-%d`'/
       ' "$gtfsmapfile"


# Seitenfuss wird erstellt
echo "  </table>" >./gtfstohtml_fuss.txt
echo " </div>" >>./gtfstohtml_fuss.txt
echo "</main>" >>./gtfstohtml_fuss.txt
echo "<footer>" >>./gtfstohtml_fuss.txt
echo "<p>GTFS-Data: <a href=\"https://www.rejseplanen.dk/\">rejseplanen.dk</a><br>Data is under <a href=\"http://creativecommons.org/licenses/by-nd/3.0/\">Creative Commons BY-ND 3.0</a> License.</p>" >>./gtfstohtml_fuss.txt
echo "<p id=\"createdate\">Page created on `date +%Y-%m-%d`.</p>" >>./gtfstohtml_fuss.txt
echo "</footer>" >>./gtfstohtml_fuss.txt
echo "</body>" >>./gtfstohtml_fuss.txt
echo "</html>" >>./gtfstohtml_fuss.txt

cat ./gtfstohtml_kopf.txt ./gtfstohtml.txt ./gtfstohtml_fuss.txt >../htmlfiles/gtfs/${gtfsshapeid}.html

# *** HTML-Seitenerstellung - Ende ***
}

# ***** GPX-Konvertierung für Openlayers *****
# Track wird in Route umgeschrieben.
gpxconvert() {

# ShapeID-Variablen werden angeglichen (Auch wichtig für weiteren Code! (z.B. Funktion gtfsdatatohtml)).
if [ -n "$shapeanswer" ]; then
 gtfsshapeid="${shapeanswer}"
elif [ -n "$gtfsid" ]; then
 gtfsshapeid="${gtfsid}"
fi

echo "GPX-Datei wird für die Verwendung mit Openlayers konvertiert ..."
sed '
     3s/\(.*\)/<!-- Data source: rejseplanen.dk (CC-BY-ND 3.0) -->\n\1/
     s/<name>/<desc>/g
     s/<\/name>/<\/desc>/g
     s/<trk>/<rte>/g
     s/<trkpt/<rtept/g
     s/<\/trkpt>/<\/rtept>/g
     s/<desc>'"$busnumber"'_.*<\/desc>/<desc>Route '"$busnumber"'<\/desc>/
     s/<gpx version="1.1" creator="gtfsanalyzer">/<gpx version="1.1" creator="rcompare">/
     /<\/trkseg>/d
     /<trkseg>/d
     /<\/trk>/d' <${gtfsgpxfile} >"../htmlfiles/gtfs/maps/${gtfsshapeid}.gpx"

zeilennr="$(grep -nio '<wpt' ../htmlfiles/gtfs/maps/${gtfsshapeid}.gpx | sed -n 1p | sed 's/\(^.*\):.*/\1/')"
sed -i ''"$zeilennr"'s/\(.*\)/<\/rte>\n\1/' "../htmlfiles/gtfs/maps/${gtfsshapeid}.gpx"
echo "Konvertierung abgeschlossen. Neue Datei befindet sich im Ordner htmlfiles/gtfs/maps/"
}

# ***** Kompletter Ablauf mit der Option -s *****
relgtfsvergleich() {
	
if [ -n "$relanswer" ]; then
 cfgline="$(grep '^'"${relanswer}"'' "$cfgfile")"
 shapeanswer="$(echo "$cfgline" | cut -d" " -f5)"
fi
if [ -n "$shapeanswer" ]; then
 cfgline="$(grep '^.* .* .* .* '"${shapeanswer}"'' "$cfgfile")"
 relanswer="$(echo "$cfgline" | cut -d" " -f1)"
fi
busnumber="$(echo "$cfgline" | cut -d" " -f4)"
busstops="$(echo "$cfgline" | cut -d" " -f2)"

doubleshapeid="$(grep '^.* .* .* .* '"${shapeanswer}"'' "$cfgfile" | sed '/^#/d' | sed '/^$/d' | cut -d" " -f5 | sort | uniq -d)"
doublerelid="$(grep '^'"${relanswer}"'' "$cfgfile" | sed '/^#/d' | sed '/^$/d' | cut -d" " -f1 | sort | uniq -d)"

echo "****************** Inhaltliche Auswertung OSM-Routen <=> GTFS-Daten *********************" | tee "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
echo "" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"

# ***** Überprüfung der einzelnen Felder der .cfg-Zeile *****

# RelationID wird auf Vorhandensein in route_bus.osm kontrolliert.
if [ "$(grep '<relation id='\'''"$relanswer"''\''' "$pathtoosmdata"/route_bus.osm | wc -l)" == "0" ]; then
 echo "RelationID (${relanswer}) in .cfg-Datei ungültig. Skript wird abgebrochen!" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 exit 1
fi

# Es wird auf doppelte ShapeIDs überprüft.
if [ -n "$doubleshapeid" ]; then
 echo "Die auszuwertende Shape-IDs gibt es doppelt:" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "$doubleshapeid" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "Auswertung abgebrochen!" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 exit 1
fi

# Es wird auf doppelte RelationIDs überprüft.
if [ -n "$doublerelid" ]; then
 echo "Die auszuwertende Relation-IDs gibt es doppelt:" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "$doublerelid" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "Auswertung abgebrochen!" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 exit 1
fi

# Variablen zur Überprüfung der Routennummer in .cfg-Datei mittels GTFS-Daten
routeid="$(grep '^[^,]*,[^,]*,[^,]*,\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,'"$shapeanswer"',.*' "$pathtogtfsdata"/trips.txt | sed -n '1p' | cut -d, -f1)"
route_short_name="$(grep '^'"$routeid"',' "$pathtogtfsdata"/routes.txt | sed -n '1p' | sed 's/^'"$routeid"',[^,]*,\"\([^\"]*\)\"[^,]*,.*$/\1/')"

# Variablen zur Überprüfung der Routennummer in .cfg-Datei mittels OSM-Daten
relbereich=$(sed -n "/<relation id=."$relanswer"/,/<\/relation>/p" "$pathtoosmdata"/route_bus.osm)
refnumber="$(echo "$relbereich" | grep '<tag k='\''ref'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/')"

if [ ! "$route_short_name" == "$busnumber" ] || [[ ! "$refnumber" == *"$busnumber"* ]]; then

 # GTFS-Überprüfung auf fehlerhafte Liniennummer in .cfg-Datei
 if [ ! "$route_short_name" == "$busnumber" ]; then
  echo "Liniennummern (gtfs: route_short_name) stimmen in der .cfg-Datei nicht überein:" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
  echo "ShapeID: ${shapeanswer} | route_short_name: ${route_short_name} | .cfg-Datei: ${busnumber}" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 fi

 # OSM-Überprüfung auf fehlerhafte Liniennummer in .cfg-Datei
 if [[ ! "$refnumber" == *"$busnumber"* ]]; then
  echo "Liniennummern (OSM-tag: ref) stimmen in der .cfg-Datei nicht überein:" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
  echo "RelationID: ${relanswer} | ref: ${refnumber} | .cfg-Datei: ${busnumber}" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 fi

 exit 1

else echo "Überprüfungen der Routennummer in cfg-Datei erfolgreich beendet."

fi

cd "$pathtogtfsdata"
 gtfsanalyzer -s singleauto "$agencynumber" "$busnumber" "$shapeanswer"
 if [ "$OPTARG" == "all" ]; then
  gtfsanalyzer -g singleauto "$agencynumber" "$busnumber" "$shapeanswer"
 fi
cd -

if [ "$OPTARG" == "all" ]; then
  gtfsgpxfile="$(find "${pathtogtfsgpx}" -name "${busnumber}_${shapeanswer}.gpx")"
  ./ptroute2gpx "${relanswer}" ../osmdata/route_bus.osm  && mv *.gpx "$pathtoresults"/"${busnumber}"_"${relanswer}".gpx
fi

gtfsanalyzerfile="$(find ${pathtogtfsresults} -name *shapesingle_${shapeanswer}.txt | sort -r | sed -n '1p')"
if [ -z "$gtfsanalyzerfile" ]; then
 echo "Schwerwiegender Fehler! Es konnte keine Analysedatei von gtfsanalyzer gefunden werden."
 echo "Dieses Skript wird abgebrochen!"
 echo "GTFSID: ${shapeanswer}"
 exit 1
fi

if [ "$OPTARG" == "all" ]; then

 # Werte aus gtfsanalyzerfile auslesen (für trip example (HTML-Seite))
 evaluatedid="$(sed -n 's/^Augewertete Trip-ID: \([[:digit:]]*\) .*/\1/p' "$gtfsanalyzerfile")"
 triptime="$(sed -n 's/^Augewertete Trip-ID:.*(\(.*\))$/\1/p' "$gtfsanalyzerfile" | sed 's/ Uhr//g')"
 # .$ bzw .*$ wandelt ggf. DOS-Zeilenumbrüche in Unix-Zeilenumbrüche um.
 # Die Ausgabe soll einzeilig erfolgen.
 adddate="$(sed -n '/^Zusätzliche Verkehrstage/,/^Fährt nicht an diesen Tagen\|^Dauer der Fahrt/p' "$gtfsanalyzerfile" | sed -n 's/\(^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*$/\1,/p' | tr '\n' ' ')"
 rmdate="$(sed -n '/^Fährt nicht an diesen Tagen/,/^Dauer der Fahrt/p' "$gtfsanalyzerfile" | sed -n 's/\(^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*$/\1,/p' | tr '\n' ' ')"
 # Bei der Umwandlung ist etwas getrickst worden.
 # Zunächst werden alle - in @ und alle x in # umgewandelt, bevor awesome-Element eingefügt wird.
 # Ansonsten würden die x und - in Awesome-Element auch mit umgewandelt.
 servicedays="$(sed -n 's/^Verkehrstage des ausgewerteten Trips (Mo-So): \(.*\)/\1/p' "$gtfsanalyzerfile" | sed 's/-/@/g;s/x/#/g;s/@/<i class="fa-div fa fa-times fa-1x"><\/i>/g;s/#/<i class="fa-div fa fa-check fa-1x"><\/i>/g')"
 serviceinterval="$(sed -n 's/^Gültigkeit des ausgewerteten Trips (von-bis einschließlich): \(....\)\(..\)\(..\)-\(....\)\(..\)\(..\)/\1-\2-\3 - \4-\5-\6/p' "$gtfsanalyzerfile")"

 gpxconvert
 mv ${gtfsgpxfile} ./results/

fi

stopstring="$(sed -n '/<h5 id="st_ar1">Stop_positions/,/<\/table>/p' "../htmlfiles/osm/${relanswer}.html")"
platformstring="$(sed -n '/<h5 id="st_ar2">Platforms/,/<\/table>/p' "../htmlfiles/osm/${relanswer}.html")"

if [ -n "$(echo "$stopstring" | grep 'No stop_position in route.')" ]; then
 echo "No stop_position in route."
else
 htmlstoplist="$(echo "$stopstring" | grep 'stn_f' | sed '/^--$/D;s/^.*<td[^>]*>\(.*\)<\/td>.*$/\1/;s/^$/no_name/')"
echo "$htmlstoplist" >./htmlstop.txt
fi

if [ -n "$(echo "$platformstring" | grep 'No platform in route.')" ]; then
 echo "No platform in route."
else
 htmlplatformlist="$(echo "$platformstring" | grep 'pln_f' | sed '/^--$/D;s/^.*<td[^>]*>\(.*\)<\/td>.*$/\1/;s/^$/no_name/')"
echo "$htmlplatformlist" >./htmlplatform.txt

fi

gtfsshapelist="$(grep '^Stop' "$gtfsanalyzerfile" | sed 's/^Stop .*: \(.*\)/\1/')"
anzgtfsstops="$(echo "$gtfsshapelist" | wc -l)"

if [ ! "$anzgtfsstops" == "$busstops" ]; then
 echo "Haltestellen der OSM-Daten und der GTFS-Daten stimmen nicht überein!" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
fi
 echo "Liniennummer: ${busnumber}" >>"$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "RelationID: ${relanswer}" >>"$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "ShapeID: ${shapeanswer}" >>"$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "Haltestellen in cfg Datei: ${busstops}" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "Haltestellen in GTFS-Daten: ${anzgtfsstops}" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "" >>"$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo ""

 echo "$gtfsshapelist" | tee ./gtfstohtml.tmp ./gtfs.txt 1>/dev/null
 echo ""
 
 if [ "$OPTARG" == "all" ]; then
  # GTFS-HTML-Seite wird erstellt.
  gtfsdatatohtml

  # Überschrift wird angepasst
  osmname="$(echo "$relbereich" | grep '<tag k='\''name'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/' | sed 's/=&[^\;]*\;/=>/g;s/\//\\\//g')"
  osmzeilennr="$(grep -ni '^'"$relanswer"' ' "$cfgfile" | sed 's/\(^[^:]*\):.*/\1/' )"
  sed -i ''"$(("$osmzeilennr"-1))"'s/^#.*/# '"${osmname}"' (GTFS: '"${startstop}"' => '"${endstop}"')/' "$cfgfile"
  # Überschrift anpassen - Ende
 fi

if [ -n "$(echo "$stopstring" | grep 'No stop_position in route.')" ]; then
 echo "No stop_position in route." >>"$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
else
 echo "****************************** OSM-Stop-Data <=> GTFS-Data ******************************" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 diff -yiZd --width=100 ./htmlstop.txt ./gtfs.txt | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
fi

echo ""
read -p "Weiter"
echo "" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"

if [ -n "$(echo "$platformstring" | grep 'No platform in route.')" ]; then
 echo "No platform in route." >>"$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
else
 echo "*************************** OSM-Platform-Data <=> GTFS-Data *****************************" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 echo "" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
 diff -yiZd --width=100 ./htmlplatform.txt ./gtfs.txt | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${relanswer}_${shapeanswer}.txt"
fi

if [ "$OPTARG" == "all" ]; then
 # Bei gleicher Anzahl von Haltestellen wird das Datum aktualisiert.
 if [ "$busstops" == "$anzgtfsstops" ]; then
  sed -i 's/\(^'"$relanswer"'.*\)\(....-..-..\)\(.*$\)/\1'`date +%Y-%m-%d`'\3/' "$cfgfile"
  echo "Datum in .cfg-Datei wurde aktualisiert."
 fi
fi

mv ${gtfsanalyzerfile} ./results/
}

# ***** Funktion -g *****
# Verarbeitung wird wegen Erstellung einer Logdatei in Funktion gepackt.
# Ansonsten würden u.U., je nachdem wo tee gesetzt würde, die Counter nicht richtig zählen.
# Achtung: Variablen verlieren dadurch ihren Wert und können woanders in diesem Skript nicht ohne weiteres mehr genutzt werden.
# Siehe zum Beispiel Variable errorcode.
gtfscheck() {
		
# Backup der .cfg-Datei anlegen.
echo "cfg-Datei wird gesichert."
cp -v "$cfgfile" ./backup/${datumjetzt}_real_bus_stops.cfg
echo ""
		
echo "******************** Auswertung der GTFS-Daten aus $(basename ${cfgfile}) ***********************"
echo "Die Überschriften der einzelnen Spalten beim Fund von mehreren ShapeIDs lauten wie folgt:"
echo "1. Spalte: Neue ShapeID"
echo "2. Spalte: Bei Übereinstimmung der alten und neuen Start-/Endhaltestellennamen = yes"
echo "3. Spalte: Bei Übereinstimmung der alten und neuen Anzahl von Haltestellen = yes"
echo "4. Spalte: Neue Anzahl der Haltestellen"
echo "5. Spalte: Neuer Name der ersten Haltestelle"
echo "6. Spalte: Neuer Name der letzten Haltestelle"
anzrealbuslines="$(cat "$cfgfile" | sed '/^#/d' | sed '/^$/d' | wc -l)"
allrealbuslines="$(cat "$cfgfile" | sed '/^#/d' | sed '/^$/d')"

errorcounterlt="0"
errorcountergt="0"
gtfsupdatecounter="0"
stopupdatecounter="0"
checkcounter="0"

for ((a=1 ; a<=(("$anzrealbuslines")) ; a++)); do

 singleline="$(echo "$allrealbuslines" | sed -n ''$a'p')"
 busstops="$(echo "$singleline" | cut -d" " -f2)"
 gtfsid="$(echo "$singleline" | cut -d" " -f5)"
 busnumber="$(echo "$singleline" | cut -d" " -f4)"
 # Variablen zur Überprüfung der Routennummer in .cfg-Datei mittels GTFS-Daten
 routeid="$(grep '^[^,]*,[^,]*,[^,]*,\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,'"$gtfsid"',.*' "$pathtogtfsdata"/trips.txt | sed -n '1p' | cut -d, -f1)"
 route_short_name="$(grep '^'"$routeid"',' "$pathtogtfsdata"/routes.txt | sed -n '1p' | sed 's/^'$routeid',[^,]*,\"\([^\"]*\)\"[^,]*,.*$/\1/')"
 osmzeilennr="$(grep -ni ' '"$gtfsid"'$' "$cfgfile" | sed 's/\(^[^:]*\):.*/\1/')"
 kommentarzeile="$(sed -n ''"$(("$osmzeilennr"-1))"'p' "${cfgfile}")"
 gtfsoldstartstop="$(echo "$kommentarzeile" | sed 's/.*(GTFS: \(.*\) => .*)$/\1/')"
 gtfsoldendstop="$(echo "$kommentarzeile" | sed 's/.*(GTFS: .* => \(.*\))$/\1/')"
      
 shapeidlist="$(cd "$pathtogtfsdata" && gtfsanalyzer -l shapeid ${agencynumber} ${busnumber})"
 anzshapeidlist="$(echo "$shapeidlist" | wc -l)"

 # Shapetable wird erstellt, damit später auf relevante Daten zurückgegriffen werden kann.
 # Es werden alle Routenvarianten gecheckt.
 unset shapetable
 for singleshape in $(seq 1 ${anzshapeidlist}); do

   singleshapeid="$(echo "$shapeidlist" | sed -n ''${singleshape}'p')"
   gtfscontent="$(cd "$pathtogtfsdata" && gtfsanalyzer -s singleauto ${agencynumber} ${busnumber} ${singleshapeid})"
   gtfsstops="$(echo "$gtfscontent" | grep '^Stop ')"
   gtfsnewstartstop="$(echo "$gtfsstops" | sed -n '1p' | sed 's/^Stop 1: \(.*\)/\1/')"
   gtfsnewendstop="$(echo "$gtfsstops" | sed -n '$p' | sed 's/^Stop [[:digit:]]*: \(.*\)/\1/')"
   newbusstops="$(echo "$gtfscontent" | grep 'Haltestellen in Route' | sed 's/Haltestellen in Route: \(.*\)/\1/')"
   if [ "$gtfsoldstartstop" == "$gtfsnewstartstop" -a  "$gtfsoldendstop" == "$gtfsnewendstop" ]; then
    stopcompare="yes"
   else
    stopcompare="no"
   fi
   if [ "$busstops" == "$newbusstops" ]; then
    anzstopcompare="yes"
   else
    anzstopcompare="no"
   fi
   shapetable=$(echo "$shapetable"; echo "${singleshapeid}@${stopcompare}@${anzstopcompare}@${gtfsnewstartstop}@${gtfsnewendstop}@${newbusstops}")
   gtfsanalyzerfile="$(find ${pathtogtfsresults} -name *shapesingle_${singleshapeid}.txt | sort -r | sed -n '1p')"

   if [ -z "$gtfsanalyzerfile" ]; then
    echo "Schwerwiegender Fehler! Es konnte keine Analysedatei von gtfsanalyzer gefunden werden."
    echo "Dieses Skript wird abgebrochen!"
    echo "GTFSID: ${singleshapeid}"
    exit 1
   else
    mv ${gtfsanalyzerfile} ./results/
   fi

  done
      
  # Evtl. Leerzeilen in shapetable werden entfernt
  shapetable="$(echo "$shapetable" | sed '/^$/d')"

  # Hier wird die Änderung an Datei real_bus_stops.cfg vorgenommen.
  # Nur, wenn die Start- bzw. Endhaltestelle bei EINER gefundenen ShapeID gleich sind,
  # werden die Zeilen in .cfg-File ggf. geändert.

  echo -e "\n*** Analyse von .cfg-Datei-Zeile ${osmzeilennr} (Route ${busnumber}) ***"

  if [ "$(echo "$shapetable" | cut -f2 -d@ | grep -c 'yes')" == "1" ]; then

   shapetableline="$(echo "$shapetable" | grep '^[[:digit:]]*@yes')"
   shapetableshapeid="$(echo "$shapetableline" | cut -f1 -d@)"
   shapetablebusstops="$(echo "$shapetableline" | cut -f6 -d@)"
   echo "Passende ShapeID in den GTFS-Daten gefunden (${shapetableshapeid})."

   simpleservdayscontent="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays ${shapetableshapeid})"
   simpleservicedays="$(echo "$simpleservdayscontent" | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)"

   # Auf Prüfung der dauerhaften Verkehrstage wird (nur hier in diesem Bereich) verzichtet. Lediglich der checkcounter wird aktiviert.
   # Es gibt ja nur einen passenden Fund und mache Hauptrouten haben auch 0 0 0 0 0 0 0 (warum auch immer. Ist das ein Fehler in den GTFS-Daten?)
   echo "Verkehrstage (mo-su):"
   echo "$simpleservicedays"
   
   if [ "$simpleservicedays" == "0 0 0 0 0 0 0" ]; then
   
     # ** Vorgang A2 **
     # Levenshtein-Überprüfung der Start-/Endhaltestellen
     # Achtung! Hier wird nicht wie zum Beispiel beim Vorgang L1 (no@yes) die Prozentuale Änderung
     # sowie die Mindestanzahl der Zwischenhalte berücksichtigt.
     # Auch deswegen ist die nachträgliche Überprüfung dieser Route wichtig.
     echo "Hinweis: Routenvariante ohne dauerhafte Verkehrstage."
     echo "** Weitere Analyse der übrigen Routen **"
     while read -r levprint; do
      printf "%-6d %-3s %-3s %4d   %-50.50s %-30s \n" "$(echo "$levprint" | cut -f1 -d@)" \
                                                      "$(echo "$levprint" | cut -f2 -d@)" \
                                                      "$(echo "$levprint" | cut -f3 -d@)" \
                                                      "$(echo "$levprint" | cut -f6 -d@)" \
                                                      "$(echo "$levprint" | cut -f4 -d@)" \
                                                      "$(echo "$levprint" | cut -f5 -d@)"
     done <<<"$shapetable"
     
     # Löschung der @yes-Zeile
     levshapetable="$(echo "$shapetable" | sed '/^[[:digit:]]*@yes/d')"

     levcounter=0
     while read -r levsearch; do

      levsearchstartstop="$(echo "$levsearch" | cut -f4 -d@)"
      levsearchendstop="$(echo "$levsearch" | cut -f5 -d@)"
      # Die Haltestellenanalyse der Start-/Endhaltestelle wird nach der Levenshtein-Distanz analysiert.
      # Je niedriger der ermittelte Wert ist, desto genauer ist die Übereinstimmung.
      # 0 ist also eine 100%ige Übereinstimmung.
      levstartresult="$(bin/levenshtein "$gtfsoldstartstop" "$levsearchstartstop")"
      levendresult="$(bin/levenshtein "$gtfsoldendstop" "$levsearchendstop")"

      if [ "$levstartresult" -gt "0" ]; then
       startchars=$(("$(printf "$gtfsoldstartstop" | wc -m)"+"$(printf "$levsearchstartstop" | wc -m)"))
       levstartproc=$((100*"$levstartresult"/"$startchars"))
      elif [ "$levstartresult" == "0" ]; then
       levstartproc="0"
      else
       levstartproc="100"
       echo "Fehler bei der Starthaltestellenauswertung."
      fi
      if [ "$levendresult" -gt "0" ]; then
       endchars=$(("$(printf "$gtfsoldendstop" | wc -m)"+"$(printf "$levsearchendstop" | wc -m)"))
       levendproc=$((100*"$levendresult"/"$endchars"))
      elif [ "$levendresult" == "0" ]; then
       levendproc="0"
      else
       levendproc="100"
       echo "Fehler bei der Endhaltestellenauswertung."
      fi
      if [ "$levstartproc" -lt "30" -a "$levendproc" -lt "30" ]; then
       let levcounter++
       # Diese Variable wird nur für die GPX-Erstellung benötigt.
       levshapegpx="$(echo "$levsearch" | cut -f1 -d@)"
       if [ "$levcounter" == 1 ]; then
        levstartstop="$levsearchstartstop"
        levendstop="$levsearchendstop"
        levshape="$(echo "$levsearch" | cut -f1 -d@)"
        levstops="$(echo "$levsearch" | cut -f6 -d@)"
        levsamestopnames="$(echo "$levsearch" | cut -f2 -d@)"
        levsamestops="$(echo "$levsearch" | cut -f3 -d@)"
        levstartnr="$levstartproc"
        levendnr="$levendproc"
       fi
       # GPX-Erstellung aller möglichen Routen mit ähnlicher Start-/Endhaltestelle.
       cd "$pathtogtfsdata"
       gtfsanalyzer -g singleauto "$agencynumber" "$busnumber" "${levshapegpx}" 2>&1 > /dev/null
       cd - 2>&1 > /dev/null
       a2gtfsgpxfile="$(find ${pathtogtfsgpx} -name ${busnumber}_${levshapegpx}.gpx)"
       mv ${a2gtfsgpxfile} ./results/
       a2gpxanalyzerfile="$(find ${pathtogtfsresults} -name *generategpx_*.txt | sort -r | sed -n '1p')"
       mv ${a2gpxanalyzerfile} ./results/ 
      
      fi

     done <<<"$levshapetable"
     
     # Analyse des EINEN Fundes mit ähnlicher Start-/Endhaltestelle.
     if [ "$levcounter" == "1" ]; then
     
      echo -e "\nEine Route mit ähnlichen Namen der Start- bzw. Endhaltestellen gefunden:"
      printf "                   Alte Route (aus .cfg-Datei)          Neue Route                           Grad der Differenz\n"
      echo '---------------- | --------------------------------------------------------------------------------------------'
      printf 'Starthaltestelle : %-36s %-36s (%d)\n' "$gtfsoldstartstop" "$levstartstop" "$levstartnr"
      printf 'Endhaltestelle   : %-36s %-36s (%d)\n' "$gtfsoldendstop" "$levendstop" "$levendnr"
      printf 'GTFSID           : %d                                 %d\n' "$gtfsid" "$levshape"
      printf 'Stops            : %.4d                                 %.4d\n' "$busstops" "$levstops" 
      echo ""
      levservdayscontent="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays ${levshape})"
      levservicedays="$(echo "$levservdayscontent" | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)"
      echo "Verkehrstage (ShapeID: ${levshape}):"
      echo "$levservicedays"
      
      # Überprüfung der Zwischenhalte
      if [ ! -e "../htmlfiles/gtfs/${gtfsid}.html" ]; then
       echo "Schwerwiegender Fehler! Es konnte keine Datei ../htmlfiles/gtfs/${gtfsid}.html zur Analyse gefunden werden."
       echo "Dieses Skript wird abgebrochen!"
       exit 1
      else
       a2oldhtmlstoplist="$(cat ../htmlfiles/gtfs/${gtfsid}.html | grep '<tr><th>Stop' | sed 's/^.*<td>\(.*\)<\/td>.*/\1/;1d;$d')"
      fi
      shapesinglefile="$(find ${pathtoresults} -name *shapesingle_${levshape}.txt | sort -r | sed -n '1p')"
      if [ -z "$shapesinglefile" ]; then
       echo "Schwerwiegender Fehler! Es konnte keine Analysedatei von gtfsanalyzer gefunden werden."
       echo "Dieses Skript wird abgebrochen!"
       echo "GTFSID: ${levshape}"
       exit 1
      else
       a2newstoplist="$(cat "$shapesinglefile" | grep '^Stop [[:digit:]]*:' | sed 's/^Stop [[:digit:]]*: \(.*$\)/\1/;1d;$d')"
      fi

      # Alte GPX-Datei wird kopiert.
      if [ -e "../htmlfiles/gtfs/maps/${gtfsid}.gpx" ]; then
       echo "Alte GPX-Datei kopiert:"
       cp -v "../htmlfiles/gtfs/maps/${gtfsid}.gpx" "${pathtoresults}/${busnumber}_${gtfsid}_old.gpx"
      fi
      # diff zur Fehlerauswertung
      echo "Haltestellenanalyse:"
      stopfilename="${datumjetzt}_gtfshaltestellenanalyse_${gtfsid}_${levshape}.txt"
      echo "Analysedatei: ${pathtoresults}/${stopfilename}"
      echo "$a2oldhtmlstoplist" >./${datumjetzt}_gtfsoldstops.tmp
      echo "$a2newstoplist" >./${datumjetzt}_gtfsnewstops.tmp
      echo "******* GTFS Haltestellenanalyse (ohne Start- bzw. Endhaltestelle) Alte GTFS-Daten <=> Neue GTFS-Daten *******" >"${pathtoresults}/${stopfilename}"
      echo "Route: ${busnumber}" >>"${pathtoresults}/${stopfilename}"
      echo "Alte ShapeID: ${gtfsid}" >>"${pathtoresults}/${stopfilename}"
      echo "Neue ShapeID: ${levshape}" >>"${pathtoresults}/${stopfilename}"
      echo "Alte Starthaltestelle: ${gtfsoldstartstop}" >>"${pathtoresults}/${stopfilename}"
      echo "Alte Endhaltestelle  : ${gtfsoldendstop}" >>"${pathtoresults}/${stopfilename}"
      echo "Neue Starthaltestelle: ${levstartstop}" >>"${pathtoresults}/${stopfilename}"
      echo "Neue Endhaltestelle  : ${levendstop}" >>"${pathtoresults}/${stopfilename}"
      echo "Ausgewertete Datei <: ../htmlfiles/gtfs/${gtfsid}.html" >>"${pathtoresults}/${stopfilename}"
      echo "Ausgewertete Datei >: $(find ${pathtoresults} -name *shapesingle_${levshape}.txt | sort -r | sed -n '1p')" >>"${pathtoresults}/${stopfilename}"
      echo "****************************************************************************" >>"${pathtoresults}/${stopfilename}"
      diff -yiZd --width=160 ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp >>"${pathtoresults}/${stopfilename}"
      echo -e "\n********** Auswertung der Verkehrstage *********" >>"${pathtoresults}/${stopfilename}"
      echo "$levservdayscontent" >>"${pathtoresults}/${stopfilename}"
      stopchange="$(diff ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp | sed -n '/^[<>]/p' | sed '/^$/d')"         
      if [ -n "$stopchange" ]; then
       anzstopchange="$(echo "$stopchange" | wc -l)"
       echo "Haltestellenänderungen (Zwischenhalte; <bestehende >neue ):"
       bestehendlist="$(echo "$stopchange" | grep '^<')"
       neuelist="$(echo "$stopchange" | grep '^>')"
       for printline in $(seq 1 "$anzstopchange"); do
        bestehend="$(echo "$bestehendlist" | sed -n ''$printline'p')"
        neue="$(echo "$neuelist" | sed -n ''$printline'p')"
        if [ -n "$bestehend" -o "$neue" ]; then
         printf '%-60s ' "$bestehend"
         printf '%s\n' "$neue"
        fi
       done
      else
       # Diese Variable (anzstopchange) ist hier eigentlich nicht nötig.
       # Falls aber eine prozentuale Überprüfung der Zwischenhalte eingebaut werden sollte,
       # wird diese hier benötigt.
       anzstopchange="0"
       echo "Haltestellennamen stimmen überein."
      fi
      rm -f ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp
      
      if [ ! "$levservicedays" == "0 0 0 0 0 0 0" ]; then
      
       # ShapeIDs werden überprüft.
       # Die neuen ShapeIDs werden am Ende mit new eingetragen, ansonsten kann es vorkommen,
       # das eine identische alte und neue ShapeID im Dokument vorkommt. 
       # Dann würde es Probleme mit der Variable osmzeilennr geben.
       if [ ! "$gtfsid" == "$levshape" ]; then
        sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${levshape}'new/' "$cfgfile"
        echo "ShapeID von ${gtfsid} auf ${levshape} geändert. (Vorgang A2)"
        let gtfsupdatecounter++
        updateline=$(echo ${updateline}; echo ${osmzeilennr})
        let checkcounter++
        checkline=$(echo ${checkline}; echo ${osmzeilennr})
       elif [ "$gtfsid" == "$levshape" ]; then
        echo "Alte und neue ShapeID sind identisch (${levshape})."
       fi
       # Anzahl der Haltestellen werden überprüft.
       if [ ! "$busstops" == "$levstops" ]; then
        sed -i ''${osmzeilennr}'s/\(^[[:digit:]]* \)'"${busstops}"'\(.*$\)/\1'${levstops}'\2/' "$cfgfile"
        echo "Anzahl der Haltestellen von ${busstops} auf ${levstops} geändert."
        let stopupdatecounter++
        updateline2=$(echo ${updateline2}; echo ${osmzeilennr})
       elif [ "$busstops" == "$levstops" ]; then
        echo "Anzahl der Haltestellen sind identisch (${levstops})."
       fi
      
      else
      
       echo "Es wurde keine Route mit ähnlicher Start-/Endhaltestelle gefunden."
       let errorcounterlt++
       errorlinelt=$(echo ${errorlinelt}; echo ${osmzeilennr})
       
      fi

     else
     
      if [ "$levcounter" == "0" ]; then
        echo "Es wurde keine Route mit ähnlicher Start-/Endhaltestelle gefunden."
        let errorcounterlt++
        errorlinelt=$(echo ${errorlinelt}; echo ${osmzeilennr})
      elif [ "$levcounter" -gt "1" ]; then
        echo "Es wurden ${levcounter} Routen mit ähnlichen Start-/Endhaltestellen gefunden."
        echo "Für diese Route(n) wurde zur Überprüfung eine GPX-Datei erstellt."
        let errorcountergt++
        errorlinegt=$(echo ${errorlinegt}; echo ${osmzeilennr})
      fi
      
     fi
     
   else
   
     # ** Vorgang A1 **
     # ShapeIDs werden überprüft.
     # Die neuen ShapeIDs werden am Ende mit new eingetragen, ansonsten kann es vorkommen,
     # das eine identische alte und neue ShapeID im Dokument vorkommt. 
     # Dann würde es Probleme mit der Variable osmzeilennr geben.
     if [ ! "$gtfsid" == "$shapetableshapeid" ]; then
      sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${shapetableshapeid}'new/' "$cfgfile"
      echo "ShapeID von ${gtfsid} auf ${shapetableshapeid} geändert. (Vorgang A1)"
      let gtfsupdatecounter++
      updateline=$(echo ${updateline}; echo ${osmzeilennr})
     elif [ "$gtfsid" == "$shapetableshapeid" ]; then
      echo "Alte und neue ShapeID sind identisch (${shapetableshapeid})."
     fi
     # Anzahl der Haltestellen werden überprüft.
     if [ ! "$busstops" == "$shapetablebusstops" ]; then
      sed -i ''${osmzeilennr}'s/\(^[[:digit:]]* \)'"${busstops}"'\(.*$\)/\1'${shapetablebusstops}'\2/' "$cfgfile"
      echo "Anzahl der Haltestellen von ${busstops} auf ${shapetablebusstops} geändert."
      let stopupdatecounter++
      updateline2=$(echo ${updateline2}; echo ${osmzeilennr})
     elif [ "$busstops" == "$shapetablebusstops" ]; then
      echo "Anzahl der Haltestellen sind identisch (${shapetablebusstops})."
     fi
     
   fi

  # Verarbeitung, wenn keine passende ShapeID (gleiche Start-/Endhaltestellennamen) gefunden wurde.
  elif [ "$(echo "$shapetable" | cut -f2 -d@ | grep -c 'yes')" -lt "1" ]; then

   echo -e "Keine identischen Start-/Endhaltestellen.\nWegverläufe werden anhand der Zwischenhalte analysiert."
   echo "Route: ${busnumber}"
   echo "Alte ShapeID (aus .cfg-Datei): ${gtfsid}"
   printf "Alte Start-/Endhaltestellen: %-40s %-40s\n" "$gtfsoldstartstop" "$gtfsoldendstop"
   anzshapetableline="$(echo "$shapetable" | wc -l)"
   echo "GTFS-Routenvarianten:"
   for printline in $(seq 1 "$anzshapetableline"); do
    singleprintline="$(echo "$shapetable" | sed -n ''${printline}'p')"
    printf "%-6d %-3s %-3s %4d   %-50.50s %-30s \n" "$(echo "$singleprintline" | cut -f1 -d@)" \
                                                    "$(echo "$singleprintline" | cut -f2 -d@)" \
                                                    "$(echo "$singleprintline" | cut -f3 -d@)" \
                                                    "$(echo "$singleprintline" | cut -f6 -d@)" \
                                                    "$(echo "$singleprintline" | cut -f4 -d@)" \
                                                    "$(echo "$singleprintline" | cut -f5 -d@)"
   done
   
   # ** Detailanalyse no@yes **
   echo "** Detailanalyse **"

   # Auswertung bei unterschiedlichen Start- und Endhaltestellen,
   # aber gleicher Anzahl der Haltestellen.
   # Es werden erst die Haltestellennamen (Zwischenhalte) verglichen.
   # Wenn die Anzahl der Zwischenhalte zu klein ist, wird auf Ähnlichkeiten im Namen der Start-/Endhaltestelle geprüft.
   if [ -n "$(echo "$shapetable" | cut -f2,3 -d@ | grep 'no@yes')" ]; then
   
     nyshapeidlist="$(echo "$shapetable" | grep 'no@yes' | cut -f1 -d@)"
     anznyshapeid="$(echo "$nyshapeidlist" | wc -l)"
     if [ ! -e "../htmlfiles/gtfs/${gtfsid}.html" ]; then
      echo "Schwerwiegender Fehler! Es konnte keine Datei ../htmlfiles/gtfs/${gtfsid}.html zur Analyse gefunden werden."
      echo "Dieses Skript wird abgebrochen!"
      exit 1
     else
      # Da die Start- und Endhaltestellen nicht übereinstimmen,
      # werden diese aus der Liste entfernt.
      oldhtmlstoplist="$(cat ../htmlfiles/gtfs/${gtfsid}.html | grep '<tr><th>Stop' | sed 's/^.*<td>\(.*\)<\/td>.*/\1/;1d;$d')"
      anzoldstopovers="$(echo "$oldhtmlstoplist" | wc -l)"
     fi
     
     # Erstellung von GPX-Dateien
     for nyshapegpx in $(seq 1 "$anznyshapeid"); do
      nygpxshapeid="$(echo "$nyshapeidlist" | sed -n ''${nyshapegpx}'p')"
      cd "$pathtogtfsdata"
      gtfsanalyzer -g singleauto "$agencynumber" "$busnumber" "${nygpxshapeid}" 2>&1 > /dev/null
      cd - 2>&1 > /dev/null
      gtfsgpxfile="$(find ${pathtogtfsgpx} -name ${busnumber}_${nygpxshapeid}.gpx)"
      mv ${gtfsgpxfile} ./results/
      gpxanalyzerfile="$(find ${pathtogtfsresults} -name *generategpx_*.txt | sort -r | sed -n '1p')"
      mv ${gpxanalyzerfile} ./results/
     done
     echo "GPX Datei wurde erstellt."
     
     unset nypositivelist
     unset nypositiveservice
     unset mehrererouten
     for nyshapeid in $(seq 1 "$anznyshapeid"); do
     
       nyshapetableshapeid="$(echo "$nyshapeidlist" | sed -n ''${nyshapeid}'p')"
       echo "ShapeID: ${nyshapetableshapeid}"
       shapesinglefile="$(find ${pathtoresults} -name *shapesingle_${nyshapetableshapeid}.txt | sort -r | sed -n '1p')"
       if [ -z "$shapesinglefile" ]; then
        echo "Schwerwiegender Fehler! Es konnte keine Analysedatei von gtfsanalyzer gefunden werden."
        echo "Dieses Skript wird abgebrochen!"
        echo "GTFSID: ${nyshapetableshapeid}"
        exit 1
       fi
       # Da die Start- und Endhaltestellen nicht übereinstimmen,
       # werden diese aus der Liste entfernt.
       newstoplist="$(cat "$shapesinglefile" | grep '^Stop [[:digit:]]*:' | sed 's/^Stop [[:digit:]]*: \(.*$\)/\1/;1d;$d')"
       anznewstopovers="$(echo "$newstoplist" | wc -l)"
       altstopovers=$((${anzoldstopovers} + ${anznewstopovers}))
       
       # diff zur Fehlerauswertung
       stopfilename="${datumjetzt}_gtfshaltestellenanalyse_${gtfsid}_${nyshapetableshapeid}.txt"
       echo "Analysedatei: ${pathtoresults}/${stopfilename}"
       echo "$oldhtmlstoplist" >./${datumjetzt}_gtfsoldstops.tmp
       echo "$newstoplist" >./${datumjetzt}_gtfsnewstops.tmp
       echo "******* GTFS Haltestellenanalyse (ohne Start- bzw. Endhaltestelle) Alte GTFS-Daten <=> Neue GTFS-Daten *******" >"${pathtoresults}/${stopfilename}"
       echo "Route: ${busnumber}" >>"${pathtoresults}/${stopfilename}"
       echo "Alte ShapeID: ${gtfsid}" >>"${pathtoresults}/${stopfilename}"
       echo "Neue ShapeID: ${nyshapetableshapeid}" >>"${pathtoresults}/${stopfilename}"
       echo "Alte Starthaltestelle: ${gtfsoldstartstop}" >>"${pathtoresults}/${stopfilename}"
       echo "Alte Endhaltestelle  : ${gtfsoldendstop}" >>"${pathtoresults}/${stopfilename}"
       echo "Ausgewertete Datei <: ../htmlfiles/gtfs/${gtfsid}.html" >>"${pathtoresults}/${stopfilename}"
       echo "Ausgewertete Datei >: $(find ${pathtoresults} -name *shapesingle_${nyshapetableshapeid}.txt | sort -r | sed -n '1p')" >>"${pathtoresults}/${stopfilename}"
       echo "****************************************************************************" >>"${pathtoresults}/${stopfilename}"
       diff -yiZd --width=160 ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp >>"${pathtoresults}/${stopfilename}"
       stopchange="$(diff ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp | sed -n '/^[<>]/p' | sed '/^$/d')"         
       if [ -n "$stopchange" ]; then
        anzstopchange="$(echo "$stopchange" | wc -l)"
        echo "Haltestellenänderungen (Zwischenhalte; <bestehende >neue ):"
        bestehendlist="$(echo "$stopchange" | grep '^<')"
        neuelist="$(echo "$stopchange" | grep '^>')"
        for printline in $(seq 1 "$anzstopchange"); do
        bestehend="$(echo "$bestehendlist" | sed -n ''$printline'p')"
        neue="$(echo "$neuelist" | sed -n ''$printline'p')"
        if [ -n "$bestehend" -o "$neue" ]; then
         printf '%-60s ' "$bestehend"
         printf '%s\n' "$neue"
        fi
        done
       else
        anzstopchange="0"
       fi
       rm -f ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp
       if [ -e "../htmlfiles/gtfs/maps/${gtfsid}.gpx" ]; then
        echo "Alte GPX-Datei kopiert:"
        cp -v "../htmlfiles/gtfs/maps/${gtfsid}.gpx" "${pathtoresults}/${busnumber}_${gtfsid}_old.gpx"
       fi
       if [ -n "$stopchange" -a "$anzoldstopovers" -gt "8" -a "$anznewstopovers" -gt "8" ]; then
        procchange=$((100*${anzstopchange}/${altstopovers}))
        echo "Änderungen der Zwischenhalte in Prozent: ${procchange}%"
       elif [ "$anzoldstopovers" -le "8" -a "$anznewstopovers" -le "8" ]; then
        procchange=$((100*${anzstopchange}/${altstopovers}))
        echo "Änderungen der Zwischenhalte in Prozent: ${procchange}%"
        echo -e "Anzahl der Zwischenhalte (<${anzoldstopovers}/>${anznewstopovers}) ist zu klein für eine Auswertung.\nStart-/Endhaltestellen-Analyse:"
       else
        procchange="0"
        echo "Zwischenhalte sind gleich."
       fi
       # Es werden nur ShapeIDs in die positive Liste aufgenommen,
       # wo die Änderungen der Haltestellen unter 10% liegen,
       # und mindestens 9 Zwischenhalte vorhanden sind.
       # oder (im 2. Teil der Verzweigung):
       # die Namen der Start-/Endhaltestellen eine gewisse Ähnlichkeit im Namen aufweisen.
       if [ "$procchange" -lt "10" -a "$anzoldstopovers" -gt "8" -a "$anznewstopovers" -gt "8" ]; then

        nypositivelist="$(echo ${nypositivelist}; echo ${nyshapetableshapeid})"

       elif [ "$procchange" -lt "15" -a "$anzoldstopovers" -le "8" -a "$anznewstopovers" -le "8" ]; then

         levnewstartstop="$(cat "$shapesinglefile" | grep '^Stop [[:digit:]]*:' | sed 's/^Stop [[:digit:]]*: \(.*$\)/\1/' | sed -n '1p')"
         levnewendstop="$(cat "$shapesinglefile" | grep '^Stop [[:digit:]]*:' | sed 's/^Stop [[:digit:]]*: \(.*$\)/\1/' | sed -n '$p')"
         # Die Haltestellenanalyse der Start-/Endhaltestelle wird nach der Levenshtein-Distanz analysiert.
         # Je niedriger der ermittelte Wert ist, desto genauer ist die Übereinstimmung.
         # 0 ist also eine 100%ige Übereinstimmung.
         levstart="$(bin/levenshtein "$gtfsoldstartstop" "$levnewstartstop")"
         levend="$(bin/levenshtein "$gtfsoldendstop" "$levnewendstop")"
         if [ "$levstart" -gt "0" ]; then
          startchars=$(("$(printf "$gtfsoldstartstop" | wc -m)"+"$(printf "$levnewstartstop" | wc -m)"))
          levstartproc=$((100*"$levstart"/"$startchars"))
         elif [ "$levstart" == "0" ]; then
          levstartproc="0"
         else
          levstartproc="100"
          echo "Fehler bei der Starthaltestellenauswertung."
         fi
         if [ "$levend" -gt "0" ]; then
          endchars=$(("$(printf "$gtfsoldendstop" | wc -m)"+"$(printf "$levnewendstop" | wc -m)"))
          levendproc=$((100*"$levend"/"$endchars"))
         elif [ "$levend" == "0" ]; then
          levendproc="0"
         else
          levendproc="100"
          echo "Fehler bei der Endhaltestellenauswertung."
         fi
         # Der ermittelte levenshtein-Wert wird prozentual umgerechnet.
         # Es wird eine gewisse Ähnlichkeit der Haltestellennamen festgestellt, wenn der prozentuale Wert unter 30 liegt.
         # Bei Wert 100 wäre der neue Haltestellenname ein komplett anderer.
         # Østerport St. (Oslo Plads) | Østerport St. (Folke Bernardottes Allé) wäre zum Beispiel ein ermittelter Wert von 29.
         # Spätere eventuelle Änderung wird hier freigegeben (nypositivelist).
         if [ "$levstartproc" -lt "30" -a "$levendproc" -lt "30" ]; then
          echo "Haltestellennamen der Start-/Endhaltestelle sind ähnlich (siehe oben)."
          nypositivelist="$(echo ${nypositivelist}; echo ${nyshapetableshapeid})"
         else
          echo "Die Haltestellennamen unterscheiden sich erheblich. Bitte prüfen (siehe oben)."
         fi

       fi

       nyservicedays="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays ${nyshapetableshapeid})"
       if [ -z "$(echo "$nyservicedays" | grep '^Gefundene Routen : 1$')" ]; then
        mehrererouten="yes"
       fi
       nyservicedaysraw="$(echo "$nyservicedays" | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)"
       if [ ! "$nyservicedaysraw" == "0 0 0 0 0 0 0" ]; then
        nypositiveservice="$(echo "$nypositiveservice"; echo ${nyshapetableshapeid})"
       fi
       echo "Zusammenfassung der Verkehrstage (mo-su):"
       echo "$nyservicedaysraw"
             
     done
     
     nypositivelist="$(echo "$nypositivelist" | sed '/^$/d')"
     # Wichtig! Hier noch mal Leerzeilen entfernen! 
     # Wenn nämlich nypositivelist leer ist, wird mit dem echo-Befehl hier eine neue Leerzeile reingeschrieben!
     anznypositivelist="$(echo "$nypositivelist" | sed '/^$/d' | wc -l)"
     nypositiveservice="$(echo "$nypositiveservice" | sed '/^$/d')"
     anznypositiveservice="$(echo "$nypositiveservice" | sed '/^$/d' | wc -l)"

     # Es wird nur bei einem passenden Fund und dauerhaften Verkehrstagen geändert.
     # Man könnte noch elif [ "$anznypositivelist" -gt "1" ... einbauen, kommt aber so gut wie gar nicht vor.
     if [ "$anznypositivelist" == "1" -a ! "$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays ${nypositivelist} | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)" == "0 0 0 0 0 0 0" -a ! "$mehrererouten" == "yes" ]; then

      # Auch hier wird die neue ID mit new eingetragen.
      if [ ! "$gtfsid" == "$nypositivelist" ]; then
       sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${nypositivelist}'new/' "$cfgfile"
       echo "ShapeID von ${gtfsid} auf ${nypositivelist} geändert. (Vorgang L1)"
       let gtfsupdatecounter++
       updateline=$(echo ${updateline}; echo ${osmzeilennr})
       let checkcounter++
       checkline=$(echo ${checkline}; echo ${osmzeilennr})
      elif [ "$gtfsid" == "$nypositivelist" ]; then
       echo "Alte und neue ShapeID sind identisch (${nypositivelist})."
      fi

     else

      echo "Keine detaillierte Analyse möglich."
      let errorcounterlt++
      errorlinelt=$(echo ${errorlinelt}; echo ${osmzeilennr})

     fi 
     
   else
   
     echo "Keine detaillierte Analyse möglich."
     let errorcounterlt++
     errorlinelt=$(echo ${errorlinelt}; echo ${osmzeilennr})
     
   fi

  # ***** Verarbeitung, wenn mehrere passende ShapeIDs gefunden wurde *****
  elif [ "$(echo "$shapetable" | cut -f2 -d@ | grep -c 'yes')" -gt "1" ]; then

   # Counter?

   shapetableline="$(echo "$shapetable" | grep '^[[:digit:]]*@yes')"
   echo "Es wurden mehrere Routen in den GTFS-Daten gefunden:"
   
   # Formatierter Auszug aus shapetable
   anzshapetableline=$(echo "$shapetableline" | wc -l)
   for printline in $(seq 1 "$anzshapetableline"); do
    singleprintline="$(echo "$shapetableline" | sed -n ''${printline}'p')"
    printf "%-6d %-3s %-3s %4d   %-50.50s %-30s \n" "$(echo "$singleprintline" | cut -f1 -d@)" \
                                                    "$(echo "$singleprintline" | cut -f2 -d@)" \
                                                    "$(echo "$singleprintline" | cut -f3 -d@)" \
                                                    "$(echo "$singleprintline" | cut -f6 -d@)" \
                                                    "$(echo "$singleprintline" | cut -f4 -d@)" \
                                                    "$(echo "$singleprintline" | cut -f5 -d@)"
   done

   # Erstellung von GPX-Dateien
   for printline2 in $(seq 1 "$anzshapetableline"); do
    singleprintline2="$(echo "$shapetableline" | sed -n ''${printline2}'p')"
    shapetableshapeid="$(echo "$singleprintline2" | cut -f1 -d@)"
    cd "$pathtogtfsdata"
     gtfsanalyzer -g singleauto "$agencynumber" "$busnumber" "${shapetableshapeid}" 2>&1 > /dev/null
    cd - 2>&1 > /dev/null
    gtfsgpxfile="$(find ${pathtogtfsgpx} -name ${busnumber}_${shapetableshapeid}.gpx)"
    mv ${gtfsgpxfile} ./results/
    gpxanalyzerfile="$(find ${pathtogtfsresults} -name *generategpx_*.txt | sort -r | sed -n '1p')"
    mv ${gpxanalyzerfile} ./results/
   done

   echo "GPX Dateien wurden erstellt."

         # Es wird auf gleiche Anzahl von Haltestellen geprüft (In shapetable yes@yes)
         if [ "$(echo "$shapetable" | cut -f2,3 -d@ | grep -c 'yes@yes')" == "1" ]; then

          shapetablestopline="$(echo "$shapetable" | grep '^[[:digit:]]*@yes@yes')"
          shapetableshapeid2="$(echo "$shapetablestopline" | cut -f1 -d@)"
          shapetablebusstops2="$(echo "$shapetablestopline" | cut -f6 -d@)"
          echo "Es wurde eine Übereinstimmung mit gleicher Haltestellenanzahl gefunden (${shapetableshapeid2})."
          oldhtmlstoplist="$(cat ../htmlfiles/gtfs/${gtfsid}.html | grep '<tr><th>Stop' | sed 's/^.*<td>\(.*\)<\/td>.*/\1/')"
          shapesinglefile="$(find ${pathtoresults} -name *shapesingle_${shapetableshapeid2}.txt | sort -r | sed -n '1p')"
          if [ -z "$shapesinglefile" ]; then
           echo "Schwerwiegender Fehler! Es konnte keine Analysedatei von gtfsanalyzer gefunden werden."
           echo "Dieses Skript wird abgebrochen!"
           echo "GTFSID: ${shapetableshapeid2}"
           exit 1
          fi
          newstoplist="$(cat "$shapesinglefile" | grep '^Stop [[:digit:]]*:' | sed 's/^Stop [[:digit:]]*: \(.*$\)/\1/')"

          # ** Es werden die Namen der Haltestellen verglichen **
          if [ "$oldhtmlstoplist" == "$newstoplist" ]; then
          
            echo "Namen der Haltestellen stimmen überein."
            simpleservdayscontent2="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays ${shapetableshapeid2})"
            simpleservicedays2="$(echo "$simpleservdayscontent2" | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)"

            # Wenn die Namen der Haltestellen übereinstimmen, wird hier zusätzlich noch
            # auf dauerhafte Verkehrstage gecheckt.
            if [ ! "$simpleservicedays2" == "0 0 0 0 0 0 0" ]; then

             echo "Verkehrstage (mo-su):"
             echo "$simpleservicedays2"
             # ShapeIDs werden überprüft.
             # Auch hier wird die neue ID mit new eingetragen
             if [ ! "$gtfsid" == "$shapetableshapeid2" ]; then
              sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${shapetableshapeid2}'new/' "$cfgfile"
              echo "ShapeID von ${gtfsid} auf ${shapetableshapeid2} geändert. (Vorgang B1)"
              let gtfsupdatecounter++
              updateline=$(echo ${updateline}; echo ${osmzeilennr})
             elif [ "$gtfsid" == "$shapetableshapeid2" ]; then
              echo "Alte und neue ShapeID sind identisch (${shapetableshapeid2})."
             fi

            else
             
             # Wenn keine dauerhaften Verkehrstage ermittelt werden konnten,
             # wird die gesamte shapetable nochmal nach dauerhaften Verkehrstagen gecheckt.
             echo "Keine dauerhaften Verkehrstage ermittelt."
             echo "** Auswertung der Verkehrstage aller oben aufgelisteten Routen **"
             # Tabellenüberschrift für printf-Befehl in for-Schleife
             echo "ShapeID    Verkehrstage    trip_headsign"
             servdayscounter2=0
             oldheadsign4="$(cd "$pathtooldgtfsdata" && gtfsanalyzer -l servicedays ${gtfsid} | sed -n 's/^trip_headsign *: \(.*$\)/\1/p')"
             unset currentshapeid4
             unset currentstops4
             for printline6 in $(seq 1 "$anzshapetableline"); do
               singleprintline6="$(echo "$shapetableline" | sed -n ''${printline6}'p')"
               shapeidforanalysis="$(echo "$singleprintline6" | cut -f1 -d@)"
               gtfsservdayscontentforanalysis="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays ${shapeidforanalysis})"
               gtfsrawcontent="$(echo "$gtfsservdayscontentforanalysis" | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)"
               newheadsign4="$(echo "$gtfsservdayscontentforanalysis" | sed -n 's/^trip_headsign *: \(.*$\)/\1/p')"
               printf '%-10s %-13s   %-20s\n' "$shapeidforanalysis" "$gtfsrawcontent" "$newheadsign4" | sed 's/^\([[:digit:]] .*\)/           \1/'
               if [ ! "$gtfsrawcontent" == "0 0 0 0 0 0 0" -a "$oldheadsign4" == "$newheadsign4" ]; then
                let servdayscounter2++
                currentshapeid4="$shapeidforanalysis"
                currentstops4="$(echo "$singleprintline6" | cut -f6 -d@)"
               fi
             done
            
             # Zukünftige Neuerung: Hier könnte noch eine diff-Auswertung der Haltestellen rein.
             if [ "$servdayscounter2" == "1" ]; then

              echo "Es wurde eine Route  mit trip_headsign \"${oldheadsign4}\" und dauerhaften Verkehrstagen gefunden. (ShapeID: ${currentshapeid4})"

              # ShapeIDs werden überprüft.
              # Auch hier wird die neue ID mit new eingetragen
              if [ ! "$gtfsid" == "$currentshapeid4" ]; then
               sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${currentshapeid4}'new/' "$cfgfile"
               echo "ShapeID von ${gtfsid} auf ${currentshapeid4} geändert. (Vorgang R1)"
               let gtfsupdatecounter++
               updateline=$(echo ${updateline}; echo ${osmzeilennr})
               let checkcounter++
               checkline=$(echo ${checkline}; echo ${osmzeilennr})
              elif [ "$gtfsid" == "$currentshapeid4" ]; then
               echo "Alte und neue ShapeID sind identisch (${currentshapeid4})."
              fi
              if [ ! "$busstops" == "$currentstops4" ]; then
               sed -i ''${osmzeilennr}'s/\(^[[:digit:]]* \)'"${busstops}"'\(.*$\)/\1'${currentstops4}'\2/' "$cfgfile"
               echo "Anzahl der Haltestellen von ${busstops} auf ${currentstops4} geändert."
               let stopupdatecounter++
               updateline2=$(echo ${updateline2}; echo ${osmzeilennr})
              elif [ "$busstops" == "$currentstops4" ]; then
               echo "Anzahl der Haltestellen sind identisch (${currentstops4})."
              fi

             else
            
              if [ "$servdayscounter2" == "0" ]; then
                echo "Es wurde keine Route mit dauerhaften Verkehrstagen gefunden."
                let errorcounterlt++
                errorlinelt=$(echo ${errorlinelt}; echo ${osmzeilennr})
              elif [ "$servdayscounter2" -gt "1" ]; then
                echo "Es wurden ${servdayscounter2} Routen mit dauerhaften Verkehrstagen gefunden."
                let errorcountergt++
                errorlinegt=$(echo ${errorlinegt}; echo ${osmzeilennr})
              fi
            
             fi
             
            fi
            
          else
          
            # **** Vorgang T1/T2/V1 ****
            # Tiefergehende Analyse, da Haltestellennamen nicht übereinstimmen
            # Es werden alle Routen aus der shapetable geprüft!
            # ** Analyse nach Trip-Headsign **
          
            echo -e "Haltestellennamen stimmen nicht überein.\n** Analyse trip_headsign **"
            
            if [ -e "../htmlfiles/gtfs/maps/${gtfsid}.gpx" ]; then
             echo "Alte GPX-Datei kopiert:"
             cp -v "../htmlfiles/gtfs/maps/${gtfsid}.gpx" "${pathtoresults}/${busnumber}_${gtfsid}_old.gpx"
            fi 
          
            oldheadsign="$(cd "$pathtooldgtfsdata" && gtfsanalyzer -l servicedays ${gtfsid} | sed -n 's/^trip_headsign *: \(.*$\)/\1/p')"
            headsigncounter=0
            unset currentshapeid
            unset currentnewheadsign
            unset currentservicedays
            unset currentdiff
            unset currentstops
            unset yesyesservdays
            unset yesyesdiff
            servcounter=0
            unset servcheckshapeid
            unset servchecknewstops
            unset servcheckservdays
            unset servcheckdiff
            unset sameheadsignshapeidlist
            for printline3 in $(seq 1 "$anzshapetableline"); do
              singleprintline3="$(echo "$shapetableline" | sed -n ''${printline3}'p')"
              shapeidforheadsignanalysis="$(echo "$singleprintline3" | cut -f1 -d@)"
              
              # Analysefiles erstellen
              shapesinglefile2="$(find ${pathtoresults} -name *shapesingle_${shapeidforheadsignanalysis}.txt | sort -r | sed -n '1p')"
              if [ -z "$shapesinglefile2" ]; then
               echo "Schwerwiegender Fehler! Es konnte keine Analysedatei von gtfsanalyzer gefunden werden."
               echo "Dieses Skript wird abgebrochen!"
               echo "GTFSID: ${shapeidforheadsignanalysis}"
               exit 1
              fi
              newstoplist2="$(cat "$shapesinglefile2" | grep '^Stop [[:digit:]]*:' | sed 's/^Stop [[:digit:]]*: \(.*$\)/\1/')"
              stopfilename2="${datumjetzt}_gtfshaltestellenanalyse_${gtfsid}_${shapeidforheadsignanalysis}.txt"
              echo -e "Analysedatei: ${pathtoresults}/${stopfilename2}"
              # diff zur Fehlerauswertung
              echo "$oldhtmlstoplist" >./${datumjetzt}_gtfsoldstops.tmp
              echo "$newstoplist2" >./${datumjetzt}_gtfsnewstops.tmp
              echo "******* GTFS Haltestellenanalyse Alte GTFS-Daten <=> Neue GTFS-Daten *******" >"${pathtoresults}/${stopfilename2}"
              echo "Route: ${busnumber}" >>"${pathtoresults}/${stopfilename2}"
              echo "Alte ShapeID: ${gtfsid}" >>"${pathtoresults}/${stopfilename2}"
              echo "Neue ShapeID: ${shapeidforheadsignanalysis}" >>"${pathtoresults}/${stopfilename2}"
              echo "Ausgewertete Datei <: ../htmlfiles/gtfs/${gtfsid}.html" >>"${pathtoresults}/${stopfilename2}"
              echo "Ausgewertete Datei >: $(find ${pathtoresults} -name *shapesingle_${shapeidforheadsignanalysis}.txt | sort -r | sed -n '1p')" >>"${pathtoresults}/${stopfilename2}"
              echo "****************************************************************************" >>"${pathtoresults}/${stopfilename2}"
              diff -yiZd --width=160 ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp >>"${pathtoresults}/${stopfilename2}"

              gtfsservdayscontent="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays ${shapeidforheadsignanalysis})"
              echo "***************** Ergebnis der ausgewerteten Verkehrstage ******************" >>"${pathtoresults}/${stopfilename2}"
              echo "$gtfsservdayscontent" >>"${pathtoresults}/${stopfilename2}"
              newheadsign="$(echo "$gtfsservdayscontent" | sed -n 's/^trip_headsign *: \(.*$\)/\1/p')"
              if [ "$oldheadsign" == "$newheadsign" ]; then
               let headsigncounter++
               currentshapeid="$shapeidforheadsignanalysis"
               sameheadsignshapeidlist+="${currentshapeid} "
               currentnewheadsign="$newheadsign"
               currentservicedays="$(echo "$gtfsservdayscontent" | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)"
               currentdiff="$(diff ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp)"
               currentstops="$(echo "$singleprintline3" | cut -f6 -d@)"
               # Wird wichtig, wenn mehrere Funde gleicher trip_headsign lokalisiert wurden und yes@yes ausgewertet wird.
               # Ist wichtig, das folgende if-Verzweigung in if-Verzweigung [ "$oldheadsign" == "$newheadsign" ] steht.
               # So wird sichergestellt, das auch der neue trip_headsign der gleiche, wie der alte ist.
               if [ "$shapetableshapeid2" == "$shapeidforheadsignanalysis" ]; then
                yesyesservdays="$currentservicedays"
                yesyesdiff="$currentdiff"
               fi
               # Diese Auswertungen werden ggf. für Vorgang V1 benötigt (trip_headsign gleich, yes@yes-Route aber keine dauerhaften Verkehrstage).
               if [ ! "$currentservicedays" == "0 0 0 0 0 0 0" ]; then
                let servcounter++
                servcheckshapeid="$currentshapeid"
                servchecknewstops="$currentstops"
                servcheckservdays="$currentservicedays"
                servcheckdiff="$currentdiff"
               fi
              fi
              rm -f ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp
              
            done

            if [ "$headsigncounter" == "1" -a ! "$currentservicedays" == "0 0 0 0 0 0 0" ]; then
            
             echo "Es wurde eine Übereinstimmung mit trip_headsign \"${oldheadsign}\" (ShapeID: ${currentshapeid}) gefunden."
             echo "Zusammenfassung der Verkehrstage: (ShapeID: ${currentshapeid})"
             echo "$currentservicedays"
             echo "Änderungen bei den Haltestellen (diff-Kurzform <Alte ShapeID (${gtfsid}) >Neue ShapeID (${currentshapeid}))"
             echo "$currentdiff"
             # ShapeIDs werden überprüft.
             # Auch hier wird die neue ID mit new eingetragen (Erklärung siehe etwas weiter oben)
             if [ ! "$gtfsid" == "$currentshapeid" ]; then
              sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${currentshapeid}'new/' "$cfgfile"
              echo "ShapeID von ${gtfsid} auf ${currentshapeid} geändert. (Vorgang T1)"
              let gtfsupdatecounter++
              updateline=$(echo ${updateline}; echo ${osmzeilennr})
              let checkcounter++
              checkline=$(echo ${checkline}; echo ${osmzeilennr})
             elif [ "$gtfsid" == "$currentshapeid" ]; then
              echo "Alte und neue ShapeID sind identisch (${currentshapeid})."
             fi
             if [ ! "$busstops" == "$currentstops" ]; then
              sed -i ''${osmzeilennr}'s/\(^[[:digit:]]* \)'"${busstops}"'\(.*$\)/\1'${currentstops}'\2/' "$cfgfile"
              echo "Anzahl der Haltestellen von ${busstops} auf ${currentstops} geändert."
              let stopupdatecounter++
              updateline2=$(echo ${updateline2}; echo ${osmzeilennr})
             elif [ "$busstops" == "$currentstops" ]; then
              echo "Anzahl der Haltestellen sind identisch (${currentstops})."
             fi
            
            else
            
             echo "Es wurde(n) ${headsigncounter} Übereinstimmung(en) mit trip_headsign \"${oldheadsign}\" gefunden ("${sameheadsignshapeidlist% }")."

             # Da mehrere trip_headsign gefunden wurden, wird zunächst versucht, auf yes@yes geändert.
             # Die trip_headsign-Überprüfung ist hier indirekt schon drin,
             # weil yesyesservdays nur definiert wird, wenn trip_headsigns identisch sind (siehe oben for-Schleife (printline3)).
             if [ ! "$yesyesservdays" == "0 0 0 0 0 0 0" -a -n "$yesyesservdays" ]; then
             
               echo "Es wird nun die ursprünglich gefundene yes@yes Zeile verarbeitet."
               echo "Zusammenfassung der Verkehrstage (ShapeID: ${shapetableshapeid2}):"
               echo "$yesyesservdays"
               echo "Änderungen bei den Haltestellen (diff-Kurzform <Alte ShapeID (${gtfsid}) >Neue ShapeID (${shapetableshapeid2}))"
               echo "$yesyesdiff"
               # ShapeIDs werden überprüft.
               # Auch hier wird die neue ID mit new eingetragen (Erklärung siehe etwas weiter oben)
               if [ ! "$gtfsid" == "$shapetableshapeid2" ]; then
                sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${shapetableshapeid2}'new/' "$cfgfile"
                echo "ShapeID von ${gtfsid} auf ${shapetableshapeid2} geändert. (Vorgang T2)"
                let gtfsupdatecounter++
                updateline=$(echo ${updateline}; echo ${osmzeilennr})
                let checkcounter++
                checkline=$(echo ${checkline}; echo ${osmzeilennr})
               elif [ "$gtfsid" == "$shapetableshapeid2" ]; then
                echo "Alte und neue ShapeID sind identisch (${shapetableshapeid2})."
               fi
               
             else
             
               # ** Vorgang V1 **
               # Es wird nur eine Route mit dauerhaften Verkehrstagen berücksichtigt,
               # die außerdem das gleiche trip_headsign hat (siehe Kommentare zu Beginn dieser if-Verzweigung). 
               
               if [ "$servcounter" == "1" ]; then
               
                echo "Überprüfung auf eine Route mit gleichem trip_headsign, die dauerhafte Verkehrstage hat."
                echo "Eine Routenvariante mit dauerhaften Verkehrstagen gefunden (${servcheckshapeid})."
                echo "$servcheckservdays"
                echo "Änderungen bei den Haltestellen (diff-Kurzform <Alte ShapeID (${gtfsid}) >Neue ShapeID (${servcheckshapeid}))"
                echo "$servcheckdiff"
               
                if [ ! "$gtfsid" == "$servcheckshapeid" ]; then
                 sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${servcheckshapeid}'new/' "$cfgfile"
                 echo "ShapeID von ${gtfsid} auf ${servcheckshapeid} geändert. (Vorgang V1)"
                 let gtfsupdatecounter++
                 updateline=$(echo ${updateline}; echo ${osmzeilennr})
                 let checkcounter++
                 checkline=$(echo ${checkline}; echo ${osmzeilennr})
                elif [ "$gtfsid" == "$servcheckshapeid" ]; then
                 echo "Alte und neue ShapeID sind identisch (${servcheckshapeid})."
                fi
                if [ ! "$busstops" == "$servchecknewstops" ]; then
                 sed -i ''${osmzeilennr}'s/\(^[[:digit:]]* \)'"${busstops}"'\(.*$\)/\1'${servchecknewstops}'\2/' "$cfgfile"
                 echo "Anzahl der Haltestellen von ${busstops} auf ${servchecknewstops} geändert."
                 let stopupdatecounter++
                 updateline2=$(echo ${updateline2}; echo ${osmzeilennr})
                elif [ "$busstops" == "$servchecknewstops" ]; then
                 echo "Anzahl der Haltestellen sind identisch (${servchecknewstops})."
                fi
             
               else
                
                # servicedates werden an bestehende Analysedateien angefügt.
                idstring=${sameheadsignshapeidlist% }
                for idaddsdays in ${idstring[@]}; do
                 addservdayscontent="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedates ${idaddsdays})"
                 echo "$addservdayscontent" >>"${pathtoresults}/${datumjetzt}_gtfshaltestellenanalyse_${gtfsid}_${idaddsdays}.txt"
                done

                echo "Es konnte keine Routenvariante eindeutig verifiziert werden."
                let errorcounterlt++
                errorlinelt=$(echo ${errorlinelt}; echo ${osmzeilennr})
               
               fi            
             
             fi
             
            fi

          # **** Vorgang T1/T2/V1 - Ende ****          
          fi
          
         elif [ "$(echo "$shapetable" | cut -f2,3 -d@ | grep -c 'yes@yes')" -lt "1" ]; then
         
           # ** Detailanalyse yes@no **
           echo "** Detailanalyse **"

           # Auswertung bei gleichnamigen Start- und Endhaltestellen,
           # aber bei unterschiedlicher Anzahl der Haltestellen.
           if [ -n "$(echo "$shapetable" | cut -f2,3 -d@ | grep 'yes@no')" ]; then

            echo "Alte Anzahl von Haltestellen (${busstops}) der alten ShapeID ${gtfsid}"
            ynshapeidlist="$(echo "$shapetable" | grep 'yes@no' | cut -f1 -d@)"
            anzynshapeid="$(echo "$ynshapeidlist" | wc -l)"
            if [ ! -e "../htmlfiles/gtfs/${gtfsid}.html" ]; then
             echo "Schwerwiegender Fehler! Es konnte keine Datei ../htmlfiles/gtfs/${gtfsid}.html zur Analyse gefunden werden."
             echo "Dieses Skript wird abgebrochen!"
             exit 1
            else
             oldhtmlstoplist="$(cat ../htmlfiles/gtfs/${gtfsid}.html | grep '<tr><th>Stop' | sed 's/^.*<td>\(.*\)<\/td>.*/\1/')"
            fi
            
            unset ynpositiveservice
            unset mehrererouten
            copycounter="0"
            for ynshapeid in $(seq 1 "$anzynshapeid"); do
             ynshapetableshapeid="$(echo "$ynshapeidlist" | sed -n ''${ynshapeid}'p')"
             ynservicedates="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedates ${ynshapetableshapeid})"
             echo "ShapeID ${ynshapetableshapeid}:"
             shapesinglefile="$(find ${pathtoresults} -name *shapesingle_${ynshapetableshapeid}.txt | sort -r | sed -n '1p')"
             if [ -z "$shapesinglefile" ]; then
              echo "Schwerwiegender Fehler! Es konnte keine Analysedatei von gtfsanalyzer gefunden werden."
              echo "Dieses Skript wird abgebrochen!"
              echo "GTFSID: ${ynshapetableshapeid}"
              exit 1
             fi
             newstoplist="$(cat "$shapesinglefile" | grep '^Stop [[:digit:]]*:' | sed 's/^Stop [[:digit:]]*: \(.*$\)/\1/')"

             # diff zur Fehlerauswertung
             stopfilename="${datumjetzt}_gtfshaltestellenanalyse_${gtfsid}_${ynshapetableshapeid}.txt"
             echo -e "Haltestellennamen stimmen nicht überein.\nAnalysedatei: ${pathtoresults}/${stopfilename}"
             echo "$oldhtmlstoplist" >./${datumjetzt}_gtfsoldstops.tmp
             echo "$newstoplist" >./${datumjetzt}_gtfsnewstops.tmp
             echo "******* GTFS Haltestellenanalyse Alte GTFS-Daten <=> Neue GTFS-Daten *******" >"${pathtoresults}/${stopfilename}"
             echo "Route: ${busnumber}" >>"${pathtoresults}/${stopfilename}"
             echo "Alte ShapeID: ${gtfsid}" >>"${pathtoresults}/${stopfilename}"
             echo "Neue ShapeID: ${ynshapetableshapeid}" >>"${pathtoresults}/${stopfilename}"
             echo "Ausgewertete Datei <: ../htmlfiles/gtfs/${gtfsid}.html" >>"${pathtoresults}/${stopfilename}"
             echo "Ausgewertete Datei >: $(find ${pathtoresults} -name *shapesingle_${ynshapetableshapeid}.txt | sort -r | sed -n '1p')" >>"${pathtoresults}/${stopfilename}"
             echo "****************************************************************************" >>"${pathtoresults}/${stopfilename}"
             diff -yiZd --width=160 ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp >>"${pathtoresults}/${stopfilename}"
             shortdiff2="$(diff ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp)"
             if [ -n "$shortdiff2" ]; then
              echo "Änderungen bei den Haltestellen (diff-Kurzform <Alte ShapeID (${gtfsid}) >Neue ShapeID (${ynshapetableshapeid}))"
              echo "$shortdiff2"
             fi
             echo "********** Auswertung der zusätzlichen bzw. fehlenden Verkehrstage *********" >>"${pathtoresults}/${stopfilename}"
             echo "$ynservicedates" >>"${pathtoresults}/${stopfilename}"
             rm -f ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp
             
             # Die Datei mit den alten Haltestellennamen wird nur ein Mal kopiert.
             if [ -e "../htmlfiles/gtfs/maps/${gtfsid}.gpx" -a "$copycounter" == "0" ]; then
              let copycounter++
              echo "Alte GPX-Datei kopiert:"
              cp -v "../htmlfiles/gtfs/maps/${gtfsid}.gpx" "${pathtoresults}/${busnumber}_${gtfsid}_old.gpx"
             fi  

             ynservicedays="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays ${ynshapetableshapeid})"
             if [ -z "$(echo "$ynservicedays" | grep '^Gefundene Routen : 1$')" ]; then
              mehrererouten="yes"
             fi
             ynservicedaysraw="$(echo "$ynservicedays" | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)"
             if [ ! "$ynservicedaysraw" == "0 0 0 0 0 0 0" ]; then
              ynpositiveservice="$(echo "$ynpositiveservice"; echo ${ynshapetableshapeid})"
             fi
             echo "Zusammenfassung der Verkehrstage (mo-su):"
             echo "$ynservicedaysraw"

            done
            
            # Variablen mit ShapeIDs, die dauerhafte Verkehrstage haben.
            ynpositiveservice="$(echo "$ynpositiveservice" | sed '/^$/d')"
            anzynpositiveservice="$(echo "$ynpositiveservice" | sed '/^$/d' | wc -l)"
            
            # Es wird nur bei einem Fund von dauerhafen Verkehrstagen
            # die ShapeID und die Haltestellenanzahl geändert.
            if [ "$anzynpositiveservice" == "1" ]; then
            
              sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${ynpositiveservice}'new/' "$cfgfile"
              echo "Der eine Fund mit dauerhaften Verkehrstagen wurde von ShapeID ${gtfsid} auf ${ynpositiveservice} geändert."
              let gtfsupdatecounter++
              updateline=$(echo ${updateline}; echo ${osmzeilennr})
              ynshapetableline="$(echo "$shapetable" | grep "^${ynpositiveservice}")"
              ynshapetablebusstops="$(echo "$ynshapetableline" | cut -f6 -d@)"
              sed -i ''${osmzeilennr}'s/\(^[[:digit:]]* \)'"${busstops}"'\(.*$\)/\1'${ynshapetablebusstops}'\2/' "$cfgfile"
              echo "Anzahl der Haltestellen von ${busstops} auf ${ynshapetablebusstops} geändert."
              let stopupdatecounter++
              updateline2=$(echo ${updateline2}; echo ${osmzeilennr})
              let checkcounter++
              checkline=$(echo ${checkline}; echo ${osmzeilennr})
             
            else
            
              # **** Vorgang M1 ****
            
              # Wenn obriger Schritt nicht greift, wird auf gleiches trip_headsign wie bei der alten ShapeID geprüft (gesamte Shapetable!).
              # Änderungen werden nur bei EINEM passenden Fund durchgeführt.
              oldheadsign3="$(cd "$pathtooldgtfsdata" && gtfsanalyzer -l servicedays ${gtfsid} | sed -n 's/^trip_headsign *: \(.*$\)/\1/p')"
              echo "** Auswertung der Verkehrstage und trip_headsign aller oben aufgelisteten Routen **"
              echo "Altes trip_headsign der ShapeID ${gtfsid}: ${oldheadsign3}"
              # Tabellenüberschrift für printf-Befehl in for-Schleife
              echo "ShapeID    Verkehrstage    trip_headsign"
              headsigncounter2=0
              unset currentshapeid3
              unset currentstops3
              unset currentheadsign3
              for printline5 in $(seq 1 "$anzshapetableline"); do
                singleprintline5="$(echo "$shapetableline" | sed -n ''${printline5}'p')"
                shapeidforanalysis="$(echo "$singleprintline5" | cut -f1 -d@)"
                gtfsservdayscontentforanalysis="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays ${shapeidforanalysis})"
                gtfsrawcontent="$(echo "$gtfsservdayscontentforanalysis" | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)"
                newheadsign3="$(echo "$gtfsservdayscontentforanalysis" | sed -n 's/^trip_headsign *: \(.*$\)/\1/p')"
                printf '%-10s %-13s   %-20s\n' "$shapeidforanalysis" "$gtfsrawcontent" "$newheadsign3" | sed 's/^\([[:digit:]] .*\)/           \1/'
               if [ "$oldheadsign3" == "$newheadsign3" ]; then
                 let headsigncounter2++
                 currentshapeid3="$shapeidforanalysis"
                 currentstops3="$(echo "$singleprintline5" | cut -f6 -d@)"
                 currentheadsign3="$newheadsign3"
                fi

              done
            
              if [ "$headsigncounter2" == "1" ]; then
               echo "Es wurde eine Route mit gleichem trip_headsign gefunden. (ShapeID: ${currentshapeid3})"

               # ShapeIDs werden überprüft.
               # Auch hier wird die neue ID mit new eingetragen
               if [ ! "$gtfsid" == "$currentshapeid3" ]; then
                sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${currentshapeid3}'new/' "$cfgfile"
                echo "ShapeID von ${gtfsid} auf ${currentshapeid3} geändert. (Vorgang M1)"
                let gtfsupdatecounter++
                updateline=$(echo ${updateline}; echo ${osmzeilennr})
                let checkcounter++
                checkline=$(echo ${checkline}; echo ${osmzeilennr})
               elif [ "$gtfsid" == "$currentshapeid3" ]; then
                echo "Alte und neue ShapeID sind identisch (${currentshapeid3})."
               fi
               if [ ! "$busstops" == "$currentstops3" ]; then
                sed -i ''${osmzeilennr}'s/\(^[[:digit:]]* \)'"${busstops}"'\(.*$\)/\1'${currentstops3}'\2/' "$cfgfile"
                echo "Anzahl der Haltestellen von ${busstops} auf ${currentstops3} geändert."
                let stopupdatecounter++
                updateline2=$(echo ${updateline2}; echo ${osmzeilennr})
               elif [ "$busstops" == "$currentstops3" ]; then
                echo "Anzahl der Haltestellen sind identisch (${currentstops3})."
               fi

              else
            
                if [ "$headsigncounter2" == "0" ]; then
                  echo "Es wurde keine Route mit passendem trip_headsign gefunden."
                  let errorcounterlt++
                  errorlinelt=$(echo ${errorlinelt}; echo ${osmzeilennr})
                elif [ "$headsigncounter2" -gt "1" ]; then
                  echo "Es wurden ${headsigncounter2} Routen mit passendem trip_headsign gefunden."
                  let errorcountergt++
                  errorlinegt=$(echo ${errorlinegt}; echo ${osmzeilennr})
                fi
             
              fi
              
            # **** Vorgang M1 - Ende ****
            fi
           
           else
           
            echo "Es wurde keine Übereinstimmung mit gleicher Haltestellenanzahl (${busstops}) gefunden."
            let errorcountergt++
            errorlinegt=$(echo ${errorlinegt}; echo ${osmzeilennr})
            
           fi


         elif [ "$(echo "$shapetable" | cut -f2,3 -d@ | grep -c 'yes@yes')" -gt "1" ]; then
         
           # ** Detailanalyse yes@yes -gt 1 **
           echo "** Detailanalyse **"
           yyshapeidlist="$(echo "$shapetable" | grep 'yes@yes' | cut -f1 -d@)"
           anzyyshapeid="$(echo "$yyshapeidlist" | wc -l)"
           if [ ! -e "../htmlfiles/gtfs/${gtfsid}.html" ]; then
            echo "Schwerwiegender Fehler! Es konnte keine Datei ../htmlfiles/gtfs/${gtfsid}.html zur Analyse gefunden werden."
            echo "Dieses Skript wird abgebrochen!"
            exit 1
           else
            oldhtmlstoplist="$(cat ../htmlfiles/gtfs/${gtfsid}.html | grep '<tr><th>Stop' | sed 's/^.*<td>\(.*\)<\/td>.*/\1/')"
           fi
           
           # Ab hier werden bei Funden von yes@yes die Haltestellen verglichen
           # und auf dauerhafte Verkehrstage geprüft.
           unset yypositivelist
           unset yypositiveservice
           unset mehrererouten
           for yyshapeid in $(seq 1 "$anzyyshapeid"); do
           
            yyshapetableshapeid="$(echo "$yyshapeidlist" | sed -n ''${yyshapeid}'p')"
            echo "ShapeID ${yyshapetableshapeid}:"
            shapesinglefile="$(find ${pathtoresults} -name *shapesingle_${yyshapetableshapeid}.txt | sort -r | sed -n '1p')"
            if [ -z "$shapesinglefile" ]; then
             echo "Schwerwiegender Fehler! Es konnte keine Analysedatei von gtfsanalyzer gefunden werden."
             echo "Dieses Skript wird abgebrochen!"
             echo "GTFSID: ${yyshapetableshapeid}"
             exit 1
            fi
            newstoplist="$(cat "$shapesinglefile" | grep '^Stop [[:digit:]]*:' | sed 's/^Stop [[:digit:]]*: \(.*$\)/\1/')"
            if [ "$oldhtmlstoplist" == "$newstoplist" ]; then
            
             echo "Haltestellennamen stimmen überein."
             yypositivelist="$(echo ${yypositivelist}; echo ${yyshapetableshapeid})"
             
            else 
            
             # diff zur Fehlerauswertung
             stopfilename="${datumjetzt}_gtfshaltestellenanalyse_${gtfsid}_${yyshapetableshapeid}.txt"
             echo -e "Haltestellennamen stimmen nicht überein.\nAnalysedatei: ${pathtoresults}/${stopfilename}"
             echo "$oldhtmlstoplist" >./${datumjetzt}_gtfsoldstops.tmp
             echo "$newstoplist" >./${datumjetzt}_gtfsnewstops.tmp
             echo "******* GTFS Haltestellenanalyse Alte GTFS-Daten <=> Neue GTFS-Daten *******" >"${pathtoresults}/${stopfilename}"
             echo "Route: ${busnumber}" >>"${pathtoresults}/${stopfilename}"
             echo "Alte ShapeID: ${gtfsid}" >>"${pathtoresults}/${stopfilename}"
             echo "Neue ShapeID: ${yyshapetableshapeid}" >>"${pathtoresults}/${stopfilename}"
             echo "Ausgewertete Datei <: ../htmlfiles/gtfs/${gtfsid}.html" >>"${pathtoresults}/${stopfilename}"
             echo "Ausgewertete Datei >: $(find ${pathtoresults} -name *shapesingle_${yyshapetableshapeid}.txt | sort -r | sed -n '1p')" >>"${pathtoresults}/${stopfilename}"
             echo "****************************************************************************" >>"${pathtoresults}/${stopfilename}"
             diff -yiZd --width=160 ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp >>"${pathtoresults}/${stopfilename}"
             rm -f ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp
             
             if [ -e "../htmlfiles/gtfs/maps/${gtfsid}.gpx" ]; then
              echo "Alte GPX-Datei kopiert:"
              cp -v "../htmlfiles/gtfs/maps/${gtfsid}.gpx" "${pathtoresults}/${busnumber}_${gtfsid}_old.gpx"
             fi  
             
            fi
            yyservicedays="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays ${yyshapetableshapeid})"
            if [ -z "$(echo "$yyservicedays" | grep '^Gefundene Routen : 1$')" ]; then
             mehrererouten="yes"
            fi
            yyservicedaysraw="$(echo "$yyservicedays" | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)"
            if [ ! "$yyservicedaysraw" == "0 0 0 0 0 0 0" ]; then
             yypositiveservice="$(echo "$yypositiveservice"; echo ${yyshapetableshapeid})"
            fi
            echo "Zusammenfassung der Verkehrstage (mo-su):"
            echo "$yyservicedaysraw"
           done
     
           # Variablen mit ShapeIDs gleicher Haltestellennamen
           yypositivelist="$(echo "$yypositivelist" | sed '/^$/d')"
           anzyypositivelist="$(echo "$yypositivelist" | sed '/^$/d' | wc -l)"
           # Variablen mit ShapeIDs, die dauerhafte Verkehrstage haben.
           yypositiveservice="$(echo "$yypositiveservice" | sed '/^$/d')"
           anzyypositiveservice="$(echo "$yypositiveservice" | sed '/^$/d' | wc -l)"
           
           # Es werden nur Zeilen geändert, wenn EIN Fund mit gleichnamigen Haltestellen und dauerhaften Verkehrstagen gefunden wurde.
           # danach werden Zeilen geändert, wenn es mehrere Funde mit gleichnamigen Haltestellen und EINEN Fund mit dauerhaften Verkehrstagen gefunden wurde.
           if [ "$anzyypositivelist" == "1" -a ! "$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays ${yypositivelist} | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)" == "0 0 0 0 0 0 0" -a ! "$mehrererouten" == "yes" ]; then
             sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${yypositivelist}'new/' "$cfgfile"
             echo "Der Fund mit gleichen Haltestellennamen und dauerhaften Verkehrstagen wurde von ShapeID ${gtfsid} auf ${yypositivelist} geändert. (Vorgang H1)"
             let gtfsupdatecounter++
             updateline=$(echo ${updateline}; echo ${osmzeilennr})
           elif [ "$anzyypositivelist" -gt "1" -a "$anzyypositiveservice" == "1" -a -n "$(echo "$yypositivelist" | grep "$yypositiveservice")" -a ! "$mehrererouten" == "yes" ]; then
             sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${yypositiveservice}'new/' "$cfgfile"
             echo "Der Fund mit gleichen Haltestellennamen und dauerhaften Verkehrstagen wurde von ShapeID ${gtfsid} auf ${yypositiveservice} geändert. (Vorgang HM)"
             let gtfsupdatecounter++
             updateline=$(echo ${updateline}; echo ${osmzeilennr})
           elif [ "$anzyypositiveservice" == "1" -a ! "$mehrererouten" == "yes" ]; then
             sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${yypositiveservice}'new/' "$cfgfile"
             echo "Der Fund mit unterschiedlichen Haltestellennamen und dauerhaften Verkehrstagen wurde von ShapeID ${gtfsid} auf ${yypositiveservice} geändert. (Vorgang HU)"
             let gtfsupdatecounter++
             updateline=$(echo ${updateline}; echo ${osmzeilennr})
             let checkcounter++
             checkline=$(echo ${checkline}; echo ${osmzeilennr})
           else
           
            # **** Vorgang N1 ****
            # Hier wird, wenn obrige Schritte nicht greifen, zusätzlich geprüft
            # ob eventuell nur nach dauerhaften Verkehstagen ausgewertet werden kann (Gesamte Shapetable!; Nur ein Fund!).
            echo "Es wurden mehrere Übereinstimmungen mit gleicher Haltestellenanzahl gefunden."
            if [ "$mehrererouten" == "yes" ]; then
             echo "Außerdem hat mindestens ein gtfsanalyzer-Resultat (-l servicedays) mehrere Routen ermittelt."
            fi
            echo "** Auswertung der Verkehrstage aller oben aufgelisteten Routen **"
            # Tabellenüberschrift für printf-Befehl in for-Schleife
            echo "ShapeID    Verkehrstage    trip_headsign"
            servdayscounter=0
            unset currentshapeid2
            unset currentstops2
            unset currentservicedays2
            for printline4 in $(seq 1 "$anzshapetableline"); do
              singleprintline4="$(echo "$shapetableline" | sed -n ''${printline4}'p')"
              shapeidforanalysis="$(echo "$singleprintline4" | cut -f1 -d@)"
              gtfsservdayscontentforanalysis="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays ${shapeidforanalysis})"
              gtfsrawcontent="$(echo "$gtfsservdayscontentforanalysis" | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)"
              newheadsign2="$(echo "$gtfsservdayscontentforanalysis" | sed -n 's/^trip_headsign *: \(.*$\)/\1/p')"
              printf '%-10s %-13s   %-20s\n' "$shapeidforanalysis" "$gtfsrawcontent" "$newheadsign2" | sed 's/^\([[:digit:]] .*\)/           \1/'
              if [ ! "$gtfsrawcontent" == "0 0 0 0 0 0 0" ]; then
               let servdayscounter++
               currentshapeid2="$shapeidforanalysis"
               currentstops2="$(echo "$singleprintline4" | cut -f6 -d@)"
               currentservicedays2="$gtfsservdayscontentforanalysis"
              fi
            done
            
            if [ "$servdayscounter" == "1" ]; then
            
             echo "Es wurde eine Route mit dauerhaften Verkehrstagen gefunden. (ShapeID: ${currentshapeid2})"

             # Analysefile erstellen
             shapesinglefile3="$(find ${pathtoresults} -name *shapesingle_${currentshapeid2}.txt | sort -r | sed -n '1p')"
             if [ -z "$shapesinglefile3" ]; then
              echo "Schwerwiegender Fehler! Es konnte keine Analysedatei von gtfsanalyzer gefunden werden."
              echo "Dieses Skript wird abgebrochen!"
              echo "GTFSID: ${currentshapeid2}"
              exit 1
             fi
             newstoplist3="$(cat "$shapesinglefile3" | grep '^Stop [[:digit:]]*:' | sed 's/^Stop [[:digit:]]*: \(.*$\)/\1/')"
             stopfilename3="${datumjetzt}_gtfshaltestellenanalyse_${gtfsid}_${currentshapeid2}.txt"
             echo -e "Analysedatei: ${pathtoresults}/${stopfilename3}"
             # diff zur Fehlerauswertung
             echo "$oldhtmlstoplist" >./${datumjetzt}_gtfsoldstops.tmp
             echo "$newstoplist3" >./${datumjetzt}_gtfsnewstops.tmp
             echo "******* GTFS Haltestellenanalyse Alte GTFS-Daten <=> Neue GTFS-Daten *******" >"${pathtoresults}/${stopfilename3}"
             echo "Route: ${busnumber}" >>"${pathtoresults}/${stopfilename3}"
             echo "Alte ShapeID: ${gtfsid}" >>"${pathtoresults}/${stopfilename3}"
             echo "Neue ShapeID: ${currentshapeid2}" >>"${pathtoresults}/${stopfilename3}"
             echo "Ausgewertete Datei <: ../htmlfiles/gtfs/${gtfsid}.html" >>"${pathtoresults}/${stopfilename3}"
             echo "Ausgewertete Datei >: $(find ${pathtoresults} -name *shapesingle_${currentshapeid2}.txt | sort -r | sed -n '1p')" >>"${pathtoresults}/${stopfilename3}"
             echo "****************************************************************************" >>"${pathtoresults}/${stopfilename3}"
             diff -yiZd --width=160 ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp >>"${pathtoresults}/${stopfilename3}"
             echo "***************** Ergebnis der ausgewerteten Verkehrstage ******************" >>"${pathtoresults}/${stopfilename3}"
             echo "$currentservicedays2" >>"${pathtoresults}/${stopfilename3}"
             shortdiff="$(diff ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp)"
             if [ -n "$shortdiff" ]; then
              echo "Änderungen bei den Haltestellen (diff-Kurzform <Alte ShapeID (${gtfsid}) >Neue ShapeID (${currentshapeid2}))"
              echo "$shortdiff"
             fi

             rm -f ./${datumjetzt}_gtfsoldstops.tmp ./${datumjetzt}_gtfsnewstops.tmp

             # ShapeIDs werden überprüft.
             # Auch hier wird die neue ID mit new eingetragen
             if [ ! "$gtfsid" == "$currentshapeid2" ]; then
              sed -i ''${osmzeilennr}'s/'${gtfsid}'$/'${currentshapeid2}'new/' "$cfgfile"
              echo "ShapeID von ${gtfsid} auf ${currentshapeid2} geändert. (Vorgang N1)"
              let gtfsupdatecounter++
              updateline=$(echo ${updateline}; echo ${osmzeilennr})
              let checkcounter++
              checkline=$(echo ${checkline}; echo ${osmzeilennr})
             elif [ "$gtfsid" == "$currentshapeid2" ]; then
              echo "Alte und neue ShapeID sind identisch (${currentshapeid2})."
             fi
             if [ ! "$busstops" == "$currentstops2" ]; then
              sed -i ''${osmzeilennr}'s/\(^[[:digit:]]* \)'"${busstops}"'\(.*$\)/\1'${currentstops2}'\2/' "$cfgfile"
              echo "Anzahl der Haltestellen von ${busstops} auf ${currentstops2} geändert."
              let stopupdatecounter++
              updateline2=$(echo ${updateline2}; echo ${osmzeilennr})
             elif [ "$busstops" == "$currentstops2" ]; then
              echo "Anzahl der Haltestellen sind identisch (${currentstops2})."
             fi

            else
            
              if [ "$servdayscounter" == "0" ]; then
                echo "Es wurde keine Route mit dauerhaften Verkehrstagen gefunden."
                let errorcounterlt++
                errorlinelt=$(echo ${errorlinelt}; echo ${osmzeilennr})
              elif [ "$servdayscounter" -gt "1" ]; then
                echo "Es wurden ${servdayscounter} Routen mit dauerhaften Verkehrstagen gefunden."
                let errorcountergt++
                errorlinegt=$(echo ${errorlinegt}; echo ${osmzeilennr})
              fi
            
            fi
            
           # **** Vorgang N1 - Ende ****
           fi
 
         fi

  fi

  # Zum debuggen
  # echo "$shapetable"

 done
 
 # Das new am Ende der neuen ShapeIDs wird im gesamten .cfg-file entfernt.
 sed -i '/^#/!s/ \([[:digit:]]*\)new$/ \1/' "$cfgfile"

 echo -e "\n******************************* Ende der GTFS-Auswertung ************************************"

 echo -e "\nStatistik:"
 echo "Insgesamt in .cfg-Datei eingebundene Routen: ${anzrealbuslines}"
 echo "Geänderte ShapeIDs: ${gtfsupdatecounter}"
 echo "$((100*${gtfsupdatecounter}/${anzrealbuslines}))% der erfassten Routen konnten überprüft werden."
 echo "Geänderte Anzahl der Haltestellen: ${stopupdatecounter}"
 echo "Funde die geändert wurden, aber zusätzlich noch mal geprüft werden sollten: ${checkcounter}"
 echo "Funde ohne passende ShapeID, die noch von Hand geändert werden müssen: ${errorcounterlt}"
 echo "Funde mit mehrfachen passenden ShapeIDs, die noch von Hand geändert werden müssen: ${errorcountergt}"

 if [ -n "$updateline" ]; then
  echo -e "\nBei folgenden Zeilen wurde die ShapeID geändert:"
  echo $updateline | sed 's/\([[:digit:]]*\) /\1, /g'
 fi
 if [ -n "$updateline2" ]; then
  echo "Bei folgenden Zeilen wurde aufgrund eines passenden Fundes die Anzahl der Haltestellen geändert:"
  echo $updateline2 | sed 's/\([[:digit:]]*\) /\1, /g'
 fi
 if [ -n "$checkline" ]; then
  echo "Zeilen, die zusätzlich noch mal geprüft werden sollten, weil nach weichen Faktoren geändert wurde:"
  echo $checkline | sed 's/\([[:digit:]]*\) /\1, /g'
 fi
 if [ -n "$errorlinelt" -o -n "$errorlinegt" ]; then
  echo -e "\nFolgende Zeilen müssen überprüft und angepasst werden:"
 fi
 # errorcode-Variable muss in Datei geschrieben werden, weil die Ausgabe dieser Funktion
 # in eine Logdatei geschrieben wird, stehen die Variablen nicht mehr zur Verfügung
 # und müssen mit source neu aktiviert werden.
 if [ -n "$errorlinelt" ]; then
  echo "Zeilen ohne passende ShapeID, die überprüft werden müssen (ShapeIDs und Haltestellen):"
  echo $errorlinelt | sed 's/\([[:digit:]]*\) /\1, /g'
  echo errorcode="1" >${datumjetzt}errorvar.tmp
 fi
 if [ -n "$errorlinegt" ]; then
  echo "Zeilen mit mehreren passenden ShapeIDs, die überprüft werden müssen (ShapeIDs und Haltestellen):"
  echo $errorlinegt | sed 's/\([[:digit:]]*\) /\1, /g'
  echo errorcode="1" >${datumjetzt}errorvar.tmp
 fi
 echo ""
 echo "Hinweise:"
 echo "Die Überschriften der einzelnen Spalten beim Fund von mehreren ShapeIDs lauten wie folgt:"
 echo "1. Spalte: Neue ShapeID"
 echo "2. Spalte: Bei Übereinstimmung der alten und neuen Start-/Endhaltestellennamen = yes"
 echo "3. Spalte: Bei Übereinstimmung der alten und neuen Anzahl von Haltestellen = yes"
 echo "4. Spalte: Neue Anzahl der Haltestellen"
 echo "5. Spalte: Neuer Name der ersten Haltestelle"
 echo "6. Spalte: Neuer Name der letzten Haltestelle"
 echo ""
 echo "Erstellte GPX Dateien zur Analyse befinden sich im Ordner ${PWD}/results"
 echo ""
}
    
# ***** Funktion -a (Automatisierter Ablauf) *****
automaticprocess() {
	
# Variablen-Datei wird hier gleich wieder gelöscht.
if [ -e ./${datumjetzt}errorvar.tmp ]; then
 source ./${datumjetzt}errorvar.tmp && rm -f ./${datumjetzt}errorvar.tmp
fi

if [ "$errorcode" == "1" ]; then
 echo -e "$(basename $0) Option -a Es wurden Fehler im vorangegangenen Prozess entdeckt.\nBitte erst prüfen und dann Skript neu starten und Prozess fortsetzen."
 if [ -e "../tools/mail/sendamail" ]; then
  ../tools/mail/sendamail -e
 fi
 exit 1
fi

unset errorcode
  
# Backup der .cfg-Datei anlegen.
cp "$cfgfile" ./backup/${datumjetzt}_real_bus_stops.cfg

# Dateien werden gelöscht.
echo "Alte GTFS-Dateien werden gelöscht."
rm -f ../htmlfiles/gtfs/*.html
rm -f ../htmlfiles/gtfs/maps/*.html
rm -f ../htmlfiles/gtfs/maps/*.js
rm -f ../htmlfiles/gtfs/maps/*.gpx

anzrealbuslines="$(cat "$cfgfile" | sed '/^#/d' | sed '/^$/d' | wc -l)"
allrealbuslines="$(cat "$cfgfile" | sed '/^#/d' | sed '/^$/d')"
doubleshapeid="$(cat "$cfgfile" | sed '/^#/d' | sed '/^$/d' | cut -d" " -f5 | sort | uniq -d)"
doublerelid="$(cat "$cfgfile" | sed '/^#/d' | sed '/^$/d' | cut -d" " -f1 | sort | uniq -d)"

echo "Fehlerdatei - Inhaltliche Auswertung OSM-Routen <=> GTFS-Daten" >./${datumjetzt}_fehlerdatei.txt
echo "" >>./${datumjetzt}_fehlerdatei.txt

# Es wird auf doppelte ShapeIDs überprüft.
if [ -n "$doubleshapeid" ]; then
 echo "Skript wird abgebrochen. Folgende Shape-IDs sind doppelt:" | tee -a ./${datumjetzt}_fehlerdatei.txt
 echo $doubleshapeid | tee -a ./${datumjetzt}_fehlerdatei.txt
 echo "**************************************" >>./${datumjetzt}_fehlerdatei.txt
 mv ${datumjetzt}_fehlerdatei.txt ./results/
 if [ -e "../tools/mail/sendamail" ]; then
  ../tools/mail/sendamail -e
 fi
 exit 1
fi

# Es wird auf doppelte RelationIDs überprüft.
if [ -n "$doublerelid" ]; then
 echo "Skript wird abgebrochen. Folgende Relation-IDs sind doppelt:" | tee -a ./${datumjetzt}_fehlerdatei.txt
 echo $doublerelid | tee -a ./${datumjetzt}_fehlerdatei.txt
 echo "**************************************" >>./${datumjetzt}_fehlerdatei.txt
 mv ${datumjetzt}_fehlerdatei.txt ./results/
 if [ -e "../tools/mail/sendamail" ]; then
  ../tools/mail/sendamail -e
 fi
 exit 1
fi

errorcounter="0"
for ((a=1 ; a<=(("$anzrealbuslines")) ; a++)); do

 rm -f ./gtfs.txt
 rm -f ./htmlstop.txt
 rm -f ./htmlplatform.txt
 rm -f ./gtfstohtml.txt

 relid="$(echo "$allrealbuslines" | sed -n ''$a'p' | cut -d" " -f1)"
 busstops="$(echo "$allrealbuslines" | sed -n ''$a'p' | cut -d" " -f2)"
 gtfsid="$(echo "$allrealbuslines" | sed -n ''$a'p' | cut -d" " -f5)"
 busnumber="$(echo "$allrealbuslines" | sed -n ''$a'p' | cut -d" " -f4)"
 # Variablen zur Überprüfung der Routennummer in .cfg-Datei mittels GTFS-Daten
 routeid="$(grep '^[^,]*,[^,]*,[^,]*,\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,'"$gtfsid"',.*' "$pathtogtfsdata"/trips.txt | sed -n '1p' | cut -d, -f1)"
 route_short_name="$(grep '^'"$routeid"',' "$pathtogtfsdata"/routes.txt | sed -n '1p' | sed 's/^'$routeid',[^,]*,\"\([^\"]*\)\"[^,]*,.*$/\1/')"
 # Variablen zur Überprüfung der Routennummer in .cfg-Datei mittels OSM-Daten
 relbereich=$(sed -n "/<relation id=."$relid"/,/<\/relation>/p" "$pathtoosmdata"/route_bus.osm)
 refnumber="$(echo "$relbereich" | grep '<tag k='\''ref'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/')"

if [ -z "$relid" ]; then
 echo "RelationID ${relid} fehlt! Analyse kann nicht ausgeführt werden." >>./${datumjetzt}_fehlerdatei.txt
 echo "(ShapeID: ${gtfsid})" >>./${datumjetzt}_fehlerdatei.txt
 echo "(Buslinienbezeichnung: ${busnumber})" >>./${datumjetzt}_fehlerdatei.txt
 echo "**************************************" >>./${datumjetzt}_fehlerdatei.txt
 let errorcounter++

elif [ -z "$gtfsid" ]; then
 echo "ShapeID ${gtfsid} fehlt! Analyse kann nicht ausgeführt werden." >>./${datumjetzt}_fehlerdatei.txt
 echo "(RelationID: ${relid})" >>./${datumjetzt}_fehlerdatei.txt
 echo "(Buslinienbezeichnung: ${busnumber})" >>./${datumjetzt}_fehlerdatei.txt
 echo "**************************************" >>./${datumjetzt}_fehlerdatei.txt
 let errorcounter++

elif [ -z "$busnumber" ]; then
 echo "Buslinienbezeichnung ${busnumber} fehlt! Analyse kann nicht ausgeführt werden." >>./${datumjetzt}_fehlerdatei.txt
 echo "(RelationID: ${relid})" >>./${datumjetzt}_fehlerdatei.txt
 echo "(ShapeID: ${gtfsid})" >>./${datumjetzt}_fehlerdatei.txt
 echo "**************************************" >>./${datumjetzt}_fehlerdatei.txt
 let errorcounter++

# RelationID wird auf Vorhandensein in route_bus.osm kontrolliert.
elif [ "$(grep '<relation id='\'''"$relid"''\''' "$pathtoosmdata"/route_bus.osm | wc -l)" == "0" ]; then
 echo "RelationID (${relid}) in .cfg-Datei ungültig! ID wurde nicht in route_bus.osm gefunden." | tee -a ./${datumjetzt}_fehlerdatei.txt
 let errorcounter++

elif [ ! "$route_short_name" == "$busnumber" ] || [[ ! "$refnumber" == *"$busnumber"* ]]; then

 # GTFS-Überprüfung auf fehlerhafte Liniennummer in .cfg-Datei
 if [ ! "$route_short_name" == "$busnumber" ]; then
  echo "Liniennummern (gtfs: route_short_name) stimmen in der .cfg-Datei nicht überein:" | tee -a ./${datumjetzt}_fehlerdatei.txt
  echo "ShapeID: ${gtfsid} | route_short_name: ${route_short_name} | .cfg-Datei: ${busnumber}" | tee -a ./${datumjetzt}_fehlerdatei.txt
  let errorcounter++
 fi

 # OSM-Überprüfung auf fehlerhafte Liniennummer in .cfg-Datei
 if [[ ! "$refnumber" == *"$busnumber"* ]]; then
  echo "Liniennummern (OSM-tag: ref) stimmen in der .cfg-Datei nicht überein:" | tee -a ./${datumjetzt}_fehlerdatei.txt
  echo "RelationID: ${relid} | ref: ${refnumber} | .cfg-Datei: ${busnumber}" | tee -a ./${datumjetzt}_fehlerdatei.txt
  let errorcounter++
 fi

# Nur wenn alle Überprüfungen ohne Fehlerfund waren, geht's weiter.
else

 cd "$pathtogtfsdata"
 gtfsanalyzer -s singleauto "$agencynumber" "$busnumber" "$gtfsid"
 cd -

 gtfsanalyzerfile="$(find ${pathtogtfsresults} -name *shapesingle_${gtfsid}.txt | sort -r | sed -n '1p')"
 if [ -z "$gtfsanalyzerfile" ]; then
  echo "Schwerwiegender Fehler! Es konnte keine Analysedatei von gtfsanalyzer gefunden werden."
  echo "Dieses Skript wird abgebrochen!"
  echo "GTFSID: ${gtfsid}"
  exit 1
 fi
 # Werte aus gtfsanalyzerfile auslesen (für trip example (HTML-Seite))
 evaluatedid="$(sed -n 's/^Augewertete Trip-ID: \([[:digit:]]*\) .*/\1/p' "$gtfsanalyzerfile")"
 triptime="$(sed -n 's/^Augewertete Trip-ID:.*(\(.*\))$/\1/p' "$gtfsanalyzerfile" | sed 's/ Uhr//g')"
 # .$ bzw .*$ wandelt ggf. DOS-Zeilenumbrüche in Unix-Zeilenumbrüche um.
 # Die Ausgabe soll einzeilig erfolgen.
 adddate="$(sed -n '/^Zusätzliche Verkehrstage/,/^Fährt nicht an diesen Tagen\|^Dauer der Fahrt/p' "$gtfsanalyzerfile" | sed -n 's/\(^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*$/\1,/p' | tr '\n' ' ')"
 rmdate="$(sed -n '/^Fährt nicht an diesen Tagen/,/^Dauer der Fahrt/p' "$gtfsanalyzerfile" | sed -n 's/\(^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*$/\1,/p' | tr '\n' ' ')"
 # Bei der Umwandlung ist etwas getrickst worden.
 # Zunächst werden alle - in @ und alle x in # umgewandelt, bevor awesome-Element eingefügt wird.
 # Ansonsten würden die x und - in Awesome-Element auch mit umgewandelt.
 servicedays="$(sed -n 's/^Verkehrstage des ausgewerteten Trips (Mo-So): \(.*\)/\1/p' "$gtfsanalyzerfile" | sed 's/-/@/g;s/x/#/g;s/@/<i class="fa-div fa fa-times fa-1x"><\/i>/g;s/#/<i class="fa-div fa fa-check fa-1x"><\/i>/g')"
 serviceinterval="$(sed -n 's/^Gültigkeit des ausgewerteten Trips (von-bis einschließlich): \(....\)\(..\)\(..\)-\(....\)\(..\)\(..\)/\1-\2-\3 - \4-\5-\6/p' "$gtfsanalyzerfile")"

 stopstring="$(sed -n '/<h5 id="st_ar1">Stop_positions/,/<\/table>/p' "../htmlfiles/osm/${relid}.html")"
 platformstring="$(sed -n '/<h5 id="st_ar2">Platforms/,/<\/table>/p' "../htmlfiles/osm/${relid}.html")"

 if [ -n "$(echo "$stopstring" | grep 'No stop_position in route.')" ]; then
  echo "No stop_position in route."
 else
  htmlstoplist="$(echo "$stopstring" | grep 'stn_f' | sed '/^--$/D;s/^.*<td[^>]*>\(.*\)<\/td>.*$/\1/;s/^$/no_name/')"
  echo "$htmlstoplist" >./htmlstop.txt
 fi

 if [ -n "$(echo "$platformstring" | grep 'No platform in route.')" ]; then
  echo "No platform in route."
 else
  htmlplatformlist="$(echo "$platformstring" | grep 'pln_f' | sed '/^--$/D;s/^.*<td[^>]*>\(.*\)<\/td>.*$/\1/;s/^$/no_name/')"
  echo "$htmlplatformlist" >./htmlplatform.txt
 fi

 gtfsshapelist="$(grep '^Stop' "$gtfsanalyzerfile" | sed 's/^Stop .*: \(.*\)/\1/')"
 anzgtfsstops="$(echo "$gtfsshapelist" | wc -l)"

 # GTFS-GPX wird immer erstellt, Relation-GPX nur bei unterschiedlicher Anzahl von Haltestellen.
 if [ ! "$busstops" == "$anzgtfsstops" ]; then
  echo "Liniennummer: ${busnumber}" >>./${datumjetzt}_fehlerdatei.txt
  echo "RelationID: ${relid}" >>./${datumjetzt}_fehlerdatei.txt
  echo "ShapeID: ${gtfsid}" >>./${datumjetzt}_fehlerdatei.txt
  echo "Haltestellen in cfg Datei: ${busstops}" >>./${datumjetzt}_fehlerdatei.txt
  echo "Haltestellen in GTFS-Daten: ${anzgtfsstops}" >>./${datumjetzt}_fehlerdatei.txt
  echo "**************************************" >>./${datumjetzt}_fehlerdatei.txt
  ./ptroute2gpx "${relid}" ../osmdata/route_bus.osm && mv *.gpx "$pathtoresults"/"${busnumber}"_"${relid}".gpx
  let errorcounter++
 fi

 cd "$pathtogtfsdata"
 gtfsanalyzer -g singleauto "$agencynumber" "$busnumber" "${gtfsid}" 
 cd -

 gtfsgpxfile="$(find ${pathtogtfsgpx} -name ${busnumber}_${gtfsid}.gpx)"
 gpxconvert
 mv -v ${gtfsgpxfile} ./results/


 echo "$gtfsshapelist" | tee ./gtfstohtml.tmp ./gtfs.txt 1>/dev/null
 echo ""
 # GTFS-HTML-Seite wird erstellt.
 gtfsdatatohtml

 # Überschrift wird angepasst
 osmname="$(echo "$relbereich" | grep '<tag k='\''name'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/' | sed 's/=&[^\;]*\;/=>/g;s/\//\\\//g')"
 osmzeilennr="$(grep -ni '^'"$relid"' ' "$cfgfile" | sed 's/\(^[^:]*\):.*/\1/' )"
 sed -i ''"$(("$osmzeilennr"-1))"'s/^#.*/# '"${osmname}"' (GTFS: '"${startstop}"' => '"${endstop}"')/' "$cfgfile"
 # Überschrift anpassen - Ende

 echo "Analysierte Daten:" | tee "$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"
 echo "Liniennummer: ${busnumber}" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"
 echo "Shape-ID: ${gtfsid}" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"
 echo "RelationID: ${relid}" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"

 if [ -n "$(echo "$stopstring" | grep 'No stop_position in route.')" ]; then
  echo "No stop_position in route." >>"$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"
 else
  echo "****************************** OSM-Stop-Data <=> GTFS-Data ******************************" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"
  echo "" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"
  diff -yiZd --width=100 ./htmlstop.txt ./gtfs.txt | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"
 fi

 echo ""

 echo "" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"

 if [ -n "$(echo "$platformstring" | grep 'No platform in route.')" ]; then
  echo "No platform in route." >>"$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"
 else
  echo "*************************** OSM-Platform-Data <=> GTFS-Data *****************************" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"
  echo "" | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"
  diff -yiZd --width=100 ./htmlplatform.txt ./gtfs.txt | tee -a "$pathtoresults/${datumjetzt}_osmgtfsdiff_${busnumber}_${relid}_${gtfsid}.txt"
 fi

# Bei gleicher Anzahl von Haltestellen wird das Datum aktualisiert.
if [ "$busstops" == "$anzgtfsstops" ]; then
 sed -i 's/\(^'"$relid"'.*\)\(....-..-..\)\(.*$\)/\1'`date +%Y-%m-%d`'\3/' "$cfgfile"
fi

mv ${gtfsanalyzerfile} ./results/

# Ende Verzweigung Überprüfung (relid/gtfsid usw.)
fi

# Ende a-Schleife
done

echo "" | tee -a ./${datumjetzt}_fehlerdatei.txt
if [ "$errorcounter" -gt "0" ]; then
 echo "Es wurden während der Bearbeitung ${errorcounter} Fehler in cfg-Datei gefunden (Siehe ./results/${datumjetzt}_fehlerdatei.txt)." | tee -a ./${datumjetzt}_fehlerdatei.txt
 errorcode="1"
else
 echo "Keine Fehler in cfg-Datei gefunden." | tee -a ./${datumjetzt}_fehlerdatei.txt
 errorcode="0"
fi
echo ""

mv ${datumjetzt}_fehlerdatei.txt ./results/
}

# Hinweis: Die Variable errorcode ist für den reibungslosen Verlauf zwischen den einzelnen
# Optionen verantwortlich.
# Beispiel: -a wird nur dann ausgeführt, wenn -g keine Fehler im Ablauf hatte. 

while getopts hadls:gm: opt

do 
 case $opt in

  h) # Hilfedatei
     usage
  ;;

  l) # Auflistung der nicht erfassten RelationIDs
     cfgfilecheck
     takstrelationlist="$(egrep -o 'relation id='\''[^'\'']*'\''' ../osmdata/route_bus.osm | sed 's/relation id='\''\(.*\)'\''/\1/')"
     allrealbuslines="$(cat "$cfgfile" | sed '/^#/d' | sed '/^$/d')"
     cfgrelidlist="$(echo "$allrealbuslines" | cut -d" " -f1)"
     echo "$takstrelationlist" >./relidlist.tmp
     echo "$cfgrelidlist" >>./relidlist.tmp
     relationlist="$(cat ./relidlist.tmp | sort -n | uniq -u)"
     anzrelid="$(echo "$relationlist" | wc -l)"

     echo ""
     echo "  *** Auflistung nicht erfasster bzw. ungültiger Routen in .cfg-Dateien. ***"
     echo ""
     echo "       RelID ref  Invstatus  Name"
     echo ""

     for ((i=1 ; i<=(("$anzrelid")) ; i++)); do
  
       relnumber=$(echo "$relationlist" | sed -n ""$i"p")
       relbereich=$(sed -n '/<relation id='\'''"$relnumber"''\''/,/<\/relation>/p' ../osmdata/route_bus.osm)
       refnumber="$(echo "$relbereich" | grep '<tag k='\''ref'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/')"
       relname="$(echo "$relbereich" | grep '<tag k='\''name'\''' | sed 's/.*v='\''\(.*\)'\''.*/\1/' | sed 's/=&gt\;/=>/g;s/=&#62\;/=>/g')"
       invalidcheck="$(grep '^'"$relnumber"' ' "$(dirname "$cfgfile")/invalidroutes.cfg")"
       if [ -n "$invalidcheck" ]; then
        invstatus="$(echo "$invalidcheck" | cut -f4 -d' ')"
        printf "%12d %-6s  %1d       %s\n" "$relnumber" "$refnumber" "$invstatus" "$relname"
       else
        printf "%12d %-6s          %s\n" "$relnumber" "$refnumber" "$relname"
       fi

     done

     echo ""
     echo "  Beschreibung Invalidstatus:"
     echo "  1 - Route doesn't exist"
     echo "  2 - Route variant doesn't exist"
     echo "  Gelöschte Routen in den OSM-Daten (Invalidstatus 0) werden nicht berücksichtigt."
     echo ""

     rm -f ./relidlist.tmp
  ;;
  
  g) # ShapeIDs überprüfen und ggf. aktualisieren.
     cfgfilecheck
     # Variable wird benötigt, um später Zeitstempel der log-Datei zurückzusetzen.
     gprocessstart="$(echo `date +%C%y%m%d%H%M.%S`)"
  
     gtfscheck | tee -a "$pathtoresults/${datumjetzt}_gtfsanalyse.txt"
     
     if [ -e "../tools/mail/sendamail" ]; then
      ../tools/mail/sendamail -g
     fi
    
     # Zeitstempel der Logdatei wird zurückgesetzt für Auswertung mit find im zip-Befehl.
     touch -t "$gprocessstart" "${pathtoresults}/${datumjetzt}_gtfsanalyse.txt" 
     zip "./backup/zipfiles/${datumjetzt}_checkgtfsid.zip" $(find "${pathtoresults}/" -type f -cnewer "$pathtoresults/${datumjetzt}_gtfsanalyse.txt") "$pathtoresults/${datumjetzt}_gtfsanalyse.txt"
     echo -e "\nAlle relevanten Analysedateien wurden gesichert und befinden sich in ./backup/zipfiles/${datumjetzt}_checkgtfsid.zip"

  ;;

  a) # Kompletter Durchlauf der HTML-Seitenerstellung
     cfgfilecheck
     # Variable wird benötigt, um später Zeitstempel der log-Datei zurückzusetzen.
     aprocessstart="$(echo `date +%C%y%m%d%H%M.%S`)"
  
     automaticprocess
     
     if [ -e "../tools/mail/sendamail" ]; then
      ../tools/mail/sendamail -a
     fi

     # Zeitstempel der Logdatei wird zurückgesetzt für Auswertung mit find im zip-Befehl.
     touch -t "$aprocessstart" "${pathtoresults}/${datumjetzt}_fehlerdatei.txt" 
     zip "./backup/zipfiles/${datumjetzt}_completehtmlgen.zip" $(find "${pathtoresults}/" -type f -cnewer "$pathtoresults/${datumjetzt}_fehlerdatei.txt") "$pathtoresults/${datumjetzt}_fehlerdatei.txt"
     echo -e "\nAlle relevanten Analysedateien wurden gesichert und befinden sich in ./backup/zipfiles/${datumjetzt}_completehtmlgen.zip"


  ;;

  s) # Einzelne Auswertung
     cfgfilecheck
     if [ "$OPTARG" == "all" ]; then
      echo "***** Full-Modus *****"
     elif [ "$OPTARG" == "diff" ]; then
      echo "***** Analyse-Modus *****"
     else
      usage
      echo "Kein gültiges Argument!"
      exit 1
     fi
 
     echo "Es kann nach [R]elationsID oder [S]hapeID ausgewertet werden."
     read -p "Wie soll ausgewertet werden? " relshapeausw

     unset relanswer
     unset shapeanswer

     case "$relshapeausw" in

      r|R) read -p "RelationID: " relanswer
        ;;

      s|S) read -p "ShapeID: " shapeanswer
        ;;

     esac

     relgtfsvergleich
     
     # gtfsroutes wird angepasst
     if [ "$OPTARG" == "all" ]; then
      $0 -m check "${!#}"
     fi

  ;;

  d) # Löschen der Arbeitsordner
  
     echo "Arbeitsordner werden gelöscht."

     rm -f ./results/*.*
     rm -f ./gtfsdata/gpx/*.*
     rm -f ./gtfsdata/results/*.*

  ;;
  
  m) # HTML-Seiten fehlender Routen, die nicht in OSM erfasst sind, erstellen.
     # ToDo: Sollte man auch die einfache Liste auf anzroutes=1 prüfen?
     
     if [ "$errorcode" == "1" ]; then
      echo -e "$(basename $0) Option -m Es wurden Fehler im vorangegangenen Prozess entdeckt.\nBitte erst prüfen und dann Skript neu starten und Prozess fortsetzen."
      if [ -e "../tools/mail/sendamail" ]; then
       ../tools/mail/sendamail -e
      fi
      exit 1
     fi
     
     unset errorcode

     cfgfilecheck
     
     # Variable wird benötigt, um später Zeitstempel der log-Datei zurückzusetzen.
     mprocessstart="$(echo `date +%C%y%m%d%H%M.%S`)"

     cfggtfslist="$(cat "$cfgfile" | sed '/^#/d' | sed '/^$/d' | cut -d" " -f5)"
     allgtfslist="$(cd "$pathtogtfsdata" && gtfsanalyzer -l allshapes ${agencynumber})"
     gtfslist="$(echo "$cfggtfslist";echo "$allgtfslist")"
     #Zum debuggen: sortgtfslist="$(echo "$gtfslist" | sort -n | uniq -u | sed -n '1,10p')"
     sortgtfslist="$(echo "$gtfslist" | sort -n | uniq -u)"
     anzshapes="$(echo "$sortgtfslist" | wc -l)"
     anzcfggtfsshapes="$(echo "$cfggtfslist" | wc -l)"
     
     # *** Funktionen ***
     headcounter="0"
     # Tabellenkopf für detaillierte Liste von GTFS-Routen
     # ohne äquivalente Route in Openstreetmap
     htmlkopf1() {
      let headcounter++
      echo " <div id=\"gtfstab2\" class=\"gtfs2\">" >./addgtfstohtml_kopf1.txt
      echo " <h4>${headcounter}. Detailed list of GTFS shapes (without similar routes in Openstreetmap data)</h4>" >>./addgtfstohtml_kopf1.txt
      echo "  <table>" >>./addgtfstohtml_kopf1.txt
      echo "   <tr>" >>./addgtfstohtml_kopf1.txt
      echo "    <th>Busnumber</th>" >>./addgtfstohtml_kopf1.txt
      echo "    <td class=\"small green\">From</td>" >>./addgtfstohtml_kopf1.txt
      echo "    <td class=\"small green\">To</td>" >>./addgtfstohtml_kopf1.txt
      echo "    <td class=\"small green\">ShapeID</td>" >>./addgtfstohtml_kopf1.txt
      echo "    <td class=\"small green \">Stops</td>" >>./addgtfstohtml_kopf1.txt
      echo "    <td class=\"green \">Map</td>" >>./addgtfstohtml_kopf1.txt
      echo "   </tr>" >>./addgtfstohtml_kopf1.txt
     }
     
     # Tabellenkopf für einfache Liste von GTFS-Routen
     # ohne äquivalente Route in Openstreetmap
     htmlkopf2() {
      let headcounter++
      echo " <div id=\"gtfstab3\" class=\"gtfs3\">" >./addgtfstohtml_kopf2.txt
      if [ "$headcounter" -gt "1" ]; then
       echo " <h4>${headcounter}. Simple list of GTFS shapes (without similar routes in Openstreetmap data; Continuation)</h4>" >>./addgtfstohtml_kopf2.txt
      else
       echo " <h4>${headcounter}. Simple list of GTFS shapes (without similar routes in Openstreetmap data)</h4>" >>./addgtfstohtml_kopf2.txt
      fi
      echo "  <table>" >>./addgtfstohtml_kopf2.txt
      echo "   <tr>" >>./addgtfstohtml_kopf2.txt
      echo "    <th>Busnumber</th>" >>./addgtfstohtml_kopf2.txt
      echo "    <td class=\"small green\">Destination (trip_headsign)</td>" >>./addgtfstohtml_kopf2.txt
      echo "    <td class=\"small green\">Agency Name</td>" >>./addgtfstohtml_kopf2.txt
      echo "    <td class=\"small green\">RouteID</td>" >>./addgtfstohtml_kopf2.txt
      echo "    <td class=\"green\">ShapeID</td>" >>./addgtfstohtml_kopf2.txt
      echo "   </tr>" >>./addgtfstohtml_kopf2.txt
     }
     
     # Tabellenkopf für Liste mit äquivalenter Route in Openstreetmap
     htmlkopf3() {
      let headcounter++
      echo " <div id=\"gtfstab4\" class=\"gtfs4\">" >./addgtfstohtml_kopf3.txt
      echo " <h4>${headcounter}. List of GTFS shapes (with similar routes in Openstreetmap data)</h4>" >>./addgtfstohtml_kopf3.txt
      echo "  <table>" >>./addgtfstohtml_kopf3.txt
      echo "   <tr>" >>./addgtfstohtml_kopf3.txt
      echo "    <th>Busnumber</th>" >>./addgtfstohtml_kopf3.txt
      echo "    <td class=\"small green\">Destination (trip_headsign)</td>" >>./addgtfstohtml_kopf3.txt
      echo "    <td class=\"small green\">Agency Name</td>" >>./addgtfstohtml_kopf3.txt
      echo "    <td class=\"small green\">RouteID</td>" >>./addgtfstohtml_kopf3.txt
      echo "    <td class=\"small green\">ShapeID</td>" >>./addgtfstohtml_kopf3.txt
      echo "    <td class=\"small green\">Stops</td>" >>./addgtfstohtml_kopf3.txt
      echo "    <td class=\"small green\">Map</td>" >>./addgtfstohtml_kopf3.txt
      echo "    <td class=\"grey\">pta OSM</td>" >>./addgtfstohtml_kopf3.txt
      echo "   </tr>" >>./addgtfstohtml_kopf3.txt
     }
     
     htmlfooter() {
      # Seitenfuss wird erstellt
      echo "</main>" >./addgtfstohtml_fuss.txt
      echo "<footer>" >>./addgtfstohtml_fuss.txt
      echo "<p>GTFS-Data: <a href=\"https://www.rejseplanen.dk/\">rejseplanen.dk</a><br>Data is under <a href=\"http://creativecommons.org/licenses/by-nd/3.0/\">Creative Commons BY-ND 3.0</a> License.</p>" >>./addgtfstohtml_fuss.txt
      echo "<p id=\"createdate\">Page created on `date +%Y-%m-%d`.</p>" >>./addgtfstohtml_fuss.txt
      echo "</footer>" >>./addgtfstohtml_fuss.txt
      echo "</body>" >>./addgtfstohtml_fuss.txt
      echo "</html>" >>./addgtfstohtml_fuss.txt
     }
     
     if [[ "$OPTARG" == [0-9]* ]] && [ "$OPTARG" -le "$anzshapes" -a ! "$OPTARG" == "0" ]; then
      smallprocess="yes"
      plimit="$OPTARG"
      echo "Es werden die ersten ${plimit} von ${anzshapes} Routen mit Liste und Kartenansicht erstellt."
     elif [ "$OPTARG" == "all" ]; then
      echo "Es werden alle ${anzshapes} Routen mit Liste und Kartenansicht erstellt."
      allprocess="yes"      
     elif [ "$OPTARG" == "no" ]; then
      noprocess="yes"
      echo "Alle ${anzshapes} Routen werden ohne Liste und Kartenansicht erstellt."
     elif [ "$OPTARG" == "check" ]; then
      echo "GTFS-HTML-Seite wird gecheckt."
      gtfshtmlfile="../htmlfiles/gtfsroutes.html"
      if [ ! -e "$gtfshtmlfile" ]; then
       echo "HTML-Seite ${gtfshtmlfile} existiert nicht."
       echo "Bitte erst mit $0 -m [param] erstellen."
       break
      fi
      gtfschecklist="$(sed -n '/<div id="gtfstab4"/,/<\/div>/p' "$gtfshtmlfile" | sed -n 's/^.*gtfsid[3]tab\([[:digit:]]*\).*$/\1/p')"
      newgtfsidlist="$(echo -e "$gtfschecklist\n$cfggtfslist" | sort -n | uniq -u)"
      anznewgtfsid="$(echo "$newgtfsidlist" | sed '/^$/d' | wc -l)"
      grep 'gtfsid3tab' "$gtfshtmlfile" | sed 's/^ *<tr><th>//' >./addgtfstohtml3.txt
      sed '/<div id="gtfstab4"/,$d' <"$gtfshtmlfile" >./newgtfsfile.tmp
      
      if [ "$anznewgtfsid" -gt "0" ]; then

        # headcounter wird nur für htmlkopf3 benötigt. Der entsprechende Wert wird aus der aktuellen
        # gtfsroutes.html ermittelt $((wert - 1)), weil in Funktion htmlkopf3 wieder +1 dazugezählt wird.
        headcounter=$(("$(sed -n 's/.*<h4>\([[:digit:]]*\)\. List of GTFS shapes.*/\1/p' "$gtfshtmlfile")" - 1))
        
        # alte Seite sichern.
        cp "$gtfshtmlfile" ./backup/${datumjetzt}_gtfsroutes.html
        
        htmlkopf3
        htmlfooter
        echo "Es wurden ${anznewgtfsid} neue ShapeIDs gefunden."
        echo "GTFS-Routen werden in HTML-Seite ${gtfshtmlfile} aktualisiert."

        for ((u=1 ; u<=(("$anznewgtfsid")) ; u++)); do
     
         printf "ShapeID %d/%d wird verarbeitet ...\r" "$u" "$anznewgtfsid"

         gtfsshapeid="$(echo "$newgtfsidlist" | sed -n ''$u'p')"
         
         # Alte Zeile wird aus Tabelle 1 bzw. 2 gelöscht.
         sed -i '/gtfsid[12]tab'"$gtfsshapeid"'/d' ./newgtfsfile.tmp
         
         analysisresult="$(cd "$pathtogtfsdata" && gtfsanalyzer -l singleshape "$gtfsshapeid")"
         anzroutes="$(echo "$analysisresult" | sed -n 's/^Gefundene Routen : \(.*$\)/\1/p')"
         if [ "$anzroutes" -gt "1" ]; then
          echo "Mehrere Routen zur ShapeID gefunden. Skript wird abgebrochen."
          exit
         fi
         busnumber="$(echo "$analysisresult" | sed -n 's/^route_short_name : \(.*$\)/\1/p')"
         routeid="$(echo "$analysisresult" | sed -n 's/^RouteID *: \(.*$\)/\1/p')"
         agencyname="$(echo "$analysisresult" | sed -n 's/^Agency name *: \(.*$\)/\1/p')"
         tripheadsign="$(echo "$analysisresult" | sed -n 's/^trip_headsign *: \(.*$\)/\1/p')"
      
         echo "${busnumber}</th><td class=\"small\">${tripheadsign}</td><td class=\"small\">${agencyname}</td><td class=\"small\">${routeid}</td><td id=\"gtfsid3tab${gtfsshapeid}\" class=\"small\">${gtfsshapeid}</td><td class=\"small\"><a href=\"gtfs/${gtfsshapeid}.html\"><i class=\"fa-td fa fa-list fa-1x\"></i></a></td><td class=\"small\"><a href=\"gtfs/maps/${gtfsshapeid}.html\"><i class=\"fa-td fa fa-map fa-1x\"></i></a></td><td class=\"pta\"><a href=\"osmroutes.html#route${busnumber}\">&nbsp;&nbsp;&nbsp;</a></td></tr>" >>./addgtfstohtml3.txt
     
         if [ ! -e "../htmlfiles/gtfs/${gtfsshapeid}.html" -o ! -e "../htmlfiles/gtfs/maps/${gtfsshapeid}.html" -o ! -e "../htmlfiles/gtfs/maps/${gtfsshapeid}.js" -o ! -e "../htmlfiles/gtfs/maps/${gtfsshapeid}.gpx" ]; then
          echo "Es fehlen HTML-Komponenten im Ordner htmlfiles/gtfs bzw. htmlfiles/gtfs/maps"
          echo "Seiten müssen erst für ShapeID ${gtfsshapeid} neu erstellt werden mit:"
          # Dieser Befehl darf hier nicht ausgeführt werden, weil Option -m auch nach
          # Option -s ausgeführt wird. Dann kommt es ggf. zu Komplikationen.
          echo "$0 -s all [NUM]"
         fi
         
        done
        
        cat ./addgtfstohtml3.txt | sort -n | sed 's/^/   <tr><th>/' >./sortaddgtfstohtml3.txt
        echo "  </table>" >>./sortaddgtfstohtml3.txt
        echo " </div>" >>./sortaddgtfstohtml3.txt
        
        # Neue Seite wird erstellt.
        cat ./newgtfsfile.tmp ./addgtfstohtml_kopf3.txt ./sortaddgtfstohtml3.txt ./addgtfstohtml_fuss.txt >"$gtfshtmlfile"
      
      else
      
        echo "Keine neu aufgenommen Routen gefunden."
        
      fi
      
      break
      
     else
      echo "Die Anzahl muss weniger oder gleich der Anzahl der ShapeIDs sein (${anzshapes}), oder mit all, no bzw. check definiert werden."
      exit 1
     fi
        
     # ****** HTML-Seitenerstellung ******
     
     htmlfooter
     
     # Seitenkopf wird erstellt.
     echo "<!DOCTYPE html>" >./addgtfstohtml_kopf0.txt
     echo "<html lang=\"de\">" >>./addgtfstohtml_kopf0.txt
     echo "<head>" >>./addgtfstohtml_kopf0.txt
     echo "  <meta content=\"text/html; charset=utf-8\" http-equiv=\"content-type\">" >>./addgtfstohtml_kopf0.txt
     echo "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">" >>./addgtfstohtml_kopf0.txt
     echo "  <meta name=\"robots\" content=\"nofollow\">" >>./addgtfstohtml_kopf0.txt
     echo "  <link rel=\"stylesheet\" href=\"css/fonts.css\">" >>./addgtfstohtml_kopf0.txt
     echo "  <link rel=\"stylesheet\" href=\"css/font-awesome.css\">" >>./addgtfstohtml_kopf0.txt
     echo "  <link rel=\"stylesheet\" href=\"css/style.css\">" >>./addgtfstohtml_kopf0.txt
     echo "</head>" >>./addgtfstohtml_kopf0.txt
     echo "<body>" >>./addgtfstohtml_kopf0.txt
     echo " <div class=\"gtfsshapes\"></div>" >>./addgtfstohtml_kopf0.txt
     echo " <header>" >>./addgtfstohtml_kopf0.txt
     echo "  <h1>List of GTFS shapes (incomplete)</h1>" >>./addgtfstohtml_kopf0.txt
     echo "  <h2 style=\"text-align: center;\">Data from rejseplanen.dk (CC-BY-ND 3.0)</h2>" >>./addgtfstohtml_kopf0.txt
     echo " </header>" >>./addgtfstohtml_kopf0.txt
     echo "<main>" >>./addgtfstohtml_kopf0.txt
     
     echo " <div class=\"headerallg headergtfs\">" >>./addgtfstohtml_kopf0.txt
     echo "  <p>" >>./addgtfstohtml_kopf0.txt
     echo "   <img id=\"ptaroutelogo\" src=\"images/ptaroute.svg\"><span>OSM</span><a href=\"osmroutes.html\">pta routes analysis</a><br>" >>./addgtfstohtml_kopf0.txt
     echo "   <img id=\"ptastoplogo\" src=\"images/ptastop.svg\"><span>OSM</span><a href=\"stop_areas.html\">pta stop area analysis</a>" >>./addgtfstohtml_kopf0.txt
     echo "   <a href=\"../index.html\"><img id=\"logo\" src=\"images/logo.svg\"></a>" >>./addgtfstohtml_kopf0.txt
     echo "  </p>" >>./addgtfstohtml_kopf0.txt
     echo "  <hr>" >>./addgtfstohtml_kopf0.txt
     echo "  <p>" >>./addgtfstohtml_kopf0.txt
     echo "   <strong>List of tables</strong>" >>./addgtfstohtml_kopf0.txt
     echo "  </p>" >>./addgtfstohtml_kopf0.txt
     echo "  <p>" >>./addgtfstohtml_kopf0.txt
     if [ "$smallprocess" == "yes" ]; then
      echo "   1. <a href=\"#gtfstab2\">Detailed list of GTFS shapes (without similar routes in Openstreetmap data)</a><br>" >>./addgtfstohtml_kopf0.txt
      echo "   2. <a href=\"#gtfstab3\">Simple list of GTFS shapes (without similar routes in Openstreetmap data)</a><br>" >>./addgtfstohtml_kopf0.txt
      echo "   3. <a href=\"#gtfstab4\">List of GTFS shapes (with similar routes in Openstreetmap data)</a>" >>./addgtfstohtml_kopf0.txt
     elif [ "$allprocess" == "yes" ]; then
      echo "   1. <a href=\"#gtfstab2\">Detailed list of GTFS shapes (without similar routes in Openstreetmap data)</a><br>" >>./addgtfstohtml_kopf0.txt
      echo "   2. <a href=\"#gtfstab4\">List of GTFS shapes (with similar routes in Openstreetmap data)</a>" >>./addgtfstohtml_kopf0.txt
     elif [ "$noprocess" == "yes" ]; then
      echo "   1. <a href=\"#gtfstab3\">Simple list of GTFS shapes (without similar routes in Openstreetmap data)</a><br>" >>./addgtfstohtml_kopf0.txt
      echo "   2. <a href=\"#gtfstab4\">List of GTFS shapes (with similar routes in Openstreetmap data)</a>" >>./addgtfstohtml_kopf0.txt
     fi
     echo "  </p>" >>./addgtfstohtml_kopf0.txt
     echo "</div>" >>./addgtfstohtml_kopf0.txt
     
     if [ "$smallprocess" == "yes" -o "$allprocess" == "yes" ]; then
      htmlkopf1
     fi
     if [ "$smallprocess" == "yes" -o "$noprocess" == "yes" ]; then
      htmlkopf2
     fi

     # ***** Hier werden die ersten beiden Tabellen generiert. *****
     counterm="0"
     echo "*** Analyselogfile - Auflistung von fehlenden Routen in OSM-Daten (Option -m) ***" >./results/${datumjetzt}_analyse_missingroutes.txt
     for ((t=1 ; t<=(("$anzshapes")) ; t++)); do
     
      if ([[ "$OPTARG" == [0-9]* ]] && [ "$t" -gt "$plimit" ]) || [ "$noprocess" == "yes" ]; then
       printf "Route %d/%d wird verarbeitet ...\r" "$t" "$anzshapes"
      else
       printf "\nRoute %d/%d wird verarbeitet ...\n" "$t" "$anzshapes"
      fi

      rm -f ./gtfs.txt
      rm -f ./htmlstop.txt
      rm -f ./htmlplatform.txt
      rm -f ./gtfstohtml.txt

      gtfsshapeid="$(echo "$sortgtfslist" | sed -n ''$t'p')"
      analysisresult="$(cd "$pathtogtfsdata" && gtfsanalyzer -l servicedays "$gtfsshapeid")"
      anzroutes="$(echo "$analysisresult" | sed -n 's/^Gefundene Routen : \(.*$\)/\1/p')"
      busnumber="$(echo "$analysisresult" | sed -n 's/^route_short_name : \(.*$\)/\1/p')"
      # sort und uniq: Weil es sehr unwahrscheinlich ist, das bei gleicher Shape
      # das Verkehrsmittel wechselt. Wird gebraucht, um Hafenfähren rauszufiltern.
      # Auf anzroutes=1 wird dann später auch noch geprüft.
      routetype="$(echo "$analysisresult" | sed -n 's/^route_type *: \(.*$\)/\1/p' | sort | uniq)"
      
      # Hier werden die Hafenfähren rausgefiltert. Alles was nicht Fähre ist, wird bearbeitet.
      # Warum negieren und nicht auf 3 (Bus) prüfen? Weil die S-Busse den nicht offiziellen
      # route_type 700 in den GTFS-Daten haben.
      if [ ! "$routetype" == "4 (Ferry)" ]; then
      
       # Variablen, die nur für Parameter no bzw. wenn nur ein Teil der Liste
       # mit Stopliste und Mapansicht generiert wird.
       if ([[ "$OPTARG" == [0-9]* ]] && [ "$t" -gt "$plimit" ]) || [ "$noprocess" == "yes" ]; then
        routeid="$(echo "$analysisresult" | sed -n 's/^RouteID *: \(.*$\)/\1/p')"
        agencyname="$(echo "$analysisresult" | sed -n 's/^Agency name *: \(.*$\)/\1/p')"
        tripheadsign="$(echo "$analysisresult" | sed -n 's/^trip_headsign *: \(.*$\)/\1/p')"
       fi
       anzgtfsstops="$(echo "$sortgtfslist" | wc -l)"
      
       if ([[ "$OPTARG" == [0-9]* ]] && [ "$t" -le "$plimit" ]) || [ "$allprocess" == "yes" ]; then
     
        cd "${pathtogtfsdata}"
         gtfsanalyzer -s singleauto "$agencynumber" "$busnumber" "$gtfsshapeid"
        cd -
        gtfsanalyzerfile="$(find ${pathtogtfsresults} -name *shapesingle_${gtfsshapeid}.txt | sort -r | sed -n '1p')"
        if [ -z "$gtfsanalyzerfile" ]; then
         echo "Schwerwiegender Fehler! Es konnte keine Analysedatei von gtfsanalyzer gefunden werden." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
         echo "Dieses Skript wird abgebrochen!" | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
         echo "GTFSID: ${gtfsshapeid}" | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
         let counterm++
         exit 1
        fi
      
        if [ ! "$(sed -n 's/^Verkehrstage des ausgewerteten Trips (Mo-So): \(.*\)/\1/p' "$gtfsanalyzerfile")" == "- - - - - - -" ]; then
      
          gtfsshapelist="$(grep '^Stop' "$gtfsanalyzerfile" | sed 's/^Stop .*: \(.*\)/\1/')"
          anzgtfsstops="$(echo "$gtfsshapelist" | wc -l)"
          echo "$gtfsshapelist" | tee ./gtfstohtml.tmp ./gtfs.txt 1>/dev/null
          # Werte aus gtfsanalyzerfile auslesen (für trip example (HTML-Seite))
          evaluatedid="$(sed -n 's/^Augewertete Trip-ID: \([[:digit:]]*\) .*/\1/p' "$gtfsanalyzerfile")"
          triptime="$(sed -n 's/^Augewertete Trip-ID:.*(\(.*\))$/\1/p' "$gtfsanalyzerfile" | sed 's/ Uhr//g')"
          # .$ bzw .*$ wandelt ggf. DOS-Zeilenumbrüche in Unix-Zeilenumbrüche um.
          # Die Ausgabe soll einzeilig erfolgen.
          adddate="$(sed -n '/^Zusätzliche Verkehrstage/,/^Fährt nicht an diesen Tagen\|^Dauer der Fahrt/p' "$gtfsanalyzerfile" | sed -n 's/\(^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*$/\1,/p' | tr '\n' ' ')"
          rmdate="$(sed -n '/^Fährt nicht an diesen Tagen/,/^Dauer der Fahrt/p' "$gtfsanalyzerfile" | sed -n 's/\(^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*$/\1,/p' | tr '\n' ' ')"
          # Bei der Umwandlung ist etwas getrickst worden.
          # Zunächst werden alle - in @ und alle x in # umgewandelt, bevor awesome-Element eingefügt wird.
          # Ansonsten würden die x und - in Awesome-Element auch mit umgewandelt.
          servicedays="$(sed -n 's/^Verkehrstage des ausgewerteten Trips (Mo-So): \(.*\)/\1/p' "$gtfsanalyzerfile" | sed 's/-/@/g;s/x/#/g;s/@/<i class="fa-div fa fa-times fa-1x"><\/i>/g;s/#/<i class="fa-div fa fa-check fa-1x"><\/i>/g')"
          serviceinterval="$(sed -n 's/^Gültigkeit des ausgewerteten Trips (von-bis einschließlich): \(....\)\(..\)\(..\)-\(....\)\(..\)\(..\)/\1-\2-\3 - \4-\5-\6/p' "$gtfsanalyzerfile")"
      
          # Es wird nur bei einem Analyseergebnis (gtfsanalyzer -l servicedays [shapeid]) von einer gefundenen Route die Seiten erstellt.
          # Bei mehreren gefundenen Routen, was relativ selten vorkommt, könnte man hier noch weiter analysieren.
          if [ "$anzroutes" == "1" ]; then
        
           # Start- und Endhaltestelle werden ermittelt.
           startstop="$(sed -n '1p' ./gtfstohtml.tmp)"
           endstop="$(sed -n '$p' ./gtfstohtml.tmp)"

           gtfsdatatohtml
         
           cd "$pathtogtfsdata"
           gtfsanalyzer -g singleauto "$agencynumber" "$busnumber" "${gtfsshapeid}" 
           cd -

           gtfsgpxfile="$(find ${pathtogtfsgpx} -name ${busnumber}_${gtfsshapeid}.gpx)"
           gpxconvert
           mv -v ${gtfsgpxfile} ./results/
         
           echo "${busnumber}</th><td class=\"small\">${startstop}</td><td class=\"small\">${endstop}</td><td id=\"gtfsid1tab${gtfsshapeid}\" class=\"small\">${gtfsshapeid}</td><td class=\"small\"><a href=\"gtfs/${gtfsshapeid}.html\"><i class=\"fa-td fa fa-list fa-1x\"></i></a></td><td><a href=\"gtfs/maps/${gtfsshapeid}.html\"><i class=\"fa-td fa fa-map fa-1x\"></i></a></td></tr>" >>./addgtfstohtml.txt
         
          else
          
           let counterm++
           echo "Mehrere Routen bei gleicher ShapeID gefunden (ShapeID: ${gtfsshapeid})." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
           echo "Route wird nicht in HTML-Seite aufgenommen." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt

          fi
        
        else
      
         let counterm++
         # plimit wird um 1 erhöht, damit auch wirklich die angegebene Anzahl von Seiten mit Listen- und Mapansicht erstellt wird.
         let plimit++
         echo "Keine dauerhaften Verkehrstage (ShapeID: ${gtfsshapeid})." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
         echo "HTML-Seitenerstellung wir nicht durchgeführt." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
       
        fi 
      
       else
        
         # Es wird nur bei einem Analyseergebnis (gtfsanalyzer -l servicedays [shapeid]) von einer gefundenen Route die Seiten erstellt.
         # Bei mehreren gefundenen Routen, was relativ selten vorkommt, könnte man hier noch weiter analysieren.
         if [ "$anzroutes" == "1" ]; then
          serviceresult="$(echo "$analysisresult" | grep '^[01] [01] [01] [01] [01] [01] [01]' | sort | uniq)"
          # Hier wird auf dauerhafte Verkehrstage geprüft.
          if [ "$serviceresult" == "0 0 0 0 0 0 0" ]; then
           let counterm++
           echo "Keine dauerhaften Verkehrstage (ShapeID: ${gtfsshapeid})." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
           echo "Route wird nicht in HTML-Seite aufgenommen." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
          else
          echo "${busnumber}</th><td class=\"small\">${tripheadsign}</td><td class=\"small\">${agencyname}</td><td class=\"small\">${routeid}</td><td id=\"gtfsid2tab${gtfsshapeid}\">${gtfsshapeid}</td></tr>" >>./addgtfstohtml2.txt
          fi
         else
          let counterm++
          echo "Mehrere Routen bei gleicher ShapeID gefunden (ShapeID: ${gtfsshapeid})." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
          echo "Route wird nicht in HTML-Seite aufgenommen." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
         fi
      
       fi
      
      else
     
       let counterm++
       echo "Route ${busnumber} mit ShapeID ${gtfsshapeid} ist keine Busroute." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
       echo "Route wird nicht in HTML-Seite aufgenommen." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt

      fi

     done
     
     # ***** Hier wird die dritte Tabelle generiert. *****
     
     htmlkopf3
     echo "GTFS-Routen mit äquivalenter Route in OSM werden verarbeitet."
     
     for ((u=1 ; u<=(("$anzcfggtfsshapes")) ; u++)); do
     
      printf "Route %d/%d wird verarbeitet ...\r" "$u" "$anzcfggtfsshapes"

      gtfsshapeid="$(echo "$cfggtfslist" | sed -n ''$u'p')"
      analysisresult="$(cd "$pathtogtfsdata" && gtfsanalyzer -l singleshape "$gtfsshapeid")"
      #anzroutes="$(echo "$analysisresult" | sed -n 's/^Gefundene Routen : \(.*$\)/\1/p')"
      busnumber="$(echo "$analysisresult" | sed -n 's/^route_short_name : \(.*$\)/\1/p')"
      routeid="$(echo "$analysisresult" | sed -n 's/^RouteID *: \(.*$\)/\1/p')"
      agencyname="$(echo "$analysisresult" | sed -n 's/^Agency name *: \(.*$\)/\1/p')"
      tripheadsign="$(echo "$analysisresult" | sed -n 's/^trip_headsign *: \(.*$\)/\1/p')"
      
      echo "${busnumber}</th><td class=\"small\">${tripheadsign}</td><td class=\"small\">${agencyname}</td><td class=\"small\">${routeid}</td><td id=\"gtfsid3tab${gtfsshapeid}\" class=\"small\">${gtfsshapeid}</td><td class=\"small\"><a href=\"gtfs/${gtfsshapeid}.html\"><i class=\"fa-td fa fa-list fa-1x\"></i></a></td><td class=\"small\"><a href=\"gtfs/maps/${gtfsshapeid}.html\"><i class=\"fa-td fa fa-map fa-1x\"></i></a></td><td class=\"pta\"><a href=\"osmroutes.html#route${busnumber}\">&nbsp;&nbsp;&nbsp;</a></td></tr>" >>./addgtfstohtml3.txt
     
     done
     
     if [ -e ./addgtfstohtml.txt ]; then
      cat ./addgtfstohtml.txt | sort -n | sed 's/^/   <tr><th>/' >./sortaddgtfstohtml.txt
      echo "  </table>" >>./sortaddgtfstohtml.txt
      echo " </div>" >>./sortaddgtfstohtml.txt
     fi
     if [ -e ./addgtfstohtml2.txt ]; then
      cat ./addgtfstohtml2.txt | sort -n | sed 's/^/   <tr><th>/' >./sortaddgtfstohtml2.txt
      echo "  </table>" >>./sortaddgtfstohtml2.txt
      echo " </div>" >>./sortaddgtfstohtml2.txt
     fi
     cat ./addgtfstohtml3.txt | sort -n | sed 's/^/   <tr><th>/' >./sortaddgtfstohtml3.txt
     echo "  </table>" >>./sortaddgtfstohtml3.txt
     echo " </div>" >>./sortaddgtfstohtml3.txt
     
     if [ "$smallprocess" == "yes" ]; then
      cat ./addgtfstohtml_kopf0.txt ./addgtfstohtml_kopf1.txt ./sortaddgtfstohtml.txt ./addgtfstohtml_kopf2.txt ./sortaddgtfstohtml2.txt ./addgtfstohtml_kopf3.txt ./sortaddgtfstohtml3.txt ./addgtfstohtml_fuss.txt >../htmlfiles/gtfsroutes.html
     elif [ "$allprocess" == "yes" ]; then
      cat ./addgtfstohtml_kopf0.txt ./addgtfstohtml_kopf1.txt ./sortaddgtfstohtml.txt ./addgtfstohtml_kopf3.txt ./sortaddgtfstohtml3.txt ./addgtfstohtml_fuss.txt >../htmlfiles/gtfsroutes.html
     elif [ "$noprocess" == "yes" ]; then
      cat ./addgtfstohtml_kopf0.txt ./addgtfstohtml_kopf2.txt ./sortaddgtfstohtml2.txt ./addgtfstohtml_kopf3.txt ./sortaddgtfstohtml3.txt ./addgtfstohtml_fuss.txt >../htmlfiles/gtfsroutes.html
     fi

     echo ""
     if [ "$counterm" == "0" ]; then
      echo "Durchlauf beendet am `date +%d.%m.%Y` um `date +%H:%M` Uhr. Keine nennenswerten Vorkommnisse." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
     else
      echo "Durchlauf beendet am `date +%d.%m.%Y` um `date +%H:%M` Uhr. Es gibt ${counterm} Einträge in ./results/${datumjetzt}_analyse_missingroutes.txt." | tee -a ./results/${datumjetzt}_analyse_missingroutes.txt
     fi
     
     if [ -e "../tools/mail/sendamail" ]; then
      ../tools/mail/sendamail -m
     fi
     
     # *** HTML-Seitenerstellung - Ende ***
     
     # Aufräumen
     rm -f ./addgtfstohtml_kopf0.txt
     rm -f ./addgtfstohtml_kopf1.txt
     rm -f ./addgtfstohtml_kopf2.txt
     rm -f ./addgtfstohtml.txt
     rm -f ./addgtfstohtml2.txt
     rm -f ./sortaddgtfstohtml.txt
     rm -f ./sortaddgtfstohtml2.txt
     rm -f ./addgtfstohtml_fuss.txt
     
     # Zeitstempel der Logdatei wird zurückgesetzt für Auswertung mit find im zip-Befehl.
     touch -t "$mprocessstart" "${pathtoresults}/${datumjetzt}_analyse_missingroutes.txt"
     zip "./backup/zipfiles/${datumjetzt}_completehtmlgen.zip" $(find "${pathtoresults}/" -type f -cnewer "$pathtoresults/${datumjetzt}_analyse_missingroutes.txt") "$pathtoresults/${datumjetzt}_analyse_missingroutes.txt"
     echo -e "\nAlle relevanten Analysedateien wurden gesichert und befinden sich in ./backup/zipfiles/${datumjetzt}_completehtmlgen.zip"

  ;;

 esac
done

# Aufräumen
rm -f ./gtfs.txt
rm -f ./htmlstop.txt
rm -f ./htmlplatform.txt
rm -f ./gtfstohtml.txt
rm -f ./gtfstohtml.tmp
rm -f ./gtfstohtml_fuss.txt
rm -f ./gtfstohtml_kopf.txt
rm -f ./addgtfstohtml_kopf0.txt
rm -f ./addgtfstohtml_kopf1.txt
rm -f ./addgtfstohtml_kopf2.txt
rm -f ./addgtfstohtml_kopf3.txt
rm -f ./addgtfstohtml.txt
rm -f ./addgtfstohtml2.txt
rm -f ./addgtfstohtml3.txt
rm -f ./sortaddgtfstohtml.txt
rm -f ./sortaddgtfstohtml2.txt
rm -f ./sortaddgtfstohtml3.txt
rm -f ./addgtfstohtml_fuss.txt
rm -f ./newgtfsfile.tmp
rm -f ./${datumjetzt}errorvar.tmp

