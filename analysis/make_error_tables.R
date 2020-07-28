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

bold_row_titles = c(5,8,11,13,14,15)

error_table = primary_errors %>%
  full_join(error_table_order, by=c('fitting_set'='model_fitting_sets')) %>%
  arrange(row_order) %>%
  mutate(row_label = cell_spec(row_label, 'latex', bold=(row_order %in% bold_row_titles))) %>%
  mutate(r2 = cell_spec(r2, 'latex', bold=(r2>=0.65))) %>%
  mutate(r2 = ifelse(r2=='NA',NA,r2)) %>% # cell_spec is inserting literal NA here
  select(row_label, r2, rmse, n_timeseries, site_years)
  
# TODO: need cv errors in here for the 2 grassland models
table_column_names = c('','R\textsuperscript{2}','RMSE','Num. Sites','Site Years')

kable(error_table, 'latex', col.names = table_column_names, escape = F) %>%
  add_indent(c(6,7,9,10,12,13,15))


##################################################################################################
# Supplemental table for site level errors

site_info = read_csv('site_list.csv') %>%
   mutate(site_label = paste(phenocam_name, roi_type, sep='-')) %>%
   select(timeseries_id, site_label)

# Arrange the csv file from columns c('fitting_set','model','timeseries_id','rmse','r2') 
# to c('site_label','fitting_set','model1_r2','model1_rmse','model2_r2',...)

site_errors = read_csv('results/site_level_error_table.csv') %>% 
   filter(timeseries_id != 32) %>% # drop jasperridge roi2000 here while the new models run.
   mutate(model = recode(model, 'NaiveMAPCorrected' = 'Naive')) %>%
   left_join(site_info, by='timeseries_id') %>%
   select(fitting_set, model, rmse, r2, site_label) %>%
   gather(error_type, error_value, r2, rmse) %>%
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
   select(site_label, fitting_label, PhenoGrass_r2, PhenoGrass_rmse, Naive_r2, Naive_rmse) %>%
   arrange(site_label) %>%
   head(10)


site_table_column_names = c('Site','Model Scale','Phenograss','','Naive Model','')
# manual 2nd row to put in:     
#           &  & R\textsuperscript{2} & RMSE & R\textsuperscript{2} & RMSE \\

kable(site_error_table, 'latex', col.names = site_table_column_names, escape = F) %>%
   collapse_rows(columns = 1, valign = 'top')
