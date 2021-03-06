#
# the general tinkering script
#
setwd("/temp/SRA-data/HMP/")
library(SRAdb)
library(stringr)
library(RCurl)
sqlfile <- "/users/222935/data/SRAmetadb.sqlite"
sra_con <- dbConnect(dbDriver("SQLite"), sqlfile)
#
#
library(data.table)
hmp_data <- fread("/users/222935/data/HMASM.csv")
# since the table contains only experiment ids (i.e. SRS), get runs ids and all other info...
hmp_runs = listSRAfile( c(hmp_data$`SRS ID`), sra_con, fileType = 'sra', srcType = "fasp" )
#
#
library(dplyr)
# filter only WGS data using the study id "SRP002163"
hmp_runs <- filter(hmp_runs, study == "SRP002163")
#
#

#
# ASCP command
#
ascpCMD <-
  "/users/222935/.aspera/connect/bin/ascp -i /users/222935/.aspera/connect/etc/asperaweb_id_dsa.openssh -QT -l 300m"
#
# download cycle
#
skip <- TRUE
counter <- 1
for (f in hmp_runs$run) {
  if (f == "SRR059895") {
    skip <<- FALSE
  }
  if (skip) {
    counter <- counter + 1
    next
  }
  print(paste(
    "Run ", counter, " of ", length(hmp_runs$run), ": ", f,
    "; current time: ", format(Sys.time(), "%D %H:%M:%S"), sep = ""
  ))

  if (0 == length(list.files(path = ".", pattern = paste("^",f,".*sra$",sep =
                                                         "")))) {
    res <- try(getFASTQfile(f, sra_con, srcType = "fasp", ascpCMD = ascpCMD))

    if ("try-error" %in% class(res)) {
      print(paste(res))
      res <-
        try(getSRAfile(f, sra_con = sra_con, destDir = getwd(),
                       method = "wget", fileType = "sra"))

      if ("try-error" %in% class(res)) {
        print(paste(res))
      }else{
        #system(paste("fastq-dump --split-files --gzip ",f,".sra",sep = ""))
      }
    }

    Sys.sleep(3)

  }else{

    print(paste("Run ",f," found...", sep = ""))
    existing_size <- file.info(paste(f, ".sra", sep = ""))$size
    row <- hmp_runs[hmp_runs$run == f, ]
    url <- gsub("anonftp@", "ftp://", row$fasp)
    rs <- getURL(url, nobody = 1L, header = 1L)
    rs_list <- base::strsplit(rs, "\r\n")
    remote_size <- as.numeric(str_match(rs_list[[1]][1], "\\d+"))
    print(paste("remote size:", remote_size, ", local size:", existing_size))
    if (existing_size != remote_size ) {
      print(paste(" *** REDOWNLOADING..."))
      res <- try(getSRAfile(f, sra_con = sra_con, destDir = getwd(),
                 method = "wget", fileType = "sra"))
      if ("try-error" %in% class(res)) {
        print(paste(res))
      }
    }

    Sys.sleep(3)
  }

  counter <- counter + 1

}


#
res = as.data.frame( listSRAfile( "SRR062326", sra_con, fileType = 'sra', srcType = "fasp" ) )

for (f in rs$run) {
  print(paste(
    "Run ",f,"; current time: ",format(Sys.time(), "%D %H:%M:%S"),sep = ""
  ))

  if (0 != length(list.files(path = ".", pattern = paste("^",f,".*sra$",sep =
                                                         "")))) {

    if (0 == length(list.files(path = ".", pattern = paste("^",f,".*fastq.gz$",sep =
                                                           "")))) {
        system(paste("fastq-dump --split-files --gzip ",f,".sra",sep = ""))
    }

    info = listSRAfile( f, sra_con, fileType = 'sra', srcType = "fasp" )

    res = rbind( res, info )
  }

}
