/* 1. extract last creatinine measure time for patients in non_aki_cohort 
 * last ICU unit
 * 2. 
 */
-- select which ICU stays have more than two creatinine measurements
with  last_icu_time as 
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
	inner join non_aki_cohort non
	on pat.subject_id = non.subject_id
	inner join admissions adm
	on icu.hadm_id = adm.hadm_id
), cohort as 
(
	select * from icustay_info
), creatinine as 
(
	select labs.subject_id, 
		   labs.charttime,
		   valuenum
		   from labevents labs
		   inner join cohort co
		   on labs.hadm_id = co.hadm_id
		   where itemid = 50912 -- CREATININE | CHEMISTRY | BLOOD | 797476
		   	 and valuenum > 0 and valuenum <= 150 and charttime between co.intime and co.outtime
), last_creatinine_time as 
(
	select distinct
		   subject_id,
		   first_value(charttime) over (partition by subject_id order by charttime desc) as charttime
		   from creatinine
), meanbp as 
(
	select subject_id,
		   charttime,
		   valuenum
	from chartevents
	where itemid in (
		456, --"NBP Mean"
  		52, --"Arterial BP Mean"
 		6702, --	Arterial BP Mean #2
 		443, --	Manual BP Mean(calc)
 		220052, --"Arterial Blood Pressure mean"
 		220181, --"Non Invasive Blood Pressure mean"
 		225312 --"ART BP mean"
	) and valuenum >= 20 and valuenum <= 200
), cohort_meanbp as 
(
	select lct.subject_id,
		   mbp.charttime as charttime,
		   mbp.valuenum as valuenum,
		   lct.charttime as last_measured_time,
		   extract(day from lct.charttime - mbp.charttime) * 1440 + extract(hour from lct.charttime - mbp.charttime)*60 + extract(minute from lct.charttime - mbp.charttime) as mintolastmeasurement
	from meanbp mbp
	inner join last_creatinine_time lct
	on mbp.subject_id = lct.subject_id
	where mbp.charttime between lct.charttime - interval '3' day and lct.charttime
)select * from cohort_meanbp order by subject_id, charttime;