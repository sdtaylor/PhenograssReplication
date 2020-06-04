library(tidyverse)
library(kableExtra)

opts <- options(knitr.kable.NA = "")

primary_errors = read_csv('results/primary_error_table.csv') 

error_table_order = tribble(
  ~model_fitting_sets, ~row_label, ~row_order, 
   'allsites', 'All Sites',  1,          
   'ecoregion_ETempForests', 'E. Temperate Forests', 2,
   'ecoregion-vegtype_ETempForests_AG', 'Agriculture', 3,
   'ecoregion-vegtype_ETempForests_GR', 'Grasslands', 4,
   
   'ecoregion_GrPlains', 'Great Plains', 5,
   'ecoregion-vegtype_GrPlains_AG', 'Agriculture', 6,
   'ecoregion-vegtype_GrPlains_GR', 'Grasslands', 7,
   'ecoregion_NADeserts', 'N. American Deserts', 8,
   'ecoregion-vegtype_NADeserts_GR', 'Grasslands',9,
   'ecoregion-vegtype_NADeserts_SH', 'Shrublands',10,
   
   'ecoregion_NWForests', 'N.W. Forests', 11,
   'ecoregion-vegtype_NWForests_GR', 'Grasslands', 12,
   'vegtype_AG',                      'All Agriculture', 13,
   'vegtype_GR',                      'All Grasslands', 14,
   'vegtype_SH',                      'All Shrublands', 15,
)

cell_type_1 = c(2,5,8,11,13,14,15)

error_table = primary_errors %>%
  left_join(error_table_order, by=c('prediction_set'='model_fitting_sets')) %>%
  arrange(row_order) %>%
  mutate(row_label = cell_spec(row_label, 'latex', bold=(row_order %in% cell_type_1))) %>%
  select(row_label, allsites, ecoregion, vegtype,  `ecoregion-vegtype`)
  
# TODO: need cv errors in here for the 2 grassland models
table_column_names = c('','All Site Model','Ecoregion Model','Vegetation Model','Ecoregion+Vegetation Model')

kable(error_table, 'latex', col.names = table_column_names, escape = F) %>%
  add_indent(c(3,4,6,7,9,10,12))


##################################################################################################
# Supplemental table for site level errors

site_errors = read_csv('results/site_level_error_table.csv')
site_table_column_names = c('Ecoregion','Veg Type','Site','All Site Model','Ecoregion Level Model','Ecoregion+Vegetation Model','Vegetation Model')

site_error_table = site_errors %>%
  select(ecoregion_desc, veg_type = roi_type, phenocam_name, allsites, ecoregion, `ecoregion-vegtype`, vegtype) %>%
  sample_n(20)

kable(site_error_table, 'latex', col.names = site_table_column_names, escape = F) %>%
  column_spec(1, width = '40em')
