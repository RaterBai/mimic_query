create table pat_dbsource as 
select subject_id, hadm_id, dbsource from icustays
order by subject_id, hadm_id;

alter table pat_dbsource add column row_id serial;
delete from
	   pat_dbsource a using 
	   pat_dbsource b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id;
alter table public.pat_dbsource drop column row_id;

select count(*) from pat_dbsource;  			/* 57786 */
select count(hadm_id) from pat_dbsource;	    /* 57786 */

/* Define adult whose age is above 16 */
drop table adult16_info;
create table adult16_info as
	select p.subject_id,
		   a.hadm_id,
		   p.gender,
		   p.dob, 
		   a.admittime, 
		   a.ethnicity, 
		   a."language", 
		   a.marital_status, 
		   a.hospital_expire_flag,
		   round((cast(a.admittime as date) - cast(p.dob as date))/365.242) as age
	from public.patients p
	inner join public.admissions a
	on p.subject_id = a.subject_id
	where round((cast(a.admittime as date) - cast(p.dob as date))/365.242) >= 16;

select count(distinct(db.subject_id)) from pat_dbsource db
inner join adult_info adult
on db.hadm_id = adult.hadm_id
where dbsource = 'carevue';      /* 22391 */

select count(distinct(db.hadm_id)) from pat_dbsource db
inner join adult_info adult
on db.hadm_id = adult.hadm_id
where dbsource = 'carevue';      /* 27568 */

select count(distinct(db.subject_id)) from pat_dbsource db
inner join adult16_info adult
on db.hadm_id = adult.hadm_id
where dbsource = 'carevue';      /* 22452 */

select count(distinct(db.hadm_id)) from pat_dbsource db
inner join adult16_info adult
on db.hadm_id = adult.hadm_id
where dbsource = 'carevue';      /* 27634 */

/* For patients with multiple admission, we only consider the first ICU stay. */
drop table if exists first_icustay;
create table first_icustay as 
select i.subject_id, i.hadm_id, i. icustay_id, i.intime from icustays i 
inner join (select subject_id, min(intime) from icustays
group by subject_id) as t
on i.subject_id = t.subject_id and i.intime = t.min
order by i.subject_id, i.hadm_id;

/* joint table of adult sourced from carevue */
drop table if exists adults_carevue_all;
create table adults_carevue_all as 
select adult.subject_id, 
	   adult.hadm_id,
	   db.dbsource,
	   adult.gender,
	   adult.age,
	   adult.hospital_expire_flag as dead_at_hospital_discharge -- 1 indicates death in hospital, 0 indicates survival to hospital discharge. 
	   from adult16_info adult
inner join pat_dbsource db
on adult.hadm_id = db.hadm_id
inner join first_icustay icu
on icu.hadm_id = adult.hadm_id
where dbsource = 'carevue';  

select count(*) from adults_carevue_all;  /* 22440 */
select count(distinct(subject_id)) from adults_carevue_all; /* 22440 */
select count(distinct(subject_id)) from adults_carevue_all
where gender = 'F';  /* 9657 */
select count(distinct(subject_id)) from adults_carevue_all
where gender = 'M';  /* 12783 */

/* get First SAPS for each subjects
 * 1. get first icustay_id for each subject 
 * 2. combine this with each table SAPS, SAPSII and SOFA */

select count(*) from first_icustay; /* 46476 */
select count(distinct(hadm_id)) from first_icustay;  /* 46476 */
select count(distinct(subject_id)) from first_icustay; /* 46476 */

select count(distinct(subject_id)) from adults_carevue_all;  /*22440*/
select count(distinct(subject_id)) from first_saps_info;     /*22439*/  

/******** age ********/
select percentile_cont(0.5) within group(order by age) from adults_carevue_all;    /* 66 */
select percentile_cont(0.25) within group(order by age) from adults_carevue_all;   /* 52 */
select percentile_cont(0.75) within group(order by age) from adults_carevue_all;   /* 78 */

select percentile_cont(0.5) within group (order by age) from adults_carevue_all   /* no replace for > 300*/
where dead_at_hospital_discharge = 1;    /* median 74 */

