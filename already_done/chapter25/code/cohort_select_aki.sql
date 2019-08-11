/* cohort selection for chapter 25
 * To detect AKI, at least 2 measurements of serum creatinine are need 
 * Age: > 15
 * last ICU stay
 * without end-stage renal disease, ICD_CODE: 5856
 */
-- select which ICU stays have more than two creatinine measurements
with hadm_end_stage_renal as 
(
	select distinct(hadm_id) from diagnoses_icd where icd9_code = '5856' -- hospital admission which end-stage renal disease has been diagonsed
), subject_end_stage_renal as 
(
	select distinct(subject_id) from diagnoses_icd where icd9_code = '5856'
), subject_without_end_stage_renal as -- remove patients who have been diagnosed an end-stage renal disease
(
	select subject_id from patients 
	except 
	select subject_id from subject_end_stage_renal 
), last_icu_time as 
(
	select subject_id, max(intime) from icustays group by subject_id
), last_icu as 
(
	select icu.subject_id, 
		   icu.hadm_id,
		   icu.icustay_id,
		   intime, 
		   outtime
	from last_icu_time last
	inner join icustays icu
	on last.subject_id = icu.subject_id and last.max = icu.intime
),icustay_info as 
(
	select icu.subject_id, 
		   icu.hadm_id, 
		   icu.icustay_id, 
		   pat.gender,
		   case 
		   		when round((cast(icu.intime as date) - cast(pat.dob as date))/365.25, 2) >= 300 then 91.4
		   		else round((cast(icu.intime as date) - cast(pat.dob as date))/365.25, 2) end as age,
		   intime,
		   outtime
	from last_icu icu
	inner join patients pat
	on icu.subject_id = pat.subject_id
	inner join subject_without_end_stage_renal sub
	on pat.subject_id = sub.subject_id
	inner join admissions adm
	on icu.hadm_id = adm.hadm_id
), cohort as 
(
	select * from icustay_info where age >= 15
), creatinine as 
(
	select labs.subject_id, 
		   labs.hadm_id,
		   co.icustay_id,
		   valuenum
		   from labevents labs
		   inner join cohort co
		   on labs.hadm_id = co.hadm_id
		   where itemid = 50912 -- CREATININE | CHEMISTRY | BLOOD | 797476
		   	 and valuenum > 0 and valuenum <= 150 and charttime between co.intime and co.outtime
), pat_cohort as -- patients who have more than 2 creatinine measurements
(
	select subject_id,
		   hadm_id,
		   icustay_id,
		   count(*)
		   from creatinine
		   group by subject_id, hadm_id, icustay_id
		   having count(*) >= 2
), resultSet as 
(
	select pat.subject_id,
		   pat.hadm_id,
		   pat.icustay_id,
		   labs.charttime,
		   labs.valuenum
	from pat_cohort pat
	inner join cohort co
	on pat.icustay_id = co.icustay_id
	left join labevents labs
	on labs.hadm_id = pat.hadm_id
	where itemid = 50912 -- CREATININE | CHEMISTRY | BLOOD | 797476
		   	 and valuenum > 0 and valuenum <= 150 and charttime between co.intime and co.outtime
)select * from resultSet;

