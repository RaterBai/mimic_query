drop table if exists avg_tidal_volume_all_hadm;
create table avg_tidal_volume_all_hadm as
with all_hr as 
(
	select subject_id, hadm_id, charttime, 
	   case 
	   		when chart.valuenum > 0 and chart.valuenum < 300 then chart.valuenum else null end as valuenum, 
	   chart.valueuom, chart.error from chartevents chart
	where itemid in (211, 220045)
	order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime
), all_rr as 
(
	select subject_id, hadm_id, charttime, 
	   case 
	   		when chart.valuenum > 0 and chart.valuenum < 70 then chart.valuenum else null end as valuenum, 
	   		chart.valueuom, chart.error from chartevents chart
	where chart.itemid in (615,618,220210,224690)
	order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime
), all_sysbp as 
(
	select subject_id, hadm_id, charttime, 
	   case 
	   		when chart.valuenum > 0 and chart.valuenum < 400 then chart.valuenum else null end as valuenum,
	   		chart.valueuom, chart.error from chartevents chart
	where chart.itemid in (51,442,455,6701,220179,220050)
	order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime
), all_diasbp as 
(
	select subject_id, hadm_id, charttime, 
	   case 
	   		when chart.valuenum > 0 and chart.valuenum < 300 then chart.valuenum else null end as valuenum, 
	   		chart.valueuom, chart.error from chartevents chart
	where chart.itemid in (8368,8440,8441,8555,220180,220051)
	order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime
), all_meanbp as 
(
	select subject_id, hadm_id, charttime, 
	   case when chart.valuenum > 0 and chart.valuenum < 300 then chart.valuenum else null end as valuenum, 
	   chart.valueuom, chart.error from chartevents chart
	where chart.itemid in (456,52,6702,443,220052,220181,225312)
	order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime
), all_temp as 
(
	select subject_id, hadm_id, charttime, 
	   case when itemid in (223761, 678) and valuenum > 70 and valuenum < 120  then (valuenum-32)/1.8  
	 		when itemid in (223762, 676) and valuenum > 10 and valuenum < 50 then valuenum
	 		else null 
	 	end as valuenum,
	   chart.valueuom, chart.error from chartevents chart
	where chart.itemid in (223761, 678, 223762, 676)
	order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime
), all_wbc as 
(
	select subject_id, hadm_id, charttime,
		   case when valuenum < 1000 then valuenum else null end as valuenum from labevents where itemid in (51300, 51301)
	order by subject_id, hadm_id, charttime
)
, avgTidalVolume as 
(
	select hadm_id, round(cast(avg(tidal_volume) as numeric), 0) as avgTV from pat_tidal_volume where tidal_volume is not null
	group by hadm_id
),
avgWBC as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) as avgWBC from all_wbc where valuenum is not null 
	group by hadm_id
),
avgRR as 				-- Respiratory Rate
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) as avgRR from all_rr where valuenum is not null    -- should I remove flag = abnormal?
	group by hadm_id
),
avgHR as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) as avghr from all_hr where valuenum is not null 
	group by hadm_id
),
avgTemp as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 1) as avgtemp from all_temp where valuenum is not null 
	group by hadm_id
),
avgDiasbp as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) as avgDiasbp from all_diasbp where valuenum is not null
	group by hadm_id
),
avgSysbp as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) as avgSysbp from all_sysbp where valuenum is not null
	group by hadm_id
),
avgMeanbp as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) as avgMeanbp from all_meanbp where valuenum is not null
	group by hadm_id
)
select adult.subject_id, 
	   adult.hadm_id, 
	   case 
	   		when adult.age >= 300 then 91.4   -- need to be determined 
	   		when adult.age < 300 then adult.age 
	   end as age,
	   adult.gender,
	   adult.ethnicity,
	   adult.admittime,
	   f.first_careunit as location,
	   td.avgTV,
	   wbc.avgWBC,
	   rr.avgRR,
	   hr.avghr,
	   atemp.avgTemp,
	   dbp.avgDiasbp,
	   sbp.avgSysbp,
	   mbp.avgMeanbp,
	   bmi.bmi,
	   adult.hospital_expire_flag
	   from adult_info  adult
inner join avgtidalvolume td
on adult.hadm_id = td.hadm_id
inner join first_careunit f
on adult.hadm_id = f.hadm_id
left join avgWBC wbc
on adult.hadm_id = wbc.hadm_id
left join avgRR rr
on adult.hadm_id = rr.hadm_id
left join avgHR hr
on adult.hadm_id = hr.hadm_id
left join avgTemp atemp
on adult.hadm_id = atemp.hadm_id
left join avgdiasbp dbp
on adult.hadm_id = dbp.hadm_id
left join avgsysbp sbp
on adult.hadm_id = sbp.hadm_id
left join avgmeanbp mbp
on adult.hadm_id = mbp.hadm_id
left join bmi_hadm bmi
on adult.hadm_id = bmi.hadm_id;

with ordered_adm as 
(
	select subject_id, hadm_id, row_number() over (partition by subject_id order by admittime) as num from admissions
),first_adm as 
(
	select subject_id, hadm_id from ordered_adm where num = 1
)
select avg.* from avg_tidal_volume_all_hadm avg
inner join first_adm adm
on avg.hadm_id = adm.hadm_id
order by avg.subject_id, avg.admittime;

select * from avg_tidal_volume_all_hadm order by subject_id, admittime;
