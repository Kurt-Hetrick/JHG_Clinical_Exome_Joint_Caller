# ---qsub parameter settings---
# --these can be overrode at qsub invocation--

# tell sge to execute in bash
#$ -S /bin/bash

# tell sge that you are in the users current working directory
#$ -cwd

# tell sge to export the users environment variables
#$ -V

# tell sge to submit at this priority setting
#$ -p -10

# tell sge to output both stderr and stdout to the same file
#$ -j y

# export all variables, useful to find out what compute node the program was executed on

	set

	echo

# INPUT VARIABLES

	ALIGNMENT_CONTAINER=$1
	CORE_PATH=$2

	PROJECT=$3
	OUTPUT_DIR=$4
	FAMILY=$5
	SM_TAG=$6
	FATHER=$7
	MOTHER=$8
	GENDER=$9
	PHENOTYPE=${10}
	GIT_LFS_VERSION=${11}

##########################################################################################
##### Grabbing the BAM header (for RG ID,PU,LB,etc) ######################################
##########################################################################################
##### THIS IS THE HEADER #################################################################
##### "PROJECT","SM_TAG","PLATFORM_UNIT","LIBRARY_NAME","PIPELINE_VERSION" ###############
##### "PIPELINE_FILES_VERSION","FAMILY","FATHER","MOTHER","EXPECTED_SEX","PHENOTYPE" #####
##########################################################################################

	if
		[ -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/RG_HEADER/${SM_TAG}.RG_HEADER.txt ]
	then
		cat ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/RG_HEADER/${SM_TAG}.RG_HEADER.txt \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				-s \
				-g 1,2 \
				collapse 3 \
				unique 4 \
				unique 5 \
			| sed 's/,/;/g' \
			| awk 'BEGIN {OFS="\t"} \
				{print $0 , "ddl-ngs-main-" "'${GIT_LFS_VERSION}'" , "'${FAMILY}'" , "'${FATHER}'" , "'${MOTHER}'" , "'${GENDER}'" , "'${PHENOTYPE}'"}' \
			| awk 'BEGIN {OFS="\t"} \
				$10=="1" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,"MALE",$11} \
				$10=="2" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,"FEMALE",$11} \
				$10!="1"&&$10!="2" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,"UNKNOWN",$11}' \
			| awk 'BEGIN {OFS="\t"} \
				$11=="-9" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,"MISSING"} \
				$11=="0" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,"MISSING"} \
				$11=="1" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,"UNAFFECTED"} \
				$11=="2" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,"AFFECTED"}' \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
		>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	elif
		[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/RG_HEADER/${SM_TAG}.RG_HEADER.txt && \
			-f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/CRAM/${SM_TAG}.cram ]];
	then

		# grab field number for SM_TAG

			SM_FIELD=(`singularity exec ${ALIGNMENT_CONTAINER} samtools \
				view -H \
			${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/CRAM/${SM_TAG}.cram \
				| grep -m 1 ^@RG \
				| sed 's/\t/\n/g' \
				| cat -n \
				| sed 's/^ *//g' \
				| awk '$2~/^SM:/ {print $1}'`)

		# grab field number for PLATFORM_UNIT_TAG

			PU_FIELD=(`singularity exec ${ALIGNMENT_CONTAINER} samtools \
				view -H \
			${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/CRAM/${SM_TAG}.cram \
				| grep -m 1 ^@RG \
				| sed 's/\t/\n/g' \
				| cat -n \
				| sed 's/^ *//g' \
				| awk '$2~/^PU:/ {print $1}'`)

		# grab field number for LIBRARY_TAG

			LB_FIELD=(`singularity exec ${ALIGNMENT_CONTAINER} samtools \
				view -H \
			${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/CRAM/${SM_TAG}.cram \
				| grep -m 1 ^@RG \
				| sed 's/\t/\n/g' \
				| cat -n \
				| sed 's/^ *//g' \
				| awk '$2~/^LB:/ {print $1}'`)

		# grab field number for PROGRAM_TAG

			PG_FIELD=(`singularity exec ${ALIGNMENT_CONTAINER} samtools \
				view -H \
			${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/CRAM/${SM_TAG}.cram \
				| grep -m 1 ^@RG \
				| sed 's/\t/\n/g' \
				| cat -n \
				| sed 's/^ *//g' \
				| awk '$2~/^PG:/ {print $1}'`)

		# Now grab the header and format
			# fill in empty fields with NA thing (for loop in awk) is a lifesaver
			# https://unix.stackexchange.com/questions/53448/replacing-missing-value-blank-space-with-zero

				singularity exec ${ALIGNMENT_CONTAINER} samtools \
					view -H \
				${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/CRAM/${SM_TAG}.cram \
					| grep ^@RG \
					| awk \
						-v SM_FIELD="$SM_FIELD" \
						-v PU_FIELD="$PU_FIELD" \
						-v LB_FIELD="$LB_FIELD" \
						-v PG_FIELD="$PG_FIELD" \
						'BEGIN {OFS="\t"} \
						{split($SM_FIELD,SMtag,":"); \
						split($PU_FIELD,PU,":"); \
						split($LB_FIELD,Library,":"); \
						split($PG_FIELD,Pipeline,":"); \
						print "'${PROJECT}'",SMtag[2],PU[2],Library[2],Pipeline[2]}' \
					| awk 'BEGIN { FS = OFS = "\t" } \
						{ for(i=1; i<=NF; i++) if($i ~ /^ *$/) $i = "NA" }; 1' \
					| singularity exec ${ALIGNMENT_CONTAINER} datamash \
						-s \
						-g 1,2 \
						collapse 3 \
						unique 4 \
						unique 5 \
					| sed 's/,/;/g' \
					| awk 'BEGIN {OFS="\t"} \
						{print $0 , "ddl-ngs-main-" "'${GIT_LFS_VERSION}'" , "'${FAMILY}'" , "'${FATHER}'" , "'${MOTHER}'" , "'${GENDER}'" , "'${PHENOTYPE}'"}' \
					| awk 'BEGIN {OFS="\t"} \
						$10=="1" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,"MALE",$11} \
						$10=="2" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,"FEMALE",$11} \
						$10!="1"&&$10!="2" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,"UNKNOWN",$11}' \
					| awk 'BEGIN {OFS="\t"} \
						$11=="-9" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,"MISSING"} \
						$11=="0" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,"MISSING"} \
						$11=="1" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,"UNPHENOTYPE"} \
						$11=="2" {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,"PHENOTYPE"}' \
					| singularity exec ${ALIGNMENT_CONTAINER} datamash \
						transpose \
				>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	else
		echo -e "${PROJECT}\t${SM_TAG}\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA" \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
		>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

#################################################
##### GENDER CHECK FROM ANEUPLOIDY CHECK ########
#################################################
##### THIS IS THE HEADER ########################
##### X_AVG_DP,X_NORM_DP,Y_AVG_DP,Y_NORM_DP #####
#################################################

	awk 'BEGIN {OFS="\t"} \
		$2=="X"&&$3=="whole" {print "X",$6,$7} \
		$2=="Y"&&$3=="whole" {print "Y",$6,$7}' \
	${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/ANEUPLOIDY_CHECK/${SM_TAG}.chrom_count_report.txt \
		| paste - - \
		| awk 'BEGIN {OFS="\t"} \
			END {if ($1=="X"&&$4=="Y") print $2,$3,$5,$6 ; \
			else if ($1=="X"&&$4=="") print $2,$3,"NaN","NaN" ; \
			else if ($1=="Y"&&$4=="") print "NaN","NaN",$5,$6 ; \
			else print "NaN","NaN","NaN","NaN"}' \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
	>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

#############################################################################################
##### VERIFY BAM ID #########################################################################
#############################################################################################
##### THIS IS THE HEADER ####################################################################
##### "VERIFYBAM_FREEMIX_PCT","VERIFYBAM_#SNPS","VERIFYBAM_FREELK1","VERIFYBAM_FREELK0" #####
##### "VERIFYBAM_DIFF_LK0_LK1","VERIFYBAM_AVG_DP" ###########################################
#############################################################################################

	if
		[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/VERIFYBAMID/${SM_TAG}.selfSM ]]
	then
		echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		awk 'BEGIN {OFS="\t"} \
			NR>1 \
			{print $7*100,$4,$8,$9,($9-$8),$6}' \
		${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/VERIFYBAMID/${SM_TAG}.selfSM \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

####################################################################################
##### INSERT SIZE ##################################################################
####################################################################################
##### THIS IS THE HEADER ###########################################################
##### "MEDIAN_INSERT_SIZE","MEAN_INSERT_SIZE","STANDARD_DEVIATION_INSERT_SIZE" #####
####################################################################################

	if
		[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/INSERT_SIZE/METRICS/${SM_TAG}.insert_size_metrics.txt ]]
	then
		echo -e NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		awk 'BEGIN {OFS="\t"} \
			NR==8 \
			{print $1,$6,$7}' \
		${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/INSERT_SIZE/METRICS/${SM_TAG}.insert_size_metrics.txt \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

##########################################################################
##### ALIGNMENT SUMMARY METRICS FOR READ 1 ###############################
##########################################################################
##### THIS THE HEADER ####################################################
##### "PCT_PF_READS_ALIGNED_R1","PF_HQ_ALIGNED_READS_R1" #################
##### "PF_MISMATCH_RATE_R1","PF_HQ_ERROR_RATE_R1","PF_INDEL_RATE_R1" #####
##### "PCT_READS_ALIGNED_IN_PAIRS_R1","PCT_ADAPTER_R1" ###################
##########################################################################

	if
		[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/ALIGNMENT_SUMMARY/${SM_TAG}.alignment_summary_metrics.txt ]]
	then
		echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		awk 'BEGIN {OFS="\t"} \
			NR==8 \
			{if ($1=="UNPAIRED") print "0","0","0","0","0","0","0"; \
			else print $7*100,$9,$13,$14,$15,$18*100,$24*100}' \
		${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/ALIGNMENT_SUMMARY/${SM_TAG}.alignment_summary_metrics.txt \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

##########################################################################
##### ALIGNMENT SUMMARY METRICS FOR READ 2 ###############################
##########################################################################
##### THIS THE HEADER ####################################################
##### "PCT_PF_READS_ALIGNED_R2","PF_HQ_ALIGNED_READS_R2" #################
##### "PF_MISMATCH_RATE_R2","PF_HQ_ERROR_RATE_R2","PF_INDEL_RATE_R2" #####
##### "PCT_READS_ALIGNED_IN_PAIRS_R2","PCT_ADAPTER_R2" ###################
##########################################################################

	if
		[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/ALIGNMENT_SUMMARY/${SM_TAG}.alignment_summary_metrics.txt ]]
	then
		echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		awk 'BEGIN {OFS="\t"} \
			NR==9 \
			{if ($1=="") print "0","0","0","0","0","0","0"; \
			else print $7*100,$9,$13,$14,$15,$18*100,$24*100}' \
		${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/ALIGNMENT_SUMMARY/${SM_TAG}.alignment_summary_metrics.txt \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

#######################################################################################
##### ALIGNMENT SUMMARY METRICS FOR PAIR ##############################################
#######################################################################################
##### THIS THE HEADER ####################################################################
##### "TOTAL_READS","RAW_GIGS","PCT_PF_READS_ALIGNED_PAIR","PF_MISMATCH_RATE_PAIR" #######
##### "PF_HQ_ERROR_RATE_PAIR","PF_INDEL_RATE_PAIR","PCT_READS_ALIGNED_IN_PAIRS_PAIR" #####
##### "PCT_PF_READS_IMPROPER_PAIRS_PAIR","STRAND_BALANCE_PAIR","PCT_CHIMERAS_PAIR" #######
##########################################################################################

	if
		[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/ALIGNMENT_SUMMARY/${SM_TAG}.alignment_summary_metrics.txt ]]
	then
		echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		awk 'BEGIN {OFS="\t"} \
			NR==10 \
			{if ($1=="") print "0","0","0","0","0","0","0","0","0","0" ; \
			else print $2,($2*$16/1000000000),$7*100,$13,$14,$15,$18*100,$20*100,$22,$23*100}' \
		${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/ALIGNMENT_SUMMARY/${SM_TAG}.alignment_summary_metrics.txt \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

####################################################################################
##### MARK DUPLICATES REPORT #######################################################
####################################################################################
##### THIS IS THE HEADER ###########################################################
##### "UNMAPPED_READS","READ_PAIR_OPTICAL_DUPLICATES","PERCENT_DUPLICATION" ########
##### "ESTIMATED_LIBRARY_SIZE","SECONDARY_OR_SUPPLEMENTARY_READS" ##################
##### "READ_PAIR_DUPLICATES","READ_PAIRS_EXAMINED","PAIRED_DUP_RATE" ###############
##### "UNPAIRED_READ_DUPLICATES","UNPAIRED_READS_EXAMINED","UNPAIRED_DUP_RATE" #####
##### "PERCENT_DUPLICATION_OPTICAL" ################################################
####################################################################################

	if
		[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/PICARD_DUPLICATES/${SM_TAG}_MARK_DUPLICATES.txt ]]
	then
		echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		MAX_RECORD=(`grep -n "^$" \
				${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/PICARD_DUPLICATES/${SM_TAG}_MARK_DUPLICATES.txt \
				| awk 'BEGIN {FS=":"} \
					NR==2 \
					{print $1}'`)

		awk 'BEGIN {OFS="\t"} \
			NR>7&&NR<'${MAX_RECORD}' \
			{if ($10!~/[0-9]/) print $5,$8,"NaN","NaN",$4,$7,$3,"NaN",$6,$2,"NaN" ; \
			else if ($10~/[0-9]/&&$2=="0") print $5,$8,$9*100,$10,$4,$7,$3,($7/$3),$6,$2,"NaN" ; \
			else print $5,$8,$9*100,$10,$4,$7,$3,($7/$3),$6,$2,($6/$2)}' \
		${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/PICARD_DUPLICATES/${SM_TAG}_MARK_DUPLICATES.txt \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			sum 1 \
			sum 2 \
			mean 4 \
			sum 5 \
			sum 6 \
			sum 7 \
			sum 9 \
			sum 10 \
		| awk 'BEGIN {OFS="\t"} \
			{if ($3!~/[0-9]/) print $1,$2,"NaN","NaN",$4,$5,$6,"NaN",$7,$8,"NaN","NaN" ; \
			else if ($3~/[0-9]/&&$1=="0") \
				print $1,$2,(($7+($5*2))/($8+($6*2)))*100,$3,$4,$5,$6,($5/$6),$7,$8,"NaN",($2/$6)*100 ; \
			else if ($3~/[0-9]/&&$1!="0"&&$8=="0") \
				print $1,$2,(($7+($5*2))/($8+($6*2)))*100,$3,$4,$5,$6,($5/$6),$7,$8,"NaN",($2/$6)*100 ; \
			else print $1,$2,(($7+($5*2))/($8+($6*2)))*100,$3,$4,$5,$6,($5/$6),$7,$8,($7/$8),($2/$6)*100}' \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

#######################################################################################################
##### HYBRIDIZATION SELECTION REPORT ##################################################################
#######################################################################################################
##### THIS IS THE HEADER ##############################################################################
##### "GENOME_SIZE","BAIT_SET","BAIT_TERRITORY","TARGET_TERRITORY" ####################################
##### "PCT_PF_UQ_READS_ALIGNED","PF_UQ_GIGS_ALIGNED","PCT_SELECTED_BASES","ON_BAIT_VS_SELECTED" #######
##### "MEAN_BAIT_COVERAGE","MEAN_TARGET_COVERAGE","MEDIAN_TARGET_COVERAGE","MAX_TARGET_COVERAGE" ######
##### "PCT_USABLE_BASES_ON_BAIT","ZERO_CVG_TARGETS_PCT" ###############################################
##### "PCT_EXC_MAPQ","PCT_EXC_BASEQ","PCT_EXC_OVERLAP","PCT_EXC_OFF_TARGET" ###########################
##### "PCT_TARGET_BASES_20X","PCT_TARGET_BASES_30X","PCT_TARGET_BASES_40X","PCT_TARGET_BASES_50X" #####
##### "AT_DROPOUT","GC_DROPOUT","THEORETICAL_HET_SENSITIVITY","HET_SNP_Q" #############################
#######################################################################################################

	# this will take when there are no reads in the file...but i don't think that it will handle when there are reads, but none fall on target
	# the next time i that happens i'll fix this to handle it.

		if
			[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/HYB_SELECTION/${SM_TAG}_hybridization_selection_metrics.txt ]]
		then
			echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
			>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

		else
			awk 'BEGIN {FS="\t";OFS="\t"} \
				NR==8 \
				{if ($12=="?"&&$44=="") \
					print $2,$1,$3,$4,"NaN",($14/1000000000),"NaN","NaN",$22,$23,$24,$25,"NaN",$29,"NaN","NaN","NaN","NaN",$39,$40,$41,$42,$51,$52,$53,$54 ; \
				else if ($12!="?"&&$44=="") \
					print $2,$1,$3,$4,$12*100,($14/1000000000),$19*100,$21,$22,$23,$24,$25,$26*100,$29*100,$31*100,$32*100,$33*100,$34*100,$39*100,$40*100,$41*100,$42*100,$51,$52,$53,$54 ; \
				else print $2,$1,$3,$4,$12*100,($14/1000000000),$19*100,$21,$22,$23,$24,$25,$26*100,$29*100,$31*100,$32*100,$33*100,$34*100,$39*100,$40*100,$41*100,$42*100,$51,$52,$53,$54}' \
			${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/HYB_SELECTION/${SM_TAG}_hybridization_selection_metrics.txt \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
			>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
		fi

##############################################
##### BAIT BIAS REPORT FOR Cref and Gref #####
##############################################
##### THIS IS THE HEADER #####################
##### "Cref_Q","Gref_Q" ######################
##############################################

	if
		[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/BAIT_BIAS/SUMMARY/${SM_TAG}.bait_bias_summary_metrics.txt ]]
	then
		echo -e NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		grep -v "^#" ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/BAIT_BIAS/SUMMARY/${SM_TAG}.bait_bias_summary_metrics.txt \
			| sed '/^$/d' \
			| awk 'BEGIN {OFS="\t"} $12=="Cref"||$12=="Gref" {print $5}' \
			| paste - - \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				collapse 1 \
				collapse 2 \
			| sed 's/,/;/g' \
			| awk 'BEGIN {OFS="\t"} {print $0}' \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

############################################################
##### PRE-ADAPTER BIAS REPORT FOR Deamination and OxoG #####
############################################################
##### THIS IS THE HEADER ###################################
##### DEAMINATION_Q,OxoG_Q #################################
############################################################

	if
		[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/PRE_ADAPTER/SUMMARY/${SM_TAG}.pre_adapter_summary_metrics.txt ]]
	then
		echo -e NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		grep -v "^#" ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/PRE_ADAPTER/SUMMARY/${SM_TAG}.pre_adapter_summary_metrics.txt \
			| sed '/^$/d' \
			| awk 'BEGIN {OFS="\t"} $12=="Deamination"||$12=="OxoG" {print $5}' \
			| paste - - \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				collapse 1 \
				collapse 2 \
			| sed 's/,/;/g' \
			| awk 'BEGIN {OFS="\t"} {print $0}' \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

