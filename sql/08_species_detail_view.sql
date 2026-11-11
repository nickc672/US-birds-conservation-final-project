-- One row per species with its groups and states as comma separated lists.

CREATE OR REPLACE VIEW species_detail AS
WITH group_lists AS ( -- each species' groups in heading order
    SELECT scientific_name, GROUP_CONCAT(group_name ORDER BY group_pos SEPARATOR ', ') AS group_category
    FROM species_group
    GROUP BY scientific_name
),
state_lists AS ( -- each species' states in alphabetical order, and how many there are
    SELECT ss.scientific_name, GROUP_CONCAT(st.state_name ORDER BY st.state_id SEPARATOR ', ') AS locations, COUNT(*) AS n_states
    FROM species_state AS ss
    JOIN us_state AS st ON st.state_id = ss.state_id
    GROUP BY ss.scientific_name
)
-- Species with their family, order, status name, groups, and states.
SELECT s.list_order,
       s.common_name,
       s.scientific_name,
       g.group_category,
       f.order_name,
       f.family_name,
       cs.status_name AS conservation_status,
       sl.locations,
       sl.n_states
FROM species AS s
JOIN bird_family AS f ON f.family_name = s.family_name
JOIN conservation_status AS cs ON cs.status_code = s.status_code
LEFT JOIN group_lists AS g ON g.scientific_name = s.scientific_name
LEFT JOIN state_lists AS sl ON sl.scientific_name = s.scientific_name;
