#!/bin/bash
# Folgende Dateien und Ordner werden berücksichtigt:
# index.html und alle Dateien und Ordner in htmlfiles (rekursiv)

exec &> >(tee -a ./backup/`date +%Y%m%d_%H%M`_gitptaweb.log)

echo "***** Versionsverwaltung der pta-Webseiten mit git *****"
echo "Datum  : `date +%d.%m.%Y`"
echo "Uhrzeit: `date +%H:%S` Uhr"

# ***** Evtl. fehlende Webseiten werden anhand der config-Datei real_bus_stops.cfg ermittelt *****
webcheckerrorcounter=0
echo "**** 1. Überprüfung der Website ****"
echo "(Auf evtl. fehlende Dateien, die in gtfsroutes.html in dem Element div.gtfs2 verknüpft sind, wird zur Zeit nicht getestet.)"
osmidlist="$(cat config/real_bus_stops.cfg | sed '/^#/d' | cut -f1 -d" ")"
gtfsidlist="$(cat config/real_bus_stops.cfg | sed '/^#/d' | cut -f5 -d" ")"

if [ ! -e htmlfiles/osmroutes.html ]; then
 let webcheckerrorcounter++
 echo "Datei htmlfiles/osmroutes.html fehlt."
fi
if [ ! -e htmlfiles/gtfsroutes.html ]; then
 let webcheckerrorcounter++
 echo "Datei htmlfiles/gtfsroutes.html fehlt."
fi
if [ ! -e htmlfiles/stop_areas.html ]; then
 let webcheckerrorcounter++
 echo "Datei htmlfiles/stop_areas.html fehlt."
fi

anzosmids="$(echo "$osmidlist" | sed '/^$/d' | wc -l)"
for printline in $(seq 1 "$anzosmids"); do
 osmid="$(echo "$osmidlist" | sed -n ''$printline'p')"
 if [ ! -e htmlfiles/osm/${osmid}.html ]; then
  osmhtmllist+="htmlfiles/osm/${osmid}.html"$'\n'
 fi
done

osmlist="$(echo "$osmhtmllist" | sed '/^$/d')"

anzgtfsids="$(echo "$gtfsidlist" | sed '/^$/d' | wc -l)"
for printline2 in $(seq 1 "$anzgtfsids"); do
 gtfsid="$(echo "$gtfsidlist" | sed -n ''$printline2'p')"
 if [ ! -e htmlfiles/gtfs/${gtfsid}.html ]; then
  gtfshtmllist+="htmlfiles/gtfs/${gtfsid}.html"$'\n'
 fi
 if [ ! -e htmlfiles/gtfs/maps/${gtfsid}.html ]; then
  gtfshtmllist+="htmlfiles/gtfs/maps/${gtfsid}.html"$'\n'
 fi
 if [ ! -e htmlfiles/gtfs/maps/${gtfsid}.gpx ]; then
  gtfshtmllist+="htmlfiles/gtfs/maps/${gtfsid}.gpx"$'\n'
 fi
 if [ ! -e htmlfiles/gtfs/maps/${gtfsid}.js ]; then
  gtfshtmllist+="htmlfiles/gtfs/maps/${gtfsid}.js"$'\n'
 fi
done

gtfslist="$(echo "$gtfshtmllist" | sed '/^$/d')"

# Evtl. fehlende Webseiten werden anhand der config-Datei invalidroutes.cfg ermittelt.
osmidlist2="$(cat config/invalidroutes.cfg | sed '/^#/d' | egrep ' 1|2 *$' | cut -f1 -d" ")"
anzosmids2="$(echo "$osmidlist2" | sed '/^$/d' | wc -l)"
for printline3 in $(seq 1 "$anzosmids2"); do
 osmid2="$(echo "$osmidlist2" | sed -n ''$printline3'p')"
 if [ ! -e htmlfiles/osm/${osmid2}.html ]; then
  osmhtmllist2+="htmlfiles/osm/${osmid2}.html"$'\n'
 fi
done

osmlist2="$(echo "$osmhtmllist2" | sed '/^$/d')"

if [ -n "$osmlist" -o -n "$gtfslist" -o -n "$osmlist2" ]; then
 let webcheckerrorcounter++
 echo -e "\nFolgende Web-Seiten fehlen:"
 [ -n "$osmlist" ] && echo "$osmlist"
 [ -n "$gtfslist" ]&& echo "$gtfslist"
 [ -n "$osmlist2" ] && echo "$osmlist2"
else
 echo "Webseiten vollständig."
fi

# Neue OSM-Routen, die in keiner der beiden .cfg-Dateien eingetragen sind, werden anhand von HTML-Seiten ermittelt.
# Ist nochmal eine zusätzliche Kontrolle zu diffchecksortlist in pt_analysis2html.sh. Dort werden die ID-Listen aus den OSM-Daten verglichen.
if [ -n "$osmidlist2" ]; then
 allosmids="$(echo -e "${osmidlist}\n${osmidlist2}")"
