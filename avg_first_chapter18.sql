-- create avg and first obs of chapter18

with avgTidalVolume as 
(
	select hadm_id, round(cast(avg(tidal_volume) as numeric), 0) AS avgTV from pat_tidal_volume
	group by hadm_id
),
avgWBC as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) AS avgWBC from all_wbc
	group by hadm_id
),
avgRR as 				-- Respiratory Rate
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) AS avgRR from all_rr   -- should I remove flag = abnormal?
	group by hadm_id
),
avgHR as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) as avghr from all_hr
	group by hadm_id
),
avgTemp as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 1) as avgtemp from all_temp
	group by hadm_id
),
avgDiasbp as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) as avgDiasbp from all_diasbp
	group by hadm_id
),
avgSysbp as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) as avgSysbp from all_sysbp
	group by hadm_id
),
avgMeanbp as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) as avgMeanbp from all_meanbp
	group by hadm_id
),
avgGlucose as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) as avgGlucose from all_glucose
	group by hadm_id
),
avgSpo2 as 
(
	select hadm_id, round(cast(avg(valuenum) as numeric), 0) as avgSpo2 from all_spo2
	group by hadm_id
)
select adult.subject_id, 
	   adult.hadm_id, 
	   case 
	   		when adult.age >= 300 then 91.4   -- need to be determined 
	   		when adult.age < 300 then adult.age 
	   end as age,
	   adult.gender,
	   td.avgTV,
	   wbc.avgWBC,
	   rr.avgRR,
	   hr.avghr,
	   atemp.avgTemp,
	   dbp.avgDiasbp,
	   sbp.avgSysbp,
	   mbp.avgMeanbp,
	   sp.avgSpo2,
	   glu.avgGlucose,
	   adult.hospital_expire_flag
	   from adult_info  adult
inner join avgtidalvolume td
on adult.hadm_id = td.hadm_id
inner join first_icustay f
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
left join avgglucose glu
on adult.hadm_id = glu.hadm_id
left join avgspo2 sp
on adult.hadm_id = sp.hadm_id;



drop table if exists first_record;
create table first_record as 
with first_tv as 
(
	select pat.hadm_id, pat.tidal_volume as tidal_volume from pat_tidal_volume pat
	inner join (select hadm_id, min(charttime) from pat_tidal_volume group by hadm_id) as mt_tv
	on mt_tv.min = pat.charttime and pat.hadm_id = mt_tv.hadm_id
),
first_wbc as 
(
	select wbc.hadm_id, valuenum as wbc from all_wbc wbc
	inner join (select hadm_id, min(charttime) from all_wbc group by hadm_id) as mt_wbc
	on mt_wbc.min = wbc.charttime and wbc.hadm_id = mt_wbc.hadm_id
),
first_rr as 				-- Respiratory Rate
(
	select rr.hadm_id, valuenum as rr from all_rr rr -- should I remove flag = abnormal?
	inner join (select hadm_id, min(charttime) from all_rr group by hadm_id) as mt_rr
	on mt_rr.min = rr.charttime and rr.hadm_id = mt_rr.hadm_id
),
first_hr as 
(
	select hr.hadm_id, valuenum as hr from all_hr hr
	inner join (select hadm_id, min(charttime) from all_hr group by hadm_id) as mt_hr
	on mt_hr.min = hr.charttime and hr.hadm_id = mt_hr.hadm_id
),
first_temp as 
(
	select temp.hadm_id, valuenum as temp from all_temp temp
	inner join (select hadm_id, min(charttime) from all_temp group by hadm_id) as mt_temp
	on mt_temp.min = temp.charttime and temp.hadm_id = mt_temp.hadm_id
),
first_diasbp as 
(
	select dbp.hadm_id, valuenum as diasbp from all_diasbp dbp
	inner join (select hadm_id, min(charttime) from all_diasbp group by hadm_id) as mt_dbp
	on dbp.charttime = mt_dbp.min and dbp.hadm_id = mt_dbp.hadm_id
),
first_sysbp as 
(
	select sbp.hadm_id, valuenum as sysbp from all_sysbp sbp
	inner join (select hadm_id, min(charttime) from all_sysbp group by hadm_id) as mt_sbp
	on sbp.charttime = mt_sbp.min and sbp.hadm_id = mt_sbp.hadm_id
),
first_meanbp as 
(
	select mbp.hadm_id, valuenum as meanbp from all_meanbp mbp
	inner join (select hadm_id, min(charttime) from all_meanbp group by hadm_id) as mt_mbp
	on mbp.charttime = mt_mbp.min and mbp.hadm_id = mt_mbp.hadm_id
),
first_Glucose as 
(
	select glu.hadm_id, valuenum as glucose from all_glucose glu
	inner join (select hadm_id, min(charttime) from all_glucose group by hadm_id) as mt_glu
	on glu.charttime = mt_glu.min and glu.hadm_id = mt_glu.hadm_id
),
first_Spo2 as 
(
	select sp.hadm_id, valuenum as Spo2 from all_spo2 sp
	inner join (select hadm_id, min(charttime) from all_spo2 group by hadm_id) as mt_sp
	on sp.charttime = mt_sp.min and sp.hadm_id = mt_sp.hadm_id
)
select adult.subject_id, 
	   adult.hadm_id, 
	   case 
	   		when adult.age >= 300 then 89   -- need to be determined 
	   		when adult.age < 300 then adult.age 
	   end as age,
	   adult.gender,
	   td.tidal_volume,
	   wbc.wbc,
	   rr.rr,
	   hr.hr,
	   atemp.temp as temperature,
	   dbp.diasbp,
	   sbp.sysbp,
	   mbp.meanbp,
	   sp.spo2,
	   glu.glucose,
	   adult.hospital_expire_flag
	   from adult_info  adult
inner join first_tv td
on adult.hadm_id = td.hadm_id
inner join first_icustay f
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
left join first_glucose glu
on adult.hadm_id = glu.hadm_id
left join first_spo2 sp
on adult.hadm_id = sp.hadm_id;

