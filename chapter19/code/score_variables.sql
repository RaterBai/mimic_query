-- merge all the variables used to calculate the OASIS, SPAS, SPASII, SOFA score
drop table if exists score_variables;
create table score_variables as
with surgflag as 
(
	select ie.icustay_id
    , max(case
        when lower(curr_service) like '%surg%' then 1
        when curr_service = 'ORTHO' then 1
    else 0 end) as surgical
  from icustays ie
  left join services se
    on ie.hadm_id = se.hadm_id
    and se.transfertime < ie.intime + interval '1' day
  group by ie.icustay_id	
),
cpap as 
(
	select ie.icustay_id
	, min(charttime - interval '1' hour) as starttime
    , max(charttime + interval '4' hour) as endtime
    , max(case when lower(value) similar to '%(cpap mask|bipap mask)%' then 1 else 0 end) as cpap
  from icustays ie
  inner join chartevents ce
    on ie.icustay_id = ce.icustay_id
    and ce.charttime between ie.intime and ie.intime + interval '1' day
  where itemid in
  (
    -- TODO: when metavision data import fixed, check the values in 226732 match the value clause below
    467, 469, 226732
  )
  and lower(ce.value) similar to '%(cpap mask|bipap mask)%'
  -- exclude rows marked as error
  AND ce.error IS DISTINCT FROM 1
  group by ie.icustay_id
),
comorb as
(
select hadm_id
-- these are slightly different than elixhauser comorbidities, but based on them
-- they include some non-comorbid ICD-9 codes (e.g. 20302, relapse of multiple myeloma)
  , max(CASE
    when icd9_code between '042  ' and '0449 ' then 1
  		end) as AIDS      /* HIV and AIDS */
  , max(CASE
    when icd9_code between '20000' and '20238' then 1 -- lymphoma
    when icd9_code between '20240' and '20248' then 1 -- leukemia
    when icd9_code between '20250' and '20302' then 1 -- lymphoma
    when icd9_code between '20310' and '20312' then 1 -- leukemia
    when icd9_code between '20302' and '20382' then 1 -- lymphoma
    when icd9_code between '20400' and '20522' then 1 -- chronic leukemia
    when icd9_code between '20580' and '20702' then 1 -- other myeloid leukemia
    when icd9_code between '20720' and '20892' then 1 -- other myeloid leukemia
    when icd9_code = '2386 ' then 1 -- lymphoma
    when icd9_code = '2733 ' then 1 -- lymphoma
  		end) as HEM
  , max(CASE
    when icd9_code between '1960 ' and '1991 ' then 1
    when icd9_code between '20970' and '20975' then 1
    when icd9_code = '20979' then 1
    when icd9_code = '78951' then 1
  		end) as METS      /* Metastatic cancer */
  from
  (
    select hadm_id, seq_num
    , cast(icd9_code as char(5)) as icd9_code
    from diagnoses_icd
  ) icd
  group by hadm_id
)
, pafi1 as
(
  -- join blood gas to ventilation durations to determine if patient was vent
  -- also join to cpap table for the same purpose
  select bg.icustay_id, bg.charttime
  , PaO2FiO2
  , case when vd.icustay_id is not null then 1 else 0 end as vent
  , case when cp.icustay_id is not null then 1 else 0 end as cpap
  from bloodgasfirstdayarterial bg
  left join ventdurations vd
    on bg.icustay_id = vd.icustay_id
    and bg.charttime >= vd.starttime
    and bg.charttime <= vd.endtime
  left join cpap cp
    on bg.icustay_id = cp.icustay_id
    and bg.charttime >= cp.starttime
    and bg.charttime <= cp.endtime
)
, pafi2 as
(
  -- get the minimum PaO2/FiO2 ratio *only for ventilated/cpap patients*
  select icustay_id
  , min(PaO2FiO2) as PaO2FiO2_vent_min
  from pafi1
  where vent = 1 or cpap = 1
  group by icustay_id
),
 wt AS
