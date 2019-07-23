-- create datasets on the original, untransformed varibles of SAPSII and SOFA (17variables)
with pafi1 as
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
), pafi2 as
(
  -- because pafi has an interaction between vent/PaO2:FiO2, we need two columns for the score
  -- it can happen that the lowest unventilated PaO2/FiO2 is 68, but the lowest ventilated PaO2/FiO2 is 120
  -- in this case, the SOFA score is 3, *not* 4.
  select icustay_id
  , min(case when IsVent = 0 then PaO2FiO2 else null end) as PaO2FiO2_novent_min
  , min(case when IsVent = 1 then PaO2FiO2 else null end) as PaO2FiO2_vent_min
  from pafi1
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
select ie.subject_id, ie.hadm_id, ie.icustay_id
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
      , pf.PaO2FiO2_novent_min
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
      , icu_death.exipre_flag as icu_expire_flag
      , pat.dead_at_hospital_discharge as hospital_expire_flag
      , death_after_year.expire_flag as death_after_a_year
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