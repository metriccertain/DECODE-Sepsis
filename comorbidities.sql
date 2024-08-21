-- !preview conn=DBI::dbConnect(RSQLite::SQLite())
-- extract other chronic comorbidities needed for scoring
WITH diag AS
(
    SELECT 
        hadm_id
        , CASE WHEN icd_version = 9 THEN icd_code ELSE NULL END AS icd9_code
        , CASE WHEN icd_version = 10 THEN icd_code ELSE NULL END AS icd10_code
    FROM `physionet-data.mimic_hosp.diagnoses_icd` diag
)
, com AS
(
    SELECT
        ad.hadm_id

        -- hypertension
        , MAX(CASE WHEN 
            SUBSTR(icd9_code, 1, 3) IN ('401')
            OR 
            SUBSTR(icd10_code, 1, 3) IN ('I10')
            THEN 1 
            ELSE 0 END) AS hypertension
            
        -- COPD
        , MAX(CASE WHEN
            SUBSTR(icd9_code, 1, 3) IN ('496')
            OR
            SUBSTR(icd10_code, 1, 3) IN ('J44')
            THEN 1 
            ELSE 0 END) AS copd

        -- asthma
        , MAX(CASE WHEN
            SUBSTR(icd9_code, 1, 3) IN ('493')
            OR
            SUBSTR(icd10_code, 1, 3) IN ('J45')
            THEN 1 
            ELSE 0 END) AS asthma
            
        -- ILD
        , MAX(CASE WHEN
            SUBSTR(icd9_code, 1, 3) IN ('515')
            OR
            SUBSTR(icd10_code, 1, 3) IN ('J84')
            THEN 1 
            ELSE 0 END) AS ild
            
        -- connective tissue disease
        , MAX(CASE WHEN
            SUBSTR(icd9_code, 1, 3) IN ('710')
            OR
            SUBSTR(icd10_code, 1, 3) IN ('M35')
            THEN 1 
            ELSE 0 END) AS ctd
            
        -- lymphoma
        , MAX(CASE WHEN
            SUBSTR(icd9_code, 1, 3) IN ('200','201','202')
            OR
            SUBSTR(icd9_code, 1, 5) IN ('V10.7')
            OR
            SUBSTR(icd10_code, 1, 3) IN ('C85','C84','C83','C82','C81')
            THEN 1 
            ELSE 0 END) AS lymphoma
            
        -- leukemia
        , MAX(CASE WHEN
            SUBSTR(icd9_code, 1, 3) IN ('203','204','205','206','207','208')
            OR
            SUBSTR(icd9_code, 1, 5) IN ('V10.6')
            OR
            SUBSTR(icd10_code, 1, 3) IN ('C90','C91','C92','C93','C94','C95')
            THEN 1 
            ELSE 0 END) AS leukemia
            
        -- cva
        , MAX(CASE WHEN
            SUBSTR(icd9_code, 1, 3) IN ('433','434','430','431','432','436')
            OR
            SUBSTR(icd10_code, 1, 3) IN ('I63')
            THEN 1 
            ELSE 0 END) AS cva
            
    FROM `physionet-data.mimic_core.admissions` ad
    LEFT JOIN diag
    ON ad.hadm_id = diag.hadm_id
    GROUP BY ad.hadm_id
)
SELECT 
    ad.subject_id
    , ad.hadm_id
    , hypertension
    , copd
    , asthma
    , ild
    , ctd
    , lymphoma
    , leukemia
    , cva
FROM `physionet-data.mimic_core.admissions` ad
LEFT JOIN com
ON ad.hadm_id = com.hadm_id
;