select percentile_cont(0.25) within group (order by age) from adults_carevue_all
where dead_at_hospital_discharge = 1;    /* 25th quantile: 60 */

select percentile_cont(0.75) within group (order by age) from adults_carevue_all
where dead_at_hospital_discharge = 1;    /* 75th quantile: 83 */

/*********** median and 0.25, 0.75 percentile 
 * age when the patients were not dead at hospital discharge***********/
select percentile_cont(0.5) within group (order by age) from adults_carevue_all
where dead_at_hospital_discharge = 0;    /* median 64 */

select percentile_cont(0.25) within group (order by age) from adults_carevue_all
where dead_at_hospital_discharge = 0;    /* 25th quantile: 51 */

select percentile_cont(0.75) within group (order by age) from adults_carevue_all
where dead_at_hospital_discharge = 0;    /* 75th quantile: 77 */

/**********  Age statistics
*    		        25%      Median     75%
*    Overall	    52        66        78 
*    Dead           60        74        83 
*	 Alive          51        64        77
*/

/***** Gender *******/
select count(subject_id) from adults_carevue_all;    /* 22440 total number */
select count(subject_id) from adults_carevue_all where gender = 'F';   /* 9657 43% */
select count(subject_id) from adults_carevue_all where dead_at_hospital_discharge = 1;  /* 2716 */
select count(subject_id) from adults_carevue_all where gender = 'F' and dead_at_hospital_discharge = 1;  /* 1283 47% */
select count(subject_id) from adults_carevue_all where dead_at_hospital_discharge = 0;  /* 19724 */
select count(subject_id) from adults_carevue_all where gender = 'F' and dead_at_hospital_discharge = 0;  /* 8374 42.5% */
select * from adults_carevue_all;


/***************************************************************************************************/
/***************************************************************************************************/
/***************************************************************************************************/
/*****************************************FIRST SAPS************************************************/
/***************************************************************************************************/
/***************************************************************************************************/
/***************************************************************************************************/

/* First SAPS*/
drop materialized view if exists first_saps cascade;
create materialized view first_saps as 
select s.subject_id, s.hadm_id, s.icustay_id, s.saps from saps s
inner join first_icustay f
on s.icustay_id = f.icustay_id;

select f.*, adult.gender, adult.dead_at_hospital_discharge from first_saps f
inner join adults_carevue_all adult
on f.hadm_id = adult.hadm_id;

delete table if exists first_saps_info;
create table first_saps_info  as -- combined with adults info
select a.*, f.icustay_id, f.saps from first_saps f
inner join adults_carevue_all a 
on f.hadm_id = a.hadm_id; 

select percentile_cont(0.5) within group (order by saps) from first_saps_info;  /* median 18*/
select percentile_cont(0.25) within group (order by saps) from first_saps_info; /* 14 */
select percentile_cont(0.75) within group (order by saps) from first_saps_info; /* 21 */

/*********** median and 0.25, 0.75 percentile of first 
 * saps when the patients were dead at hospital discharge***********/
select percentile_cont(0.5) within group (order by saps) from first_saps_info
where dead_at_hospital_discharge = 1;    /* median 22 */

select percentile_cont(0.25) within group (order by saps) from first_saps_info
where dead_at_hospital_discharge = 1;    /* 25th quantile 18 */

select percentile_cont(0.75) within group (order by saps) from first_saps_info
where dead_at_hospital_discharge = 1;    /* 75th quantile 26 */

/*********** median and 0.25, 0.75 percentile of first 
 * saps when the patients were not dead at hospital discharge***********/
select percentile_cont(0.5) within group (order by saps) from first_saps_info
where dead_at_hospital_discharge = 0;    /* median 17 */

select percentile_cont(0.25) within group (order by saps) from first_saps_info
where dead_at_hospital_discharge = 0;    /* 25th quantile 14 */

select percentile_cont(0.75) within group (order by saps) from first_saps_info
where dead_at_hospital_discharge = 0;    /* 75th quantile 21 */

/**********  SAPS statistics
*    		        25%      Median     75%
*    Overall	    14        18        21 
*    Dead           18        22        26 
*	 Alive          14        17        21
*/

