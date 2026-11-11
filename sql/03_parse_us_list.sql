-- One row per species line on the U.S. list, parsed into common name, scientific name, IUCN status code, order, and family.
-- Each line reads like 'Snowy owl, Bubo scandiacus VU'.

DROP TABLE IF EXISTS us_species_line;
CREATE TABLE us_species_line AS
WITH sections AS ( -- the US list's sections each with the total number of sections on the page
    SELECT section_idx, heading, first_paragraph, COUNT(*) OVER () AS n_sections
    FROM stg_section
    WHERE page_id = 0
),
bird_sections AS ( -- skip the 3 intro sections at the start and the 4 reference sections at the end
    SELECT section_idx, heading, first_paragraph
    FROM sections
    WHERE section_idx >= 3 AND section_idx < n_sections - 4
),
list_lines AS ( -- each line with the position of its first comma (0 if it has none)
    SELECT l.section_idx, l.line_no, l.line_text, LOCATE(',', l.line_text) AS comma_pos
    FROM stg_line AS l
    JOIN bird_sections AS b ON b.section_idx = l.section_idx
    WHERE l.page_id = 0
),
after_comma AS ( -- the words after the comma (every word if there's no comma), numbered from 1
    SELECT ll.section_idx, ll.line_no,
           CASE WHEN w.start_pos <= ll.comma_pos THEN SUBSTRING(w.word, ll.comma_pos - w.start_pos + 2) -- a word like 'owl,Bubo' keeps only 'Bubo'
                ELSE w.word END AS word,
           ROW_NUMBER() OVER (PARTITION BY ll.section_idx, ll.line_no ORDER BY w.word_no) AS n,
           COUNT(*) OVER (PARTITION BY ll.section_idx, ll.line_no) AS n_words
    FROM list_lines AS ll
    JOIN stg_word AS w ON w.page_id = 0 AND w.section_idx = ll.section_idx AND w.line_no = ll.line_no
    WHERE w.end_pos > ll.comma_pos
),
picked_words AS ( -- per line: words 1-2, words 3-4, and the last word
    SELECT section_idx, line_no,
           GROUP_CONCAT(CASE WHEN n <= 2 THEN word END ORDER BY n SEPARATOR ' ') AS words_1_2,
           GROUP_CONCAT(CASE WHEN n BETWEEN 3 AND 4 THEN word END ORDER BY n SEPARATOR ' ') AS words_3_4,
           MAX(CASE WHEN n = n_words THEN word END) AS last_word
    FROM after_comma
    GROUP BY section_idx, line_no
)
-- Common name is the text before the comma, and if it doesn't have a comma then the first two words are the common name and the next two are the scientific name.
SELECT ROW_NUMBER() OVER (ORDER BY ll.section_idx, ll.line_no) AS list_order,
       ll.section_idx,
       ll.line_no,
       ll.line_text,
       ws_trim(b.heading) AS heading,
       UPPER(CASE WHEN ll.comma_pos > 0 THEN ws_trim(LEFT(ll.line_text, ll.comma_pos - 1))
                  ELSE COALESCE(p.words_1_2, '') END) AS common_name,
       UPPER(COALESCE(CASE WHEN ll.comma_pos > 0 THEN p.words_1_2 ELSE p.words_3_4 END, '')) AS scientific_name, p.last_word AS status_raw,
       UPPER(ws_trim(REPLACE(SUBSTRING_INDEX(ws_trim(b.first_paragraph), 'Family:', 1), 'Order:', ''))) AS order_name, -- text before 'Family:'
       UPPER(CASE WHEN LOCATE('Family:', b.first_paragraph) > 0 -- text after 'Family:'
                  THEN ws_trim(SUBSTRING_INDEX(SUBSTRING_INDEX(ws_trim(b.first_paragraph), 'Family:', 2), 'Family:', -1))
                  ELSE '' END) AS family_name
FROM list_lines AS ll
JOIN bird_sections AS b ON b.section_idx = ll.section_idx -- there’s always a match so it just brings in each line’s heading and first_paragraph
LEFT JOIN picked_words AS p ON p.section_idx = ll.section_idx AND p.line_no = ll.line_no; -- a line can have no row in picked_words. That table is built from the words after the comma, 
                                                                                          -- so a line with nothing after its comma, like Snowy owl,, has no words to pick and gets no row
