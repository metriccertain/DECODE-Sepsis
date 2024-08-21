-- !preview conn=DBI::dbConnect(RSQLite::SQLite())

-- prep weight
WITH wt_lbs AS (
    SELECT
        c.subject_id, c.stay_id, c.charttime
        -- Ensure that all weights are in kilograms
        , ROUND(CAST(c.valuenum / 2.2 AS NUMERIC), 2) AS weight
        , c.valuenum AS weight_orig
    FROM `mimic_icu.chartevents` c
    WHERE c.valuenum IS NOT NULL
        -- Weight (measured in lbs)
        AND c.itemid = 226531
)

, wt_kg AS (
    SELECT
        c.subject_id, c.stay_id, c.charttime
        -- Ensure that all weights are in kilograms
        , ROUND(CAST(c.valuenum AS NUMERIC), 2) AS weight
    FROM `mimic_icu.chartevents` c
    WHERE c.valuenum IS NOT NULL
        -- Weight kg
        AND c.itemid = 226512
)

-- merge kg/weight, only take 1 value per charted row
, wt_stg0 AS (
    SELECT
        COALESCE(w1.subject_id, w1.subject_id) AS subject_id
        , COALESCE(w1.stay_id, w1.stay_id) AS stay_id
        , COALESCE(w1.charttime, w1.charttime) AS charttime
        , COALESCE(w1.weight, w2.weight) AS weight
    FROM wt_kg w1
    FULL OUTER JOIN wt_lbs w2
        ON w1.subject_id = w2.subject_id
            AND w1.charttime = w2.charttime
)

SELECT subject_id, stay_id, charttime, weight
FROM wt_stg0
WHERE weight IS NOT NULL
    -- filter out bad weights
    AND weight > 40 AND weight < 300;