/** first sapsii  **/
drop materialized view if exists first_sapsii cascade;
create materialized view first_sapsii as 
select s.subject_id, s.hadm_id, s.icustay_id, s.sapsii from sapsii s
inner join first_icustay f
on s.icustay_id = f.icustay_id;

select f.*, adult.gender, adult.dead_at_hospital_discharge from first_sapsii f
inner join adults_carevue_all adult
on f.hadm_id = adult.hadm_id;

drop table if exists first_sapsii_info;
create table first_sapsii_info  as -- combined with adults info
select a.*, f.icustay_id, f.sapsii from first_sapsii f
inner join adults_carevue_all a 
on f.hadm_id = a.hadm_id; 

select percentile_cont(0.5) within group (order by sapsii) from first_sapsii_info;  /* median 32 */
select percentile_cont(0.25) within group (order by sapsii) from first_sapsii_info; /* 24 */
select percentile_cont(0.75) within group (order by sapsii) from first_sapsii_info; /* 42 */

/*********** median and 0.25, 0.75 percentile of first 
 * sapsii when the patients were dead at hospital discharge***********/
select percentile_cont(0.5) within group (order by sapsii) from first_sapsii_info
where dead_at_hospital_discharge = 1;    /* median 48 */

select percentile_cont(0.25) within group (order by sapsii) from first_sapsii_info
where dead_at_hospital_discharge = 1;    /* median 38 */

select percentile_cont(0.75) within group (order by sapsii) from first_sapsii_info
where dead_at_hospital_discharge = 1;    /* median 59 */

/*********** median and 0.25, 0.75 percentile of first 
 * sapsii when the patients were not dead at hospital discharge***********/
select percentile_cont(0.5) within group (order by sapsii) from first_sapsii_info
where dead_at_hospital_discharge = 0;    /* median 31 */

select percentile_cont(0.25) within group (order by sapsii) from first_sapsii_info
where dead_at_hospital_discharge = 0;    /* median 23 */

select percentile_cont(0.75) within group (order by sapsii) from first_sapsii_info
where dead_at_hospital_discharge = 0;    /* median 39 */


/**********  SAPSII statistics
*    		        25%      Median     75%
*    Overall	    24        32        42 
*    Dead           38        48        59 
*	 Alive          23        31        39
*/

/**** first sofa *****/
drop materialized view if exists first_sofa cascade;
create materialized view first_sofa as 
select s.subject_id, s.hadm_id, s.icustay_id, s.sofa from sofa s
inner join first_icustay f
on s.icustay_id = f.icustay_id;

select f.*, adult.gender, adult.dead_at_hospital_discharge from first_sofa f
inner join adults_carevue_all adult
on f.hadm_id = adult.hadm_id;

drop table if exists first_sofa_info;
create table first_sofa_info  as -- combined with adults info
select a.*, f.icustay_id, f.sofa from first_sofa f
inner join adults_carevue_all a 
on f.hadm_id = a.hadm_id; 

select percentile_cont(0.5) within group (order by sofa) from first_sofa_info;  /* median 3 */
select percentile_cont(0.25) within group (order by sofa) from first_sofa_info; /* 2 */
select percentile_cont(0.75) within group (order by sofa) from first_sofa_info; /* 5 */

/*********** median and 0.25, 0.75 percentile of first 
 * sofa when the patients were dead at hospital discharge***********/
select percentile_cont(0.5) within group (order by sofa) from first_sofa_info
where dead_at_hospital_discharge = 1;    /* median 6 */

select percentile_cont(0.25) within group (order by sofa) from first_sofa_info
where dead_at_hospital_discharge = 1;    /* median 4 */

select percentile_cont(0.75) within group (order by sofa) from first_sofa_info
where dead_at_hospital_discharge = 1;    /* median 9 */

/*********** median and 0.25, 0.75 percentile of first 
 * sofa when the patients were not dead at hospital discharge***********/
select percentile_cont(0.5) within group (order by sofa) from first_sofa_info
where dead_at_hospital_discharge = 0;    /* median 3 */

select percentile_cont(0.25) within group (order by sofa) from first_sofa_info
where dead_at_hospital_discharge = 0;    /* median 1 */

select percentile_cont(0.75) within group (order by sofa) from first_sofa_info
where dead_at_hospital_discharge = 0;    /* median 5 */


