CREATE TABLE IF NOT EXISTS ATHLETE_EVENTS
(
   id      INT,
   name    VARCHAR,
   sex     VARCHAR,
   age     VARCHAR,
   height  VARCHAR,
   weight  VARCHAR,
   team    VARCHAR,
   noc     VARCHAR,
   games   VARCHAR,
   year    INT,
   season  VARCHAR,
   city    VARCHAR,
   sport   VARCHAR,
   event   VARCHAR,
   medal   VARCHAR
);

CREATE TABLE IF NOT EXISTS ATHLETE_EVENTS_NOC_REGIONS
(
   noc     VARCHAR,
   region  VARCHAR,
   notes   VARCHAR
);

SELECT * FROM athlete_events ae;
SELECT * FROM athlete_events_noc_regions;

-- 1. How many olympics games have been held?

SELECT COUNT(DISTINCT games) as total_games
FROM athlete_events;

-- 2. All olympic games held so far

SELECT DISTINCT year, season, city
FROM athlete_events
ORDER BY year ASC;

-- 3. Total number of nations participated in each olympics

SELECT games, COUNT(DISTINCT region) AS total_countries
FROM athlete_events ae
JOIN athlete_events_noc_regions ar ON ae.noc = ar.noc
GROUP BY games;

-- 4. Highest and Lowest participating countries

WITH tot_countries AS (
    SELECT games,
           COUNT(DISTINCT ar.region) AS total_countries
    FROM athlete_events ae
    JOIN athlete_events_noc_regions ar ON ar.noc = ae.noc
    GROUP BY games
)
SELECT DISTINCT
    CONCAT(MIN(games), ' - ', MIN(total_countries)) AS Lowest_Countries,
    CONCAT(MAX(games), ' - ', MAX(total_countries)) AS Highest_Countries
FROM tot_countries
ORDER BY 1;

-- 5. Nation participated in all olympic games

SELECT ar.region, COUNT(DISTINCT ae.games) AS total_games
FROM athlete_events ae
JOIN athlete_events_noc_regions ar ON ar.noc = ae.noc
GROUP BY ar.region
HAVING COUNT(DISTINCT ae.games) = (SELECT COUNT(DISTINCT games) AS total_games
FROM athlete_events
);

-- 6. Sports played in all summer olympics

SELECT sport, COUNT(DISTINCT CASE WHEN games LIKE '%Summer%' THEN games END) AS no_of_games
FROM athlete_events
GROUP BY sport
HAVING COUNT(DISTINCT CASE WHEN games LIKE '%Summer%' THEN games END) = (
    SELECT COUNT(DISTINCT games)
    FROM athlete_events
    WHERE season = 'Summer'
)
ORDER BY no_of_games DESC;

-- 7. Sports played only once in olympics

SELECT sport, COUNT(DISTINCT games) AS no_of_games, MIN(games) AS games
FROM athlete_events
GROUP BY sport
HAVING COUNT(DISTINCT games) = 1;

-- 8. Total no of sports played in each olympic games

SELECT games, COUNT(DISTINCT sport) AS no_of_sports
FROM athlete_events
GROUP BY games
ORDER BY no_of_sports DESC;

-- 9. Oldest athletes to win a Gold medal

SELECT name, sex, CAST(CASE WHEN age = 'NA' then '0' else age end as int) as age, team, games, city, sport, event, medal
FROM athlete_events
WHERE medal = 'Gold'
ORDER BY age DESC
LIMIT 2;

-- 10. Top 5 athletes who have won the most gold medals

SELECT name, team, count(medal) AS Total_medals
FROM athlete_events
WHERE medal = 'Gold'
GROUP BY name, team
ORDER BY Total_medals DESC
LIMIT 5;

-- 11. Top 5 athletes who have won the most medals

SELECT name, team, COUNT(medal) AS Total_medals
FROM athlete_events
WHERE medal <> 'NA'
GROUP BY name, team
ORDER BY total_medals DESC
LIMIT 5;

-- 12. Top 5 most successful countries by no of medals won

WITH medal_counts AS (
    SELECT region, COUNT(1) AS total_medals
    FROM athlete_events ae
    JOIN athlete_events_noc_regions ar ON ae.noc = ar.noc
    WHERE medal <> 'NA'
    GROUP BY region
)
SELECT region, total_medals,
RANK() OVER (ORDER BY total_medals DESC) AS rank
FROM medal_counts
ORDER BY total_medals DESC
LIMIT 5;

