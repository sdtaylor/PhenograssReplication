library(tidyverse)
library(kableExtra)

opts <- options(knitr.kable.NA = "")

primary_errors = read_csv('results/primary_error_table.csv') 

error_table_order = tribble(
  ~model_fitting_sets, ~row_label, ~row_order, 
   'allsites', 'All Sites',  1,          
   'vegtype_AG', 'All Agriculture', 2,
   'vegtype_GR', 'All Grasslands', 3,
   'vegtype_SH', 'All Shrublands', 4,
  
   'ETempForests', 'E. Temperate Forests', 5,
   'ecoregion-vegtype_ETempForests_AG', 'Agriculture', 6,
   'ecoregion-vegtype_ETempForests_GR', 'Grasslands', 7,
   
   'GrPlains', 'Great Plains', 8,
   'ecoregion-vegtype_GrPlains_AG', 'Agriculture', 9,
   'ecoregion-vegtype_GrPlains_GR', 'Grasslands', 10,
  
   'NADeserts', 'N. American Deserts', 11,
   'ecoregion-vegtype_NADeserts_GR', 'Grasslands',12,
   'ecoregion-vegtype_NADeserts_SH', 'Shrublands',13,
   
   'NWForests', 'N.W. Forests', 14,
   'ecoregion-vegtype_NWForests_GR', 'Grasslands', 15,

)

bold_row_titles = c(5,8,11,14)

error_table = primary_errors %>%
  full_join(error_table_order, by=c('fitting_set'='model_fitting_sets')) %>%
  arrange(row_order) %>%
  mutate(row_label = cell_spec(row_label, 'latex', bold=(row_order %in% bold_row_titles))) %>%
  mutate(nse = cell_spec(nse, 'latex', bold=(nse>=0.65))) %>%
  mutate(nse = ifelse(nse=='NA',NA,nse)) %>% # cell_spec is inserting literal NA here
  select(row_label, nse, mean_cvmae, n_timeseries, site_years)
  
# TODO: need cv errors in here for the 2 grassland models
table_column_names = c('','NSE','F','Num. Sites','Site Years')

kable(error_table, 'latex', col.names = table_column_names, escape = F) %>%
  add_indent(c(6,7,9,10,12,13,15))


##################################################################################################
# Supplemental table for site level errors

ecoregion_info = read_csv('model_fitting_set_info/ecoregion_codes.csv') %>%
   select(ecoregion, ecoregion_abbr)

site_info = read_csv('site_list.csv') %>%
   mutate(phenocam_name = str_remove(phenocam_name, '.DP1.00033')) %>% # Shorten those long neon names
   mutate(phenocam_name = str_remove(phenocam_name, '.DP1.20002')) %>%
   mutate(site_label = paste(phenocam_name, roi_type, sep=' - ')) %>%
   left_join(ecoregion_info, by='ecoregion') %>%
   select(timeseries_id, site_label, ecoregion_abbr)

# Arrange the csv file from columns c('fitting_set','model','timeseries_id','cvmae','nse') 
# to c('site_label','fitting_set','model1_nse','model1_cvmae','model2_nse',...)

site_errors = read_csv('results/site_level_error_table.csv') %>% 
   filter(timeseries_id != 32) %>% # drop jasperridge roi2000 here while the new models run.
   mutate(model = recode(model, 'NaiveMAPCorrected' = 'Naive')) %>%
   left_join(site_info, by='timeseries_id') %>%
   select(fitting_set, model, cvmae, nse, site_label, ecoregion_abbr) %>%
   gather(error_type, error_value, nse, cvmae) %>%
   mutate(error_value = round(error_value,2)) %>%
   unite(error_label, model, error_type) %>%
   spread(error_label, error_value)

fitting_set_labels = tribble(
   ~fitting_set, ~fitting_label,
   'allsites', 'All Sites', 
   'vegtype_AG', 'All Agriculture', 
   'vegtype_GR', 'All Grasslands', 
   'vegtype_SH', 'All Shrublands', 
   'ecoregion-vegtype_ETempForests_AG', 'E. Temp. Agriculture',
   'ecoregion-vegtype_ETempForests_GR', 'E. Temp. Grasslands', 

   'ecoregion-vegtype_GrPlains_AG', 'Gr. Plains Agriculture', 
   'ecoregion-vegtype_GrPlains_GR', 'Gr. Plains Grasslands', 
   
   'ecoregion-vegtype_NADeserts_GR', 'NA Deserts Grasslands',
   'ecoregion-vegtype_NADeserts_SH', 'NA Deserts Shrublands',
   
   'ecoregion-vegtype_NWForests_GR', 'NW Forests Grasslands'
)

site_error_table = site_errors %>%
   left_join(fitting_set_labels, by='fitting_set') %>%
   select(ecoregion_abbr, site_label, fitting_label, PhenoGrass_nse, PhenoGrass_cvmae, Naive_nse, Naive_cvmae) %>%
   arrange(ecoregion_abbr, site_label) 

# put in blanks so each ecoregion and site are only listed on their first respective row\
make_blanks = function(x){
   current_x = x[1]
   for(i in 2:length(x)){
      if(x[i] == current_x){
         x[i] = NA
      } else {
         current_x = x[i]
      }
   }
   return(x)
}

site_error_table$ecoregion_abbr = make_blanks(site_error_table$ecoregion_abbr)
site_error_table$site_label = make_blanks(site_error_table$site_label)


site_table_column_names = c('Ecoregion','Site','Model Scale','Phenograss','','Naive Model','')
# manual 2nd row to put in:     
#          & &  & R\textsuperscript{2} & RMSE & R\textsuperscript{2} & RMSE \\

kable(site_error_table, 'latex', col.names = site_table_column_names, escape = F) 

