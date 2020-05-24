-- region DROP TABLE

DROP TABLE IF EXISTS GruppenEinladung;
DROP TABLE IF EXISTS GruppenAnfrage;
DROP TABLE IF EXISTS Gruppe_Student;
DROP TABLE IF EXISTS GruppenBeitrag;
DROP TABLE IF EXISTS GruppenDienstLink;
DROP TABLE IF EXISTS  Gruppe;
DROP TABLE IF EXISTS StudentWiederherstellung;
DROP TABLE IF EXISTS StudentVerifizierung;
DROP TABLE IF EXISTS EindeutigeKennung;
DROP TABLE IF EXISTS Student;
DROP TABLE IF EXISTS Studiengang_Modul;
DROP TABLE IF EXISTS Modul;
DROP TABLE IF EXISTS Studiengang;
DROP TABLE IF EXISTS Fakultaet;

-- endregion


-- region TABLE

CREATE TABLE Fakultaet (
    id       INTEGER PRIMARY KEY  AUTO_INCREMENT,
    name     VARCHAR(64) NOT NULL,
    standort VARCHAR(64) NOT NULL
);

CREATE TABLE Studiengang (
    id           INTEGER PRIMARY KEY  AUTO_INCREMENT,
    name         VARCHAR(64) NOT NULL,
    fakultaet_id INTEGER      NOT NULL,
    abschluss    VARCHAR(16)  NOT NULL,
    FOREIGN KEY (fakultaet_id)
        REFERENCES Fakultaet (id)
);

ALTER TABLE Studiengang
    ADD CONSTRAINT check_Studiengang_abschluss
        CHECK (UPPER(abschluss) in (
            'BSC.INF', 'BSC.ING', 'DIPL.ING', 'DIPL.INF')
        );

CREATE TABLE Modul (
    id             INTEGER PRIMARY KEY AUTO_INCREMENT,
    name           VARCHAR(64) NOT NULL,
    dozent         VARCHAR(64)  NOT NULL,
    semester       INTEGER
);

ALTER TABLE Modul
    ADD CONSTRAINT check_Modul_semester
        CHECK (semester > 0);

CREATE TABLE Studiengang_Modul (
    studiengang_id INTEGER NOT NULL,
    modul_id INTEGER NOT NULL,
    PRIMARY KEY (studiengang_id, modul_id),
    FOREIGN KEY (studiengang_id)
        REFERENCES Studiengang (id),
    FOREIGN KEY (modul_id)
        REFERENCES Modul (id)
);

CREATE TABLE Student (
    id                  INTEGER PRIMARY KEY AUTO_INCREMENT,
    name                VARCHAR(64)      NOT NULL,
    smail_adresse       VARCHAR(64)      NOT NULL,
    studiengang_id      INTEGER           NOT NULL,
    semester            INTEGER DEFAULT 1 NOT NULL,
    -- TODO: Hash-Größe hängt von Implementierung ab.
    passwort_hash       VARCHAR(64)      NOT NULL,
    profil_beschreibung VARCHAR(256),
    profil_bild         BLOB,
    geburtsdatum        DATE,
    FOREIGN KEY (studiengang_id)
        REFERENCES Studiengang (id)
);

ALTER TABLE Student
    ADD CONSTRAINT check_Student_semester
        CHECK (semester > 0);

-- TODO [Scheduler] Nach Ablauf des Semesters `semester` des Studenten erhöhen.

CREATE TABLE EindeutigeKennung (
    id      INTEGER PRIMARY KEY AUTO_INCREMENT,
    kennung CHAR(32) NOT NULL -- UUID
);

CREATE UNIQUE INDEX index_EindeutigeKennung_kennung
    ON EindeutigeKennung(kennung);

-- Ein Eintrag zur Verifizierung des Nutzer-Accounts.
CREATE TABLE StudentVerifizierung (
    kennung_id INTEGER PRIMARY KEY,
    student_id INTEGER NOT NULL UNIQUE,
    FOREIGN KEY (kennung_id)
        REFERENCES EindeutigeKennung (id),
    FOREIGN KEY (student_id)
        REFERENCES Student (id)
);