/**********  SOFA statistics
*    		        25%      Median     75%
*    Overall	    2         3          5 
*    Dead           4         6          9 
*	 Alive          1         3          5
*/

/***        AdmissionType        ***/

drop materialized view if exists patients_info_adult_carevue cascade;
create materialized view patients_info_adult_carevue as 
with surgflag as 
(
  select adm.hadm_id
    , case when lower(curr_service) like '%surg%' then 1 else 0 end as surgical
    , ROW_NUMBER() over
    (
      PARTITION BY adm.HADM_ID
      ORDER BY TRANSFERTIME
    ) as serviceOrder
  from admissions adm
  left join services se
    on adm.hadm_id = se.hadm_id
),
admissionType as 
(select a.subject_id, 
	   a.hadm_id,
	   case 
	       when adm.ADMISSION_TYPE = 'ELECTIVE' and s.surgical = 1
	       		then 'ScheduledSurgical'
	       when adm.ADMISSION_TYPE != 'ELECTIVE' and s.surgical = 1
	       		then 'UnscheduledSurgical'
	       else 'Medical'
	    end as AdmissionType
	from adults_carevue_all a
	inner join surgflag s 
	on a.hadm_id = s.hadm_id and s.serviceorder = 1
	inner join admissions adm
	on adm.hadm_id = a.hadm_id
)
select adult.*, adm.AdmissionType, f.first_careunit from admissionType adm
inner join adults_carevue_all adult
on adm.hadm_id = adult.hadm_id
inner join first_careunit f
on f.hadm_id = adm.hadm_id

select count(*) from patients_info_adult_carevue;   -- 22440

/* The view patients_info_adult_carevue contains information about all the adult
 * patients recorded by carevue and contains the admissionType for each patients*/

select distinct(admissionType) from patients_info_adult_carevue;
-- Medical, ScheduledSurgical, UnscheduledSurgical

/** Medical  **/
select count(*) from patients_info_adult_carevue where admissiontype = 'Medical';  -- 15748,
select count(*) from patients_info_adult_carevue where admissiontype = 'Medical' and dead_at_hospital_discharge = 1;
select count(*) from patients_info_adult_carevue where admissiontype = 'Medical' and dead_at_hospital_discharge = 0;

/** Scheduled Surgical  **/
select count(*) from patients_info_adult_carevue where admissiontype = 'ScheduledSurgical';  -- 2967,
select count(*) from patients_info_adult_carevue where admissiontype = 'ScheduledSurgical' and dead_at_hospital_discharge = 1;  --73
select count(*) from patients_info_adult_carevue where admissiontype = 'ScheduledSurgical' and dead_at_hospital_discharge = 0;  -- 2894

/** Unscheduled Surgical **/
select count(*) from patients_info_adult_carevue where admissiontype = 'UnscheduledSurgical';  -- 3725,
select count(*) from patients_info_adult_carevue where admissiontype = 'UnscheduledSurgical' and dead_at_hospital_discharge = 1;  --471
select count(*) from patients_info_adult_carevue where admissiontype = 'UnscheduledSurgical' and dead_at_hospital_discharge = 0;  -- 3254

/**** SITE ****/
select distinct(first_careunit) from patients_info_adult_carevue;
-- SICU, MICU, CCU, TSICU, CSRU

/** MICU **/
select count(*) from patients_info_adult_carevue where first_careunit = 'MICU';  -- 7385
select count(*) from patients_info_adult_carevue where first_careunit = 'MICU' and dead_at_hospital_discharge = 1;  -- 1228
select count(*) from patients_info_adult_carevue where first_careunit = 'MICU' and dead_at_hospital_discharge = 0;  -- 6157

/** SICU **/
select count(*) from patients_info_adult_carevue where first_careunit = 'SICU';  -- 3320
select count(*) from patients_info_adult_carevue where first_careunit = 'SICU' and dead_at_hospital_discharge = 1;  -- 474
select count(*) from patients_info_adult_carevue where first_careunit = 'SICU' and dead_at_hospital_discharge = 0;  -- 2846

