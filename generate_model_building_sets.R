library(tidyverse)

######################################
# Put together the different aggregations of phenocam timeseries to model
# for example only grasslands, only grassland in the Grain Plains ecoregions, etc.
#
######################################

min_sites_needed = 5

phenocam_sites = read_csv('site_list.csv') %>%
  filter(has_processed_data) 

ecoregion_codes = tribble(
  ~ecoregion, ~ecoregion_desc, ~ecoregion_abbr,
  5, 'Northern Forests',                'NForest',
  6, 'Northwestern Forested Mountains', 'NWForests',
  7, 'Marine West Coast Forest',        'MWCoastForests',
  8, 'Eastern Temperate Forests',       'ETempForests',
  9, 'Great Plains',                    'GrPlains',
  10,'North American Deserts',          'NADeserts',
  11,'Mediterranean California',        'MedCA',
  12,'Southern Semi-Arid Highlands',    'SouthAridHighliands'
)


##########################

ecoregions_vegtype_sets = phenocam_sites %>%
  group_by(ecoregion, roi_type) %>%
  summarise(n_phenocams = n(),
            total_site_years = sum(site_years)) %>%
  ungroup() %>%
  filter(n_phenocams>=min_sites_needed) %>%
  left_join(ecoregion_codes, by='ecoregion') %>%
  mutate(model_building_sets = paste('ecoregion-vegtype',ecoregion_abbr,roi_type,sep='_'))

ecoregions_sets = phenocam_sites %>%
  group_by(ecoregion) %>%
  summarise(n_phenocams = n(),
            total_site_years = sum(site_years)) %>%
  ungroup() %>%
  filter(n_phenocams>=min_sites_needed) %>%
  left_join(ecoregion_codes, by='ecoregion') %>%
  mutate(model_building_sets = paste('ecoregion',ecoregion_abbr,sep='_'))

vegtype_sets = phenocam_sites %>%
  group_by(roi_type) %>%
  summarise(n_phenocams = n(),
            total_site_years = sum(site_years)) %>%
  ungroup() %>%
  filter(n_phenocams>=min_sites_needed) %>%
  mutate(model_building_sets = paste('vegtype',roi_type, sep='_'))

##########################
# Assign timeseries to each set. A timeseries can be in the 3
# broad catagories only once each.
ecoregion_set_assignments = ecoregions_sets %>%
  select(ecoregion, model_building_sets) %>%
  left_join(phenocam_sites, by=c('ecoregion')) %>%
  select(model_building_sets, timeseries_id)

ecoregions_vegtype_set_assignments = ecoregions_vegtype_sets %>%
  select(ecoregion, roi_type, model_building_sets) %>%
  left_join(phenocam_sites, by=c('ecoregion','roi_type')) %>%
  select(model_building_sets, timeseries_id)

vegtype_assignments = vegtype_sets %>%
  select(roi_type, model_building_sets) %>%
  left_join(phenocam_sites, by=c('roi_type')) %>%
  select(model_building_sets, timeseries_id)

# a model using all available sites
allsite_assignments = phenocam_sites %>%
  mutate(model_building_sets = 'allsites') %>%
  select(model_building_sets, timeseries_id)

all_assignments = ecoregion_set_assignments %>%
  bind_rows(ecoregions_vegtype_set_assignments) %>%
  bind_rows(vegtype_assignments) %>%
  bind_rows(allsite_assignments)

# Sanity check, each timeseries should not be represented > 4 times
x= all_assignments %>% count(timeseries_id) %>% pull(n)
if(any(x>4)) stop('some phenocam timeseries added more than 4 times')

#############################################
# A model building list to iterate over
model_building_set_list = ecoregions_vegtype_sets %>%
  bind_rows(ecoregions_sets) %>%
  bind_rows(vegtype_sets) %>%
  add_row(model_building_sets = 'allsites', n_phenocams = nrow(phenocam_sites), total_site_years = sum(phenocam_sites$site_years)) %>%
  select(model_building_sets, n_phenocams, total_site_years)


##############################################
write_csv(all_assignments, 'model_set_info/model_set_assignments.csv')
write_csv(model_building_set_list, 'model_set_info/model_sets.csv')