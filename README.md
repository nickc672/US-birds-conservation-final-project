# Nicholas Chaves - Final Project - DSCI 511
# U.S. Bird Checklist with MySQL & Python Pipeline

Builds a normalized MySQL database of the bird species recorded in each U.S. state from Wikipedia's
*List of birds of the United States* and its 50 state lists, then analyzes conservation status by state.
Python downloads the pages and splits them into sections, lines, and words. 
The cleaning, parsing, matching, and analysis are done in SQL.

## How it works

| Step | File                             | What it does                                                                |
|------|----------------------------------|-----------------------------------------------------------------------------|
|  1   | `sql/01_helpers.sql`             | Stored function that trims Unicode whitespace                               |
|  2   | `sql/02_schema.sql`              | Lookup, staging, and final tables with primary and foreign keys             |
|  3   | `load_pages.py`                  | Downloads the 51 pages & stores each page's information in staging tables   |
|  4   | `sql/03_parse_us_list.sql`       | Parses each U.S. list line into common name, scientific name, and IUCN code |
|  5   | `sql/04_species_master.sql`      | One row per species that maps status codes through the lookup table         |
|  6   | `sql/05_parse_state_lists.sql`   | Parses the 50 state lists                                                   |
|  7   | `sql/06_match_sightings.sql`     | Matches state lines to species by scientific name or to common name         |
|  8   | `sql/07_load_final_tables.sql`   | Loads the normalized tables                                                 |
|  9   | `sql/08_species_detail_view.sql` | A one row per species view with groups and states together                  |
|  10  | `notebooks/charts.ipynb`         | Runs the query files and makes the charts                                   |
|  -   | `sql/queries/`                   | Search, species per status, status by state, and state summary              |

`pipeline.py` runs steps 1–9 in order, then run step 10 separately, `db.py` holds the connection and SQL file helpers.


## Schema

species {
    varchar scientific_name PK
    varchar common_name
    varchar family_name FK
    varchar status_code FK
    int list_order
}
bird_family {
    varchar family_name PK
    varchar order_name
}
conservation_status {
    varchar status_code PK
    varchar status_name
    int chart_order
}
species_group {
    varchar scientific_name PK, FK
    int group_pos PK
    varchar group_name
}
species_state {
    varchar scientific_name PK, FK
    int state_id PK, FK
}
us_state {
    int state_id PK
    varchar wiki_slug
    varchar state_name
}

Groups and states are many-to-many, so they live in bridge tables. 
Each family belongs to one order, so order is stored once per family in `bird_family` so it's not on every species (3NF).


## SQL used

- **Window functions:** 
    `ROW_NUMBER()` to number words and de-duplicate species (`03`, `04`), 
    `COUNT(*) OVER ()` to keep only the bird sections of the page (`03`), 
    `SUM(COUNT(*)) OVER ()` for percent of total (`status_counts.sql`)
- **CTEs** to stage each transformation step, and a **numbers table** with `SUBSTRING_INDEX` that splits section headings into group names (`07`)
- **Conditional aggregation** with `SUM(CASE WHEN ...)` to pivot statuses into columns (`status_by_state.sql`)
- **`EXISTS` / `NOT EXISTS`** for the bridge tables for include/exclude filters (`search.sql`)
- **Text parsing** with `LOCATE`, `SUBSTRING_INDEX`, `GROUP_CONCAT`, and `REGEXP_REPLACE` (`03`, `05`, `07`)
- **A stored function** (`01`) and **user variables** for the search filters (`search.sql`)
- **Constraints:** primary keys, foreign keys, `NOT NULL`, `UNIQUE`


## Results (2026 data)

From the pages as downloaded in 2026. Running the pipeline downloads the current pages, so the numbers may change.

- 1,141 species in 99 families with 23,820 species–state records
- 79.8% of species are Least Concern; 111 (9.8%) are Vulnerable, Endangered, or Critically Endangered, 32 are extinct or extinct in the wild
- California (733), Texas (718), and Florida (649) have the most species. Hawaii has the fewest (331),
  but it has 28 of the 32 extinct species and the highest threatened share (55 species, 16.6%)
- South Dakota has the lowest share of species at risk (3.9% of 438), and Hawaii has the highest (25.1% of 331),
  including 91 species recorded in no other state


## Setup

1. **Install MySQL Server 8.0 or newer** (one time). On Windows, download the MSI installer for MySQL
   Community Server from [dev.mysql.com/downloads/mysql](https://dev.mysql.com/downloads/mysql/) and run it.
   When it finishes, let it open MySQL Configurator, keep the defaults (port 3306, run as a Windows service),
   and set a root password when asked.
2. **Add your password.** On `mysql.cnf` replace with your own password.
   `mysql.cnf` is in `.gitignore`, so the password stays off GitHub.
3. **Install the Python packages:**
   ```
   python -m pip install -r requirements.txt
   ```


## Running it

```
python pipeline.py
```

This creates the `birds` database, downloads the 51 pages into the staging tables (about a minute), and runs the SQL files. 
Later runs reuse the downloaded pages, and `python pipeline.py --refresh` downloads them again. 
Then open `notebooks/charts.ipynb` for the search and charts and run that file. 
To change the search, edit the `SET` lines at the top of `sql/queries/search.sql`.

Each SQL file also runs on its own once the pages are loaded:
- **MySQL Workbench:** open the file, double-click the `birds` schema to select it, and run it.
- **Command line:** `mysql --defaults-extra-file=mysql.cnf birds < sql/queries/status_counts.sql`


## Data

Species lists from [Wikipedia](https://en.wikipedia.org/wiki/List_of_birds_of_the_United_States),
available under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). 
The database isn't included in this repo, the `pipeline.py` builds it.
