$#!/bin/bash
#BSUB -J "F5Subset"
#BSUB -R "select[nthreads==2]"
#BSUB -n 12 

############################################################################################################################################

bsub -n 20 'ls | parallel -n300 mkdir fast5_{#}\;mv {} fast5_{#}'

############################################################################################################################################
