-- create datasets on the original, untransformed varibles of SAPSII and SOFA (17variables)
drop table if exists SL2;
create table SL2 as 
with cpap as
(
  select ie.icustay_id
    , min(charttime - interval '1' hour) as starttime
    , max(charttime + interval '4' hour) as endtime
    , max(case when lower(ce.value) similar to '%(cpap mask|bipap mask)%' then 1 else 0 end) as cpap
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
), pafi1 as
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
), comorb as
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
), surgflag as
(
  select adm.hadm_id
    , case when lower(curr_service) like '%surg%' then 1 else 0 end as surgical
    , ROW_NUMBER() over
    (
      PARTITION BY adm.HADM_ID
      ORDER BY TRANSFERTIME
    ) as serviceOrder
  from admissions adm
  left join services se
    on adm.hadm_id = se.hadm_id
)
select  ie.subject_id
      , ie.hadm_id
      , ie.icustay_id
      , ie.intime

      -- the casts ensure the result is numeric.. we could equally extract EPOCH from the interval
      -- however this code works in Oracle and Postgres
      , case 
      		when round( ( cast(ie.intime as date) - cast(pat.dob as date) ) / 365.242 , 2 ) >= 300 then 91.4
      		else round( ( cast(ie.intime as date) - cast(pat.dob as date) ) / 365.242 , 2 )
      	end as age
      , gcs.mingcs
      , vital.heartrate_max
      , vital.heartrate_min
      , vital.sysbp_max
      , vital.sysbp_min
      , vital.tempc_max
      , vital.tempc_min

      , labs.bun_max
      , labs.bun_min
      , labs.wbc_max
      , labs.wbc_min
      , labs.sodium_max
      , labs.sodium_min
      , labs.potassium_max
      , labs.potassium_min
      , labs.bicarbonate_max
      , labs.bicarbonate_min
	  , labs.bilirubin_max
	  , labs.bilirubin_min
      , uo.urineoutput
      , pf.PaO2FiO2_vent_min
	  , comorb.AIDS
	  , comorb.HEM
	  , comorb.METS
	  , case 
	  	  when adm.admission_type = 'ELECTIVE' and sf.surgical = 1
	  	  	then 'ScheduledSurgical'
	  	  when adm.ADMISSION_TYPE != 'ELECTIVE' and sf.surgical = 1
            then 'UnscheduledSurgical'
          else 'Medical'
        end as AdmissionType
from first_icustay ie
inner join admissions adm
  on ie.hadm_id = adm.hadm_id
inner join adults_carevue_all pat
  on ie.subject_id = pat.subject_id
  
-- join to custom tables to get more data....
left join surgflag sf
  on adm.hadm_id = sf.hadm_id and sf.serviceOrder = 1
left join comorb
  on ie.hadm_id = comorb.hadm_id
left join gcsfirstday gcs
  on ie.icustay_id = gcs.icustay_id
left join vitalsfirstday vital
  on ie.icustay_id = vital.icustay_id
left join uofirstday uo
  on ie.icustay_id = uo.icustay_id
left join labsfirstday labs
  on ie.icustay_id = labs.icustay_id
left join pafi2 pf
  on ie.icustay_id = pf.icustay_id
left join icu_death
on icu_death.icustay_id = ie.icustay_id
left join death_after_year
on death_after_year.hadm_id = pat.hadm_id

select * from SL2 where subject_id = 11007;