/** CCU **/
select count(*) from patients_info_adult_carevue where first_careunit = 'CCU';  -- 3782
select count(*) from patients_info_adult_carevue where first_careunit = 'CCU' and dead_at_hospital_discharge = 1;  -- 442
select count(*) from patients_info_adult_carevue where first_careunit = 'CCU' and dead_at_hospital_discharge = 0;  -- 3340

/** TSICU **/
select count(*) from patients_info_adult_carevue where first_careunit = 'TSICU';  -- 3007
select count(*) from patients_info_adult_carevue where first_careunit = 'TSICU' and dead_at_hospital_discharge = 1;  -- 363
select count(*) from patients_info_adult_carevue where first_careunit = 'TSICU' and dead_at_hospital_discharge = 0;  -- 2644

/** CSRU **/
select count(*) from patients_info_adult_carevue where first_careunit = 'CSRU';  -- 4946
select count(*) from patients_info_adult_carevue where first_careunit = 'CSRU' and dead_at_hospital_discharge = 1;  -- 209
select count(*) from patients_info_adult_carevue where first_careunit = 'CSRU' and dead_at_hospital_discharge = 0;  -- 4737

/** Heart Rate within 24 hours after getting into ICU**/
select * from chartevents where itemid = 211 order by subject_id, hadm_id, icustay_id, charttime;

select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join patients_info_adult_carevue pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (chart.charttime between f.intime and f.intime + interval '1' day) and chart.itemid = 211;

/* Resp Rate  within the 24 hours after taking into icu*/
create table m_rr as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join patients_info_adult_carevue pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (chart.charttime between f.intime and f.intime + interval '1' day) and (chart.itemid in (615, 618))
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table m_rr add column row_id serial;
delete from
	   m_rr a using 
	   m_rr b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table m_rr drop column row_id;
 
select count(distinct(subject_id)) from m_rr;   /* 21833 */


/* Potassium (K) within the 24 hours after taking into icu*/
create table m_potassium as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join patients_info_adult_carevue pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (chart.charttime between f.intime and f.intime + interval '1' day) and (chart.itemid = 1535 or chart.itemid = 3792 or chart.itemid = 829)
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table m_potassium add column row_id serial;
delete from
	   m_potassium a using 
	   m_potassium b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table m_potassium drop column row_id;
 
select count(distinct(subject_id)) from m_potassium;   /* 21369 */

/* Sodium (Na) within the 24 hours after taking into icu*/
create table m_sodium as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join patients_info_adult_carevue pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (chart.charttime between f.intime and f.intime + interval '1' day) and (chart.itemid = 1536 or chart.itemid = 3803 or chart.itemid = 837)
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table m_sodium add column row_id serial;
delete from
	   m_sodium a using 
	   m_sodium b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table m_sodium drop column row_id;
 
select count(distinct(subject_id)) from m_sodium;   /* 21198 */

/* HCO3 within the 24 hours after taking into icu*/
create table m_hco3 as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join patients_info_adult_carevue pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (chart.charttime between f.intime and f.intime + interval '1' day) and chart.itemid = 812
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table m_hco3 add column row_id serial;
delete from
	   m_hco3 a using 
	   m_hco3 b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table m_hco3 drop column row_id;
 
select count(distinct(subject_id)) from m_hco3;   /* 1 */

/* WBC within the 24 hours after taking into icu*/
create table m_wbc as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join patients_info_adult_carevue pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (chart.charttime between f.intime and f.intime + interval '1' day) and (chart.itemid = 1542 or itemid = 4200 or itemid = 861 or itemid = 1127)
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table m_wbc add column row_id serial;
delete from
	   m_wbc a using 
	   m_wbc b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table m_wbc drop column row_id;
 
select count(distinct(subject_id)) from m_wbc;   /* 20861 */

/* Arterial BP [systolic] within the 24 hours after taking into icu*/
drop table m_abps;
create table m_abps as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join patients_info_adult_carevue pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (chart.charttime between f.intime and f.intime + interval '1' day) and (chart.itemid in (6, 51, 442, 455, 6701))
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table m_abps add column row_id serial;
delete from
	   m_abps a using 
	   m_abps b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table m_abps drop column row_id;
 
select count(distinct(subject_id)) from m_abps;   /* 21886 */

