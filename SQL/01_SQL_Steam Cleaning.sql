-- STEAM DATA CLEANING & TRANSFORMATION
-- Dataset source: https://www.kaggle.com/datasets/nikdavis/steam-store-games?select=steam.csv
-- Raw dataset timeframe: Games released up to May 2019 (~27,075 records)

-- STEP 0: INITIAL SETUP
-- --------------------------------------------------------------------
-- Creating working copy `steam_cleaning` to alter data safely without losing the raw source table.
CREATE TABLE steam_cleaning
LIKE steam;

INSERT INTO steam_cleaning
SELECT *
FROM steam;

-- STEP 1: DUPLICATE DETECTION & REMOVAL
-- --------------------------------------------------------------------
-- Using a CTE with COUNT() OVER(PARTITION BY...) to identify identical rows across all attributes.
-- 
-- Handling Methodology:
-- If duplicate rows exist (row_num > 1):
-- 1. Create a secondary staging table (`steam_cleaning2`) including the `row_num` column.
-- 2. Insert all partitioned records into `steam_cleaning2`.
-- 3. Delete records where `row_num > 1`.
--
-- Result: This dataset contained 0 duplicate records.
WITH chcek_dup AS
(
	SELECT 
		*,
		COUNT(*) OVER( PARTITION BY appid, `name`, release_date, english, developer, publisher, platforms, 
									required_age, categories, genres, steamspy_tags, achievements, positive_ratings, 
                                    negative_ratings, average_playtime, median_playtime, owners, price
						) as row_num
	FROM steam_cleaning
)
SELECT *
FROM chcek_dup
WHERE row_num > 1;

-- STEP 2: DATA STANDARDIZATION
-- --------------------------------------------------------------------
-- Planned transformations & logic:
-- 1. Create new calculated metrics and buckets:
--    - `all_ratings`: Total user review count (positive + negative) as a product engagement proxy.
--    - `rating_score`: Positive rating percentage calculated as (positive / total) * 100.
--    - `price_range`: Price tiers (e.g. Free to Play, $0.1-9.99, $10-19.99, etc.) for revenue grouping.
--    - `date_range`: Release timeframes ('2000 - 2004', '2005 - 2009', etc.) to observe market growth over time.
--    - `median_playtime_hours`: Converted from minutes to hours for better readability.
--    - `playtime_range`: Categorical duration buckets ('0 - 2', '2 - 10', etc.) to group games by player commitment.
-- 2. Quality Threshold: Filter out games with fewer than 100 total ratings to remove noise/shovelware.
-- 3. Data Normalization: Move multi-value columns (`genres`, `tags`, `platforms`, `developers`, `publishers`, `categories`) to 1:M tables.
-- 4. Column Cleanup Rationale:
--    - `achievements`: High variance, minimal analytical value (many games lack them entirely).
--    - `english`: Low impact on general revenue/market trends.
--    - `average_playtime`: Highly susceptible to bot inflation and extreme outliers; `median_playtime` offers a much more realistic user engagement metric.
--    - `steamspy_tags`, `categories`, `genres`, `platforms`, `developer`, `publisher`: Extracted into normalized tables.

CREATE TABLE steam_standarize
LIKE steam_cleaning;

INSERT INTO steam_standarize
SELECT *
FROM steam_cleaning;

-- Add new engineered columns
ALTER TABLE steam_standarize
	ADD COLUMN `all_ratings` BIGINT,
	ADD COLUMN `rating_score` INT,
	ADD COLUMN `price_range` VARCHAR(50),
	ADD COLUMN `date_range` VARCHAR(50),
    ADD COLUMN `median_playtime_hours` DECIMAL(10, 1),
	ADD COLUMN `playtime_range` VARCHAR(50);

-- Convert median playtime from minutes to hours and remove redundant column
UPDATE steam_standarize
SET median_playtime_hours = ROUND(median_playtime / 60.0, 1);

ALTER TABLE steam_standarize
DROP COLUMN median_playtime;

