library(tidyverse)

######################################
# Put together the different aggregations of phenocam timeseries to model
# for example only grasslands, only grassland in the Grain Plains ecoregions, etc.
#
######################################

min_sites_needed = 5

phenocam_sites = read_csv('site_list.csv') %>%
  filter(has_processed_data) 

ecoregion_codes = read_csv('model_fitting_set_info/ecoregion_codes.csv')

##########################

ecoregions_vegtype_sets = phenocam_sites %>%
  group_by(ecoregion, roi_type) %>%
  summarise(n_phenocams = n(),
            total_site_years = sum(site_years)) %>%
  ungroup() %>%
  filter(n_phenocams>=min_sites_needed) %>%
  left_join(ecoregion_codes, by='ecoregion') %>%
  mutate(model_fitting_sets = paste('ecoregion-vegtype',ecoregion_abbr,roi_type,sep='_')) %>%
  mutate(model_fitting_scale = 'ecoregion-vegtype')

vegtype_sets = phenocam_sites %>%
  group_by(roi_type) %>%
  summarise(n_phenocams = n(),
            total_site_years = sum(site_years)) %>%
  ungroup() %>%
  filter(n_phenocams>=min_sites_needed) %>%
  mutate(model_fitting_sets = paste('vegtype',roi_type, sep='_')) %>%
  mutate(model_fitting_scale = 'vegtype')

##########################
# Assign timeseries to each set. A timeseries can be in the 3
# broad catagories only once each.

ecoregions_vegtype_set_assignments = ecoregions_vegtype_sets %>%
  select(ecoregion, roi_type, model_fitting_sets) %>%
  left_join(phenocam_sites, by=c('ecoregion','roi_type')) %>%
  select(model_fitting_sets, timeseries_id)

vegtype_assignments = vegtype_sets %>%
  select(roi_type, model_fitting_sets) %>%
  left_join(phenocam_sites, by=c('roi_type')) %>%
  select(model_fitting_sets, timeseries_id)

# a model using all available sites
allsite_assignments = phenocam_sites %>%
  mutate(model_fitting_sets = 'allsites') %>%
  select(model_fitting_sets, timeseries_id)

all_assignments = allsite_assignments %>%
  bind_rows(vegtype_assignments) %>%
  bind_rows(ecoregions_vegtype_set_assignments)

# Sanity check, each timeseries should not be represented > 3 times
x= all_assignments %>% count(timeseries_id) %>% pull(n)
if(any(x>3)) stop('some phenocam timeseries added more than 3 times')

#############################################
# A model building list to iterate over
model_building_set_list = ecoregions_vegtype_sets %>%
  bind_rows(vegtype_sets) %>%
  add_row(model_fitting_sets = 'allsites',model_fitting_scale='allsites', n_phenocams = nrow(phenocam_sites), total_site_years = sum(phenocam_sites$site_years)) %>%
  select(model_fitting_sets,model_fitting_scale, n_phenocams, total_site_years)


##############################################
write_csv(all_assignments, 'model_fitting_set_info/fitting_set_assignments.csv')
write_csv(model_building_set_list, 'model_fitting_set_info/fitting_sets.csv')
