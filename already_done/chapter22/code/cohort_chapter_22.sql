-- include icu information for all the icustay. all ages, can filter by age
drop materialized view if exists cohort_chapter_22;
create materialized view cohort_chapter_22 as 
with cohort as (
	select 
		pat.subject_id,
		adm.hadm_id,
		icu.icustay_id,
		pat.dob,
		pat.dod,
		case 
			when round((cast(icu.intime as date) - cast(pat.dob as date))/365.242, 2) >= 300 then 91.4
			else round((cast(icu.intime as date) - cast(pat.dob as date))/365.242, 2) end as age,
		extract(day from icu.outtime - icu.intime) * 1440 + extract(hour from icu.outtime - icu.intime)*60 + extract(minute from icu.outtime - icu.intime) as minstodischarge,
		icu.los,
		pat.gender,
		adm.ethnicity,
		icu.intime,
		icu.outtime,
		icu.first_careunit,
		icu_death.expire_flag as icu_death,
		icu_death_within_24.expire_flag as icu_death_within_24,
		case 
			when time_to_icu_death.days_to_death < 0 then 0     -- people died in ICU
			else time_to_icu_death.days_to_death end as days_to_death
	from patients pat
	inner join admissions adm
	on pat.subject_id = adm.subject_id
	inner join icustays icu
	on adm.hadm_id = icu.hadm_id
	left join icu_death
	on icu_death.icustay_id = icu.icustay_id
	left join icu_death_within_24 
	on icu_death_within_24.icustay_id = icu.icustay_id
	left join time_to_icu_death
	on time_to_icu_death.icustay_id = icu.icustay_id
	where adm.hadm_id is not null and icu.icustay_id is not null
)select * from cohort; --61532

