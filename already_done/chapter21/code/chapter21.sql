with static_data as 
(
	select ie.subject_id,
		   ie.hadm_id,
		   ie.icustay_id,
		   case 
      		when round( ( cast(ie.intime as date) - cast(pat.dob as date) ) / 365.242 , 2 ) >= 150 then 91.4
      		else round( ( cast(ie.intime as date) - cast(pat.dob as date) ) / 365.242 , 2 )
      	   end as age,
      	   pat.gender,
      	   adm.ADMISSION_TYPE,
		   first_careunit.first_careunit as icustay_first_service
		   -- need 30 days mortality
	from first_icustay ie
	inner join patients pat
	on pat.subject_id = ie.subject_id
	inner join admissions adm
	on ie.hadm_id = adm.hadm_id
	inner join first_careunit
	on ie.hadm_id = first_careunit.hadm_id
), surgflag as
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
) 
, first_creatinine as 
(
	select distinct hadm_id, first_value(valuenum) over (partition by hadm_id order by charttime) as creatinine 
	from labevents where itemid = 50912 
) , first_chloride as 
(
	select distinct hadm_id, first_value(valuenum) over (partition by hadm_id order by charttime) as chloride 
	from labevents
	where itemid in (50806, 50902)
) , first_bicarbonate as 
(
	select distinct hadm_id, first_value(valuenum) over (partition by hadm_id order by charttime) as bicarbonate 
	from labevents
	where itemid = 50882
), first_hematocrit as 
(
	select distinct hadm_id, first_value(valuenum) over (partition by hadm_id order by charttime) as hematocrit 
	from labevents
	where itemid in (50810, 51221)
), first_wbc as 
(
	select distinct hadm_id, first_value(valuenum) over (partition by hadm_id order by charttime) as wbc 
	from labevents
	where itemid in (51300, 51301)
), first_glucose as 
(
	select distinct hadm_id, first_value(valuenum) over (partition by hadm_id order by charttime) as glucose 
	from labevents
	where itemid in (50809, 50931)
), first_lactate as 
(
	select distinct hadm_id, first_value(valuenum) over (partition by hadm_id order by charttime) as lactate 
	from labevents
	where itemid = 50813
), first_magnesium as 
(
	select distinct hadm_id, first_value(valuenum) over (partition by hadm_id order by charttime) as magnesium 
	from labevents
	where itemid = 50960
), first_calcium as 
(
	select distinct hadm_id, first_value(valuenum) over (partition by hadm_id order by charttime) as calcium 
	from labevents
	where itemid = 50893
), first_sodium as 
(
	select distinct hadm_id, first_value(valuenum) over (partition by hadm_id order by charttime) as sodium 
	from labevents
	where itemid in (50983, 50824)
), first_potassium as 
(
	select distinct hadm_id, first_value(valuenum) over (partition by hadm_id order by charttime) as potassium 
	from labevents
	where itemid in (50971, 50822)
), first_hr as 
(
	select distinct icustay_id, first_value(valuenum) over (partition by icustay_id order by charttime) as hr 
	from chartevents
	where itemid in (211, 22045)
), first_sysbp as 
(
	select distinct icustay_id, first_value(valuenum) over (partition by icustay_id order by charttime) as sysbp 
	from chartevents
	where itemid in (51, --	Arterial BP [Systolic]
  				     442, --	Manual BP [Systolic]
                     455, --	NBP [Systolic]
                     6701, --	Arterial BP #2 [Systolic]
                     220179, --	Non Invasive Blood Pressure systolic
                     220050 --	Arterial Blood Pressure systolic
                     )
), first_meanbp as 
(
	select distinct icustay_id, first_value(valuenum) over (partition by icustay_id order by charttime) as meanbp 
	from chartevents
	where itemid in (-- MEAN ARTERIAL PRESSURE
  				     456, --"NBP Mean"
  					 52, --"Arterial BP Mean"
  					 6702, --	Arterial BP Mean #2
  					 443, --	Manual BP Mean(calc)
  					 220052, --"Arterial Blood Pressure mean"
  					 220181, --"Non Invasive Blood Pressure mean"
  					 225312 --"ART BP mean"
                     )
), first_spo2 as 
(
	select distinct icustay_id, first_value(valuenum) over (partition by icustay_id order by charttime) as spo2 
	from chartevents
	where itemid in ( -- SPO2, peripheralmea
  					  646, 220277)
), temperature as  -- celcius
(
	select icustay_id, charttime,  
		case 
			when itemid in (223761, 687) then (valuenum-32)/1.8 
			else valuenum 
		end as valuenum from chartevents where itemid in (
															-- TEMPERATURE
  															223762, -- "Temperature Celsius"
  															676,	-- "Temperature C"
  															223761, -- "Temperature Fahrenheit"
  															678 --	"Temperature F"
														  )		  
), first_temp as 
(
	select distinct icustay_id, first_value(valuenum) over (partition by icustay_id order by charttime) as temperature 
	from temperature
), first_rr as 
(
	select distinct icustay_id, first_value(valuenum) over (partition by icustay_id order by charttime) as resprate
	from chartevents
	where itemid in ( -- RESPIRATORY RATE
  					  618,--	Respiratory Rate
   					  615,--	Resp Rate (Total)
  					  220210,--	Respiratory Rate
  				  	  224690 --	Respiratory Rate (Total)
  					)
)
select stat.subject_id, 
   	     stat.hadm_id, 
   	     stat.icustay_id,
   	     stat.age,
   	     stat.icustay_first_service,
   	     case
          when stat.ADMISSION_TYPE = 'ELECTIVE' and sf.surgical = 1
            then 'ScheduledSurgical'
          when stat.ADMISSION_TYPE != 'ELECTIVE' and sf.surgical = 1
            then 'UnscheduledSurgical'
          else 'Medical'
         end as AdmissionType,
   	     cr.creatinine,
   	     cl.chloride,
   	     bi.bicarbonate,
   	     he.hematocrit,
   	     wbc.wbc,
   	     gl.glucose,
   	     la.lactate,
   	     mg.magnesium,
   	     ca.calcium,
   	     na.sodium,
   	     k.potassium,
   	     hr.hr as heartrate,
   	     sysbp.sysbp as sysbp,
   	     meanbp.meanbp as meanbp,
   	     spo2.spo2 as spo2,
   	     /*icu_death.exipre_flag as icu_expire_flag,
   	     death_after_a_month.expire_flag as death_after_a_month,
   	     death_after_a_year.expire_flag as death_after_a_year,*/
   	     temp.temperature,
   	     rr.resprate
   	     from static_data stat
