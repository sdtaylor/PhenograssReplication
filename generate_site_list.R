library(tidyverse)

phenocam_sites = phenocamapi::get_rois() %>%
  select(site, lat, lon, roitype, first_date, last_date, site_years) 

site_stats = phenocamr::list_sites() %>%
  select(site, ecoregion, MAP_daymet, MAT_daymet)

phenocam_sites = phenocam_sites %>%
  left_join(site_stats, by='site')

sites_with_multipe_rois = phenocam_sites %>%
  group_by(site, lon, lat) %>%
  summarise(n_rois = n_distinct(roitype),
            rois   = paste(unique(roitype),collapse=',')) %>%
  ungroup() %>%
  filter(n_rois>1)


site_subset = phenocam_sites %>%
  filter(roitype %in% c('GR','AG','SH')) %>% # agriculture, shrubland, and grassland only
  filter(!grepl('*0042', site)) %>% # Drop the NEON...42 mid-tower cameras
  filter(site_years>3) %>%   # Has atleast 3 full years and is operational till fairly recently
  filter(last_date > '2017-01-01') %>%
  filter(lon < -65, lon > -135, lat>25, lat<55) # contiguous us only

write_csv(site_subset, 'site_list.csv')
