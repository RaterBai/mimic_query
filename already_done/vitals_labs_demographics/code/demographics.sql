-- demographics on ICU stay level
select pat.subject_id,
	   adm.hadm_id,
	   icu.icustay_id,
	   pat.gender, 					-- 1
	   adm.ethnicity, 				-- 2
	   case 
      		when round( ( cast(icu.intime as date) - cast(pat.dob as date) ) / 365.242 , 2 ) >= 150 then 91.4
      		else round( ( cast(icu.intime as date) - cast(pat.dob as date) ) / 365.242 , 2 )
       end as age, 					-- 3
       bmi.bmi,
       adm.hospital_expire_flag,
       icu_death.exipre_flag as icu_expire_flag,
       death_after_a_month.expire_flag as death_after_a_month
	   from patients pat
inner join admissions adm
on pat.subject_id = adm.subject_id
inner join icustays icu
on icu.hadm_id = adm.hadm_id
left join bmi_icu bmi
on icu.icustay_id = bmi.icustay_id
left join icu_death
on icu_death.icustay_id = icu.icustay_id
left join death_after_a_month
on death_after_a_month.hadm_id = adm.hadm_id
left join death_after_a_year
on death_after_a_year.hadm_id = adm.hadm_id;


-- demographics on hospital stay level
select pat.subject_id,
	   adm.hadm_id,
	   pat.gender, 					-- 1
	   adm.ethnicity, 				-- 2
	   case 
      		when round( ( cast(adm.admittime as date) - cast(pat.dob as date) ) / 365.242 , 2 ) >= 150 then 91.4
      		else round( ( cast(adm.admittime as date) - cast(pat.dob as date) ) / 365.242 , 2 )
       end as age, 					-- 3
       bmi.bmi,						-- 4
       adm.hospital_expire_flag,
       death_after_a_month.expire_flag as death_after_a_month
	   from patients pat
inner join admissions adm
on pat.subject_id = adm.subject_id
left join bmi_hadm bmi
on adm.hadm_id = bmi.hadm_id
left join death_after_a_month
on death_after_a_month.hadm_id = adm.hadm_id
left join death_after_a_year
on death_after_a_year.hadm_id = adm.hadm_id;
