-- One row per species line on each state list parsed into common and scientific name. Reference sections are skipped.

DROP TABLE IF EXISTS state_species_line;
CREATE TABLE state_species_line AS
WITH list_lines AS ( -- each line outside the reference sections with the position of its first comma (or period if there's no comma)
    SELECT l.page_id AS state_id, l.section_idx, l.line_no, l.line_text,
           CASE WHEN LOCATE(',', l.line_text) > 0 THEN LOCATE(',', l.line_text)
                ELSE LOCATE('.', l.line_text) END AS sep_pos
    FROM stg_line AS l
    JOIN stg_section AS s ON s.page_id = l.page_id AND s.section_idx = l.section_idx
    WHERE l.page_id > 0 AND ws_trim(s.heading) NOT IN ('See also', 'References', 'External links', 'Further reading', 'Notes')
),
after_sep AS ( -- the words after the separator (every word if there's none) numbered from 1
    SELECT ll.state_id, ll.section_idx, ll.line_no,
           CASE WHEN w.start_pos <= ll.sep_pos THEN SUBSTRING(w.word, ll.sep_pos - w.start_pos + 2)
                ELSE w.word END AS word,
           ROW_NUMBER() OVER (PARTITION BY ll.state_id, ll.section_idx, ll.line_no ORDER BY w.word_no) AS n
    FROM list_lines AS ll
    JOIN stg_word AS w ON w.page_id = ll.state_id AND w.section_idx = ll.section_idx AND w.line_no = ll.line_no
    WHERE w.end_pos > ll.sep_pos
),
picked_words AS ( -- per line words 1-2 and words 3-4
    SELECT state_id, section_idx, line_no,
           GROUP_CONCAT(CASE WHEN n <= 2 THEN word END ORDER BY n SEPARATOR ' ') AS words_1_2,
           GROUP_CONCAT(CASE WHEN n BETWEEN 3 AND 4 THEN word END ORDER BY n SEPARATOR ' ') AS words_3_4
    FROM after_sep
    GROUP BY state_id, section_idx, line_no
),
raw_names AS ( -- common name before the separator, scientific name the two words after it, if without a separator then words 1-2 and 3-4
    SELECT ll.state_id, ll.section_idx, ll.line_no, ll.line_text,
           CASE WHEN ll.sep_pos > 0 THEN ws_trim(LEFT(ll.line_text, ll.sep_pos - 1))
                WHEN p.words_1_2 = 'Saltmarsh sparrowAmmospiza' THEN 'Saltmarsh sparrow' -- missing space on the source page (error on wiki)
                ELSE COALESCE(p.words_1_2, '') END AS common_raw,
           CASE WHEN ll.sep_pos > 0 THEN COALESCE(p.words_1_2, '')
                WHEN p.words_1_2 = 'Saltmarsh sparrowAmmospiza' THEN 'Ammospiza caudacuta'
                ELSE COALESCE(p.words_3_4, '') END AS scientific_raw
    FROM list_lines AS ll
    LEFT JOIN picked_words AS p ON p.state_id = ll.state_id AND p.section_idx = ll.section_idx AND p.line_no = ll.line_no
)
-- Uppercase the names and keep only the first of alternatives like 'Name A/Name B'.
SELECT state_id, section_idx, line_no, line_text,
       CASE WHEN LOCATE('/', common_raw) > 0 THEN ws_trim(SUBSTRING_INDEX(UPPER(common_raw), '/', 1))
            ELSE UPPER(common_raw) END AS common_name,
       CASE WHEN LOCATE('/', scientific_raw) > 0 THEN ws_trim(SUBSTRING_INDEX(UPPER(scientific_raw), '/', 1))
            ELSE UPPER(scientific_raw) END AS scientific_name
FROM raw_names;