(
  SELECT ie.icustay_id
    -- ensure weight is measured in kg
    , avg(CASE
        WHEN itemid IN (762, 763, 3723, 3580, 226512)
          THEN valuenum
        -- convert lbs to kgs
        WHEN itemid IN (3581)
          THEN valuenum * 0.45359237
        WHEN itemid IN (3582)
          THEN valuenum * 0.0283495231
        ELSE null
      END) AS weight

  from icustays ie
  left join chartevents c
    on ie.icustay_id = c.icustay_id
  WHERE valuenum IS NOT NULL
  AND itemid IN
  (
    762, 763, 3723, 3580,                     -- Weight Kg
    3581,                                     -- Weight lb
    3582,                                     -- Weight oz
    226512 -- Metavision: Admission Weight (Kg)
  )
  AND valuenum != 0
  and charttime between ie.intime - interval '1' day and ie.intime + interval '1' day
  -- exclude rows marked as error
  AND c.error IS DISTINCT FROM 1
  group by ie.icustay_id
)
-- 5% of patients are missing a weight, but we can impute weight using their echo notes
, echo2 as(
  select ie.icustay_id, avg(weight * 0.45359237) as weight
  from icustays ie
  left join echodata echo
    on ie.hadm_id = echo.hadm_id
    and echo.charttime > ie.intime - interval '7' day
    and echo.charttime < ie.intime + interval '1' day
  group by ie.icustay_id
)
, vaso_cv as
(
  select ie.icustay_id
    -- case statement determining whether the ITEMID is an instance of vasopressor usage
    , max(case
            when itemid = 30047 then rate / coalesce(wt.weight,ec.weight) -- measured in mcgmin
            when itemid = 30120 then rate -- measured in mcgkgmin ** there are clear errors, perhaps actually mcgmin
            else null
          end) as rate_norepinephrine

    , max(case
            when itemid =  30044 then rate / coalesce(wt.weight,ec.weight) -- measured in mcgmin
            when itemid in (30119,30309) then rate -- measured in mcgkgmin
            else null
          end) as rate_epinephrine

    , max(case when itemid in (30043,30307) then rate end) as rate_dopamine
    , max(case when itemid in (30042,30306) then rate end) as rate_dobutamine

  from icustays ie
  inner join inputevents_cv cv
    on ie.icustay_id = cv.icustay_id and cv.charttime between ie.intime and ie.intime + interval '1' day
  left join wt
    on ie.icustay_id = wt.icustay_id
  left join echo2 ec
    on ie.icustay_id = ec.icustay_id
  where itemid in (30047,30120,30044,30119,30309,30043,30307,30042,30306)
  and rate is not null
  group by ie.icustay_id
)
, vaso_mv as
(
  select ie.icustay_id
    -- case statement determining whether the ITEMID is an instance of vasopressor usage
    , max(case when itemid = 221906 then rate end) as rate_norepinephrine
    , max(case when itemid = 221289 then rate end) as rate_epinephrine
    , max(case when itemid = 221662 then rate end) as rate_dopamine
    , max(case when itemid = 221653 then rate end) as rate_dobutamine
  from icustays ie
  inner join inputevents_mv mv
    on ie.icustay_id = mv.icustay_id and mv.starttime between ie.intime and ie.intime + interval '1' day
  where itemid in (221906,221289,221662,221653)
  -- 'Rewritten' orders are not delivered to the patient
  and statusdescription != 'Rewritten'
  group by ie.icustay_id
)
, pafi_sofa_1 as
(
  -- join blood gas to ventilation durations to determine if patient was vent
  select bg.icustay_id, bg.charttime
  , PaO2FiO2
  , case when vd.icustay_id is not null then 1 else 0 end as IsVent
  from bloodgasfirstdayarterial bg
  left join ventdurations vd
    on bg.icustay_id = vd.icustay_id
    and bg.charttime >= vd.starttime
    and bg.charttime <= vd.endtime
  order by bg.icustay_id, bg.charttime
)
, pafi_sofa_2 as
(
  -- because pafi has an interaction between vent/PaO2:FiO2, we need two columns for the score
  -- it can happen that the lowest unventilated PaO2/FiO2 is 68, but the lowest ventilated PaO2/FiO2 is 120
  -- in this case, the SOFA score is 3, *not* 4.
  select icustay_id
  , min(case when IsVent = 0 then PaO2FiO2 else null end) as PaO2FiO2_sofa_novent_min
  , min(case when IsVent = 1 then PaO2FiO2 else null end) as PaO2FiO2_sofa_vent_min
  from pafi_sofa_1
  group by icustay_id
),
cohort as 
(
	select ie.subject_id, ie.hadm_id, ie.icustay_id
      , ie.intime
      , ie.outtime
      , adm.deathtime
      , pat.gender
      , adm.ethnicity
      , adm.religion
      , cast(ie.intime as timestamp) - cast(adm.admittime as timestamp) as PreICULOS
      , floor( ( cast(ie.intime as date) - cast(pat.dob as date) ) / 365.242 ) as age
      , gcs.mingcs
      , vital.heartrate_max
      , vital.heartrate_min
      , vital.meanbp_max
      , vital.meanbp_min
      , vital.sysbp_max
      , vital.sysbp_min
      , vital.resprate_max
      , vital.resprate_min
      , vital.tempc_max
      , vital.tempc_min
      
      -- this value is non-null iff the patients in on vent/cpap
      ,pf.PaO2FiO2_vent_min
      
      , coalesce(vital.glucose_max, labs.glucose_max) as glucose_max
      , coalesce(vital.glucose_min, labs.glucose_min) as glucose_min
      
      , labs.bun_max
      , labs.bun_min
      , labs.hematocrit_max
      , labs.hematocrit_min
      , labs.wbc_max
      , labs.wbc_min
      , labs.sodium_max
      , labs.sodium_min
      , labs.potassium_max
      , labs.potassium_min
      , labs.bicarbonate_max
      , labs.bicarbonate_min
      , labs.bilirubin_min
      , labs.bilirubin_max
      , labs.creatinine_max
      , labs.platelet_min
      
      , pf_sofa.PaO2FiO2_sofa_novent_min
      , pf_sofa.PaO2FiO2_sofa_vent_min
      
      , vent.vent as mechvent
      , uo.urineoutput
      ,cp.cpap
      , comorb.AIDS
      , comorb.HEM
      , comorb.METS
      , case
          when adm.ADMISSION_TYPE = 'ELECTIVE' and sf.surgical = 1
            then 1
          when adm.ADMISSION_TYPE is null or sf.surgical is null
            then null
          else 0
        end as ElectiveSurgery

      -- age group
      , case
        when ( ( cast(ie.intime as date) - cast(pat.dob as date) ) / 365.242 ) <= 1 then 'neonate'
        when ( ( cast(ie.intime as date) - cast(pat.dob as date) ) / 365.242 ) <= 15 then 'middle'
        else 'adult' end as ICUSTAY_AGE_GROUP

      -- mortality flags
      , adm.hospital_expire_flag
      , coalesce(cv.rate_norepinephrine, mv.rate_norepinephrine) as rate_norepinephrine
  	  , coalesce(cv.rate_epinephrine, mv.rate_epinephrine) as rate_epinephrine
      , coalesce(cv.rate_dopamine, mv.rate_dopamine) as rate_dopamine
      , coalesce(cv.rate_dobutamine, mv.rate_dobutamine) as rate_dobutamine
      , icu_death.exipre_flag as icu_expire_flag
      , death.expire_flag as death_after_a_year
      
from icustays ie
inner join admissions adm
  on ie.hadm_id = adm.hadm_id
inner join patients pat
  on ie.subject_id = pat.subject_id
left join icu_death
  on ie.icustay_id = icu_death.icustay_id
left join death_after_year death
  on ie.hadm_id = death.hadm_id
left join labsfirstday labs
  on ie.icustay_id = labs.icustay_id
left join gcsfirstday gcs
  on ie.icustay_id = gcs.icustay_id
left join vitalsfirstday vital
  on ie.icustay_id = vital.icustay_id
left join uofirstday uo
  on ie.icustay_id = uo.icustay_id
left join pafi_sofa_2 pf_sofa
  on ie.icustay_id = pf_sofa.icustay_id
left join pafi2 pf
  on ie.icustay_id = pf.icustay_id
left join ventfirstday vent
  on ie.icustay_id = vent.icustay_id
left join surgflag sf
  on ie.icustay_id = sf.icustay_id
left join cpap cp
  on ie.icustay_id = cp.icustay_id
left join vaso_cv cv
  on ie.icustay_id = cv.icustay_id
left join vaso_mv mv
  on ie.icustay_id = mv.icustay_id
left join comorb
	on ie.hadm_id = comorb.hadm_id 
-- join to custom tables to get more data....
)
select * from cohort order by subject_id, hadm_id, icustay_id;
