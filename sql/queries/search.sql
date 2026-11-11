-- Search species by any combination of filters. 
-- Set a filter to NULL to ignore it.
-- States can be given by name ('Alaska') or Wikipedia URL form ('ALASKA').

-- Filters
SET @common_name = NULL;
SET @scientific_name = NULL;
SET @group_name = NULL;
SET @order_name = NULL;
SET @family_name = NULL;
SET @status = NULL;
SET @state = 'ALASKA'; -- example: species recorded in Alaska...

-- "Not" filters
SET @common_name_not = NULL;
SET @scientific_name_not = NULL;
SET @group_name_not = 'SWIFTS'; -- ...excluding swifts
SET @order_name_not = NULL;
SET @family_name_not = NULL;
SET @status_not = NULL;
SET @state_not = NULL;

-- Species that pass every filter that's set, in list order.
SELECT d.*
FROM species_detail AS d
WHERE (@common_name IS NULL OR d.common_name = UPPER(@common_name))
  AND (@common_name_not IS NULL OR d.common_name != UPPER(@common_name_not))
  AND (@scientific_name IS NULL OR d.scientific_name = UPPER(@scientific_name))
  AND (@scientific_name_not IS NULL OR d.scientific_name != UPPER(@scientific_name_not))
  AND (@order_name IS NULL OR d.order_name = UPPER(@order_name))
  AND (@order_name_not IS NULL OR d.order_name != UPPER(@order_name_not))
  AND (@family_name IS NULL OR d.family_name = UPPER(@family_name))
  AND (@family_name_not IS NULL OR d.family_name != UPPER(@family_name_not))
  AND (@status IS NULL OR d.conservation_status = UPPER(@status))
  AND (@status_not IS NULL OR d.conservation_status != UPPER(@status_not))
  -- Groups and states can have many values per species, like the raven which is in two groups and many states. 
  -- Those are stored in bridge tables, one row per species and group or species and state,
  -- So group and state filters check the bridge tables because a species can have several of each:
  AND (@group_name IS NULL OR EXISTS (
          SELECT * 
          FROM species_group AS g
          WHERE g.scientific_name = d.scientific_name AND g.group_name = UPPER(@group_name)))
  AND (@group_name_not IS NULL OR NOT EXISTS (
          SELECT * 
          FROM species_group AS g
          WHERE g.scientific_name = d.scientific_name AND g.group_name = UPPER(@group_name_not)))
  AND (@state IS NULL OR EXISTS (
          SELECT * 
          FROM species_state AS ss 
          JOIN us_state AS st ON st.state_id = ss.state_id
          WHERE ss.scientific_name = d.scientific_name AND UPPER(@state) IN (UPPER(st.state_name), UPPER(st.wiki_slug))))
  AND (@state_not IS NULL OR NOT EXISTS (
          SELECT * 
          FROM species_state AS ss 
          JOIN us_state AS st ON st.state_id = ss.state_id
          WHERE ss.scientific_name = d.scientific_name AND UPPER(@state_not) IN (UPPER(st.state_name), UPPER(st.wiki_slug))))
ORDER BY d.list_order;