-- Ein Eintrag zur Widerherstellung des Passworts eines Studenten.
CREATE TABLE StudentWiederherstellung (
    kennung_id INTEGER PRIMARY KEY,
    student_id INTEGER NOT NULL UNIQUE,
    FOREIGN KEY (kennung_id)
        REFERENCES EindeutigeKennung (id),
    FOREIGN KEY (student_id)
        REFERENCES Student (id)
);

CREATE TABLE Gruppe (
    id           INTEGER PRIMARY KEY AUTO_INCREMENT,
    modul_id     INTEGER             NOT NULL,
    ersteller_id INTEGER             NOT NULL,
    name         VARCHAR(64)        NOT NULL,
    v_limit        INTEGER DEFAULT 8,
    oeffentlich  CHAR(1) DEFAULT '1' NOT NULL,
    betretbar    CHAR(1) DEFAULT '0' NOT NULL COMMENT 'Studenten können der Gruppe beitreten ohne erst vom Ersteller angenommen werden zu müssen.',
    deadline     DATE,
    -- FIXME: Ort als Geokoordinaten abspeichern.
    ort          VARCHAR(64),
    FOREIGN KEY (modul_id)
        REFERENCES Modul (id),
    FOREIGN KEY (ersteller_id)
        REFERENCES Student (id)
);

ALTER TABLE Gruppe
    ADD CONSTRAINT check_Gruppe_limit
        CHECK (v_limit > 0);

ALTER TABLE Gruppe -- TODO: Kann man das irgendwie schöner abbilden?
    ADD CONSTRAINT check_Gruppe_oeffentlich
        CHECK (oeffentlich in ('1', '0'));

ALTER TABLE Gruppe
    ADD CONSTRAINT check_Gruppe_betretbar
        CHECK (betretbar in ('1', '0'));

CREATE TABLE GruppenDienstLink (
    gruppe_id INTEGER     NOT NULL,
    url        varchar(250) NOT NULL,
    FOREIGN KEY (gruppe_id)
        REFERENCES Gruppe (id)
);

CREATE TABLE GruppenBeitrag (
    id         INTEGER PRIMARY KEY AUTO_INCREMENT,
    gruppe_id  INTEGER        NOT NULL,
    student_id INTEGER        NOT NULL,
    datum      DATE           NOT NULL,
    nachricht  VARCHAR(1024) NOT NULL,
    FOREIGN KEY (gruppe_id)
        REFERENCES Gruppe (id),
    FOREIGN KEY (student_id)
        REFERENCES Student (id)
);

CREATE INDEX index_GruppenBeitrag_gruppe_datum
    ON GruppenBeitrag (gruppe_id, datum);

ALTER TABLE GruppenBeitrag
    ADD CONSTRAINT check_GruppenBeitrag_nachricht
        CHECK (LENGTH(nachricht) > 0);

-- Studenten die in einer Gruppe sind.
CREATE TABLE Gruppe_Student (
    gruppe_id      INTEGER NOT NULL,
    student_id     INTEGER NOT NULL,
    beitrittsdatum DATE    NOT NULL,
    PRIMARY KEY (gruppe_id, student_id),
    FOREIGN KEY (gruppe_id)
        REFERENCES Gruppe (id),
    FOREIGN KEY (student_id)
        REFERENCES Student (id)
);

-- Anfrage eines Studenten um einer Gruppe beizutreten.
CREATE TABLE GruppenAnfrage (
    gruppe_id  INTEGER NOT NULL,
    student_id INTEGER NOT NULL,
    datum      DATE    NOT NULL,
    nachricht  VARCHAR(256),
    bestaetigt CHAR(1) DEFAULT '0' NOT NULL,
    PRIMARY KEY (gruppe_id, student_id),
    FOREIGN KEY (gruppe_id)
        REFERENCES Gruppe (id),
    FOREIGN KEY (student_id)
        REFERENCES Student (id)
);

ALTER TABLE GruppenAnfrage
    ADD CONSTRAINT check_GruppenAnfrage_betretbar
        CHECK (bestaetigt in ('1', '0'));






-- Eine Einladung zu einer Gruppe. Wird für Einladungslinks verwendet.
CREATE TABLE GruppenEinladung (
    kennung_id   INTEGER PRIMARY KEY,
    gruppe_id    INTEGER NOT NULL,
    ersteller_id INTEGER NOT NULL,
    gueltig_bis  DATE,
    FOREIGN KEY (kennung_id)
        REFERENCES EindeutigeKennung (id),
    FOREIGN KEY (gruppe_id)
        REFERENCES Gruppe (id),
    FOREIGN KEY (ersteller_id)
        REFERENCES Student (id)
);

