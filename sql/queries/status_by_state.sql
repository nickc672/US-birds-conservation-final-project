-- Conservation status counts per state, one column per status, ordered by total species.

SELECT st.state_name,
       SUM(CASE WHEN s.status_code = 'UNK' THEN 1 ELSE 0 END) AS `UNKNOWN`,
       SUM(CASE WHEN s.status_code = 'LC' THEN 1 ELSE 0 END) AS `LEAST CONCERN`,
       SUM(CASE WHEN s.status_code = 'NT' THEN 1 ELSE 0 END) AS `NEAR THREATENED`,
       SUM(CASE WHEN s.status_code = 'VU' THEN 1 ELSE 0 END) AS `VULNERABLE`,
       SUM(CASE WHEN s.status_code = 'EN' THEN 1 ELSE 0 END) AS `ENDANGERED`,
       SUM(CASE WHEN s.status_code = 'CR' THEN 1 ELSE 0 END) AS `CRITICALLY ENDANGERED`,
       SUM(CASE WHEN s.status_code = 'EW' THEN 1 ELSE 0 END) AS `EXTINCT IN THE WILD`,
       SUM(CASE WHEN s.status_code = 'EX' THEN 1 ELSE 0 END) AS `EXTINCT`,
       COUNT(*) AS total_species
FROM species_state AS ss
JOIN species AS s ON s.scientific_name = ss.scientific_name
JOIN us_state AS st ON st.state_id = ss.state_id
GROUP BY st.state_name
ORDER BY total_species DESC, st.state_name;
