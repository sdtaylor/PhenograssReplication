library(daymetr)
library(tidyverse)

phenocam_sites = read_csv('site_list.csv')

get_daymet_data = function(lon,lat,phenocam_name){
  print(phenocam_name)
  download_output = daymetr::download_daymet(lat = lat, lon = lon,
                                             start = 2000, end = 2019,
                                             silent = T)
  
  df = download_output$data
  colnames(df) <- c('year','doy','daylength','precip','radiation','swe','tmax','tmin','vp')
  df$phenocam_name = phenocam_name
  
  return(df)
}

daymetr_output = purrr::pmap_dfr(phenocam_sites[,c('lon','lat','phenocam_name')], get_daymet_data)

write_csv(daymetr_output, './data/daymet_data.csv')
