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

tv <- read.csv("./Desktop/MIMIC-III/combine/pat_tidal_volume.csv")
wbc <- read.csv("./Desktop/MIMIC-III/combine/wbc.csv")
temp <- read.csv("./Desktop/MIMIC-III/combine/temp.csv")
sysbp <- read.csv("./Desktop/MIMIC-III/combine/sysbp.csv")
spo2 <- read.csv("./Desktop/MIMIC-III/combine/spo2.csv")
rr <- read.csv("./Desktop/MIMIC-III/combine/rr.csv")
meanbp <- read.csv("./Desktop/MIMIC-III/combine/meanbp.csv")
hr <- read.csv("./Desktop/MIMIC-III/combine/hr.csv")
glucose <- read.csv("./Desktop/MIMIC-III/combine/glucose.csv")
diasbp <- read.csv("./Desktop/MIMIC-III/combine/diasbp.csv")
bmi <- read.csv("./Desktop/MIMIC-III/combine/pat_bmi.csv")

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
hadm_id_list <- tv$hadm_id
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
                       diasbp = curr_diasbp$valuenum[1:numRec])
  combined <- rbind(combined, newRec)
}
