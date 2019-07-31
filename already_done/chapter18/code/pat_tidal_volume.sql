# 
# Derive the observed tidal volume for adult patients (age >= 18)
# whose first careunit is MICU/CCU & the initial service is not surgical.
# Tidal volumes are chosen from labevents and chartevents, and charttime in 
# these two are matched with the chartdate in cptevent by (year, month, day)
#
with adult_info as 
(
	select p.subject_id,
		   a.hadm_id,
		   p.gender,
		   p.dob, 
		   a.admittime, 
		   a.ethnicity, 
		   a."language", 
		   a.marital_status, 
		   a.hospital_expire_flag,
		   round((cast(a.admittime as date) - cast(p.dob as date))/365.242, 2) as age
	from public.patients p
	inner join public.admissions a
	on p.subject_id = a.subject_id
	where round((cast(a.admittime as date) - cast(p.dob as date))/365.242, 2) >= 18
),
pat_useiv as 
(
select adult.hadm_id, 
	   adult.subject_id, 
	   cpt.chartdate, 
	   extract(year from chartdate) as year, 
	   extract(month from chartdate) as month,
	   extract(day from chartdate) as day
from  adult_info adult
inner join cptevents cpt
on adult.hadm_id = cpt.hadm_id
where cpt.costcenter = 'Resp' and cpt.description like '%INVASIVE%'
order by adult.subject_id
),
first_icu_stay_time as 
(
	select hadm_id, min(intime) from icustays
	group by hadm_id
),
first_icu_stay_info as 
(
	select i.hadm_id, t.min, i.first_careunit from icustays i
	inner join first_icu_stay_time t
	on i.hadm_id = t.hadm_id and i.intime = t.min
),
first_careunit as  -- the first careunit information for each subject, each hospital admission
(
	select adm.subject_id, tmp.hadm_id as hadm_id, tmp.min as intime, tmp.first_careunit as first_careunit
	from admissions adm
	inner join first_icu_stay_info tmp
	on adm.hadm_id = tmp.hadm_id
),
pat_useiv_micu_ccu as 
(
	select pat.*, unit.first_careunit
	from pat_useiv pat
	inner join first_careunit unit
	on pat.hadm_id = unit.hadm_id
	where unit.first_careunit = 'MICU' or unit.first_careunit = 'CCU'
),
-- remove patients whose initial service is surgical service
first_time_service as 
(
	select hadm_id, min(transfertime) from services
	group by hadm_id
),
pat_first_service as 
(
	select s.subject_id, s.hadm_id, s.transfertime as intime, s.curr_service as services from first_time_service t
	inner join services s
	on t.hadm_id = s.hadm_id and t.min = s.transfertime
),
pat_required as 
(
	select pat1.*,
		   case 
		   	   when pat2.services in ('CSURG', 'NSURG', 'PSURG', 'SURG', 'TSURG', 'VSURG') then 1
		   	   else 0
		   end as surgical
	from pat_useiv_micu_ccu pat1
	left join pat_first_service pat2
	on pat1.hadm_id = pat2.hadm_id
),
pat_tidal_volume as 
(
	select pat.subject_id, 
	   pat.hadm_id,
	   pat.chartdate,
	   c.charttime, 
	   c.valuenum as tidal_volume,
	   c.valueuom,
	   pat.first_careunit,
	   case 
	   		when true then 'chart'
	   end as marker
	from pat_required pat
	inner join chartevents c
	on pat.hadm_id = c.hadm_id   
	where c.itemid in (682, 224685) and pat."year" = extract(year from c.charttime) 
	  and pat."month" = extract(month from c.charttime) 
	  and pat."day" = extract(day from c.charttime) and c.valuenum is not null
	  and pat.surgical = 0
	  
	  union 
	 
	select pat.subject_id, 
	   pat.hadm_id,
	   pat.chartdate,
	   lab.charttime, 
	   lab.valuenum as tidal_volume,
	   lab.valueuom,
	   pat.first_careunit,
	   case 
	   		when true then 'lab'
	   end as marker
	from pat_required pat
	inner join labevents lab
	on pat.hadm_id = lab.hadm_id   
	where lab.itemid = 50826 and pat."year" = extract(year from lab.charttime) 
	  and pat."month" = extract(month from lab.charttime) 
	  and pat."day" = extract(day from lab.charttime) and lab.valuenum is not null and pat.surgical = 0
)
select * from pat_tidal_volume order by subject_id, hadm_id, chartdate, charttime;
