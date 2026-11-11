-- One row per state, species counts by conservation level, at risk amounts, diversity, and species found in no other state.

WITH state_counts AS ( -- each state's species, counted by conservation level (COUNT skips the NULLs from non-matching rows)
    SELECT ss.state_id,
           COUNT(*) AS total_species,
           COUNT(CASE WHEN s.status_code = 'LC' THEN 1 END) AS least_concern,
           COUNT(CASE WHEN s.status_code = 'NT' THEN 1 END) AS near_threatened,
           COUNT(CASE WHEN s.status_code IN ('VU', 'EN', 'CR') THEN 1 END) AS threatened,
           COUNT(CASE WHEN s.status_code = 'CR' THEN 1 END) AS critically_endangered,
           COUNT(CASE WHEN s.status_code IN ('EW', 'EX') THEN 1 END) AS extinct,
           COUNT(CASE WHEN s.status_code = 'UNK' THEN 1 END) AS unknown_status,
           COUNT(DISTINCT s.family_name) AS families,
           COUNT(DISTINCT f.order_name) AS orders
    FROM species_state AS ss
    JOIN species AS s ON s.scientific_name = ss.scientific_name
    JOIN bird_family AS f ON f.family_name = s.family_name
    GROUP BY ss.state_id
),
species_spread AS ( -- how many states each species is recorded in
    SELECT scientific_name, COUNT(*) AS n_states
    FROM species_state
    GROUP BY scientific_name
),
only_here AS ( -- species recorded in exactly one state, counted for that state
    SELECT ss.state_id, COUNT(*) AS only_in_state
    FROM species_state AS ss
    JOIN species_spread AS sp ON sp.scientific_name = ss.scientific_name
    WHERE sp.n_states = 1
    GROUP BY ss.state_id
)
-- Shares are of the state's own species; at risk = threatened (VU, EN, CR) plus extinct (EW, EX).
SELECT st.state_name,
       RANK() OVER (ORDER BY c.total_species DESC) AS species_rank,
       c.total_species,
       ROUND(100.0 * c.total_species / (SELECT COUNT(*) FROM species), 1) AS pct_of_us_species,
       c.least_concern,
       c.near_threatened,
       c.threatened,
       c.critically_endangered,
       c.extinct,
       c.unknown_status,
       ROUND(100.0 * c.least_concern / c.total_species, 1) AS pct_least_concern,
       ROUND(100.0 * c.threatened / c.total_species, 1) AS pct_threatened,
       ROUND(100.0 * (c.threatened + c.extinct) / c.total_species, 1) AS pct_at_risk,
       ROW_NUMBER() OVER (ORDER BY (c.threatened + c.extinct) / c.total_species, c.total_species DESC) AS risk_rank, -- 1 = lowest at risk share
       COALESCE(o.only_in_state, 0) AS only_in_state,
       c.families,
       c.orders
FROM state_counts AS c
JOIN us_state AS st ON st.state_id = c.state_id
LEFT JOIN only_here AS o ON o.state_id = c.state_id
ORDER BY c.total_species DESC, st.state_name;
