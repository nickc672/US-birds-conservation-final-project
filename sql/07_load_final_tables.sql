-- Loads species recorded in at least one state, their families, their group names, and their states.

-- Clear the final tables, children before parents.
DELETE FROM species_state;
DELETE FROM species_group;
DELETE FROM species;
DELETE FROM bird_family;

-- Each family (with its order) that has a species recorded in a state.
INSERT INTO bird_family (family_name, order_name)
SELECT DISTINCT m.family_name, m.order_name
FROM species_master AS m
WHERE m.scientific_name IN (SELECT scientific_name FROM sighting_match);

-- Each species recorded in a state.
INSERT INTO species (scientific_name, common_name, family_name, status_code, list_order)
SELECT m.scientific_name, m.common_name, m.family_name, m.status_code, m.list_order
FROM species_master AS m
WHERE m.scientific_name IN (SELECT scientific_name FROM sighting_match);

-- Group names split out of each section heading, like 'Pigeons and doves' -> PIGEONS, DOVES.
INSERT INTO species_group (scientific_name, group_pos, group_name)
WITH headings AS ( -- each distinct heading, with ', ', ', and ' and ' and ' replaced by '|'
    SELECT DISTINCT heading, REGEXP_REPLACE(heading, '\\s*,\\s*(?:and\\s+)?|\\s+and\\s+', '|') AS delimited
    FROM species_master
),
numbers AS ( -- part positions 1-10, more than any heading has, most have 2 or 3, so 10 is beyond safe
    SELECT n FROM (VALUES ROW(1), ROW(2), ROW(3), ROW(4), ROW(5), ROW(6), ROW(7), ROW(8), ROW(9), ROW(10)) AS nums (n)
),
heading_parts AS ( -- the Nth part of each heading, for N from 1 up to its number of parts
    SELECT h.heading, nb.n AS pos, SUBSTRING_INDEX(SUBSTRING_INDEX(h.delimited, '|', nb.n), '|', -1) AS part
    FROM headings AS h
    JOIN numbers AS nb ON nb.n <= CHAR_LENGTH(h.delimited) - CHAR_LENGTH(REPLACE(h.delimited, '|', '')) + 1
)
SELECT s.scientific_name, ROW_NUMBER() OVER (PARTITION BY s.scientific_name ORDER BY hp.pos) AS group_pos, UPPER(ws_trim(hp.part)) AS group_name
FROM species AS s
JOIN species_master AS m ON m.scientific_name = s.scientific_name
JOIN heading_parts AS hp ON hp.heading = m.heading
WHERE ws_trim(hp.part) <> '';

-- Each state a species was recorded in.
INSERT INTO species_state (scientific_name, state_id)
SELECT scientific_name, state_id
FROM sighting_match;
