#!/bin/bash
#BSUB -J "Mega004[1-9]%9"                               #Array Job with 9 subjobs = [1-9], 9 jobs can run in parallel = %9
#BSUB -R "rusage[mem=12000,ngpus_excl_p=1]"             #Request 12 GB per gpu
#BSUB -R "select[gpu_model0==NVIDIAGeForceRTX2080Ti]"   #Specify the GPU type
#BSUB -R "select[nthreads==2]"                          #Use only nodes where hyper-threading is activated = 1 core = 2 threads = 2 processes (basecaller)
#BSUB -R "rusage[scratch=5000]"                         #Use 5G scratch - might not be needed for array jobs
#BSUB -n 12                                             #Requesting 12 cores
#BSUB -W 12:00                                          #Send job to the 24h queue with 12h run time

########################################################################################################################

# Load required modules
module load megalodon

########################################################################################################################

# Get the internal job index variable (ArraySize)
IDX=$LSB_JOBINDEX

########################################################################################################################

# Run megalodon = basecalling, mapping, methylation calling (BAM with 5mC Info, bedMethyl)
megalodon \
 /cluster/work/nme/data/pascal/HM27/0h/20210819_SEQ0004/fast5/fast5_${IDX} \
 --guppy-server-path /cluster/work/nme/software/apps/guppy_gpu/6.0.1/bin/guppy_basecall_server \
 --outputs basecalls mappings mod_mappings mods per_read_mods \
 --mod-output-formats bedmethyl \
 --reference $WORK/data/pascal/ont_genomes/ncbi/human/GRCh38/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna \
 --mod-motif m CG 0 \
 --devices 0 \
 --processes 24 \
 --guppy-timeout 100 \
 --guppy-concurrent-reads 8 \
 --mappings-format bam \
 --basecalls-format fastq \
 --overwrite \
 --output-directory /cluster/work/nme/data/pascal/HM27/0h/20210819_SEQ0004/megalodon_out_SEQ004_${IDX}

########################################################################################################################
