## How to get from FastQ files to Counts using Rsubread


# load required libraries in R 
library(Rsubread)
library(dplyr)


# 1. build index
# here, you need a .fa file that is your index/reference file for alignment. This can be downloaded from UCSC Genome website 
# "basename" is just what you want to call the output file of your index.
buildindex(basename="hg38_index",reference="/sc/arion/projects/psychgen/HUCKINS_LAB_DONT_DELETE/resources/bulkRNA_alignment/hg38.fa.gz")

# 2. align
# to run this as a job, save the code as a file (ie: align.R) then use the code at the bottom to submit it as a job. 
# note that the beginning process before the if/else here is subject on the structure of your directories. You may have to change it depending on how your files are laid out

# align.R ======================

# load required libraries in R
library(Rsubread)
library(dplyr)

# set the R script to take arguments from the command line
args <- commandArgs(trailingOnly=TRUE) 
i <- as.numeric(as.character(args[1]))  # i is going to be the number of the file in your directory (ie: first file in directory i=1)


index_dir <- "/sc/arion/projects/psychgen/collab/hiPSC_SCZ_PRS_RNAseq/FURIN_edited_RNAseq/"  # this is the path where your index file is
project_dir <- "/sc/arion/projects/psychgen/collab/hiPSC_SCZ_PRS_RNAseq/FURIN_edited_RNAseq/full_cohort/Project_Kd679/" # this is the path where your input files lie
output_dir <- "/sc/arion/projects/psychgen/collab/hiPSC_SCZ_PRS_RNAseq/FURIN_edited_RNAseq/full_cohort/bam_files/" # this is where you want your aligned files to go

samples <- list.files(project_dir)  # loads all of the names of the input files

input <- list.files(paste0(project_dir,samples[i]))  # loads the name of only the sample you're running here 

# get samples that have been completed
done_samples <- list.files(output_dir) 
done_samples <- done_samples[grepl(".summary", done_samples)] 
done_samples <- gsub(".bam.summary", "", done_samples)

# check if sample to run has already been completed. If it has, don't run alignment again.
if (samples[i] %in% done_samples) {
	print("Sample already completed")

} else {  # align samples that have not been completed
	align(index=paste0(index_dir, "hg38_index"),
	readfile1=paste0(project_dir,samples[i],"/",input[1]),  # 2 readfiles due to paired-end sequencing. Here, the two inputs are in the same directory, named for the sample name
	readfile2=paste0(project_dir,samples[i],"/",input[2]),
	type="dna", 
	output_file=paste0(output_dir, samples[i], ".bam"),
	minFragLength=50,
	maxFragLength=600)
}



# to run the above code on the command line as a job
ml R

for i in {1..121}
do
bsub -q long -P acc_psychgen -n 1 -W 100:00 -R rusage[mem=80000] -J align -o ./scratch/align.out -e ./scratch/align.err "Rscript align.R $i"
done




# 3. generate read counts
# generate_counts.R ====================

# load required libraries
library(Rsubread)
library(dplyr)

# set the R script to take arguments from the command line
args <- commandArgs(trailingOnly=TRUE) 
i <- as.numeric(as.character(args[1])) # i is going to be the number of the file in your directory (ie: first file in directory i=1)

project_dir <- "/sc/arion/projects/psychgen/collab/hiPSC_SCZ_PRS_RNAseq/FURIN_edited_RNAseq/full_cohort/bam_files/" # this is the path where your input files lie
output_dir <- "/sc/arion/projects/psychgen/collab/hiPSC_SCZ_PRS_RNAseq/FURIN_edited_RNAseq/full_cohort/read_counts/" # this is where you want your read counts to go

samples <- list.files(project_dir) # loads all of the names of the input files
samples <- sub(".indel.vcf", "", samples)
samples <- sub(".summary", "", samples)
samples <- unique(samples)
samples <- samples[-122]  # I had a directory name in my list of files so this was just to get rid of it (you can remove this line if doesn't apply)

sample_name <- sub(".bam", "", samples[i]) # get rid of ".bam" in sample name

# check if it's been completed yet
done_samples <- list.files(output_dir)
done_samples <- gsub("_count_matrix.txt", "", done_samples)


if (samples[i] %in% done_samples) {
	print("Sample already completed")

} else {
	count_matrix <- featureCounts(files=paste0(project_dir, samples[i]),
	annot.inbuilt="hg38",
	useMetaFeatures=TRUE,
	allowMultiOverlap=FALSE,
	largestOverlap=TRUE,
	countMultiMappingReads=TRUE,
	isPairedEnd=TRUE)

	# extract counts from output
	x <- data.frame(count_matrix$annotation[c("GeneID","Length")],
		count_matrix$counts)
	# save the counts
	write.table(x, paste0(output_dir,sample_name,"_count_matrix.txt"), row.names=F, quote=F)
}


# submit above R code as a job
ml R

for i in {1..121}
do
bsub -q long -P acc_psychgen -n 1 -W 200:00 -R rusage[mem=80000] -J generate_counts -o ./scratch/generate_counts.out -e ./scratch/generate_counts.err "Rscript generate_counts.R $i"
done





## 4. Make nice count file 

#Add count files from each sample all together (on command line)

# subset for all counts in file
for i in `find . -name "*.txt" -type f`; do     awk {'print $3'} "$i" > "$i".raw; done       


paste -d "\t" Sample*.txt.raw > RawCountMatrix.txt            # creates a big matrix


awk {'print $1'} Sample_G13_143_050_count_matrix.txt > GeneSymbolsMatrix.txt     # pick up the gene symbols in the final raw count matrix

paste -d "\t" *Matrix* > RawCountMatrix_final.txt            # creates a big matrix


# make column names not ridiculous (replace .bam with whatever you want to replace)
sed -i -e 's/.bam//g' RawCountMatrix_final.txt 


# map GeneID to actual gene name (using R)
library(tidyverse)
library(data.table)

counts <- data.frame(fread("RawCountMatrix_final.txt"))
anno <- read.csv("/sc/arion/projects/psychgen/collab/wtc_biomarkers/eQTL/anno.csv")  # message Carina for this file if you don't already have it
anno <- anno[,c(10,14)]
colnames(anno) <- c("Gene_name", "GeneID")
counts <- merge(anno, counts, by="GeneID")
write.table(counts, "Count_Matrix_Annotated.txt", quote=F, row.names=F)


