
-- OTT Content Trend Analysis: Netflix catalog
-- Dialect: PostgreSQL. Load the CSV into a table named netflix_titles first.
-- Expected source columns: show_id, type, title, country, date_added,
-- release_year, rating, duration, listed_in, director, cast, description.

-- 1. Catalog composition by format
SELECT type, COUNT(*) AS title_count
FROM netflix_titles
GROUP BY type
ORDER BY title_count DESC;

-- 2. Titles by original release year
SELECT release_year, COUNT(*) AS title_count
FROM netflix_titles
WHERE release_year IS NOT NULL
GROUP BY release_year
ORDER BY release_year;

-- 3. Top genres (explode comma-separated values)
SELECT TRIM(g.genre) AS genre, COUNT(DISTINCT n.show_id) AS title_count
FROM netflix_titles n
CROSS JOIN LATERAL unnest(string_to_array(COALESCE(n.listed_in, ''), ',')) AS g(genre)
WHERE TRIM(g.genre) <> ''
GROUP BY TRIM(g.genre)
ORDER BY title_count DESC
LIMIT 15;

-- 4. Ratings profile
SELECT COALESCE(NULLIF(TRIM(rating), ''), 'Unknown') AS rating,
       COUNT(*) AS title_count
FROM netflix_titles
GROUP BY 1
ORDER BY title_count DESC;

-- 5. Top production countries (multi-country titles counted for each country)
SELECT TRIM(c.country) AS country, COUNT(DISTINCT n.show_id) AS title_count
FROM netflix_titles n
CROSS JOIN LATERAL unnest(string_to_array(COALESCE(n.country, ''), ',')) AS c(country)
WHERE TRIM(c.country) <> ''
GROUP BY TRIM(c.country)
ORDER BY title_count DESC
LIMIT 15;

-- 6. Netflix catalog additions by year and format
SELECT EXTRACT(YEAR FROM TO_DATE(date_added, 'Month DD, YYYY'))::int AS year_added,
       type, COUNT(*) AS titles_added
FROM netflix_titles
WHERE date_added IS NOT NULL AND TRIM(date_added) <> ''
GROUP BY 1, 2
ORDER BY 1, 2;

-- 7. Movie runtime distribution (minutes)
SELECT
  CASE
    WHEN NULLIF(regexp_replace(duration, '[^0-9]', '', 'g'), '')::int < 60 THEN '<60 min'
    WHEN NULLIF(regexp_replace(duration, '[^0-9]', '', 'g'), '')::int < 90 THEN '60–89 min'
    WHEN NULLIF(regexp_replace(duration, '[^0-9]', '', 'g'), '')::int < 120 THEN '90–119 min'
    ELSE '120+ min'
  END AS runtime_band,
  COUNT(*) AS movie_count
FROM netflix_titles
WHERE type = 'Movie'
  AND duration ~ '[0-9]+ min'
GROUP BY 1
ORDER BY 1;

-- 8. TV show season distribution
SELECT
  NULLIF(regexp_replace(duration, '[^0-9]', '', 'g'), '')::int AS seasons,
  COUNT(*) AS show_count
FROM netflix_titles
WHERE type = 'TV Show' AND duration ~ '[0-9]+ Season'
GROUP BY 1
ORDER BY 1;

-- 9. Median movie runtime and TV seasons by format
SELECT type,
       percentile_cont(0.5) WITHIN GROUP (
         ORDER BY NULLIF(regexp_replace(duration, '[^0-9]', '', 'g'), '')::int
       ) AS median_duration_value
FROM netflix_titles
WHERE duration ~ '[0-9]+'
GROUP BY type;

-- 10. Genre mix by content format
SELECT n.type, TRIM(g.genre) AS genre,
       COUNT(DISTINCT n.show_id) AS title_count
FROM netflix_titles n
CROSS JOIN LATERAL unnest(string_to_array(COALESCE(n.listed_in, ''), ',')) AS g(genre)
WHERE TRIM(g.genre) <> ''
GROUP BY n.type, TRIM(g.genre)
ORDER BY n.type, title_count DESC;

-- 11. Country x format matrix
SELECT TRIM(c.country) AS country, n.type, COUNT(DISTINCT n.show_id) AS title_count
FROM netflix_titles n
CROSS JOIN LATERAL unnest(string_to_array(COALESCE(n.country, ''), ',')) AS c(country)
WHERE TRIM(c.country) <> ''
GROUP BY TRIM(c.country), n.type
ORDER BY country, n.type;

-- 12. Data quality: missingness by column
SELECT
  COUNT(*) AS total_rows,
  COUNT(*) FILTER (WHERE country IS NULL OR TRIM(country) = '') AS missing_country,
  COUNT(*) FILTER (WHERE date_added IS NULL OR TRIM(date_added) = '') AS missing_date_added,
  COUNT(*) FILTER (WHERE rating IS NULL OR TRIM(rating) = '') AS missing_rating,
  COUNT(*) FILTER (WHERE duration IS NULL OR TRIM(duration) = '') AS missing_duration
FROM netflix_titles;
