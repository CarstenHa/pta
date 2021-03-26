# pta - Public transport analysis
Data analysis of public transport

Dieses Tool analysiert die Public-Transport-Daten (route=bus) des Openstreetmap-Projekts und die entsprechenden GTFS Sollfahrplandaten. Das Gebiet, welches analysiert wird, deckt sich mit dem "Takst Sjælland" (DOT) in Ost-Dänemark.  
Die Idee, die hinter diesem Projekt steht ist, eine bessere inhaltliche Überprüfbarkeit der OSM-Daten gegenüber den tatsächlichen Gegebenheiten eines Verkehrsgebietes herzustellen, da sich Fahrpläne, Routen und Haltestellen relativ schnell ändern können. Bitte beachten Sie die Lizenzhinweise am Ende dieser Seite.  
In der Regel sind OSM-Routen nach dem Public Transport Schema 2 ja wie folgt angeordnet:

Stop 1  
Platform 1  
Stop 2  
Platform 2  
...  
Weg 1  
Weg 2  
Weg 3  
usw.  

In den HTML-Seiten nach der Auswertung mit diesem Tool werden die stops und platforms zur besseren Übersichtlichkeit in getrennten Tabellen angezeigt.  
Außerdem wird zum Beispiel das OSM-tag 'check_date=*' mit der Fahrplanperiode verglichen und vieles mehr ...

Die generierten HTML-Seiten, die ein Teil dieses Tools sind, finden Sie übrigens unter:  
https://carstenha.github.io/pta/htmlfiles/takst_sjaelland.html  
Den Programmcode und weitere Informationen finden Sie unter:  
https://github.com/CarstenHa/pta  
Diese Informationen finden Sie unter:  
https://carstenha.github.io/pta/

Für alle, die dieses Tool für andere Verkehrsgebiete umschreiben wollen, gibt es ein kleines Wiki, wo die einzelnen Skripte etwas näher vorgestellt werden.  
https://github.com/CarstenHa/pta/wiki

### 1. Vorbereitende Schritte

Um dieses Tool nutzen zu können, müssen einige Schritte vorher durchgeführt werden:

* Das Programm Osmosis muss herunter geladen, entpackt und in das Verzeichnis 'tools/osmosis' verschoben werden. Informationen zu dem Programm finden sich unter:  
https://wiki.openstreetmap.org/wiki/Osmosis

* Das Programm Osmconvert muss heruntergeladen und in das Verzeichnis 'tools/osmconvert' verschoben werden. Informationen zu dem Programm finden sich unter:  
https://wiki.openstreetmap.org/wiki/Osmconvert

* In dem Ordner 'config' ist die Datei 'real_bus_stops.lst'. Diese Datei umbenennen in 'real_bus_stops.cfg'. Diese neue Datei kann dann mit Daten gefüttert werden. Nähere Erläuterungen dazu befinden sich in der Datei selber.

* Außerdem gibt es in dem Ordner 'config' die Datei 'invalidroutes.lst'. Auch diese Datei umbenennen in 'invalidroutes.cfg'. Diese Datei ist vorgesehen für ungültige und veraltete Routen. Auch in dieser Datei stehen weitere Erläuterungen im Kopf der Datei.

### 2. Ausführung

* Start des Erstellungsprozesses:  
    ./start.sh

* Anzeigen der Hilfe:  
    ./start.sh -h

### 3. Lizenzhinweise

Die Openstreetmap-Daten stehen unter der ODbL-Lizenz https://opendatacommons.org/licenses/odbl/  
© OpenStreetMap contributors https://www.openstreetmap.org/copyright

GTFS-Daten: rejseplanen.dk (https://www.rejseplanen.dk/)  
Daten stehen unter Creative Commons BY-ND 3.0 Lizenz (http://creativecommons.org/licenses/by-nd/3.0/)

Die GTFS-Kartenansicht wurde mit Openlayers realisiert.
Der Code von Openlayers (https://openlayers.org/) steht unter der Lizenz 2-Clause BSD (https://tldrlegal.com/license/bsd-2-clause-license-(freebsd))

Font Rubik: Copyright 2015 The Rubik Project Authors (https://github.com/googlefonts/rubik). The font is licensed under the SIL Open Font License.  
http://scripts.sil.org/OFL

Font Awesome: Font Awesome by Dave Gandy (http://fontawesome.io). The font is licensed under the SIL Open Font License 1.1 (http://scripts.sil.org/OFL). CSS files are licensed under MIT License (http://opensource.org/licenses/mit-license.html)

Font Exo2: Copyright (c) 2013, Natanael Gama (www.ndiscovered.com info(at)ndiscovered.com), with Reserved Font Name Exo. This Font Software is licensed under the SIL Open Font License, Version 1.1. http://scripts.sil.org/OFL

CarstenHa/pta is licensed under the GNU Lesser General Public License v3.0  
https://github.com/CarstenHa/pta/blob/master/LICENSE



Viel Spaß!

