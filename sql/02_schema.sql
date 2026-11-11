-- Lookup tables, staging tables for the raw page text, and the normalized final tables.

-- Remove the view and the lookup and final tables (staging tables are kept).
DROP VIEW IF EXISTS species_detail;
DROP TABLE IF EXISTS species_state;
DROP TABLE IF EXISTS species_group;
DROP TABLE IF EXISTS species;
DROP TABLE IF EXISTS bird_family;
DROP TABLE IF EXISTS conservation_status;
DROP TABLE IF EXISTS us_state;

-- IUCN conservation statuses, from least to most severe.
CREATE TABLE conservation_status (
    status_code VARCHAR(3) PRIMARY KEY,
    status_name VARCHAR(30) NOT NULL UNIQUE,
    chart_order INT NOT NULL -- bottom to the top in order in the stacked bar charts
);
INSERT INTO conservation_status (status_code, status_name, chart_order) VALUES
    ('UNK', 'UNKNOWN', 0),
    ('LC', 'LEAST CONCERN', 1),
    ('NT', 'NEAR THREATENED', 2),
    ('VU', 'VULNERABLE', 3),
    ('EN', 'ENDANGERED', 4),
    ('CR', 'CRITICALLY ENDANGERED', 5),
    ('EW', 'EXTINCT IN THE WILD', 6),
    ('EX', 'EXTINCT', 7);

-- The 50 states of the name each one uses in its Wikipedia URL.
CREATE TABLE us_state (
    state_id INT PRIMARY KEY,
    wiki_slug VARCHAR(50) NOT NULL UNIQUE, -- used to build the Wikipedia URL
    state_name VARCHAR(50) NOT NULL UNIQUE
);
INSERT INTO us_state (state_id, wiki_slug, state_name) VALUES
    (1, 'Alabama', 'Alabama'),
    (2, 'Alaska', 'Alaska'),
    (3, 'Arizona', 'Arizona'),
    (4, 'Arkansas', 'Arkansas'),
    (5, 'California', 'California'),
    (6, 'Colorado', 'Colorado'),
    (7, 'Connecticut', 'Connecticut'),
    (8, 'Delaware', 'Delaware'),
    (9, 'Florida', 'Florida'),
    (10, 'Georgia_(U.S._state)', 'Georgia'), -- wiki URL is different from how I want to represent name
    (11, 'Hawaii', 'Hawaii'),
    (12, 'Idaho', 'Idaho'),
    (13, 'Illinois', 'Illinois'),
    (14, 'Indiana', 'Indiana'),
    (15, 'Iowa', 'Iowa'),
    (16, 'Kansas', 'Kansas'),
    (17, 'Kentucky', 'Kentucky'),
    (18, 'Louisiana', 'Louisiana'),
    (19, 'Maine', 'Maine'),
    (20, 'Maryland', 'Maryland'),
    (21, 'Massachusetts', 'Massachusetts'),
    (22, 'Michigan', 'Michigan'),
    (23, 'Minnesota', 'Minnesota'),
    (24, 'Mississippi', 'Mississippi'),
    (25, 'Missouri', 'Missouri'),
    (26, 'Montana', 'Montana'),
    (27, 'Nebraska', 'Nebraska'),
    (28, 'Nevada', 'Nevada'),
    (29, 'New_Hampshire', 'New Hampshire'),
    (30, 'New_Jersey', 'New Jersey'),
    (31, 'New_Mexico', 'New Mexico'),
    (32, 'New_York', 'New York'),
    (33, 'North_Carolina', 'North Carolina'),
    (34, 'North_Dakota', 'North Dakota'),
    (35, 'Ohio', 'Ohio'),
    (36, 'Oklahoma', 'Oklahoma'),
    (37, 'Oregon', 'Oregon'),
    (38, 'Pennsylvania', 'Pennsylvania'),
    (39, 'Rhode_Island', 'Rhode Island'),
    (40, 'South_Carolina', 'South Carolina'),
    (41, 'South_Dakota', 'South Dakota'),
    (42, 'Tennessee', 'Tennessee'),
    (43, 'Texas', 'Texas'),
    (44, 'Utah', 'Utah'),
    (45, 'Vermont', 'Vermont'),
    (46, 'Virginia', 'Virginia'),
    (47, 'Washington_(state)', 'Washington'),
    (48, 'West_Virginia', 'West Virginia'),
    (49, 'Wisconsin', 'Wisconsin'),
    (50, 'Wyoming', 'Wyoming');

-- Staging: raw page text loaded by load_pages.py. page_id 0 is the U.S. list; 1-50 are the states.
CREATE TABLE IF NOT EXISTS stg_section (
    page_id INT,
    section_idx INT, -- position of the section on its page from 0
    heading TEXT,
    first_paragraph TEXT, -- the 'Order: ... Family: ...' line on the U.S. list
    PRIMARY KEY (page_id, section_idx)
);

-- One row per line of each section's list.
CREATE TABLE IF NOT EXISTS stg_line (
    page_id INT,
    section_idx INT,
    line_no INT,
    line_text TEXT,
    PRIMARY KEY (page_id, section_idx, line_no)
);

-- One row per word of each line, where the word sits in the line.
CREATE TABLE IF NOT EXISTS stg_word (
    page_id INT,
    section_idx INT,
    line_no INT,
    word_no INT,
    word TEXT,
    start_pos INT, -- position of the word's first character in line_text, from 1
    end_pos INT, -- position of its last character
    PRIMARY KEY (page_id, section_idx, line_no, word_no)
);

-- Each bird family and the order it belongs to.
CREATE TABLE bird_family (
    family_name VARCHAR(255) PRIMARY KEY,
    order_name VARCHAR(255) NOT NULL
);

-- One row per species.
CREATE TABLE species (
    scientific_name VARCHAR(255) PRIMARY KEY,
    common_name VARCHAR(500) NOT NULL,
    family_name VARCHAR(255) NOT NULL,
    status_code VARCHAR(3) NOT NULL,
    list_order INT NOT NULL, -- position on the U.S. list (taxonomic order)
    FOREIGN KEY (family_name) REFERENCES bird_family (family_name),
    FOREIGN KEY (status_code) REFERENCES conservation_status (status_code)
);

-- The groups each species belongs to (a species can be in several).
CREATE TABLE species_group (
    scientific_name VARCHAR(255) NOT NULL,
    group_pos INT NOT NULL, -- order of the group within the section heading
    group_name VARCHAR(255) NOT NULL,
    PRIMARY KEY (scientific_name, group_pos),
    FOREIGN KEY (scientific_name) REFERENCES species (scientific_name)
);

-- The states each species has been recorded in.
CREATE TABLE species_state (
    scientific_name VARCHAR(255) NOT NULL,
    state_id INT NOT NULL,
    PRIMARY KEY (scientific_name, state_id),
    FOREIGN KEY (scientific_name) REFERENCES species (scientific_name),
    FOREIGN KEY (state_id) REFERENCES us_state (state_id)
);