-- 13. Total gold, silver and bronze medals won by each country

SELECT ar.region AS country,
       COALESCE(SUM(CASE WHEN medal = 'Gold' THEN 1 ELSE 0 END), 0) AS gold,
       COALESCE(SUM(CASE WHEN medal = 'Silver' THEN 1 ELSE 0 END), 0) AS silver,
       COALESCE(SUM(CASE WHEN medal = 'Bronze' THEN 1 ELSE 0 END), 0) AS bronze
FROM athlete_events ae
JOIN athlete_events_noc_regions ar ON ar.noc = ae.noc
WHERE medal IN ('Gold', 'Silver', 'Bronze')
GROUP BY country
ORDER BY gold DESC, silver DESC, bronze DESC;

-- 14. Total gold, silver and bronze medals won by each country in each olympic games

SELECT DISTINCT games, ar.region AS country,
       COALESCE(SUM(CASE WHEN medal = 'Gold' THEN 1 ELSE 0 END), 0) AS gold,
       COALESCE(SUM(CASE WHEN medal = 'Silver' THEN 1 ELSE 0 END), 0) AS silver,
       COALESCE(SUM(CASE WHEN medal = 'Bronze' THEN 1 ELSE 0 END), 0) AS bronze
FROM athlete_events ae
JOIN athlete_events_noc_regions ar ON ar.noc = ae.noc
WHERE medal IN ('Gold', 'Silver', 'Bronze')
GROUP BY games, country
ORDER BY games ASC;

-- 15. Country which won the most gold, silver and bronze medals in each olympic games

SELECT DISTINCT
    ae.games,
    FIRST_VALUE(ar.region || ' - ' || COUNT(CASE WHEN ae.medal = 'Gold' THEN 1 END) ) OVER (PARTITION BY ae.games ORDER BY COUNT(CASE WHEN ae.medal = 'Gold' THEN 1 END) DESC) AS max_gold,
    FIRST_VALUE(ar.region || ' - ' || COUNT(CASE WHEN ae.medal = 'Silver' THEN 1 END) ) OVER (PARTITION BY ae.games ORDER BY COUNT(CASE WHEN ae.medal = 'Silver' THEN 1 END) DESC) AS max_silver,
    FIRST_VALUE(ar.region || ' - ' || COUNT(CASE WHEN ae.medal = 'Bronze' THEN 1 END) ) OVER (PARTITION BY ae.games ORDER BY COUNT(CASE WHEN ae.medal = 'Bronze' THEN 1 END) DESC) AS max_bronze
FROM athlete_events ae
JOIN athlete_events_noc_regions ar ON ae.noc = ar.noc
WHERE ae.medal IN ('Gold', 'Silver', 'Bronze')
GROUP BY ae.games, ar.region
ORDER BY ae.games;

-- 16. Countries which never won gold medal but won silver/bronze medals

SELECT 
    country,
    SUM(gold_medal) AS gold,
    SUM(silver_medal) AS silver,
    SUM(bronze_medal) AS bronze 
FROM (
    SELECT 
        ar.region AS country, 
        CASE WHEN medal = 'Gold' THEN 1 ELSE 0 END AS gold_medal, 
        CASE WHEN medal = 'Silver' THEN 1 ELSE 0 END AS silver_medal,
        CASE WHEN medal = 'Bronze' THEN 1 ELSE 0 END AS bronze_medal
    FROM athlete_events ae
    JOIN athlete_events_noc_regions ar USING(noc)
) AS medals
GROUP BY country
HAVING SUM(gold_medal) = 0 AND (SUM(silver_medal) > 0 OR SUM(bronze_medal) > 0)
ORDER BY 3 ASC, 4 ASC;

-- 17. Which Sport India have won highest medals

SELECT sport, COUNT(medal) AS Total_medals
FROM athlete_events ae
JOIN athlete_events_noc_regions ar ON ae.noc = ar.noc
WHERE medal <> 'NA'
  AND region = 'India'
GROUP BY sport
ORDER BY total_medals DESC
LIMIT 1;

-- 18. All olympic games where India won medal for hockey and medals in each games

SELECT team, sport, games, COUNT(medal) AS Total_medals
FROM athlete_events ae
JOIN athlete_events_noc_regions ar ON ae.noc = ar.noc
WHERE sport = 'Hockey'
  AND team = 'India'
GROUP BY team, sport, games
ORDER BY total_medals ASC;