-- TODO [Tabelle] Treffzeiten nach Wochentag.

-- endregion

--region Tabellen mit Daten befuellen zum Testzwecken-------------
--------------------Erstellung Fakultaet-----------------------------
INSERT INTO Fakultaet (name, standort) values('Fakultaet InfoING', 'Gummersbach');
INSERT INTO Fakultaet(name, standort) values('Fakultaet fuer Fahrzeugsysteme und Produktion', 'Koeln');
INSERT INTO Fakultaet (name, standort) values(' Fakultaet fuer Architektur', 'Koeln');
/*Erstellung Studiangang */

INSERT INTO Studiengang values(1,'MASCHINENBAU',1, 'BSC.INF');
INSERT INTO Studiengang values(2,'INFORMATIK', 2, 'BSC.ING');
INSERT INTO Studiengang values(3,'ELEKTROTECHNIK', 3, 'BSC.ING');

/*Erstellung Modulen */
INSERT INTO Modul values(1,  'INFORMATIK','Koenen', 1);
INSERT INTO Modul values(2, 'INFORMATIK','EISENMANN',  2);
INSERT INTO Modul values(3, 'Werkstoffe','Mustermann',  3);

/* Erstellung Student */

INSERT INTO Student values(1,'Tobias','help@smail.th-koeln.de',1,2,'xxxa','Lernstube',NULL,SYSDATE());
INSERT INTO Student values(2,'Hermann','test@smail.th-koeln.de',2,4,'ppp','study',NULL,DATE_FORMAT('17/12/2008', 'DD/MM/YYYY'));
INSERT INTO Student values(3,'Luc','luc@smail.th-koeln.de',3,2,'lll','etude',NULL,DATE_FORMAT('09/12/2008', 'DD/MM/YYYY'));
INSERT INTO Student values(4,'Frida','bol@smail.th-koeln.de',2,4,'ppp','pass',NULL,DATE_FORMAT('17/12/2000', 'DD/MM/YYYY'));

/*Erstellung Gruppe */
INSERT INTO Gruppe values(1,1,3,'TEST',5,'1','1',DATE_FORMAT('17/06/2020', 'DD/MM/YYYY'),'Gummersbach');
INSERT INTO Gruppe values(2,2,2,'zudy',3,'1','1',DATE_FORMAT('17/06/2020', 'DD/MM/YYYY'),'Gummersbach');
INSERT INTO Gruppe values(3,3,1,'PP',3,'1','0',DATE_FORMAT('01/07/2020', 'DD/MM/YYYY'),'Koeln');
INSERT INTO Gruppe values(4,3,1,'ALGO',2,'0','1',DATE_FORMAT('01/06/2020', 'DD/MM/YYYY'),'Koeln');

/* Erstellung Gruppenbeitrag */

INSERT INTO GruppenBeitrag values(1,1,2,'2015-12-17','hello world');
INSERT INTO GruppenBeitrag values(2,2,1,'2020-06-17','was lauft..');
INSERT INTO GruppenBeitrag values(3,1,2,'2020-07-17' ,'wann ist naechste ..');
INSERT INTO GruppenBeitrag values(4,3,2,'2019-02-01','Termin wird verschoben ..');
INSERT INTO GruppenBeitrag values(5,3,2,'2020-05-17','ich bin heute nicht dabei..');
INSERT INTO GruppenBeitrag values(6,3,2,'2020-07-17','wann ist naechste ..');



/*Erstellung gruppeDiensLink */

INSERT INTO GruppenDienstLink values('1','https://ggogleTrst');
INSERT INTO GruppenDienstLink values('2','https://google.de');
INSERT INTO GruppenDienstLink values('4','https://test.de');


/*Erstellung beitrittsAnfrage */

INSERT INTO GruppenAnfrage values(1,2,SYSDATE(),'hello, ich wuerde gerne..', '1');
INSERT INTO GruppenAnfrage values(3,1,ifnull(DATE_FORMAT('17/12/2015', 'DD/MM/YYYY'), ''),'hello, ich wuerde gerne..','1');
INSERT INTO GruppenAnfrage values(2,3,ifnull(DATE_FORMAT('17/12/2019', 'DD/MM/YYYY'), ''),'hello, ich wuerde gerne..','0');
COMMIT;