-- Populate calculated metrics and categorical ranges
UPDATE steam_standarize
SET 
    all_ratings = positive_ratings + negative_ratings,
    rating_score = ROUND(positive_ratings / NULLIF(positive_ratings + negative_ratings, 0) * 100, 1),
    price_range = CASE
        WHEN price = 0 THEN 'Free to Play'                    
        WHEN price BETWEEN 0.1 AND 9.99 THEN '0.1 - 9.99'                
        WHEN price BETWEEN 10 AND 19.99 THEN '10 - 19.99'                
        WHEN price BETWEEN 20 AND 39.99 THEN '20 - 39.99'                               
        ELSE '40+'                                        
    END,
    date_range = CASE
        WHEN release_date <= '1999-12-31' THEN '1998 - 1999'                  
        WHEN release_date BETWEEN '2000-01-01' AND '2004-12-31' THEN '2000 - 2004' 
        WHEN release_date BETWEEN '2005-01-01' AND '2009-12-31' THEN '2005 - 2009'
        WHEN release_date BETWEEN '2010-01-01' AND '2014-12-31' THEN '2010 - 2014'
        WHEN release_date BETWEEN '2015-01-01' AND '2019-12-31' THEN '2015 - 2019'
        ELSE '2020+'                                        
    END,
    playtime_range = CASE
        WHEN median_playtime_hours <= 2 THEN '0 - 2' 
		WHEN median_playtime_hours BETWEEN 2 AND 10 THEN '2 - 10'                  
        WHEN median_playtime_hours BETWEEN 11 AND 30 THEN '11 - 30'            
        WHEN median_playtime_hours BETWEEN 31 AND 60 THEN '31 - 60'            
        WHEN median_playtime_hours BETWEEN 61 AND 100 THEN '61 - 100'            
        ELSE '100+'                                        
    END;

    
-- Filter out low-volume products (<100 ratings)
DELETE FROM steam_standarize
WHERE All_Ratings < 100;


-- STEP 3: CREATING RELATIONAL TABLES
-- --------------------------------------------------------------------

-- 3.1 Play Mode Dimensions
-- Categorizes titles as Singleplayer, Multiplayer, or Both based on string matching.
CREATE TABLE steam_categories AS
	SELECT 
		appid,
		CASE 
			WHEN (LOWER(categories) LIKE '%single-player%' OR LOWER(categories) LIKE '%singleplayer%') 
				AND (LOWER(categories) LIKE '%multi-player%' OR LOWER(categories) LIKE '%multiplayer%') THEN 'Both (Single & Multi)'
			WHEN (LOWER(categories) LIKE '%single-player%' OR LOWER(categories) LIKE '%singleplayer%') THEN 'Singleplayer Only'
			WHEN (LOWER(categories) LIKE '%multi-player%' OR LOWER(categories) LIKE '%multiplayer%') THEN 'Multiplayer Only'
			ELSE 'Unknown'
		END AS play_mode
	FROM steam_standarize;

-- 3.2 Main Genres Table
-- Data inspection showed a maximum of 7 genres per game.
CREATE TABLE steam_genres_main AS
	-- First Genre
	SELECT appid, TRIM(SUBSTRING_INDEX(genres, ';', 1)) AS genre_name
	FROM steam_standarize
	WHERE genres IS NOT NULL AND genres != ''
UNION ALL
	-- Second Genre if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(genres, ';', 2), ';', -1)) AS genre_name
	FROM steam_standarize
	WHERE genres LIKE '%;%'
UNION ALL
-- Third Genre if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(genres, ';', 3), ';', -1)) AS genre_name
	FROM steam_standarize
	WHERE genres LIKE '%;%;%'
UNION ALL
-- Fourth Genre if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(genres, ';', 4), ';', -1)) AS genre_name
	FROM steam_standarize
	WHERE genres LIKE '%;%;%;%'
UNION ALL
-- Fifth Genre if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(genres, ';', 5), ';', -1)) AS genre_name
	FROM steam_standarize
	WHERE genres LIKE '%;%;%;%;%'
UNION ALL
-- Sixth Genre if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(genres, ';', 6), ';', -1)) AS genre_name
	FROM steam_standarize
	WHERE genres LIKE '%;%;%;%;%;%'
UNION ALL
-- Seventh Genre if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(genres, ';', 7), ';', -1)) AS genre_name
	FROM steam_standarize
	WHERE genres LIKE '%;%;%;%;%;%;%';

-- 3.3 Tag Genres Table (SteamSpy Tags)
-- Data inspection showed a maximum of 3 tags per game.
CREATE TABLE steam_genres_tag AS
	-- First Genre
	SELECT appid, TRIM(SUBSTRING_INDEX(steamspy_tags, ';', 1)) AS tag_genre_name
	FROM steam_standarize
	WHERE steamspy_tags IS NOT NULL AND steamspy_tags != ''
