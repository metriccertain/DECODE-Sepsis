-- !preview conn=DBI::dbConnect(RSQLite::SQLite())
-- This query generates a row for every hour the patient is in the ICU.
-- The hours are based on clock-hours (i.e. 02:00, 03:00).
-- The hour clock starts 24 hours before the first heart rate measurement.
-- Note that the time of the first heart rate measurement is ceilinged to
-- the hour.

-- this query extracts the cohort and every possible hour they were in the ICU
-- this table can be to other tables on stay_id and (ENDTIME - 1 hour,ENDTIME]

-- get first/last measurement time
WITH all_hours AS (
    SELECT
        it.stay_id

        -- round the intime up to the nearest hour
        -- but we only really care about the fist 7 days... or even the first 24 hours
        --  so I think we can just add 24 hours to intime using datetime and we will end up
        --  with even intervals
        --, CASE
        --    WHEN DATETIME_TRUNC(it.intime_hr, HOUR) = it.intime_hr
        --        THEN it.intime_hr
        --    ELSE
        --        DATETIME_ADD(
        --            DATETIME_TRUNC(it.intime_hr, HOUR), INTERVAL 1 HOUR
        --        )
        --END AS endtime
        , DATETIME(it.intime_hr, '24 HOURS') AS endtime

        -- create integers for each charttime in hours from admission
        -- so 0 is admission time, 1 is one hour after admission, etc,
        -- up to ICU disch
        --  we allow 24 hours before ICU admission (to grab labs before admit)
        --, GENERATE_ARRAY(-24, CAST(CEIL(DATETIME_DIFF(it.outtime_hr, it.intime_hr, HOUR)) AS INTEGER)) AS hrs -- noqa: L016
        , GENERATE_ARRAY(-24, CAST(CEIL((STRFTIME(endtime) - STRFTIME(it.intime_hr))/3600) AS INTEGER)) AS hrs
    FROM `physionet-data.mimic_derived.icustay_times` it
)

, hr_unnested AS (
UNNEST(all_hours.hrs)
)

SELECT stay_id
    , CAST(hr_unnested AS INT64) AS hr
    -- , DATETIME_ADD(endtime, INTERVAL CAST(hr_unnested AS INT64) HOUR) AS endtime
    , DATETIME(STRFTIME(endtime) + 3600*CAST(hr_unnested AS integer))
FROM all_hours
CROSS JOIN hr_unnested;
