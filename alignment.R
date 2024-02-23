# Define the directory paths where the files are located
directory_paths <- c(
  "/gpfs/gibbs/pi/brennand/shared/projects/NDD/Novin/22SP01P8T1-1/RQ18781/NB22PE36/Sample_NB22PE36_095_098",
  "/gpfs/gibbs/pi/brennand/shared/projects/NDD/Novin/NB22TE28/RQ18269/2607-2_SNaP_Bestradiol_1/Sample_2607-2_SNaP_Bestradiol_1_208_369"
)

# Function to find R1 and R2 files in a directory
find_R1_R2_files <- function(directory_path) {
  # List all files in the directory
  all_files <- list.files(directory_path, full.names = TRUE)
  
  # Pattern to match R1 and R2 files
  pattern <- ".*_S\\d+_L\\d+_R(1|2)_001.fastq.gz$"
  
  # Filter R1 and R2 files
  R1_files <- grep(pattern, all_files, value = TRUE)
  R2_files <- gsub("_R1_", "_R2_", R1_files)
  
  # Return a list of R1 and R2 files
  list(R1 = R1_files, R2 = R2_files)
}

# List to store R1 and R2 files from all directory paths
all_R1_files <- list()
all_R2_files <- list()

# Loop through each directory path
for (path in directory_paths) {
  # Find R1 and R2 files in the directory
  files <- find_R1_R2_files(path)
  
  # Add R1 and R2 files to the lists
  all_R1_files <- c(all_R1_files, files$R1)
  all_R2_files <- c(all_R2_files, files$R2)
}

# Print the list of R1 files
print(all_R1_files)

# Print the list of R2 files
print(all_R2_files)
