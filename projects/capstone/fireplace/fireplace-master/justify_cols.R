library(data.table)
library(lubridate)
library(dplyr)
library(tidyr)
library(magrittr)
library(readr)
library(zoo)
library(lazyeval)

install.packages("data.table", repos = "https://Rdatatable.github.io/data.table", type = "source")

# Load package
library(data.table)

#allpartial = list()

unique_cols = c()

for (i in 1:250) {
  load(paste0('./alec_capstone/widened_pieces/', paste0('wide',i,'.RData')))
  unique_cols = unique(c(unique_cols, names(partial)))
  print(length(unique_cols))
}

for (i in 1:250) {
  print(i)
  load(paste0('./alec_capstone/widened_pieces/', paste0('wide',i,'.RData')))
  partial = data.table(partial)
  print(length(unique(partial$game_id)))
  print(dim(partial))
  
  for (uc in unique_cols) {
    if (!(uc %in% names(partial))) {
      partial[, uc := 0, with=F]
    }
  }
  print(dim(partial))
  #allpartial[[i]] = partial
  
  #write.csv(partial, paste0('./alec_capstone/widened_piece_csvs/', paste0('wide',i,'.csv')), row.names=F)
  fwrite(partial, paste0('./alec_capstone/widened_piece_csvs/', paste0('wide',i,'.csv')))
}

# allpartial = data.table(rbindlist(allpartial))
# nacols = colnames(allpartial)[colSums(is.na(allpartial)) > 0]
# 
# ehp = names(allpartial)[grepl('^enemy_hero_power', names(allpartial))]
# tmp = allpartial[, ehp, with=F]
# colSums(tmp)
# 