-- region TRIGGER

/* ein trigger für deadline um eine Gruppe beizutreten   */
DROP TRIGGER IF EXISTS trigger_Gruppe_deadline;
 DELIMITER // 
CREATE TRIGGER trigger_Gruppe_deadline 
BEFORE INSERT ON Gruppe 
FOR EACH ROW 
BEGIN 
    IF (NEW.deadline < SYSDATE()) THEN
     SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Deadline darf nicht in der Vergangenheit liegen.'; 
     END IF; 
END//

DELIMITER ;


/* ein trigger, der Gruppendienslink limitiert   */
DROP TRIGGER IF EXISTS trigger_GruppenDienstLink_limitiert ;

DELIMITER //
CREATE TRIGGER trigger_GruppenDienstLink_limitiert 
BEFORE INSERT ON GruppenDienstLink 
FOR EACH ROW 
BEGIN 
DECLARE v_limit INTEGER; 
DECLARE v_anzahl INTEGER; 
SELECT 8 INTO v_limit FROM dual; 
SELECT COUNT(gruppe_id) INTO v_anzahl FROM GruppenDienstLink GROUP BY gruppe_id; 
IF (v_anzahl > v_limit) THEN 
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Eine Gruppe kann nicht mehr als 5 Dienstlinks haben.';
 END IF; 
 END //
DELIMITER ;

/* PROCEDURE FÜR LETZER BEITRAG EINER GRUPPE */

DELIMITER ;

DROP  PROCEDURE IF EXISTS LetzterBeitragVonGruppe;

delimiter //

CREATE PROCEDURE LetzterBeitragVonGruppe(v_gruppe_id INT )  

BEGIN
    DECLARE r_comment VARCHAR(250);
    DECLARE v_name VARCHAR(250);
    DECLARE v_start date;
    DECLARE v_date date;
    DECLARE nr INT;
    DECLARE finished INT DEFAULT 0;

    DECLARE kundenCursor CURSOR FOR  SELECT  (b.datum ),e.name, b.Nachricht
    FROM  gruppenBeitrag b INNER JOIN gruppe e  ON  b.gruppe_id = e.id  
    where b.gruppe_id = v_gruppe_id ORDER BY b.datum DESC LIMIT 1;

    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET finished=1;  

    /*Eine temporaere Table erzeugen um die Werten abzuspeichern */
    DROP TEMPORARY TABLE IF EXISTS TempTable;
	CREATE TEMPORARY TABLE TempTable( v_date DATE,v_name VARCHAR(250),r_comment VARCHAR(250));

    /*--Die Anzahl von den Beiteagen zu einer gegebenen 
    --Gruppe in der Variable nr speicher*/
    SELECT COUNT(gruppe_id) into nr
	FROM gruppenBeitrag where gruppe_id = v_gruppe_id;    

    /*---Wenn die anzahl der Beitraegen großer null ist, dann der Cursor öffnen*/
    IF (nr> 0) THEN

    OPEN kundenCursor;
  	forloop:LOOP
		FETCH kundenCursor INTO v_date,v_name ,r_comment ;
			IF finished THEN
				LEAVE forLoop;
			END IF;
        INSERT INTO TempTable (v_date,v_name ,r_comment)
		VALUES ( v_date,v_name ,r_comment);
	END LOOP forLoop;
	SELECT * from TempTable; /*---Ergebnis aus der Tabelle ausgeben*/
    CLOSE kundenCursor;

/*---Eine Fehlermeldung ausgeben, wenn keine Beitrege der Gruppe vorhanden ist.*/
    ELSE
	    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Es liegen keine Beitraegen von deiner Gruppe vor' ; 
    END IF;

END //
DELIMITER ;

/* INSTEAD OF VIEW TRigger VIEW */
CREATE or replace VIEW studentNachricht AS 
SELECT gb.id, gb.nachricht, gb.gruppe_id,gb.student_id, s.name, st.abschluss
from gruppenBeitrag gb , student s,  studiengang st
where gb.student_id = s.id
AND UPPER(st.name) LIKE '%INF%';