###########################################################
##### BASE DISTRIBUTION REPORT AVERAGE FROM PER CYCLE #####
###########################################################
##### THIS IS THE HEADER ##################################
##### PCT_A,PCT_C,PCT_G,PCT_T,PCT_N #######################
###########################################################

	BASE_DISTIBUTION_BY_CYCLE_ROW_COUNT=$(wc -l ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/BASE_DISTRIBUTION_BY_CYCLE/METRICS/${SM_TAG}.base_distribution_by_cycle_metrics.txt | awk '{print $1}')

	if
		[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/BASE_DISTRIBUTION_BY_CYCLE/METRICS/${SM_TAG}.base_distribution_by_cycle_metrics.txt ]]
	then
		echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	elif
		[[ -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/BASE_DISTRIBUTION_BY_CYCLE/METRICS/${SM_TAG}.base_distribution_by_cycle_metrics.txt && \
		${BASE_DISTIBUTION_BY_CYCLE_ROW_COUNT} -lt 8 ]]
	then
		echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	else
		sed '/^$/d' ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/BASE_DISTRIBUTION_BY_CYCLE/METRICS/${SM_TAG}.base_distribution_by_cycle_metrics.txt \
			| awk 'NR>6' \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				mean 3 \
				mean 4 \
				mean 5 \
				mean 6 \
				mean 7 \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

