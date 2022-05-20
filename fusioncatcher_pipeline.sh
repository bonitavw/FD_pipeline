#!/bin/bash
#
#SBATCH --job-name=fusioncatcher
#SBATCH --output=fusioncatcher_pipeline.txt
#
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --time=5-00:00:00
#SBATCH --mem-per-cpu=32000


count=0

# loops through directory containing RNA-seq reads
for path in /scratch/13077201/RNA-seq/*;
do
  # if statement is true for every second read, so for every reverse read. This needs to be adjusted if there are more than 2 files per individual
  if [ ${count} -eq 1 ]
  then
    path=$(echo ${path} | cut -d '_' -f 1)
    filename=$(echo ${path} | cut -d '/' -f 5 | cut -d '_' -f 1)
    # runs fusioncatcher with two input files and writes it to a specified directory, containing the accession numer as name
    srun -n1 -w omics-cn003 fusioncatcher -d /scratch/13077201/FusionCatcherGenome/human_v102/ -i ${path}_1.fastq.gz,${path}_2.fastq.gz -o /scratch/13077201/FusionCatcherResults/FC_healthy_${path} --visualization-psl
    count=0
  else
    ((count+=1))
  fi
done

