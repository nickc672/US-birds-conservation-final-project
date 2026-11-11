-- Species per conservation status, with each status's portion of all species.

-- SUM(COUNT(*)) OVER () is the total across all statuses, used for the percentage.
SELECT cs.status_name,
       COUNT(*) AS n_species,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_species
FROM species AS s
JOIN conservation_status AS cs ON cs.status_code = s.status_code
GROUP BY cs.status_name
ORDER BY n_species DESC, cs.status_name;
