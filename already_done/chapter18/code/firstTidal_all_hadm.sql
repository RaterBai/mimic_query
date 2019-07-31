drop table if exists first_tidal_volume_all_hadm;
create table first_tidal_volume_all_hadm as
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
),
all_wbc as 
(
	select subject_id, hadm_id, charttime,
		   case when valuenum < 1000 then valuenum else null end as valuenum from labevents where itemid in (51300, 51301)
	order by subject_id, hadm_id, charttime
),
ordered_tv as 
(
	select hadm_id, tidal_volume, row_number() over (partition by hadm_id order by charttime) as num from pat_tidal_volume where tidal_volume is not null
),
first_tv as 
(
	select o.hadm_id, o.tidal_volume as tidal_volume from ordered_tv o 
	where o.num = 1
),
ordered_wbc as 
(
	select hadm_id, valuenum, row_number() over (partition by hadm_id order by charttime) as num from all_wbc where valuenum is not null
),
first_wbc as 
(
	select hadm_id, valuenum as wbc from ordered_wbc where num = 1
),
ordered_rr as 
(
	select hadm_id, valuenum, row_number() over (partition by hadm_id order by charttime) as num from all_rr where valuenum is not null
),
first_rr as 				-- Respiratory Rate
(
	select hadm_id, valuenum as rr from ordered_rr where num = 1
),
ordered_hr as 
(
	select hadm_id, valuenum, row_number() over (partition by hadm_id order by charttime) as num from all_hr where valuenum is not null
),
first_hr as 
(
	select hadm_id, valuenum as hr from ordered_hr where num = 1
),
ordered_temp as 
(
	select hadm_id, valuenum, row_number() over (partition by hadm_id order by charttime) as num from all_temp where valuenum is not null
),
first_temp as 
(
	select hadm_id, valuenum as temp from ordered_temp where num = 1
),
ordered_diasbp as
(
	select hadm_id, valuenum, row_number() over (partition by hadm_id order by charttime) as num from all_diasbp where valuenum is not null
),
first_diasbp as 
(
	select hadm_id, valuenum as diasbp from ordered_diasbp where num = 1
),
ordered_sysbp as 
(
	select hadm_id, valuenum, row_number() over (partition by hadm_id order by charttime) as num from all_sysbp where valuenum is not null
),
first_sysbp as 
(
	select hadm_id, valuenum as sysbp from ordered_sysbp where num = 1
),
ordered_meanbp as 
(
select hadm_id, valuenum, row_number() over (partition by hadm_id order by charttime) as num from all_meanbp where valuenum is not null
),
first_meanbp as 
(
	select hadm_id, valuenum as meanbp from ordered_meanbp where num = 1
),
ordered_bmi as 
(
	select hadm_id, bmi, row_number() over (partition by hadm_id order by charttime) as num from pat_bmi where bmi is not null
),
first_bmi as 
(
	select hadm_id, bmi from ordered_bmi where num = 1
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
	   td.tidal_volume,
	   f.first_careunit as location,
	   wbc.wbc,
	   rr.rr,
	   hr.hr,
	   atemp.temp as temperature,
	   dbp.diasbp,
	   sbp.sysbp,
	   mbp.meanbp,
	   bmi.bmi,
	   adult.hospital_expire_flag
	   from adult_info adult
inner join first_tv td
on adult.hadm_id = td.hadm_id
inner join first_careunit f
on adult.hadm_id = f.hadm_id
left join first_wbc wbc
on adult.hadm_id = wbc.hadm_id
left join first_rr rr
on adult.hadm_id = rr.hadm_id
left join first_hr hr
on adult.hadm_id = hr.hadm_id
left join first_temp atemp
on adult.hadm_id = atemp.hadm_id
left join first_diasbp dbp
on adult.hadm_id = dbp.hadm_id
left join first_sysbp sbp
on adult.hadm_id = sbp.hadm_id
left join first_meanbp mbp
on adult.hadm_id = mbp.hadm_id
left join first_bmi bmi
on adult.hadm_id = bmi.hadm_id;

with ordered_adm as 
(
	select subject_id, hadm_id, row_number() over (partition by subject_id order by admittime) as num from admissions
),first_adm as 
(
	select subject_id, hadm_id from ordered_adm where num = 1
)
select first.* from first_tidal_volume_all_hadm first
inner join first_adm adm
on first.hadm_id = adm.hadm_id;