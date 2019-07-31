library(dplyr)
getQ <- function(filename) {
  filename = paste("./Desktop/chapter20/", filename, sep = "")
  overall_data <- read.csv(filename)
  dead <- overall_data %>% filter(dead_at_hospital_discharge == 1)
  alive <- overall_data %>% filter(dead_at_hospital_discharge == 0)
  cat("Percentile of overall data:\n\n")
  print(quantile(overall_data$valuenum, na.rm = T))
  cat("\nPercentile of patients dead at hospital discharge:\n\n")
  print(quantile(dead$valuenum, na.rm = T))
  cat("\nPercentile of patients alive at hospital discharge:\n\n")
  print(quantile(alive$valuenum, na.rm = T))
}
getQ_hos <- function(filename) {
  filename = paste("./Desktop/chapter20/", filename, sep = "")
  overall_data <- read.csv(filename)
  data <- overall_data %>% filter(valuenum >= 0)
  dead <- data %>% filter(dead_at_hospital_discharge == 1)
  alive <- data %>% filter(dead_at_hospital_discharge == 0)
  cat("Percentile of overall data:\n\n")
  print(quantile(data$valuenum, na.rm = T))
  cat("\nPercentile of patients dead at hospital discharge:\n\n")
  print(quantile(dead$valuenum, na.rm = T))
  cat("\nPercentile of patients alive at hospital discharge:\n\n")
  print(quantile(alive$valuenum, na.rm = T))
}
getQ("potassium.csv")
getQ("Sodium.csv")
getQ("wbc.csv")
getQ("abps.csv")
getQ("abpm.csv")
getQ("gcs.csv")
getQ("temperature.csv")
getQ("paO2.csv")
getQ("bun.csv")
getQ("resp_rate.csv")
getQ_hos("hosp_los.csv")


# Choose the number (x) of rows which is the minimum among all the files for each single hadm_id
# and combine the first x rows from all the files for all the hadm_id together.

tv <- read.csv("./Desktop/MIMIC-III/already_done/chapter18/data/combine_first//pat_tidal_volume.csv")
wbc <- read.csv("./Desktop/MIMIC-III/already_done/chapter18/data/combine_first/wbc.csv")
temp <- read.csv("./Desktop/MIMIC-III/already_done/chapter18/data/combine_first/temp.csv")
sysbp <- read.csv("./Desktop/MIMIC-III/already_done/chapter18/data/combine_first/sysbp.csv")
rr <- read.csv("./Desktop/MIMIC-III/already_done/chapter18/data/combine_first/resprate.csv")
meanbp <- read.csv("./Desktop/MIMIC-III/already_done/chapter18/data/combine_first/meanbp.csv")
hr <- read.csv("./Desktop/MIMIC-III/already_done/chapter18/data/combine_first/heartrate.csv")
diasbp <- read.csv("./Desktop/MIMIC-III/already_done/chapter18/data/combine_first/diasbp.csv")
bmi <- read.csv("./Desktop/MIMIC-III/already_done/chapter18/data/combine_first/bmi.csv")

combined <- data.frame(hadm_id = numeric(0), 
                       tv = numeric(0), 
                       wbc = numeric(0), 
                       temp = numeric(0),
                       sysbp = numeric(0),
                       rr = numeric(0),
                       meanbp = numeric(0),
                       hr = numeric(0),
                       diasbp = numeric(0),
                       bmi = numeric(0))
b = 0
hadm_id_list <- unique(tv$hadm_id)
for(i in hadm_id_list){
  b = b+1
  print(b)
  curr_tv <- tv %>% filter(hadm_id == i)        # current tidal volume
  curr_wbc <- wbc %>% filter(hadm_id == i)      # current wbc
  curr_temp <- temp %>% filter(hadm_id == i)    # current temperature
  curr_sysbp <- sysbp %>% filter(hadm_id == i)
  curr_rr <- rr %>% filter(hadm_id == i)
  curr_meanbp <- meanbp %>% filter(hadm_id == i)
  curr_hr <- hr %>% filter(hadm_id == i)
  curr_diasbp <- diasbp %>% filter(hadm_id == i)
  curr_bmi <- bmi %>% filter(hadm_id == i)
  
  num <- numeric(10)
  num[1] <- nrow(curr_tv) 
  num[2] <- nrow(curr_wbc)
  num[3] <- nrow(curr_temp)
  num[4] <- nrow(curr_sysbp)
  num[5] <- nrow(curr_rr)
  num[6] <- nrow(curr_meanbp)
  num[7] <- nrow(curr_hr)
  num[8] <- nrow(curr_diasbp)
  num[9] <- nrow(curr_bmi)
  
  numRec <- min(num[num!=0])
  newRec <- data.frame(hadm_id = rep(i, numRec),
                       tv = curr_tv$tidal_volume[1:numRec],
                       wbc = curr_wbc$valuenum[1:numRec],
                       temp = curr_temp$valuenum[1:numRec],
                       sysbp = curr_sysbp$valuenum[1:numRec],
                       rr = curr_rr$valuenum[1:numRec],
                       meanbp = curr_rr$valuenum[1:numRec],
                       hr = curr_hr$valuenum[1:numRec],
                       diasbp = curr_diasbp$valuenum[1:numRec],
                       bmi = curr_bmi$bmi[1:numRec])
  combined <- rbind(combined, newRec)
}
write.csv(combined, "./Desktop/MIMIC-III/already_done/chapter18/data/first_hospital_stay/tidal_volume_complete_version_first_adm.csv", row.names = F,na = "")

length(unique(na.omit(combined)$hadm_id))