############################################
##### BASE SUBSTITUTION RATE ###############
############################################
##### THIS IS THE HEADER ###################
##### PCT_A_to_C,PCT_A_to_G,PCT_A_to_T #####
##### PCT_C_to_A,PCT_C_to_G,PCT_C_to_T #####
############################################

	if
		[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/ERROR_SUMMARY/${SM_TAG}.error_summary_metrics.txt ]]
	then
		echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		sed '/^$/d' ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/ERROR_SUMMARY/${SM_TAG}.error_summary_metrics.txt \
			| awk 'NR>6 {print $6*100}' \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

#######################################################################################################
##### GRAB VCF METRICS FOR USER DEFINED PADDED BAIT REGION ############################################
#######################################################################################################
##### THIS IS THE HEADER ##############################################################################
##### COUNT_PASS_BIALLELIC_SNV_BAIT,COUNT_FILTERED_SNV_BAIT,PERCENT_PASS_SNV_SNP138_BAIT ##############
##### COUNT_PASS_BIALLELIC_INDEL_BAIT,COUNT_FILTERED_INDEL_BAIT,PERCENT_PASS_INDEL_SNP138_BAIT ########
##### DBSNP_INS_DEL_RATIO_BAIT,NOVEL_INS_DEL_RATIO_BAIT ###############################################
##### COUNT_PASS_MULTIALLELIC_SNV_BAIT,COUNT_PASS_MULTIALLELIC_SNV_SNP138_BAIT ########################
##### COUNT_PASS_COMPLEX_INDEL_BAIT,COUNT_PASS_COMPLEX_INDEL_SNP138_BAIT ##############################
##### SNP_REFERENCE_BIAS_BAIT,HET_HOMVAR_RATIO_BAIT,PCT_GQ0_VARIANTS_BAIT,COUNT_GQ0_VARIANTS_BAIT #####
#######################################################################################################

	# since I don't have have any examples of what failures look like, I can't really build that in

	if
		[[ ! -f ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/VCF_METRICS/${SM_TAG}_BAIT.variant_calling_detail_metrics.txt ]]
	then
		echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		awk 'BEGIN {FS="\t";OFS="\t"} \
			NR==8 \
			{print $6,$9,$10*100,$13,$15,$16*100,$18,$19,$20,$21,$22,$23,$24,$2,$3,$4}' \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/VCF_METRICS/${SM_TAG}_BAIT.variant_calling_detail_metrics.txt \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

