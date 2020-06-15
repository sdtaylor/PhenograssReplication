library(tidyverse)
library(kableExtra)

ecoregion_info = read_csv('model_fitting_set_info/ecoregion_codes.csv') %>%
  mutate(ecoregion_desc = str_wrap(ecoregion_desc,10))
hufkin2016_sites = read_csv('hufkins2016_sites.csv')

site_list = read_csv('site_list.csv') %>%
  filter(has_processed_data) %>%
  mutate(phenocam_name = str_remove(phenocam_name, 'DP1.00033')) %>% # Shorten those long neon names
  mutate(phenocam_name = str_remove(phenocam_name, 'DP1.20002')) %>%
  mutate(lat = round(lat,2), lon=round(lon,2)) %>%
  rename(name = phenocam_name) %>%
  left_join(ecoregion_info, by='ecoregion') %>%
  select(name,lat,lon,vegetation=roi_type,roi_id,first_date,last_date,site_years,ecoregion = ecoregion_abbr)

site_list = site_list %>%
  mutate(name = case_when(
    name %in% hufkin2016_sites$phenocam_name ~ paste0(name,'*'),
    TRUE ~name))

kable(site_list, 'latex')
