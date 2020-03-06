library(tidyverse)


####################
# These timeseries all have various issues, which are noted.
# note some cameras have multiple ROI's, (ie. 1000,2000,etc)
# so most cameras still have another ROI being included

timeseries_to_drop = tribble(
  ~phenocam_name, ~roitype, ~roi,
  'bouldinalfalfa','AG', '1000', # lots of camera shifts here as noted on the phenocam site
  'cucamongasouth','SH', '1000', # lots of missing data in this one
  #'ahwahnee',      ''  # has three GR timeseries, 1000,2000,3000, maybe ok?
  'goodwater',    'AG',  '1000',  # keeping AG_1001 since it excludes the field edge
  'hawbeckereddy','AG',  '2000',  #  AG_2000 roi is < 1 year, but AG_1000 for here is good
  'ibp',          'SH',  '1000',  # replicated by SH_1001
  'jernort',      'SH',  '1000',  # only 1.5 years. jernort_SH_2000 is 3
  'luckyhills',   'SH',  '1000',  # drop all lucky hills except SH_2000, whic his ~3 years
  'luckyhills',   'SH',  '3000',
  'luckyhills',   'SH',  '4000',
  'NEON.D15.ONAQ.DP1.00033','SH','1000', # SH_1001 for this camera has a better shrub ROI
  
  'ufona',         'SH', '1000', # This has some very bad outliers. could potentially be dealth with
  'usgseros',      'GR', '2000', # the GR_1000 for this camera has ~3 years while 2000 has ~1
  'uiefmiscanthus','AG', '2000', # has only 2.5 years while ag_1000 has > 8
  
  'spruceA0EMI',   'SH', '1000',  # This site is way over represented. I'm only keeping the
  'spruceA0EMT',   'SH', '1000',  # camera 'spruceT6P16E'
  'spruceA0P07',   'SH', '1000',
  'spruceT0P06',   'SH', '1000',
  'spruceT0P19E',   'SH', '1000',
  'spruceT2P11E',   'SH', '1000',
  'spruceT2P20',   'SH', '1000',
  'spruceT4P04E',   'SH', '1000',
  'spruceT4P13',   'SH', '1000',
  'spruceT6P08',   'SH', '1000',
  'spruceT9P17',   'SH', '1000',
  'spruceT9P10E',   'SH', '1000'
)

timeseries_to_drop$keep=FALSE

####
# Take the data downloaded by phenocamr and put into
# a format suitable for pyGrasslandModels
####

read_in_phenocam_file = function(full_file_path){
  filename = basename(full_file_path)
  phenocam_name = str_split(filename, '_')[[1]][1]
  phenocam_veg = str_split(filename, '_')[[1]][2]
  phenocam_roi = str_split(filename, '_')[[1]][3]
  
  read_csv(full_file_path, skip=24) %>%
    select(date, year, doy, gcc_90, smooth_gcc_90, snow_flag, outlierflag_gcc_90) %>%
    mutate(phenocam_name = phenocam_name, roitype = phenocam_veg, roi = phenocam_roi)
}

phenocam_files = list.files('data/phenocam/', pattern = '_3day.csv', full.names = T)
phenocam_data = purrr::map_dfr(phenocam_files, read_in_phenocam_file)

# Drop all the timeseries listed above
phenocam_data = phenocam_data %>%
  left_join(timeseries_to_drop, by=c('phenocam_name','roitype','roi')) %>%
  mutate(keep = replace_na(keep, TRUE)) %>%
  filter(keep) %>%
  select(-keep)

# only from 2012 onwards.
# 2 sites have data going back to ~2004. but the vast majority of data is > 2012
# also limit to 2018 since thats the daymet limit
phenocam_data = phenocam_data %>%
  filter(date >= lubridate::ymd('2012-01-01')) %>%
  filter(date <= lubridate::ymd('2018-12-31'))

# Using the smoothed dataset to drop most of the really bad
# outliers
phenocam_data$gcc = phenocam_data$smooth_gcc_90

# scale to a site-specific 0-1
phenocam_data = phenocam_data %>%
  group_by(phenocam_name, roitype, roi) %>%
  mutate(gcc = (gcc - min(gcc, na.rm = T)) / (max(gcc, na.rm=T)- min(gcc, na.rm=T))) %>%
  ungroup()

write_csv(phenocam_data, 'data/processed_phenocam_data.csv')

########################
# Visualize all timeseries
# outliers = phenocam_data %>%
#   filter(outlierflag_gcc_90==1)
# 
# big_fig = ggplot(phenocam_data, aes(x=date)) +
#   #geom_point(aes(y=gcc_90), color='black') +
#   geom_line(aes(y=gcc), color='red') +
#   geom_point(aes(y=gcc), color='red') +
#   #geom_point(aes(y=scaled_gcc_90), color='red') +
#   geom_vline(data = outliers, aes(xintercept=date), color='blue') +
# 
#   facet_wrap(phenocam_name~roitype~roi, scales='free')
# 
# ggsave('big_ts_series.png', plot=big_fig, width=80, height=80, unit='cm', dpi=200)
