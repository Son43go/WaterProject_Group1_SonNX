-- Step 3: sql/queries.sql
CREATE OR REPLACE TABLE bw AS SELECT * FROM 'data/processed/beach.parquet';
-- Q1: samples and share unsafe by five-year period, with the change against the period before (LAG)
SELECT FLOOR(year / 5) * 5 AS period, COUNT(*) AS samples, COUNT(DISTINCT site) AS sites, 100.0 * AVG(unsafe) AS unsafe_pct, 100.0 * AVG(unsafe) - LAG(100.0 * AVG(unsafe)) OVER (ORDER BY FLOOR(year / 5) * 5) AS change_points FROM bw GROUP BY 1 ORDER BY 1;
-- Q2: share unsafe by rain in the three days before the sample
SELECT CASE WHEN rain_3d = 0 THEN '1: no rain' WHEN rain_3d < 5 THEN '2: below 5 mm' WHEN rain_3d < 20 THEN '3: 5 to 20 mm' WHEN rain_3d < 50 THEN '4: 20 to 50 mm' ELSE '5: 50 mm or more' END AS rain_band, COUNT(*) AS samples, 100.0 * AVG(unsafe) AS unsafe_pct, MEDIAN(enterococci) AS median_count FROM bw GROUP BY 1 ORDER BY 1;
-- Q3: sites ranked by the share of unsafe samples since 2015
SELECT site, region, COUNT(*) AS samples, 100.0 * AVG(unsafe) AS unsafe_pct, RANK() OVER (ORDER BY AVG(unsafe) DESC) AS rank FROM bw WHERE year >= 2015 GROUP BY 1, 2 HAVING COUNT(*) >= 100 ORDER BY 5 LIMIT 15;
-- Q4: model table; the history of a site uses only samples taken before the present one
CREATE OR REPLACE TABLE feat AS
SELECT row_id, region, site, date, year, month, latitude, longitude, unsafe, rain_today, rain_1d, rain_3d, rain_7d, air_temp_max, water_temp, conductivity, temp_missing, cond_missing,
       COALESCE(AVG(unsafe) OVER (PARTITION BY site ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0.15) AS site_unsafe_rate_before,
       COALESCE(LN(1 + LAG(enterococci) OVER w), 2.0) AS last_log_count, COALESCE(date_diff('day', LAG(date) OVER w, date), 30) AS days_since_last_sample,
       SIN(2 * PI() * month / 12) AS month_sin, COS(2 * PI() * month / 12) AS month_cos,
       CASE region WHEN 'Sydney Harbour' THEN 0 WHEN 'Northern Sydney' THEN 1 WHEN 'Sydney City' THEN 2 WHEN 'Southern Sydney' THEN 3 ELSE 4 END AS region_code
FROM bw WINDOW w AS (PARTITION BY site ORDER BY date);
SELECT CASE WHEN year < 2020 THEN 'before 2020' ELSE '2020 to 2025' END AS part, COUNT(*) AS n, 100.0 * AVG(unsafe) AS unsafe_pct FROM feat GROUP BY 1 ORDER BY 1 DESC;