/* Arterial BP Mean within the 24 hours after taking into icu*/
drop table if exists m_abpm;
create table m_abpm as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join patients_info_adult_carevue pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (chart.charttime between f.intime and f.intime + interval '1' day) and chart.itemid  in (456,52,6702,443)
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table m_abpm add column row_id serial;
delete from
	   m_abpm a using 
	   m_abpm b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table m_abpm drop column row_id;
 
select count(distinct(subject_id)) from m_abpm;   /* 21883 */

/* Glasgow Coma Scale within the 24 hours after taking into icu*/
create table m_gcs as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join patients_info_adult_carevue pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (chart.charttime between f.intime and f.intime + interval '1' day) and chart.itemid = 198
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table m_gcs add column row_id serial;
delete from
	   m_gcs a using 
	   m_gcs b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table m_gcs drop column row_id;
 
select count(distinct(subject_id)) from m_gcs;   /* 21801 */

/* Temperature within the 24 hours after taking into icu*/
create table m_temperature as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join patients_info_adult_carevue pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (chart.charttime between f.intime and f.intime + interval '1' day) and chart.itemid = 678
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table m_temperature add column row_id serial;
delete from
	   m_temperature a using 
	   m_temperature b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table m_temperature drop column row_id;
 
select count(distinct(subject_id)) from m_temperature;   /* 19145 */

/* PaO2 within the 24 hours after taking into icu*/
create table m_paO2 as (
select pat.*, f.intime, chart.charttime, chart.valuenum, chart.valueuom, chart.error from chartevents chart
inner join patients_info_adult_carevue pat
on chart.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (chart.charttime between f.intime and f.intime + interval '1' day) and chart.itemid = 779
order by chart.subject_id, chart.hadm_id, chart.icustay_id, chart.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table m_paO2 add column row_id serial;
delete from
	   m_paO2 a using 
	   m_paO2 b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table m_paO2 drop column row_id;
 
select count(distinct(subject_id)) from m_paO2;   /* 12996 */

/* Bilirubin within the 24 hours after taking into icu*/
drop table if exists m_bilirubin;
create table m_bilirubin as (
select pat.*, f.intime, lab.charttime, lab.valuenum, lab.valueuom, lab.flag from labevents lab
inner join patients_info_adult_carevue pat
on lab.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (lab.charttime between f.intime and f.intime + interval '1' day) and lab.itemid in (50883, 50884, 50885)
order by lab.subject_id, lab.hadm_id, lab.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table m_bilirubin add column row_id serial;
delete from
	   m_bilirubin a using 
	   m_bilirubin b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table m_bilirubin drop column row_id;
 
select count(distinct(subject_id)) from m_bilirubin;   /* 6647 */

/* Blood urea nitrogen within the 24 hours after taking into icu*/
create table m_bun as (
select pat.*, f.intime, lab.charttime, lab.valuenum, lab.valueuom, lab.flag from labevents lab
inner join patients_info_adult_carevue pat
on lab.hadm_id = pat.hadm_id
inner join first_icustay f
on f.hadm_id = pat.hadm_id
where (lab.charttime between f.intime and f.intime + interval '1' day) and lab.itemid = 51006
order by lab.subject_id, lab.hadm_id, lab.charttime);

/* there are some duplicates due to the different itemid may have the same measurements, remove them*/

alter table m_bun add column row_id serial;
delete from
	   m_bun a using 
	   m_bun b where a.row_id > b.row_id and a.subject_id = b.subject_id and a.hadm_id = b.hadm_id and a.charttime = b.charttime;
alter table m_bun drop column row_id;
 
select count(distinct(subject_id)) from m_bun;   /* 21478 */


/** Hospital LOS **/
drop table if exists adult_hosp_los;
create table adult_hosp_los as 
select pat.*, los_hospital from icustay_detail icu
inner join patients_info_adult_carevue pat
on icu.hadm_id = pat.hadm_id;
select * from adult_hosp_los;
alter table adult_hosp_los add column row_id serial;

delete from 
	   adult_hosp_los a using 
	   adult_hosp_los b where a.row_id > b.row_id and a.hadm_id = b.hadm_id;
alter table adult_hosp_los drop column row_id;

/** 
