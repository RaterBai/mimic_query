-- death during icu stay would include those within 24h of leaving the icu.

drop table if exists icu_death;
create table icu_death
(
	ROW_ID INT NOT NULL,
  	SUBJECT_ID INT NOT NULL,
  	HADM_ID INT NOT NULL,
  	ICUSTAY_ID INT NOT NULL,
	DBSOURCE VARCHAR(20) NOT NULL,
	FIRST_CAREUNIT VARCHAR(20) NOT NULL,
	LAST_CAREUNIT VARCHAR(20) NOT NULL,
	FIRST_WARDID SMALLINT NOT NULL,
	LAST_WARDID SMALLINT NOT NULL,
	LOS DOUBLE PRECISION,
	EXIPRE_FLAG INT not null
);


-- expire_flag = 0 -- not dead in icu
-- expire_flag = 1 -- dead in icu

drop table if exists death_after_year;  -- survival duration up to one year after hospital discharge
create table death_after_year
(
	ROW_ID INT NOT NULL,
  	SUBJECT_ID INT NOT NULL,
  	HADM_ID INT NOT NULL,
  	EXPIRE_FLAG INT not null    -- death occured after 1 year from hospital discharge.
);

with icu_expire as 
(select subject_id, 
	   case
	   		when sum(exipre_flag) != 0 then 1
	   		else 0
	   end as icu_expire_flag from icu_death
group by subject_id
)
select adult.subject_id,
	   adult.hadm_id,
	   adult.admittime,
	   adult.age,
	   adult.gender,
	   adult.hospital_expire_flag,
	   icu.icu_expire_flag,
	   d.expire_flag as death_after_a_year,
	   oasis.oasis,
	   saps.saps,
	   sapsii.sapsii,
	   sofa.sofa from adult_info adult
left join icu_expire icu
on adult.subject_id = icu.subject_id
left join death_after_year d
on adult.hadm_id = d.hadm_id
left join oasis
on adult.hadm_id = oasis.hadm_id
left join saps 
on adult.hadm_id = saps.hadm_id
left join sapsii
on adult.hadm_id = sapsii.hadm_id
left join sofa
on adult.hadm_id = sofa.hadm_id;