###############################################################################################################
##### GRAB VCF METRICS FOR USER DEFINED PADDED TARGET REGION ##################################################
###############################################################################################################
##### THIS IS THE HEADER ######################################################################################
##### COUNT_PASS_BIALLELIC_SNV_TARGET,COUNT_FILTERED_SNV_TARGET,PERCENT_PASS_SNV_SNP138_TARGET ################
##### COUNT_PASS_BIALLELIC_INDEL_TARGET,COUNT_FILTERED_INDEL_TARGET,PERCENT_PASS_INDEL_SNP138_TARGET ##########
##### DBSNP_INS_DEL_RATIO_TARGET,NOVEL_INS_DEL_RATIO_TARGET ###################################################
##### COUNT_PASS_MULTIALLELIC_SNV_TARGET,COUNT_PASS_MULTIALLELIC_SNV_SNP138_TARGET ############################
##### COUNT_PASS_COMPLEX_INDEL_TARGET,COUNT_PASS_COMPLEX_INDEL_SNP138_TARGET ##################################
##### SNP_REFERENCE_BIAS_TARGET,HET_HOMVAR_RATIO_TARGET,PCT_GQ0_VARIANTS_TARGET,COUNT_GQ0_VARIANTS_TARGET #####
###############################################################################################################

	if
		[[ ! -f ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/VCF_METRICS/${SM_TAG}_TARGET.variant_calling_detail_metrics.txt ]]
	then
		echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		awk 'BEGIN {FS="\t";OFS="\t"} \
			NR==8 \
			{print $6,$9,$10*100,$13,$15,$16*100,$18,$19,$20,$21,$22,$23,$24,$2,$3,$4}' \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/VCF_METRICS/${SM_TAG}_TARGET.variant_calling_detail_metrics.txt \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