UNION ALL
	-- Second Genre if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(steamspy_tags, ';', 2), ';', -1)) AS tag_genre_name
	FROM steam_standarize
	WHERE steamspy_tags LIKE '%;%'
UNION ALL
-- Third Genre if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(steamspy_tags, ';', 3), ';', -1)) AS tag_genre_name
	FROM steam_standarize
	WHERE steamspy_tags LIKE '%;%;%';

-- 3.4 Supported Platforms Table
-- Steam supports 3 core OS platforms: PC, Mac, Linux.
CREATE TABLE steam_platforms AS
	-- First Platform
	SELECT appid, TRIM(SUBSTRING_INDEX(platforms, ';', 1)) AS platform_name
	FROM steam_standarize
	WHERE platforms IS NOT NULL AND platforms != ''
UNION ALL
	-- Second Platform if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(platforms, ';', 2), ';', -1)) AS platform_name
	FROM steam_standarize
	WHERE platforms LIKE '%;%'
UNION ALL
-- Third Platform if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(platforms, ';', 3), ';', -1)) AS platform_name
	FROM steam_standarize
	WHERE platforms LIKE '%;%;%'; 

-- 3.5 Developers Table
-- Data inspection showed a maximum of 4 developers per game.
CREATE TABLE steam_developers AS
	-- First Developer
	SELECT appid, TRIM(SUBSTRING_INDEX(developer, ';', 1)) AS developer_name
	FROM steam_standarize
	WHERE developer IS NOT NULL AND developer != ''
UNION ALL
	-- Second Developer if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(developer, ';', 2), ';', -1)) AS developer_name
	FROM steam_standarize
	WHERE developer LIKE '%;%'
UNION ALL
-- Third Developer if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(developer, ';', 3), ';', -1)) AS developer_name
	FROM steam_standarize
	WHERE developer LIKE '%;%;%'
    UNION ALL
-- Forth Developer if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(developer, ';', 4), ';', -1)) AS developer_name
	FROM steam_standarize
	WHERE developer LIKE '%;%;%;%';

-- 3.6 Publishers Table
-- Data inspection showed a maximum of 4 publishers per game.
CREATE TABLE steam_publishers AS
	-- First Publisher
	SELECT appid, TRIM(SUBSTRING_INDEX(publisher, ';', 1)) AS publisher_name
	FROM steam_standarize
	WHERE publisher IS NOT NULL AND publisher != ''
UNION ALL
	-- Second Publisher if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(publisher, ';', 2), ';', -1)) AS publisher_name
	FROM steam_standarize
	WHERE publisher LIKE '%;%'
UNION ALL
-- Third Publisher if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(publisher, ';', 3), ';', -1)) AS publisher_name
	FROM steam_standarize
	WHERE publisher LIKE '%;%;%'
    UNION ALL
-- Forth Publisher if exist
	SELECT appid, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(publisher, ';', 4), ';', -1)) AS publisher_name
	FROM steam_standarize
	WHERE publisher LIKE '%;%;%;%';
    

-- STEP 4: CLEANUP UNNECESSARY COLUMNS
-- --------------------------------------------------------------------
-- Dropping columns that have been split into relational tables or are irrelevant for analysis.
ALTER TABLE steam_standarize
DROP COLUMN achievements,
DROP COLUMN steamspy_tags,
DROP COLUMN english,
DROP COLUMN average_playtime,
DROP COLUMN categories,
DROP COLUMN genres,
DROP COLUMN platforms,
DROP COLUMN developer,
DROP COLUMN publisher;

-- STEP 5: ANOMALY CORRECTION & ENTITY MAPPING
-- --------------------------------------------------------------------
-- 5.1 Anomaly Fix: Remove 'Free to Play' genre tag for games with an explicit price (> 0).
DELETE FROM steam_genres_main
WHERE genre_name = 'Free to Play'
  AND appid IN (
      SELECT appid 
      FROM steam_standarize 
      WHERE price > 0
  );
  
DELETE FROM steam_genres_tag
WHERE tag_genre_name = 'Free to Play'
  AND appid IN (
      SELECT appid 
      FROM steam_standarize 
      WHERE price > 0
  );

