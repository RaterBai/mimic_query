# Algorithm to detect AKI onset 
# 1: acute increase of serum creatinine >= 0.3 mg/dL
# 2: increase at least (include) 50% within 48h

install.packages("chron")
library(chron)
library(dplyr)

data <- read.csv("./chapter25/data/creatinine.csv")
data$charttime <- as.Date(data$charttime)
head(data)

dtimes <- as.character(data$charttime)
dtparts <- t(as.data.frame(strsplit(dtimes, ' ')))
row.names(dtparts) = NULL
charttime2 <- chron(dates = dtparts[, 1], times=dtparts[, 2],
                  format = c('y-m-d', 'h:m:s'))
data <- cbind(data, charttime2)
head(data)

# initialize

{usub <- unique(data$subject_id)  #unique subjects
result <- data.frame(subject_id = as.numeric(), AKI = as.numeric(), charttime = as.character())
num = 0
epsilon <- 1e-10  # set a tolerance
}

for(sub in usub) {
  print(num)
  num <- num + 1
  # for each subject, first extract all his/her records
  flag <- 0  # if AKI onset, put flag = 1 
  pos <- NULL
  info <- data %>% filter(subject_id == sub)
  for(i in seq(length(info$valuenum) - 1)) {
    diff <- info$valuenum[i+1] - info$valuenum[i]
    if((diff+epsilon) >= 0.3){
      flag = 1
      pos = i+1 # indicator for position of charttime
      break
    }
  }
  if(flag == 0) {  #if flag == 0, check whether in 48h, there is a increase more than 50%
    for(i in seq(length(info$valuenum) - 1)) {
      #print("now i is:")
      #print(i)
      maxTime <- info$charttime2[i] + 2
      maxValue <- info$valuenum[i] * 1.5
      #print(paste("maxTime: ", maxTime, sep = ""))
      #print(paste("maxVaule: ", maxValue, sep = ""))
      for(j in seq(i+1, length(info$valuenum) -1)) {
        #print(paste("j:", j, sep = " "))
        if(info$charttime2[j] > maxTime)
          break
        if((info$valuenum[j]+epsilon) >= maxValue) {
          flag = 2     # acute increase >= 50% within 48 hours
          pos = j      # record the position
          break
        }
      }
      if(flag == 2)
        break
    }
  }
  if(flag == 1){
    newRec <- data.frame(subject_id = info$subject_id[pos], AKI = 1, charttime = format(info$charttime2[pos], "%Y-%m-%d %H:%M:%S"))
  }
  else if (flag == 2) {
    newRec <- data.frame(subject_id = info$subject_id[pos], AKI = 2, charttime = format(info$charttime2[pos], "%Y-%m-%d %H:%M:%S"))
  }
  else{
    newRec <- data.frame(subject_id = info$subject_id[1], AKI = 0, charttime = '')
  }
  result <- rbind(result, newRec)
}

aki1 <- result %>% filter(AKI == 1)
aki2 <- result %>% filter(AKI == 2)
nrow(aki1) + nrow(aki2)
head(aki1, 20)
head(aki2, 20)
aki_onset <- result %>% filter(AKI == 1 | AKI == 2)
non_aki <- result %>% filter(AKI == 0)
write.csv(aki_onset, "./Desktop/MIMIC-III/already_done/chapter25/data/AKI_cohort.csv", row.names = F, na = "")
write.csv(non_aki$subject_id, "./Desktop/MIMIC-III/already_done/chapter25/data/non_aki_cohort.csv", row.names = F, na = "")
