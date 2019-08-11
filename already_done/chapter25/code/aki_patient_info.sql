-- info for aki patients
with last_icu_time as 
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
), cohort as 
(
	select aki.subject_id,
		   adm.hadm_id,
		   icu.icustay_id,
		   icu.intime,
		   icu.outtime,
		   pat.gender,
		   case 
		   	   when round((cast(icu.intime as date) - cast(pat.dob as date))/365.242, 2) >= 300 then 91.4
			   else round((cast(icu.intime as date) - cast(pat.dob as date))/365.242, 2) end as age
		   
	from aki_cohort aki
	inner join patients pat
	on aki.subject_id = pat.subject_id
	inner join admissions adm
	on aki.subject_id = adm.subject_id
	inner join last_icu icu
	on adm.hadm_id = icu.hadm_id
), creatinine as 
(
	select co.*,
		   labs.charttime,
		   labs.valuenum
		   from labevents labs
		   inner join cohort co
		   on labs.hadm_id = co.hadm_id
		   where itemid = 50912 -- CREATININE | CHEMISTRY | BLOOD | 797476
		   	 and valuenum > 0 and valuenum <= 150 and charttime between co.intime and co.outtime
), first_creatinine as -- admission creatinine
(
	select distinct
		   subject_id,
		   first_value(valuenum) over (partition by subject_id order by charttime) as valuenum
		   from creatinine
), chronic_renal_failure as 
(
	select subject_id,
		   hadm_id,
		   'chronic_renal_failure' disease
		   from diagnoses_icd where icd9_code = '5859'
), hypertension as 
(
	select subject_id,
		   hadm_id,
		   'hypertension' disease
		   from diagnoses_icd where icd9_code = '4019'
), diabetes as 
(
	select subject_id,
		   hadm_id,
		   'diabetes' disease
		   from diagnoses_icd where icd9_code = '25000'
), coronary_atherosclerosis as 
(
	select subject_id,
		   hadm_id,
		   'coronary_atherosclerosis' disease
		   from diagnoses_icd where icd9_code = '41401'
), congestive_heart_failure as 
(
	select subject_id,
		   hadm_id,
		   'congestive_heart_failure' disease
		   from diagnoses_icd where icd9_code = '4280'
), septic_shock as 
(
	select subject_id,
		   hadm_id,
		   'septic_shock' disease
		   from diagnoses_icd where icd9_code = '78552'
), severe_sepsis as 
(
	select subject_id,
		   hadm_id,
		   'severe_sepsis' disease
		   from diagnoses_icd where icd9_code = '99592'
)
select cohort.*,
	    first_creatinine.valuenum as admission_creatinine,
	    case 
	    	when chronic_renal_failure.disease = 'chronic_renal_failure' then 1
	    	else 0 end as chronic_renal_failure,
	    case 
	    	when hypertension.disease = 'hypertension' then 1
	    	else 0 end as hypertension,
	    case 
	    	when diabetes.disease = 'diabetes' then 1
	    	else 0 end as diabetes,
	    case 
	    	when coronary_atherosclerosis.disease = 'coronary_atherosclerosis' then 1
	    	else 0 end as coronary_atherosclerosis,
	    case 
	    	when congestive_heart_failure.disease = 'congestive_heart_failure' then 1
	    	else 0 end as congestive_heart_failure,
	    case 
	    	when septic_shock.disease = 'septic_shock' then 1
	    	else 0 end as septic_shock,
	    case 
	    	when severe_sepsis.disease = 'severe_sepsis' then 1
	    	else 0 end as severe_sepsis,
	    saps.saps
	    from cohort
left join first_creatinine
on cohort.subject_id = first_creatinine.subject_id
left join chronic_renal_failure
on cohort.hadm_id = chronic_renal_failure.hadm_id
left join hypertension
on cohort.hadm_id = hypertension.hadm_id
left join diabetes
on cohort.hadm_id = diabetes.hadm_id
left join coronary_atherosclerosis
on cohort.hadm_id = coronary_atherosclerosis.hadm_id
left join congestive_heart_failure
on cohort.hadm_id = congestive_heart_failure.hadm_id
left join septic_shock
on cohort.hadm_id = septic_shock.hadm_id
left join severe_sepsis
on cohort.hadm_id = severe_sepsis.hadm_id
left join saps
on cohort.icustay_id = saps.icustay_id