/*inner join icu_death
on icu_death.icustay_id = stat.icustay_id
inner join death_after_a_month
on death_after_a_month.hadm_id = stat.hadm_id
inner join death_after_a_year
on death_after_a_year.hadm_id = stat.hadm_id*/
left join surgflag sf
  on stat.hadm_id = sf.hadm_id and sf.serviceOrder = 1
left join first_creatinine cr
on stat.hadm_id = cr.hadm_id
left join first_chloride cl
on stat.hadm_id = cl.hadm_id
left join first_bicarbonate bi
on stat.hadm_id = bi.hadm_id
left join first_hematocrit he
on stat.hadm_id = he.hadm_id
left join first_wbc wbc
on stat.hadm_id = wbc.hadm_id
left join first_glucose gl
on stat.hadm_id = gl.hadm_id
left join first_lactate la
on stat.hadm_id = la.hadm_id
left join first_magnesium mg
on stat.hadm_id = mg.hadm_id
left join first_calcium ca
on stat.hadm_id = ca.hadm_id
left join first_sodium na
on stat.hadm_id = na.hadm_id
left join first_potassium k
on stat.hadm_id = k.hadm_id
left join first_hr hr
on stat.icustay_id = hr.icustay_id
left join first_sysbp sysbp
on stat.icustay_id = sysbp.icustay_id
left join first_meanbp meanbp
on stat.icustay_id = meanbp.icustay_id
left join first_spo2 spo2
on stat.icustay_id = spo2.icustay_id
left join first_temp temp
on stat.icustay_id = temp.icustay_id
left join first_rr rr
on stat.icustay_id = rr.icustay_id