##############################################
##### GRAB VCF METRICS FOR TITV BED FILE #####
##############################################
##### THIS IS THE HEADER #####################
##### ALL_TI_TV_COUNT,ALL_TI_TV_RATIO ########
##### NOVEL_TI_TV_COUNT,NOVEL_TI_TV_RATIO ####
##############################################

	if
		[[ ! -f ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/VCF_METRICS/${SM_TAG}_TITV.variant_calling_detail_metrics.txt ]]
	then
		echo -e NaN'\t'NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		awk 'BEGIN {FS="\t";OFS="\t"} \
			NR==8 \
			{print $6,$11,$8,$12}' \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/VCF_METRICS/${SM_TAG}_TITV.variant_calling_detail_metrics.txt \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

########################################################################################################
##### HYBRIDIZATION SELECTION REPORT FOR MITOCHONDRIA ##################################################
########################################################################################################
##### THIS IS THE HEADER ###############################################################################
##### "MT_MEAN_TARGET_CVG","MT_MAX_TARGET_CVG","MT_MIN_TARGET_CVG" #####################################
##### "MT_PCT_TARGET_BASES_10X","MT_PCT_TARGET_BASES_20X","MT_PCT_TARGET_BASES_30X" ####################
##### "MT_PCT_TARGET_BASES_40X","MT_PCT_TARGET_BASES_50X","MT_PCT_TARGET_BASES_100X" ###################
##### "MT_TOTAL_READS","MT_PF_UNIQUE_READS","MT_PCT_PF_UQ_READS","MT_PF_UQ_READS_ALIGNED" ##############
##### "MT_PCT_PF_UQ_READS_ALIGNED","MT_PF_BASES","MT_PF_BASES_ALIGNED","MT_PF_UQ_BASES_ALIGNED" ########
##### "MT_ON_TARGET_BASES","MT_PCT_USABLE_BASES_ON_TARGET" #############################################
##### "MT_PCT_EXC_DUPE","MT_PCT_EXC_ADAPTER","MT_PCT_EXC_MAPQ","MT_PCT_EXC_BASEQ","MT_PCT_EXC_OVERLAP" #
##### "MT_MEAN_BAIT_CVG,"MT_PCT_USABLE_BASES_ON_BAIT","MT_AT_DROPOUT","MT_GC_DROPOUT" ##################
########################################################################################################

	# this will take when there are no reads in the file...but i don't think that it will handle when there are reads, but none fall on target
	# the next time i that happens i'll fix this to handle it.

		if
			[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/MT_OUTPUT/COLLECTHSMETRICS_MT/${SM_TAG}.output.metrics ]]
		then
			echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
			>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

		else
			awk 'BEGIN {FS="\t";OFS="\t"} \
				NR==8 \
				{print $34,$36,$37,\
					$48*100,$49*100,$50*100,$51*100,$52*100,$53*100,\
					$23,$26,$32*100,$27,$33*100,$25,$28,$29,$30,$12,\
					$39*100,$40*100,$41*100,$42*100,$43*100,\
					$10,$11*100,$54,$55}' \
			${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/MT_OUTPUT/COLLECTHSMETRICS_MT/${SM_TAG}.output.metrics \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
			>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
		fi

#######################################################################################################
##### GRAB VCF METRICS MUTECT2 MT VCF AFTER FILTERING AND MASKING #####################################
#######################################################################################################
##### THIS IS THE HEADER ##############################################################################
##### MT_COUNT_PASS_BIALLELIC_SNV,MT_COUNT_FILTERED_SNV,MT_PERCENT_PASS_SNV_SNP138 ####################
##### MT_COUNT_PASS_BIALLELIC_INDEL,MT_COUNT_FILTERED_INDEL,MT_PERCENT_PASS_INDEL_SNP138 ##############
##### MT_COUNT_PASS_MULTIALLELIC_SNV,MT_COUNT_PASS_MULTIALLELIC_SNV_SNP138 ############################
##### MT_COUNT_PASS_COMPLEX_INDEL,MT_COUNT_PASS_COMPLEX_INDEL_SNP138 ##################################
##### MT_SNP_REFERENCE_BIAS,MT_PCT_GQ0_VARIANTS,MT_COUNT_GQ0_VARIANTS #################################
#######################################################################################################

	# since I don't have have any examples of what failures look like, I can't really build that in

	if
		[[ ! -f ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/MT_OUTPUT/VCF_METRICS_MT/${SM_TAG}_MUTECT2_MT.variant_calling_detail_metrics.txt ]]
	then
		echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		awk 'BEGIN {FS="\t";OFS="\t"} \
			NR==8 \
			{print $6,$9,$10*100,$13,$15,$16*100,$20,$21,$22,$23,$24,$3*100,$4}' \
		${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/MT_OUTPUT/VCF_METRICS_MT/${SM_TAG}_MUTECT2_MT.variant_calling_detail_metrics.txt \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

#########################################################
##### COUNT HOW MANY DELETIONS DETECTED BY EKLIPLSE #####
#########################################################
##### THIS IS THE HEADER ################################
##### MT_COUNT_EKLIPSE_DEL ##############################
#########################################################

	# EKLIPSE WRITES AN OUTPUT FOLDER APPENDING A RANDOM HASH TO FOLDER NAME.
	# CREATE A VARIABLE CONTAINING THE FULL PATH FOR THE LATEST EKLIPSE RUN

		LATEST_EKLIPSE_OUTPUT_DIR=$(ls -trd ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/MT_OUTPUT/EKLIPSE/* | tail -n 1)

	if
		[[ ! -f ${LATEST_EKLIPSE_OUTPUT_DIR}/${SM_TAG}_deletions.tsv ]]
	then
		echo -e NaN \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt

	else
		awk 'BEGIN {OFS="\t"} END {print NR-1}' \
			${LATEST_EKLIPSE_OUTPUT_DIR}/${SM_TAG}_deletions.tsv \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt
	fi

##############################
# tranpose from rows to list #
##############################

	cat ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}.QC_REPORT_TEMP.txt \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
	>| ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/QC_REPORT_PREP/${SM_TAG}.QC_REPORT_PREP.txt

#######################################
# check the exit signal at this point #
#######################################

	SCRIPT_STATUS=`echo $?`
