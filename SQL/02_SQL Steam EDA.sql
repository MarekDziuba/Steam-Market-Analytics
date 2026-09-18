-- Exploratory Data Analysis
-- Note: Genre analyses excluded 'Free to play' and 'Early Access' 
-- to show better revenue and they are not typical game genres

-- 1. OVERALL MARKET METRICS
-- --------------------------------------------------------------------
-- Total game count, rating of all games, and cumulative revenue (in millions)
SELECT 
    COUNT(appid) AS total_games,
    ROUND(AVG(rating_score), 2) AS overall_avg_rating,
    ROUND(SUM(estimated_revenue) / 1000000, 2) AS total_revenue_millions,
    ROUND(AVG(estimated_revenue) / 1000000, 2) AS average_revenue_millions
FROM steam_standarize;


-- 2. PRICE & PLAYTIME DISTRIBUTION
-- --------------------------------------------------------------------
-- Game volume breakdown across price ranges
SELECT 
	price_range, 
    COUNT(appid) AS count_games
FROM steam_standarize
GROUP BY price_range
ORDER BY count_games DESC;

-- Game volume and average rating across playtime categories
SELECT 
	playtime_range, 
    COUNT(appid) AS count_games,
    ROUND(AVG(rating_score), 2) AS avg_rating
FROM steam_standarize
GROUP BY playtime_range
ORDER BY count_games DESC;


-- 3. MARKET GENRE ANALYSIS
-- --------------------------------------------------------------------
-- TOP 15 genres ranked by total volume of games
SELECT 
	sgt.tag_genre_name AS genre, 
    COUNT(DISTINCT sgt.appid) AS count_games
FROM steam_genres_tag sgt 
GROUP BY genre
ORDER BY count_games DESC
LIMIT 15;

-- TOP 15 genres: Performance metrics (ratings & revenue)
SELECT
	sg.tag_genre_name AS genre,
    COUNT(DISTINCT ss.appid) AS count_games,
    ROUND(AVG(ss.rating_score), 2) AS avg_rating,
    ROUND(AVG(ss.estimated_revenue) / 1000000, 2) AS avg_revenue_millions, 
    ROUND(SUM(ss.estimated_revenue) / 1000000, 2) AS sum_revenue_millions
FROM steam_standarize ss
JOIN steam_genres_tag sg
	ON ss.appid = sg.appid
WHERE sg.tag_genre_name NOT IN ('Free to Play', 'Early Access')
GROUP BY sg.tag_genre_name
ORDER BY COUNT(DISTINCT ss.appid) DESC
LIMIT 15;

-- TOP 15 genres by total estimated player base (minimum owners in millions)
WITH CTE AS
(
SELECT 
	sg.tag_genre_name AS genre, 
    ROUND(SUM(ss.owners_min) / 1000000, 2) as bought_genre_game_millions
FROM steam_standarize ss
JOIN steam_genres_tag sg
	ON ss.appid = sg.appid
WHERE sg.tag_genre_name NOT IN ('Free to Play', 'Early Access')
GROUP BY sg.tag_genre_name
ORDER BY COUNT(DISTINCT ss.appid) DESC
LIMIT 15
)
SELECT *
FROM CTE
ORDER BY bought_genre_game_millions DESC;


-- 4. PUBLISHERS AND DEVELOPERS BENCHMARKING
-- --------------------------------------------------------------------
-- TOP 15 publishers performance by volume of released games
SELECT 
	sp.publisher_name AS publisher, 
    COUNT(DISTINCT ss.appid) AS count_games,
    ROUND(SUM(ss.estimated_revenue) / 1000000, 2) AS total_revenue_millions,
    ROUND(AVG(ss.rating_score), 2) AS avg_rating
FROM steam_publishers sp
JOIN steam_standarize ss 
	ON sp.appid = ss.appid
GROUP BY publisher_name
ORDER BY count_games desc
LIMIT 15;

-- TOP 15 developers performance by volume of released games
SELECT
	sd.developer_name AS developer, 
    COUNT(DISTINCT ss.appid) AS count_games,
    ROUND(SUM(ss.estimated_revenue) / 1000000, 2) AS total_revenue_millions,
    ROUND(AVG(ss.rating_score), 2) AS avg_rating
FROM steam_developers sd
JOIN steam_standarize ss 
	ON sd.appid = ss.appid
GROUP BY sd.developer_name
ORDER BY count_games DESC
LIMIT 15;
