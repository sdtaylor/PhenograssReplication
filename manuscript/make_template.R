# load required R extension packages:
library("rticles")
library("rmarkdown")

# create a new document using a template: 
rmarkdown::draft(file = "manuscript",
                 template = "copernicus_article",
                 package = "rticles", edit = FALSE)

# render the source of the document to the default output format:
rmarkdown::render(input = "manuscript/manuscript.Rmd")