-- TODO Anstatt eines Triggers welcher das Datum des erstellten Beitrags
--      überprüft, wäre eine Prozedur welche einen Beitrag erstellt sinnvoller.
/*/
-- FIXME: Trigger wurde einfach nur von `trigger_Gruppe_deadline` kopiert.
CREATE TRIGGER trigger_GruppenBeitrag_datum
    BEFORE INSERT
    ON GruppenBeitrag
    FOR EACH ROW
BEGIN
    IF (:NEW.datum < SYSDATE)
    THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Datum darf nicht in der Vergangenheit liegen.' ||
                to_char(:NEW.datum, 'YYYY-MM-DD HH24:MI:SS')
        );
    END IF;
END;
/
/**/

-- TODO [Trigger] Einfügen überlappender Treffzeiten zusammenführen.
-- Falls ein einzufügender Zeitintervall mit einem anderen überlappt
-- sollte der existierende geupdated werden anstatt einen Fehler zu werden.
-- -> { von: MIN(:old.von, :new.von), bis: MAX(:old.bis, :new.bis) }

-- endregion


-- region PROCEDURE

-- TODO [Prozedur] Prüfen ob ein Student/Nutzer verifiziert ist.
-- Überprüft ob in der Tabelle `StudentVerifizierung` ein Eintrag vorhanden ist.
-- Nützlich für Client-seitiges welches nur für verifizierte Nutzer möglich ist.

-- TODO [Prozedur] Studenten/Nutzer verifizieren.
-- Nimmt Parameter `student_id` und `kennung` (UUID) und überprüft
-- ob damit ein der gegebene Student verifiziert werden kann.
-- 1) Eintrag in `StudentVerifizierung` nicht vorhanden -> ERROR
-- 1) Ansonsten -> Eintrag entfernen + SUCCESS

-- TODO [Prozedur] Einer Gruppe beitreten.
-- Versucht einer Gruppe einen Studenten hinzuzufügen.
-- Die folgenden 3 Fälle müssen abgedeckt werden:
-- 1) Die Gruppe ist bereits vollständig belegt -> ERROR
-- 2) Die Gruppe ist direkt betretbar
--      -> Student hinzufügen + Anfrage löschen, falls vorhanden
-- 3) Sonst -> Beitrittsanfrage erstellen (Prozedur aufrufen)
--      + entsprechenden Wert zurückgeben

-- TODO [Prozedur] Eine Gruppe verlassen.

-- TODO [Prozedur] Eine Beitrittsanfrage erstellen.
-- Erstellt für einen Studenten eine Beitrittsanfrage zu einer Gruppe.
-- 1) Der Student ist bereits in der Gruppe -> ERROR
-- 2) Sonst -> Beitrittsanfrage erstellen

-- TODO [Prozedur] Eine Beitrittsanfrage annehmen.
-- Nimmt eine Beitrittsanfrage eines Studenten an.
-- 1) Die Gruppe ist vollständig belegt -> ERROR
-- 2) Sonst -> Student hinzufügen und alle anderen
--      Anfragen des Studenten welche zum selben Modul gehören löschen.
--      Man möchte wahrscheinlich nicht mehrere Gruppen für ein Modul belegen.
--      Oder doch?

-- TODO [Prozedur] Eine Beitrittsanfrage ablehnen.

-- endregion


-- region SEQUENCE

CREATE SEQUENCE sequence_Fakultaet;
CREATE SEQUENCE sequence_Studiengang;
CREATE SEQUENCE sequence_Modul;
CREATE SEQUENCE sequence_Student;
CREATE SEQUENCE sequence_EindeutigeKennung;
CREATE SEQUENCE sequence_Gruppe;
CREATE SEQUENCE sequence_GruppenBeitrag;

-- endregion


-- region Notizen
/*

CREATE OR REPLACE TYPE DienstLink_t AS OBJECT (
    url HTTPURITYPE
)
FINAL;

DROP TABLE DienstLink;

CREATE TABLE DienstLink
OF DienstLink_t
OBJECT IDENTIFIER IS PRIMARY KEY;

INSERT INTO DienstLink
VALUES (HTTPURITYPE('https://web.whatsapp.com/invite?id=123'));

SELECT LOWER(SYS_GUID()) FROM dual; -- , * FROM DienstLink;

*/
-- endregion
