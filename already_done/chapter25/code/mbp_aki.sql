-- extract meanbp measurements for patients who have AKI 3days before AKI onset
with meanbp as 
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
	select co.subject_id,
		   mbp.charttime as charttime,
		   mbp.valuenum as valuenum,
		   co.charttime as aki_onset_time,
		   extract(day from co.charttime - mbp.charttime) * 1440 + extract(hour from co.charttime - mbp.charttime)*60 + extract(minute from co.charttime - mbp.charttime) as mintoakionset
	from meanbp mbp
	inner join aki_cohort co
	on mbp.subject_id = co.subject_id
	where mbp.charttime between co.charttime - interval '3' day and co.charttime
)select * from cohort_meanbp order by subject_id, charttime;