-- 5.2 Anomaly Fix: Remove ghost games with zero median playtime across all tables.
DELETE FROM steam_genres_tag
WHERE appid IN (
    SELECT appid 
    FROM steam_standarize 
    WHERE median_playtime_hours = 0 OR median_playtime_hours IS NULL
);

DELETE FROM steam_publishers
WHERE appid IN (
    SELECT appid 
    FROM steam_standarize 
    WHERE median_playtime_hours = 0 OR median_playtime_hours IS NULL
);

DELETE FROM steam_developers
WHERE appid IN (
    SELECT appid 
    FROM steam_standarize 
    WHERE median_playtime_hours = 0 OR median_playtime_hours IS NULL
);

DELETE FROM steam_standarize
WHERE median_playtime_hours = 0 OR median_playtime_hours IS NULL;
    
-- 5.3 Owners Range Parsing & Revenue Calculation:
-- Convert string range (e.g. '20000-50000') into numeric lower boundary (`owners_min`)
-- and calculate estimated revenue (`owners_min * price`).
ALTER TABLE steam_standarize
ADD COLUMN owners_min INT,
ADD COLUMN estimated_revenue DECIMAL(15, 2);

UPDATE steam_standarize
SET 
	owners_min = TRIM(SUBSTRING_INDEX(owners, '-', 1)),
	estimated_revenue = TRIM(SUBSTRING_INDEX(owners, '-', 1)) * price;
    
-- 5.4 Entity Normalization for Companies (Developers & Publishers):
-- Problem: Variations like 'Feral Interactive (Mac)', 'Feral Interactive (Linux)' distort brand metrics.
-- Approach:
-- Step 5.4.1: Clean legal and platform suffixes using Regex.
-- Step 5.4.2: Create Mapping Table to parent brands via a custom dictionary table.

-- Step 5.4.1: Regex Cleaning
-- Developers
UPDATE `steam_developers`
SET developer_name = TRIM(
    REGEXP_REPLACE(
        REGEXP_REPLACE(
            REGEXP_REPLACE(developer_name, '\\s*\\(.*?\\)', '', 1, 0, 'i'),
            '\\s*(Co\\.,\\s*Ltd\\.|Ltd\\.|Inc\\.|Corp\\.|LLC|Studios?|Entertainment)', '', 1, 0, 'i'
        ),
        '\\s*(in collaboration with|,).*$', '', 1, 0, 'i'
    )
)
WHERE developer_name IS NOT NULL AND developer_name != '';

-- Publishers
UPDATE `steam_publishers`
SET publisher_name = TRIM(
    REGEXP_REPLACE(
        REGEXP_REPLACE(
            REGEXP_REPLACE(publisher_name, '\\s*\\(.*?\\)', '', 1, 0, 'i'),
            '\\s*(Co\\.,\\s*Ltd\\.|Ltd\\.|Inc\\.|Corp\\.|LLC|Studios?|Entertainment)', '', 1, 0, 'i'
        ),
        '\\s*(in collaboration with|,).*$', '', 1, 0, 'i'
    )
)
WHERE publisher_name IS NOT NULL AND publisher_name != '';

-- Step 5.4.2: Parent Brand Mapping Table
CREATE TABLE IF NOT EXISTS company_dictionary (
    pattern VARCHAR(255),
    clean_brand VARCHAR(255)
);

INSERT INTO company_dictionary (pattern, clean_brand) VALUES
('%Ubisoft%', 'Ubisoft'),
('%Capcom%', 'Capcom'),
('%Square Enix%', 'Square Enix'),
('%Bandai Namco%', 'Bandai Namco'),
('%Electronic Arts%', 'EA'),
('%EA Games%', 'EA'),
('%Warner Bros%', 'Warner Bros'),
('%Feral Interactive%', 'Feral Interactive'),
('%THQ%', 'THQ Nordic'),
('%SEGA%', 'SEGA'),
('%Paradox%', 'Paradox Interactive');

-- Update developers
UPDATE `steam_developers` sd
JOIN company_dictionary cd ON sd.developer_name LIKE cd.pattern
SET sd.developer_name = cd.clean_brand;

-- Update publishers
UPDATE `steam_publishers` sp
JOIN company_dictionary cd ON sp.publisher_name LIKE cd.pattern
SET sp.publisher_name = cd.clean_brand;