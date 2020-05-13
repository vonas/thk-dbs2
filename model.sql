/* / - Zusammenfassung - /* /

Eintrage mit [x] sind bereits implementiert.
Solche mit einem leeren Kästchen [ ] müssen noch geschrieben werden.
Falls hinter einem Eintrag `Xa` steht bedeutet das, dass die
    Implementierung des Elements `X` `a`nweisungen beansprucht hat.


[Trigger]
    Student:
        -

trigger_GruppenDienstLink_limitiert
trigger_GruppenBeitrag_datum

    Gruppe:
        [x] `trigger_Gruppe_deadline` - 1a
            Spalte `deadline` darf beim Einfügen das aktuelle
            Datum nicht überschreiten. (2 Anweisungen)

    GruppenDienstLink:
        [x] `trigger_GruppenDienstLink_limitiert` - 3a
            Anzahl der Dienstlinks für eine Gruppe
            darf nicht das Limit überschreiten.


[Scheduler]
    Student:
        [ ] Spalte `semester` erhöhen sobald das nächste Semester beginnt.


/**/


DROP TABLE GruppenEinladung;
DROP TABLE GruppenAnfrage;
DROP TABLE Gruppe_Student;
DROP TABLE GruppenBeitrag;
DROP TABLE GruppenDienstLink;
DROP TABLE Gruppe;
DROP TABLE StudentWiederherstellung;
DROP TABLE StudentVerifizierung;
DROP TABLE EindeutigeKennung;
-- DROP TABLE Student_Modul;
DROP TABLE Student;
DROP TABLE Studiengang_Modul;
DROP TABLE Modul;
DROP TABLE Studiengang;
DROP TABLE Fakultaet;


CREATE TABLE Fakultaet (
    id       INTEGER PRIMARY KEY,
    name     VARCHAR2(64) NOT NULL,
    standort VARCHAR2(64) NOT NULL
);

CREATE TABLE Studiengang (
    id           INTEGER PRIMARY KEY,
    name         VARCHAR2(64) NOT NULL,
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
    id             INTEGER PRIMARY KEY,
    name           VARCHAR2(64) NOT NULL,
    dozent         VARCHAR(64)  NOT NULL,
    semester       INTEGER
);

ALTER TABLE Modul
    ADD CONSTRAINT check_Modul_semester
        CHECK (semester > 0);

-- Zugehörigkeit zwischen Studiengang und Modul.
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
    id                  INTEGER PRIMARY KEY,
    name                VARCHAR2(64)      NOT NULL,
    smail_adresse       VARCHAR2(64)      NOT NULL,
    studiengang_id      INTEGER           NOT NULL,
    semester            INTEGER DEFAULT 1 NOT NULL,
    -- TODO: Hash-Größe hängt von Implementierung ab.
    passwort_hash       VARCHAR2(64)      NOT NULL,
    profil_beschreibung VARCHAR(256),
    profil_bild         BLOB,
    geburtstag          DATE,
    FOREIGN KEY (studiengang_id)
        REFERENCES Studiengang (id)
);

ALTER TABLE Student
    ADD CONSTRAINT check_Student_semester
        CHECK (semester > 0);

-- TODO [Scheduler] Nach Ablauf des Semesters `semester` des Studenten erhöhen.

CREATE TABLE EindeutigeKennung (
    id      INTEGER PRIMARY KEY,
    kennung CHAR(32) NOT NULL -- UUID
);

CREATE UNIQUE INDEX index_EindeutigeKennung_kennung
    ON EindeutigeKennung(kennung);

-- Ein Eintrag zur Verifizierung des Nutzer-Accounts.
CREATE TABLE StudentVerifizierung (
    student_id INTEGER PRIMARY KEY,
    kennung_id INTEGER NOT NULL UNIQUE,
    FOREIGN KEY (student_id)
        REFERENCES Student (id),
    FOREIGN KEY (kennung_id)
        REFERENCES EindeutigeKennung (id)
);

-- Ein Eintrag zur Widerherstellung des Passworts eines Studenten.
CREATE TABLE StudentWiederherstellung (
    student_id INTEGER PRIMARY KEY,
    kennung_id INTEGER NOT NULL UNIQUE,
    FOREIGN KEY (student_id)
        REFERENCES Student (id),
    FOREIGN KEY (kennung_id)
        REFERENCES EindeutigeKennung (id)
);

CREATE TABLE Gruppe (
    id           INTEGER PRIMARY KEY,
    modul_id     INTEGER             NOT NULL,
    ersteller_id INTEGER             NOT NULL,
    name         VARCHAR2(64)        NOT NULL,
    limit        INTEGER DEFAULT 8,
    oeffentlich  CHAR(1) DEFAULT '1' NOT NULL,
    betretbar    CHAR(1) DEFAULT '0' NOT NULL,
    deadline     DATE,
    -- FIXME: Ort als Geokoordinaten abspeichern.
    ort          VARCHAR2(64),
    FOREIGN KEY (modul_id)
        REFERENCES Modul (id),
    FOREIGN KEY (ersteller_id)
        REFERENCES Student (id)
);

COMMENT ON COLUMN Gruppe.betretbar
    IS 'Studenten können der Gruppe beitreten ohne erst vom Ersteller angenommen werden zu müssen.';

ALTER TABLE Gruppe
    ADD CONSTRAINT check_Gruppe_limit
        CHECK (limit > 0);

