-- ============================================================
-- CMS Hospital Quality Analysis — SQL Queries
-- Database: cms_hospital
-- Tables: hospital_info, complications_deaths, hcahps, hac_reduction
-- Author: Healthcare Informatics Portfolio
-- ============================================================

USE cms_hospital;

-- ============================================================
-- QUERY 1: Star Rating Distribution by State
-- Question: For each state, how many hospitals received each star rating?
-- Used for: State-level map visual in Power BI
-- ============================================================
SELECT
    state,
    hospital_overall_rating,
    COUNT(*) AS hospital_count
FROM hospital_info
WHERE hospital_overall_rating IS NOT NULL
GROUP BY state, hospital_overall_rating
ORDER BY state, hospital_overall_rating;


-- ============================================================
-- QUERY 2: Average Star Rating by State
-- Question: Which states have the best and worst hospitals overall?
-- Used for: Filled map color saturation in Power BI
-- Note: HAVING COUNT(*) >= 5 applies minimum sample size threshold
-- ============================================================
SELECT
    state,
    ROUND(AVG(hospital_overall_rating), 2) AS avg_star_rating,
    COUNT(*) AS hospital_count
FROM hospital_info
WHERE hospital_overall_rating IS NOT NULL
GROUP BY state
HAVING COUNT(*) >= 5
ORDER BY avg_star_rating DESC;


-- ============================================================
-- QUERY 3: Mortality Performance Nationally
-- Question: How many hospitals are Better, Same, or Worse than national average on mortality?
-- Used for: Donut chart in Power BI
-- Note: LIKE 'MORT%' filters only mortality measures
--       COUNT(DISTINCT facility_id) counts each hospital once regardless of measure count
-- ============================================================
SELECT
    compared_to_national,
    COUNT(DISTINCT facility_id) AS hospital_count,
    ROUND(COUNT(DISTINCT facility_id) * 100.0 /
        (SELECT COUNT(DISTINCT facility_id) FROM complications_deaths), 2) AS pct
FROM complications_deaths
WHERE measure_id LIKE 'MORT%'
AND compared_to_national NOT IN ('Not Available', 'Number of Cases Too Small')
GROUP BY compared_to_national
ORDER BY hospital_count DESC;


-- ============================================================
-- QUERY 4: Top 20 Worst Performing Hospitals
-- Question: Which hospitals are failing across the most quality measures?
-- Used for: Worst hospitals reference table
-- Note: COALESCE replaces NULL with 0 to prevent math errors
--       LEFT JOIN keeps all hospitals even if not in HAC program
-- ============================================================
SELECT
    h.facility_name,
    h.state,
    h.hospital_overall_rating,
    h.count_of_mort_measures_worse,
    h.count_of_safety_measures_worse,
    h.count_of_readm_measures_worse,
    (COALESCE(h.count_of_mort_measures_worse, 0) +
     COALESCE(h.count_of_safety_measures_worse, 0) +
     COALESCE(h.count_of_readm_measures_worse, 0)) AS total_worse_measures
FROM hospital_info h
LEFT JOIN hac_reduction hac ON h.facility_id = hac.`Facility ID`
WHERE h.hospital_overall_rating IS NOT NULL
ORDER BY total_worse_measures DESC
LIMIT 20;


-- ============================================================
-- QUERY 5: HAC Penalty Rate by State
-- Question: Which states have the highest % of hospitals penalized for preventable harm?
-- Used for: HAC penalty bar chart in Power BI
-- Note: SUM(CASE WHEN...) = conditional aggregation to count penalized hospitals
--       Dividing penalized / total gives the penalty rate percentage
-- ============================================================
SELECT
    state,
    COUNT(*) AS total_hospitals,
    SUM(CASE WHEN `Payment Reduction` = 'Yes' THEN 1 ELSE 0 END) AS penalized,
    ROUND(SUM(CASE WHEN `Payment Reduction` = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS penalty_rate_pct
FROM hac_reduction
WHERE `Payment Reduction` IN ('Yes', 'No')
GROUP BY state
ORDER BY penalty_rate_pct DESC;


-- ============================================================
-- QUERY 6: Patient Experience — Best and Worst Survey Questions
-- Question: Which HCAHPS questions score highest and lowest nationally?
-- Used for: Patient experience bar chart in Power BI
-- Note: CAST converts text column to decimal for AVG() calculation
-- ============================================================
SELECT
    hcahps_question,
    ROUND(AVG(CAST(hcahps_linear_mean_value AS DECIMAL(10,2))), 2) AS avg_score,
    COUNT(DISTINCT facility_id) AS hospital_count
FROM hcahps
WHERE hcahps_linear_mean_value IS NOT NULL
AND hcahps_linear_mean_value != 'Not Applicable'
GROUP BY hcahps_question
ORDER BY avg_score DESC;


-- ============================================================
-- QUERY 7: Full Hospital Scorecard (JOIN across tables)
-- Question: What is each hospital's complete quality picture?
-- Used for: Main scorecard table in Power BI dashboard
-- Note: LEFT JOIN brings HAC data where it exists, NULL where it does not
--       ORDER BY two columns — star rating first, then HAC score within each rating
-- ============================================================
SELECT
    h.facility_id,
    h.facility_name,
    h.state,
    h.hospital_type,
    h.hospital_ownership,
    h.hospital_overall_rating,
    h.count_of_mort_measures_better,
    h.count_of_mort_measures_worse,
    h.count_of_safety_measures_better,
    h.count_of_safety_measures_worse,
    h.count_of_readm_measures_better,
    h.count_of_readm_measures_worse,
    hac.`Total HAC Score`,
    hac.`Payment Reduction`
FROM hospital_info h
LEFT JOIN hac_reduction hac ON h.facility_id = hac.`Facility ID`
WHERE h.hospital_overall_rating IS NOT NULL
ORDER BY h.hospital_overall_rating DESC, hac.`Total HAC Score` ASC;


-- ============================================================
-- QUERY 8: Hospital Ownership Type vs Average Star Rating
-- Question: Does who owns a hospital affect how well it performs?
-- Used for: Ownership bar chart in Power BI
-- Note: Multiple aggregations in one query — avg rating, total count, 5-star count and %
-- ============================================================
SELECT
    hospital_ownership,
    ROUND(AVG(hospital_overall_rating), 2) AS avg_star_rating,
    COUNT(*) AS hospital_count,
    SUM(CASE WHEN hospital_overall_rating = 5 THEN 1 ELSE 0 END) AS five_star_count,
    ROUND(SUM(CASE WHEN hospital_overall_rating = 5 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS five_star_pct
FROM hospital_info
WHERE hospital_overall_rating IS NOT NULL
GROUP BY hospital_ownership
ORDER BY avg_star_rating DESC;
