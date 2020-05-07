# pta - Public transport analysis
Openstreetmap data analysis of public transport

Dieses Tool analysiert die Public-Transport-Daten (route=bus) des Openstreetmap-Projekts. Das Gebiet, welches analysiert wird, deckt sich mit dem Verkehrsgebiet "Takst Sjælland" in Ost-Dänemark.  
Ziel dieses Projekts ist es, eine bessere Überprüfbarkeit der OSM-Daten gegenüber den tatsächlichen Gegebenheiten eines Verkehrsgebietes herzustellen. So wird zum Beispiel das OSM-tag 'check_date=*' mit der Fahrplanperiode verglichen, um nur ein Merkmal dieses Tools zu nennen.

### 1. Vorbereitende Schritte

Um dieses Tool nutzen zu können, müssen einige Schritte vorher durchgeführt werden:

* Das Programm Osmosis muss herunter geladen, entpackt und in das Verzeichnis 'tools/osmosis' verschoben werden. Informationen zu dem Programm finden sich unter:  
https://wiki.openstreetmap.org/wiki/Osmosis

* Das Programm Osmconvert muss heruntergeladen und in das Verzeichnis 'tools/osmconvert' verschoben werden. Informationen zu dem Programm finden sich unter:  
https://wiki.openstreetmap.org/wiki/Osmconvert

* Schriftarten müssen noch in den Webordner eingebunden werden. Die fertigen HTML-Seiten benötigen unter Anderem den Icon-Font Awesome, den man unter folgender Adresse herunterladen kann:  
http://fontawesome.io/
Die heruntergeladene(n) Font-Datei(en) müssen in den Ordner 'htmlfiles/fonts' verschoben werden.
font-awesome.css in den Ordner 'htmlfiles/css'.  
Außerdem können natürlich noch weitere Schriftarten eingebunden werden. CSS-Anweisungen weiterer Schriftarten können in eine separate 'htmlfiles/css/fonts.css' gespeichert werden. Diese Datei ist (wie auch font-awesome.css) bereits im head-Bereich jeder HTML-Seite eingebunden. In der Datei style.css muss dann noch eventuell die Deklaration 'font-family:' angepasst werden.  

* In dem Ordner 'config' ist die Datei 'real_bus_stops.lst'. Diese Datei umbenennen in 'real_bus_stops.cfg'. Diese neue Datei kann dann mit Daten gefüttert werden. Nähere Erläuterungen dazu befinden sich in der Datei selber.

Die generierten HTML-Seiten von diesem Tool finden Sie übrigens unter:  
https://www.langstreckentouren.de/osm/takst_sjaelland.html

### 2. Ausführung

* Start des Erstellungsprozesses:  
    ./start.sh

* Anzeigen der Hilfe:  
    ./start.sh -h

### 3. Lizenzhinweise

Die Openstreetmap-Daten stehen unter der ODbL-Lizenz https://opendatacommons.org/licenses/odbl/  
© OpenStreetMap contributors https://www.openstreetmap.org/copyright

Viel Spaß!