ALTER TABLE Gruppe -- TODO: Kann man das irgendwie schöner abbilden?
    ADD CONSTRAINT check_Gruppe_oeffentlich
        CHECK (oeffentlich in ('1', '0'));

ALTER TABLE Gruppe
    ADD CONSTRAINT check_Gruppe_betretbar
        CHECK (betretbar in ('1', '0'));

CREATE TRIGGER trigger_Gruppe_deadline
    BEFORE INSERT
    ON Gruppe
    FOR EACH ROW
BEGIN
    IF (:NEW.deadline < SYSDATE)
    THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Deadline darf nicht in der Vergangenheit liegen.' ||
                to_char(:NEW.deadline, 'YYYY-MM-DD HH24:MI:SS')
        );
    END IF;
END;
/

CREATE TABLE GruppenDienstLink (
    gruppe_id  INTEGER     NOT NULL,
    dienst_url HTTPURITYPE NOT NULL,
    FOREIGN KEY (gruppe_id)
        REFERENCES Gruppe (id)
);

CREATE TRIGGER trigger_GruppenDienstLink_limitiert
    BEFORE INSERT
    ON GruppenDienstLink
DECLARE
    v_limit INTEGER;
    v_anzahl INTEGER;
BEGIN
    SELECT 5 INTO v_limit FROM dual;

    SELECT COUNT(gruppe_id)
    INTO v_anzahl
    FROM GruppenDienstLink
    GROUP BY gruppe_id;

    IF (v_anzahl > v_limit) THEN
        RAISE_APPLICATION_ERROR(
            -20003,
            'Eine Gruppe kann nicht mehr als '
                    || v_limit || ' Dienstlinks haben.'
        );
    END IF;
END;
/

CREATE TABLE GruppenBeitrag (
    gruppe_id  INTEGER        NOT NULL,
    student_id INTEGER        NOT NULL,
    datum      DATE           NOT NULL,
    nachricht  VARCHAR2(1024) NOT NULL,
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

-- Studenten die in einer Gruppe sind.
CREATE TABLE Gruppe_Student (
    gruppe_id      INTEGER,
    student_id     INTEGER,
    beitrittsdatum DATE NOT NULL,
    PRIMARY KEY (gruppe_id, student_id),
    FOREIGN KEY (gruppe_id)
        REFERENCES Gruppe (id),
    FOREIGN KEY (student_id)
        REFERENCES Student (id)
);

-- Anfrage eines Studenten um einer Gruppe beizutreten.
CREATE TABLE GruppenAnfrage (
    gruppe_id  INTEGER,
    student_id INTEGER,
    datum      DATE NOT NULL,
    nachricht  VARCHAR2(256),
    PRIMARY KEY (gruppe_id, student_id),
    FOREIGN KEY (gruppe_id)
        REFERENCES Gruppe (id),
    FOREIGN KEY (student_id)
        REFERENCES Student (id)
);

-- Eine Einladung zu einer Gruppe. Wird für Einladungslinks verwendet.
CREATE TABLE GruppenEinladung (
    id           INTEGER PRIMARY KEY,
    gruppe_id    INTEGER NOT NULL,
    ersteller_id INTEGER NOT NULL,
    gueltig_bis  DATE,
    kennung_id   INTEGER NOT NULL UNIQUE,
    FOREIGN KEY (gruppe_id)
        REFERENCES Gruppe (id),
    FOREIGN KEY (ersteller_id)
        REFERENCES Student (id),
    FOREIGN KEY (kennung_id)
        REFERENCES EindeutigeKennung (id)
);


-- TODO [Tabelle] Treffzeiten nach Wochentag.

-- TODO [Trigger] Einfügen überlappender Treffzeiten zusammenführen.
-- Falls ein einzufügender Zeitintervall mit einem anderen überlappt
-- sollte der existierende geupdated werden anstatt einen Fehler zu werden.
-- -> { von: MIN(:old.von, :new.von), bis: MAX(:old.bis, :new.bis) }


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



/*/ -- FIXME Ist das hier wirklich sinnvoll?

-- Ein Student kann bestimmte Module auswählen die für ihn relevant sind.
CREATE TABLE Student_Modul (
    student_id INTEGER,
    modul_id   INTEGER,
    FOREIGN KEY (student_id)
        REFERENCES Student (id)
            ON DELETE CASCADE,
    FOREIGN KEY (modul_id)
        REFERENCES Modul (id)
            -- Falls ein Modul aus irgendeinem Grund gelöscht werden sollte
            -- ist es hier sicher die Assoziation zwischen Student und Modul
            -- zu löschen, da sie nur als Suchkriterium verwendet wird.
            ON DELETE CASCADE
);

-- TODO [Trigger] Nach Anlegen eines Studenten alle aktuellen Module auswählen.
-- Falls ein Student neu erstellt wird gehen wir davon aus dass er zuerst
-- einmal alle Module seines aktuellen Studiengangs ausgewählt haben möchte.

-- Nach der Registrierung landet der Nutzer dann auf der Suchseite und kann
-- dort dann feiner einstellen welche anderen Module er noch aufgelistet
-- bekommen möchte oder an welchen er nicht interessiert ist.

-- TODO [Trigger] Student kann nur Module des eigenen Studiengangs wählen.

/**/



/* -- Notizen

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
