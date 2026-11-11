-- One row per species, with status codes mapped to names. If a species is listed twice then only the later entry's details are kept.

DROP TABLE IF EXISTS species_master;
CREATE TABLE species_master AS
WITH ranked AS ( -- number each specie's entries from latest to earliest. Keep its first position on the list
    SELECT l.*,
           MIN(list_order) OVER (PARTITION BY scientific_name) AS first_position,
           ROW_NUMBER() OVER (PARTITION BY scientific_name ORDER BY list_order DESC) AS rn
    FROM us_species_line AS l
)
-- Keep the latest entry like a status that isn't a valid IUCN code becomes UNKNOWN.
SELECT r.scientific_name, r.common_name, r.order_name,r.family_name,
       COALESCE(cs.status_code, 'UNK') AS status_code, r.heading, r.first_position AS list_order
FROM ranked AS r
LEFT JOIN conservation_status AS cs ON cs.status_code = r.status_raw AND cs.status_code != 'UNK'
WHERE r.rn = 1;
