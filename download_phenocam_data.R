library(phenocamr)


phenocam_sites = read_csv('site_list.csv')

failed_downloads = data.frame(site=NA, veg_type=NA)

for(i in 1:nrow(phenocam_sites)){
  download_attempt = try(download_phenocam(site = paste0(phenocam_sites$phenocam_name[i],'$'),
                    veg_type = paste0(phenocam_sites$roi_type[i]),
                    frequency = 3,
                    out_dir = './data/phenocam'))
  
  if(class(download_attempt) == 'try-error'){
    failed_downloads = failed_downloads %>%
      add_row(site=phenocam_sites$phenocam_name[i],
              veg_type = phenocam_sites$roi_type[i])
  }
}
