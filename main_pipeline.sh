#!/bin/bash
#
#SBATCH --job-name=pipeline
#SBATCH --output=pipeline.txt
#
#SBATCH --ntasks=1
#SBATCH --array=0-6

# change this to your own directory in /scratch
WD="/scratch/13077201/"
mkdir -p $WD
cd $WD

# fill in your own (WGS) sample names, seperated by a whitespace, without their forward or reverse status (_1, _2) 
SAMPLES=("ERR1861322" "ERR1861331" "ERR1861337" "ERR1861377" "ERR1871973" "ERR1882671")


### Pre-Processing WGS data ### 

# Quality control
# Tool: FastQC
srun fastqc /WGS/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_1.fastq.gz
srun fastqc /WGS/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_2.fastq.gz


# Trimming
# Tool: Trimmomatic
# Settings: the reads are trimmed using a sliding window of 4 with a threshold quality of 20, minimum length is 30 and leading and trailing threshold quality of 3
srun trimmomatic PE -threads 4 /scratch/13077201/WGS/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_1.fastq.gz /scratch/13077201/WGS/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_2.fastq.gz \
  /scratch/13077201/WGS/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_1P.fastq.gz /scratch/13077201/WGS/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_1U.fastq.gz \
  /scratch/13077201/WGS/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_2P.fastq.gz /scratch/13077201/WGS/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_2U.fastq.gz \
  ILLUMINACLIP:/home/13077201/personal/miniconda3/share/trimmomatic-0.39-2/adapters/TruSeq3-PE-2.fa:2:30:10 \
  LEADING:3 TRAILING:3 SLIDINGWINDOW:4:20 MINLEN:30
  
  
# Quality control on trimmed samples
# Tool: FastQC
srun fastqc /WGS/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_1P.fastq.gz
srun fastqc /WGS/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_2P.fastq.gz


# Index reference genome
# Tool: bwa
# Comment: change the file name to the preferred reference genome, must be downloaded and located in the /ref_genome/ directory
srun gunzip /ref_genome/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz
srun bwa index /ref_genome/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna

# Mapping
# Tool: bwa 
# Settings: only the trimmed, paired reads (output of trimmomatic) are mapped to the reference genome
srun bwa mem /ref_genome/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna \
  /WGS/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_1P.fastq.gz /WGS/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_2P.fastq.gz > /WGS/SAM/${SAMPLES[$SLURM_ARRAY_TASK_ID]}.sam


### Variant Calling ###

# SAM to BAM
# Tool: Samtools
# Settings: the -b option specifies that the output must be in a .bam format, -S is required (depending on the version of Samtools) if the input is in SAM format
srun samtools view -S -b /WGS/SAM/${SAMPLES[$SLURM_ARRAY_TASK_ID]}.sam > /WGS/BAM/${SAMPLES[$SLURM_ARRAY_TASK_ID]}.bam

# Sort BAM file
# Tool: Samtools
srun samtools sort /WGS/BAM/${SAMPLES[$SLURM_ARRAY_TASK_ID]}.bam -o /WGS/BAM/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_sorted.bam

# Create pileup
# Tool: Samtools
srun samtools mpileup -B -ugf /ref_genome/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna \
  /WGS/BAM/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_sorted.bam | bcftools call -mv -o /WGS/Alignment/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_alignment.vcf

# Create consensus
# Tool: Samtools
srun samtools mpileup -B -ugf /ref_genome/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna \
  /WGS/BAM/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_sorted.bam | bcftools call -c | vcfutils.pl vcf2fq > /WGS/Consensus/${SAMPLES[$SLURM_ARRAY_TASK_ID]}_consensus.fq


### Fusion analysis ###

# Tool: FusionCatcher
# Comment: this command will link to a file, in which the FusionCatcher tool will be run and RNA seq data will be analysed. You will need to edit this file since it is strongly dependent on the sample names
srun fusioncatcher_pipeline.sh



