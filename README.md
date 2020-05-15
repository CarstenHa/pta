# pta - Public transport analysis
Openstreetmap data analysis of public transport

Dieses Tool analysiert die Public-Transport-Daten (route=bus) des Openstreetmap-Projekts. Das Gebiet, welches analysiert wird, deckt sich mit dem Verkehrsgebiet "Takst Sjælland" in Ost-Dänemark.  
Ziel dieses Projekts ist es, eine bessere Überprüfbarkeit der OSM-Daten gegenüber den tatsächlichen Gegebenheiten eines Verkehrsgebietes herzustellen. So wird zum Beispiel das OSM-tag 'check_date=*' mit der Fahrplanperiode verglichen, um nur ein Merkmal dieses Tools zu nennen.

Die generierten HTML-Seiten, die ein Teil dieses Tools sind, finden Sie übrigens unter:  
https://carstenha.github.io/pta/htmlfiles/takst_sjaelland.html
Den Programmcode und weitere Informationen finden Sie unter:  
https://github.com/CarstenHa  
Diese Informationen finden Sie unter:  
https://carstenha.github.io/pta/

### 1. Vorbereitende Schritte

Um dieses Tool nutzen zu können, müssen einige Schritte vorher durchgeführt werden:

* Das Programm Osmosis muss herunter geladen, entpackt und in das Verzeichnis 'tools/osmosis' verschoben werden. Informationen zu dem Programm finden sich unter:  
https://wiki.openstreetmap.org/wiki/Osmosis

* Das Programm Osmconvert muss heruntergeladen und in das Verzeichnis 'tools/osmconvert' verschoben werden. Informationen zu dem Programm finden sich unter:  
https://wiki.openstreetmap.org/wiki/Osmconvert

* In dem Ordner 'config' ist die Datei 'real_bus_stops.lst'. Diese Datei umbenennen in 'real_bus_stops.cfg'. Diese neue Datei kann dann mit Daten gefüttert werden. Nähere Erläuterungen dazu befinden sich in der Datei selber.

### 2. Ausführung

* Start des Erstellungsprozesses:  
    ./start.sh

* Anzeigen der Hilfe:  
    ./start.sh -h

### 3. Lizenzhinweise

Die Openstreetmap-Daten stehen unter der ODbL-Lizenz https://opendatacommons.org/licenses/odbl/  
© OpenStreetMap contributors https://www.openstreetmap.org/copyright

Font Rubik: Copyright 2015 The Rubik Project Authors (https://github.com/googlefonts/rubik). The font is licensed under the SIL Open Font License.  
http://scripts.sil.org/OFL

Font Awesome: Font Awesome by Dave Gandy (http://fontawesome.io). The font is licensed under the SIL Open Font License 1.1 (http://scripts.sil.org/OFL). CSS files are licensed under MIT License (http://opensource.org/licenses/mit-license.html)

### 4. Datenschutz

Ich erhebe keine personenbezogenen Daten noch werte ich Sie aus oder gebe Diese an Dritte weiter. Allerdings habe ich keinen Einfluss darauf, welche Daten Dritte (Service Provider etc.) erheben, auswerten, etc.

Viel Spaß!

