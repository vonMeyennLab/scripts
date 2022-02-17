#!/bin/bash
#BSUB -J "Bsort013[1-5]%5"
#BSUB -R "rusage[mem=7168]"

########################################################################################################################

# Get the internal job index variable (ArraySize)
IDX=$LSB_JOBINDEX

########################################################################################################################

sort -k1V -k2n /cluster/work/nme/data/pascal/HM27/24h/20220216_SEQ0013/megalodon_out_SEQ013_${IDX}/modified_bases.5mC.bed > /cluster/work/nme/data/pascal/HM27/24h/20220216_SEQ0013/megalodon_out_SEQ013_${IDX}/modified_$

########################################################################################################################