else
 allosmids="$(echo "$osmidlist")"
fi
osmhtmlnames="$(basename --suffix=.html --multiple ./htmlfiles/osm/*)"

if [ "$(echo "$allosmids" | sort -n)" == "$(echo "$osmhtmlnames" | sort -n)" ]; then
 echo "Alle OSM-Routen sind in den Dateien real_bus_stops.cfg und invalidroutes.cfg eingebunden."
else
 let webcheckerrorcounter++
 uniqidlist="$(echo -e "${allosmids}\n${osmhtmlnames}" | sort -n | uniq -u)"
 anzuniqids="$(echo "$uniqidlist" | sed '/^$/d' | wc -l)"
 echo -e "\nNeue OSM-Route(n): "
 for lastidcheck in $(seq 1 "$anzuniqids"); do
  uniqosmid="$(echo "$uniqidlist" | sed -n ''$lastidcheck'p')"
  if [ -z "$(grep "^$uniqosmid" config/real_bus_stops.cfg)" -a -z "$(grep "^$uniqosmid" config/invalidroutes.cfg)" ]; then
   echo "htmlfiles/osm/${uniqosmid}"
  fi
 done
 echo ""
fi

if [ "$webcheckerrorcounter" -gt "0" ]; then
 echo "Vor der Versionsverwaltung mit git bitte erst Fehler bereinigen bzw. neue Routen in .cfg-Datei einbinden. Skript wird abgebrochen."
 echo -e "Fehlende Dateien von eingebundenen Routen erstellen mit:\nrcompare.sh -s all"
 exit 1
fi

# ***** Ermittlung fehlender Webseiten - Ende *****

echo "**** 2. Versionsverwaltung ****"
ptawebcounter="0"

# ** index.html **
if [ -n "$(git ls-files --modified | grep '^index.html')" ]; then
 let ptawebcounter++
 echo "*** 2.${ptawebcounter}. index.html wird im Index aktualisiert ***"
 git add -u index.html
 echo "Fertig."
fi

# ** Dateien im Ordner htmlfiles **
# Gelöschte Dateien
delhtmlfiles="$(git ls-files --deleted htmlfiles)"
if [ -n "$delhtmlfiles" ]; then
 let ptawebcounter++
 echo "*** 2.${ptawebcounter}. Gelöschte Dateien im Working Tree (Ordner htmlfiles) ***"
 echo "$delhtmlfiles"
 echo "Dateien werden aus Index gelöscht ..."
 git rm $delhtmlfiles
 echo "Fertig."
fi

# Neue Dateien im Working Tree
newhtmlfiles="$(git status --porcelain htmlfiles | grep '^??' | sed 's/^?? \(.*$\)/\1/')"
if [ -n "$newhtmlfiles" ]; then
 let ptawebcounter++
 echo "*** 2.${ptawebcounter}. Neue Dateien im Working Tree (Ordner htmlfiles) ***"
 echo "$newhtmlfiles"
 echo "Dateien werden dem Index hinzugefügt ..."
 git add $newhtmlfiles
 echo "Fertig."
fi

# Geänderte Dateien
modhtmlfiles="$(git ls-files --modified htmlfiles)"
if [ -n "$modhtmlfiles" ]; then
 let ptawebcounter++
 echo "*** 2.${ptawebcounter}. Geänderte Dateien im Index (Ordner htmlfiles) ***"
 echo "$modhtmlfiles"
 echo "Index update ..."
 git add -u $modhtmlfiles
 echo "Fertig."
fi

echo ""
git status

if [ "$ptawebcounter" -gt "0" ]; then

 while true
   do
    echo "Alles richtig?"
    read -p "Soll jetzt [c]ommittet werden oder sollen Änderungen aus Index [z]urückgenommen werden? (c/z) " ptacommit
     case "$ptacommit" in
       c|C) git commit -m "pt analysis `date +%Y-%m-%d`"
            
            # Dateien veröffentlichen
            while true
              do
               read -p "Dateien veröffentlichen? (j/n) " ptapublish
                case "$ptapublish" in
                  j|J) git push
                       break
                      ;;
                  n|N) echo "Webseiten wurden nicht veröffentlicht. Zum Veröffentlichen bitte \"git push\" eingeben."
                       break
                      ;;
                  *) echo "Fehlerhafte Eingabe!"
                      ;;
                esac
            done
      
            break
           ;;
       z|Z) git reset HEAD
            break
           ;;
       *) echo "Fehlerhafte Eingabe!"
           ;;
     esac
 done

 echo ""
 git status
 echo ""

else

 echo "Keine Änderungen am pta-web gefunden."

fi

echo -e "\n$(basename $0) beendet."
