-- Matches each state entry to a species by scientific name and falls back to common name.

DROP TABLE IF EXISTS sighting_match;
CREATE TABLE sighting_match AS
WITH first_by_common AS ( -- the first species in list order for each common name
    SELECT common_name, scientific_name
    FROM (
       SELECT common_name, scientific_name,ROW_NUMBER() OVER (PARTITION BY common_name ORDER BY list_order) AS rn
       FROM species_master) AS numbered
    WHERE rn = 1
)
-- One row per state and species, and entries that match nothing are dropped.
SELECT DISTINCT l.state_id, COALESCE(by_sci.scientific_name, by_common.scientific_name) AS scientific_name
FROM state_species_line AS l
LEFT JOIN species_master AS by_sci ON by_sci.scientific_name = l.scientific_name
LEFT JOIN first_by_common AS by_common ON by_sci.scientific_name IS NULL AND by_common.common_name = l.common_name  -- (IS NULL) only when the scientific name didn't match
WHERE l.scientific_name NOT IN ('FORM (A)', 'GROUP (A)') AND COALESCE(by_sci.scientific_name, by_common.scientific_name) IS NOT NULL;  -- (A, B) temp lines, not species
