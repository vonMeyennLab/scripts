#!/bin/bash
#BSUB -J "MethIn"

######################################################################################################################################################################################

# prepare the metilene input file using the metilene_input.pl script
/cluster/work/nme/software/apps/metilene/0.2-8/metilene_input.pl --in1 collapsed_output_01.bed --in2 collapsed_output_02.bed -b /cluster/work/nme/software/apps/bedtools/2.30.0/bedtools

######################################################################################################################################################################################
