library(phenocamr)


phenocam_sites = read_csv('site_list.csv')


for(i in 1:nrow(phenocam_sites)){
  download_phenocam(site = paste0(phenocam_sites$site[i],'$'),
                    veg_type = paste0(phenocam_sites$roitype[i]),
                    frequency = 3,
                    out_dir = './data/phenocam')
}
