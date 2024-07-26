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

	OUTPUT_DIR=$3

	SCRIPT_DIR=$4
	SUBMITTER_ID=$5
	SAMPLE_SHEET=$6
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
		SAMPLE_SHEET_FILE_NAME=$(basename ${SAMPLE_SHEET})
	PED_FILE=$7
		PED_PREFIX=$(basename ${PED_FILE} .ped)
	SUBMIT_STAMP=$8
	SEND_TO=$9
	THREADS=${10}

	# create variables using the base name for the sample sheet and ped file

		PED_PREFIX=$(basename ${PED_FILE} .ped)

	# create a time stamp to incorporate into output file names

		TIMESTAMP=`date '+%F.%H-%M-%S'`

	# grab submitter's name

		PERSON_NAME=`getent passwd | awk 'BEGIN {FS=":"} $1=="'${SUBMITTER_ID}'" {print $5}'`

#################################################################################
# combining all the individual qc reports for the project and adding the header #
#################################################################################

	for SM_TAG in $(awk 1 ${SAMPLE_SHEET} \
			| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
			| awk 'NR>1' \
			| awk 'BEGIN {FS=","} \
				{print $8}' \
			| sort \
			| uniq );
	do
		cat ${CORE_PATH}/${OUTPUT_DIR}/*/${SM_TAG}/REPORTS/QC_REPORT_PREP/${SM_TAG}.QC_REPORT_PREP.txt
	done \
		| sort -k 2,2 \
		| awk 'BEGIN {print "PROJECT",\
			"SM_TAG",\
			"PLATFORM_UNIT",\
			"LIBRARY_NAME",\
			"PIPELINE_VERSION",\
			"PIPELINE_FILES_VERSION",\
			"FAMILY",\
			"FATHER",\
			"MOTHER",\
			"EXPECTED_SEX",\
			"PHENOTYPE",\
			"X_AVG_DP",\
			"X_NORM_DP",\
			"Y_AVG_DP",\
			"Y_NORM_DP",\
			"VERIFYBAM_FREEMIX_PCT",\
			"VERIFYBAM_#SNPS",\
			"VERIFYBAM_FREELK1",\
			"VERIFYBAM_FREELK0",\
			"VERIFYBAM_DIFF_LK0_LK1",\
			"VERIFYBAM_AVG_DP",\
			"MEDIAN_INSERT_SIZE",\
			"MEAN_INSERT_SIZE",\
			"STANDARD_DEVIATION_INSERT_SIZE",\
			"PCT_PF_READS_ALIGNED_R1",\
			"PF_HQ_ALIGNED_READS_R1",\
			"PF_MISMATCH_RATE_R1",\
			"PF_HQ_ERROR_RATE_R1",\
			"PF_INDEL_RATE_R1",\
			"PCT_READS_ALIGNED_IN_PAIRS_R1",\
			"PCT_ADAPTER_R1",\
			"PCT_PF_READS_ALIGNED_R2",\
			"PF_HQ_ALIGNED_READS_R2",\
			"PF_MISMATCH_RATE_R2",\
			"PF_HQ_ERROR_RATE_R2",\
			"PF_INDEL_RATE_R2",\
			"PCT_READS_ALIGNED_IN_PAIRS_R2",\
			"PCT_ADAPTER_R2",\
			"TOTAL_READS",\
			"RAW_GIGS",\
			"PCT_PF_READS_ALIGNED_PAIR",\
			"PF_MISMATCH_RATE_PAIR",\
			"PF_HQ_ERROR_RATE_PAIR",\
			"PF_INDEL_RATE_PAIR",\
			"PCT_READS_ALIGNED_IN_PAIRS_PAIR",\
			"PCT_PF_READS_IMPROPER_PAIRS_PAIR",\
			"STRAND_BALANCE_PAIR",\
			"PCT_CHIMERAS_PAIR",\
			"UNMAPPED_READS",\
			"READ_PAIR_OPTICAL_DUPLICATES",\
			"PERCENT_DUPLICATION",\
			"ESTIMATED_LIBRARY_SIZE",\
			"SECONDARY_OR_SUPPLEMENTARY_READS",\
			"READ_PAIR_DUPLICATES",\
			"READ_PAIRS_EXAMINED",\
			"PAIRED_DUP_RATE",\
			"UNPAIRED_READ_DUPLICATES",\
			"UNPAIRED_READS_EXAMINED",\
			"UNPAIRED_DUP_RATE",\
			"PERCENT_DUPLICATION_OPTICAL",\
			"GENOME_SIZE",\
			"BAIT_SET",\
			"BAIT_TERRITORY",\
			"TARGET_TERRITORY",\
			"PCT_PF_UQ_READS_ALIGNED",\
			"PF_UQ_GIGS_ALIGNED",\
			"PCT_SELECTED_BASES",\
			"ON_BAIT_VS_SELECTED",\
			"MEAN_BAIT_COVERAGE",\
			"MEAN_TARGET_COVERAGE",\
			"MEDIAN_TARGET_COVERAGE",\
			"MAX_TARGET_COVERAGE",\
			"PCT_USABLE_BASES_ON_BAIT",\
			"ZERO_CVG_TARGETS_PCT",\
			"PCT_EXC_MAPQ",\
			"PCT_EXC_BASEQ",\
			"PCT_EXC_OVERLAP",\
			"PCT_EXC_OFF_TARGET",\
			"PCT_TARGET_BASES_20X",\
			"PCT_TARGET_BASES_30X",\
			"PCT_TARGET_BASES_40X",\
			"PCT_TARGET_BASES_50X",\
			"AT_DROPOUT",\
			"GC_DROPOUT",\
			"THEORETICAL_HET_SENSITIVITY",\
			"HET_SNP_Q",\
			"Cref_Q",\
			"Gref_Q",\
			"DEAMINATION_Q",\
			"OxoG_Q",\
			"PCT_A",\
			"PCT_C",\
			"PCT_G",\
			"PCT_T",\
			"PCT_N",\
			"PCT_A_to_C",\
			"PCT_A_to_G",\
			"PCT_A_to_T",\
			"PCT_C_to_A",\
			"PCT_C_to_G",\
			"PCT_C_to_T",\
			"COUNT_PASS_BIALLELIC_SNV_BAIT",\
			"COUNT_FILTERED_SNV_BAIT",\
			"PERCENT_PASS_SNV_SNP138_BAIT",\
			"COUNT_PASS_BIALLELIC_INDEL_BAIT",\
			"COUNT_FILTERED_INDEL_BAIT",\
			"PERCENT_PASS_INDEL_SNP138_BAIT",\
			"DBSNP_INS_DEL_RATIO_BAIT",\
			"NOVEL_INS_DEL_RATIO_BAIT",\
			"COUNT_PASS_MULTIALLELIC_SNV_BAIT",\
			"COUNT_PASS_MULTIALLELIC_SNV_SNP138_BAIT",\
			"COUNT_PASS_COMPLEX_INDEL_BAIT",\
			"COUNT_PASS_COMPLEX_INDEL_SNP138_BAIT",\
			"SNP_REFERENCE_BIAS_BAIT",\
			"HET_HOMVAR_RATIO_BAIT",\
			"PCT_GQ0_VARIANTS_BAIT",\
			"COUNT_GQ0_VARIANTS_BAIT",\
			"COUNT_PASS_BIALLELIC_SNV_TARGET",\
			"COUNT_FILTERED_SNV_TARGET",\
			"PERCENT_PASS_SNV_SNP138_TARGET",\
			"COUNT_PASS_BIALLELIC_INDEL_TARGET",\
			"COUNT_FILTERED_INDEL_TARGET",\
			"PERCENT_PASS_INDEL_SNP138_TARGET",\
			"DBSNP_INS_DEL_RATIO_TARGET",\
			"NOVEL_INS_DEL_RATIO_TARGET",\
			"COUNT_PASS_MULTIALLELIC_SNV_TARGET",\
			"COUNT_PASS_MULTIALLELIC_SNV_SNP138_TARGET",\
			"COUNT_PASS_COMPLEX_INDEL_TARGET",\
			"COUNT_PASS_COMPLEX_INDEL_SNP138_TARGET",\
			"SNP_REFERENCE_BIAS_TARGET",\
			"HET_HOMVAR_RATIO_TARGET",\
			"PCT_GQ0_VARIANTS_TARGET",\
			"COUNT_GQ0_VARIANTS_TARGET",\
			"ALL_TI_TV_COUNT",\
			"ALL_TI_TV_RATIO",\
			"NOVEL_TI_TV_COUNT",\
			"NOVEL_TI_TV_RATIO", \
			"MT_MEAN_TARGET_CVG",\
			"MT_MAX_TARGET_CVG",\
			"MT_MIN_TARGET_CVG",\
			"MT_PCT_TARGET_BASES_10X",\
			"MT_PCT_TARGET_BASES_20X",\
			"MT_PCT_TARGET_BASES_30X",\
			"MT_PCT_TARGET_BASES_40X",\
			"MT_PCT_TARGET_BASES_50X",\
			"MT_PCT_TARGET_BASES_100X",\
			"MT_TOTAL_READS",\
			"MT_PF_UNIQUE_READS",\
			"MT_PCT_PF_UQ_READS",\
			"MT_PF_UQ_READS_ALIGNED",\
			"MT_PCT_PF_UQ_READS_ALIGNED",\
			"MT_PF_BASES",\
			"MT_PF_BASES_ALIGNED",\
			"MT_PF_UQ_BASES_ALIGNED",\
			"MT_ON_TARGET_BASES",\
			"MT_PCT_USABLE_BASES_ON_TARGET",\
			"MT_PCT_EXC_DUPE",\
			"MT_PCT_EXC_ADAPTER",\
			"MT_PCT_EXC_MAPQ",\
			"MT_PCT_EXC_BASEQ",\
			"MT_PCT_EXC_OVERLAP",\
			"MT_MEAN_BAIT_CVG",\
			"MT_PCT_USABLE_BASES_ON_BAIT",\
			"MT_AT_DROPOUT",\
			"MT_GC_DROPOUT",\
			"MT_COUNT_PASS_BIALLELIC_SNV",\
			"MT_COUNT_FILTERED_SNV",\
			"MT_PERCENT_PASS_SNV_SNP138",\
			"MT_COUNT_PASS_BIALLELIC_INDEL",\
			"MT_COUNT_FILTERED_INDEL",\
			"MT_PERCENT_PASS_INDEL_SNP138",\
			"MT_COUNT_PASS_MULTIALLELIC_SNV",\
			"MT_COUNT_PASS_MULTIALLELIC_SNV_SNP138",\
			"MT_COUNT_PASS_COMPLEX_INDEL",\
			"MT_COUNT_PASS_COMPLEX_INDEL_SNP138",\
			"MT_SNP_REFERENCE_BIAS",\
			"MT_PCT_GQ0_VARIANTS",\
			"MT_COUNT_GQ0_VARIANTS",\
			"MT_COUNT_EKLIPSE_DEL"} \
			{print $0}' \
	| sed 's/ /,/g' \
	| sed 's/\t/,/g' \
	>| ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.QC_REPORT.${TIMESTAMP}.csv


######################################################
# create sample array to map sm tag to original data #
######################################################

	CREATE_SAMPLE_ARRAY ()
	{
		SAMPLE_ARRAY=(`awk 'BEGIN {FS="\t"; OFS="\t"} \
			$8=="'${SAMPLE}'" \
			{print $1,$8,$20}' \
		~/JOINT_CALL_TEMP/${SAMPLE_SHEET_NAME}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq`)

			#  1  Project=the Seq Proj folder name

				PROJECT=${SAMPLE_ARRAY[0]}

			#  8  SM_Tag=sample ID

				SM_TAG=${SAMPLE_ARRAY[1]}

			# 20 family that sample belongs to

				FAMILY=${SAMPLE_ARRAY[2]}
	}

###############################################
# Concatenate all aneuploidy reports together #
#################################################################################
# TO DO CONCATENATE WITH THE CONTROLS...might not do this since this isn't used #
#################################################################################

	MAKE_ANEUPLOIDY_HEADER ()
	{
		echo "SM_TAG,CHROM,ARM,TOTAL_COVERAGE,TOTAL_TARGETS,MEAN_DEPTH,NORM_DEPTH" \
		>| ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.ANEUPLOIDY_CHECK.${TIMESTAMP}.csv
	}

	GRAB_ANEUPLOIDY_DATA ()
	{
		cat ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/ANEUPLOIDY_CHECK/${SM_TAG}.chrom_count_report.txt \
			| grep -v "SM_TAG" \
			| sed 's/\t/,/g' \
		>> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.ANEUPLOIDY_CHECK.${TIMESTAMP}.csv
	}

###############################################################
# Concatenate all per chromosome verifybamID reports together #
#################################################################################
# TO DO CONCATENATE WITH THE CONTROLS...might not do this since this isn't used #
#################################################################################

	MAKE_VERIFYBAMID_CHR_HEADER ()
	{
		echo "#SM_TAG,CHROM,VERIFYBAM_FREEMIX,VERIFYBAM_SNPS,VERIFYBAM_FREELK1,VERRIFYBAM_FREELK0,VERIFYBAM_AVG_DP" \
		>| ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.PER_AUTOSOME_VERIFYBAMID.${TIMESTAMP}.csv
	}

	GRAB_VERIFYBAMID_CHR_DATA ()
	{
		cat ${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/VERIFYBAMID_AUTO/${SM_TAG}.VERIFYBAMID.PER_AUTOSOME.txt \
			| grep -v "^#" \
			| sed 's/\t/,/g; s/ /,/g' \
		>> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.PER_AUTOSOME_VERIFYBAMID.${TIMESTAMP}.csv
	}

################################################################################################
# grab out MEAN_TARGET_COVERAGE,ZERO_CVG_TARGETS_PCT,PCT_TARGET_BASES_20X,PCT_TARGET_BASES_50X #
# for all samples and place in TEMP ############################################################
################################################################################################

	GRAB_SHORT_COVERAGE_SUMMARY ()
	{
		awk 'BEGIN {FS="\t";OFS=","} \
			NR==8 \
			{print "'${SM_TAG}'",$23,$29*100,$39*100,$42*100}' \
		${CORE_PATH}/${PROJECT}/${FAMILY}/${SM_TAG}/REPORTS/HYB_SELECTION/${SM_TAG}_hybridization_selection_metrics.txt \
		>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${OUTPUT_DIR}.SUMMARY_COVERAGE.csv
	}

MAKE_ANEUPLOIDY_HEADER
MAKE_VERIFYBAMID_CHR_HEADER

	for SAMPLE in $(awk 1 ${SAMPLE_SHEET} \
			| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
			| awk 'BEGIN {FS=","} \
				NR>1 \
				{print $8}' \
			| sort \
			| uniq );
	do
		CREATE_SAMPLE_ARRAY
		GRAB_ANEUPLOIDY_DATA
		GRAB_VERIFYBAMID_CHR_DATA
		GRAB_SHORT_COVERAGE_SUMMARY
	done

# ##########################################################################################################
# # for each family grab out summary coverage metrics above, add header and write to file in family folder #
# ##########################################################################################################

	for FAMILY in $(awk 1 ${PED_FILE} \
			| sed 's/\r//g' \
			| sort -k 2,2 \
			| cut -f 1 \
			| uniq);
	do
		echo -e SAMPLE,MEAN_TARGET_COVERAGE,ZERO_CVG_TARGETS_PCT,PCT_TARGET_BASES_20X,PCT_TARGET_BASES_50X\
		>| ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${FAMILY}.SUMMARY_COVERAGE.csv

		cat ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${OUTPUT_DIR}.SUMMARY_COVERAGE.csv \
		>> ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${FAMILY}.SUMMARY_COVERAGE.csv
	done

##############################################################
##### CLEAN-UP OR NOT DEPENDING ON IF JOBS FAILED OR NOT #####
##### RUN MD5 CHECK ON REMAINING FILES #######################
##############################################################

	# CREATE SAMPLE ARRAY, USED DURING PROJECT CLEANUP

		CREATE_SAMPLE_ARRAY_FOR_FILE_CLEANUP ()
		{
			SAMPLE_ARRAY=(`awk 1 ${SAMPLE_SHEET} \
				| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
				| awk 'BEGIN {FS=",";OFS="\t"} \
					$1=="'${PROJECT}'"&&$8=="'${SM_TAG}'" \
					{print $1,$8,$2"_"$3"_"$4"*"}' \
				| sort \
				| uniq \
				| singularity exec ${ALIGNMENT_CONTAINER} datamash \
					-g 1,2 \
					collapse 3`)

				#  1  Project=the Seq Proj folder name
				PROJECT_FILE_CLEANUP=${OUTPUT_DIR}

				#  8  SM_Tag=sample ID
				SM_TAG_FILE_CLEANUP=${SAMPLE_ARRAY[1]}

				# PLATFORM UNIT: COMPRISED OF;
					#  2  FCID=flowcell that sample read group was performed on
					#  3  Lane=lane of flowcell that sample read group was performed on]
					#  4  Index=sample barcode
				PLATFORM_UNIT=${SAMPLE_ARRAY[2]}
		}

	# RUN MD5 IN PARALLEL USING 90% OF THE CPU PROCESSORS ON THE PIPELINE OUTPUT FILES

		RUN_MD5_PARALLEL_OUTPUT_FILES ()
		{
			find ${CORE_PATH}/${OUTPUT_DIR} \
					-type f \
				| cut -f 2 \
				| singularity exec ${ALIGNMENT_CONTAINER} parallel \
					--no-notice \
					-j ${THREADS} \
					md5sum {} \
			> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/md5_output_files_${OUTPUT_DIR}_${TIMESTAMP}.txt
		}

	# count the number of records in the log file and store a variable to be used in if statement.

		MD5_DIFF=$(wc -l ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/md5_diff_JHG_Clinical_Exome_Pipeline_${SUBMIT_STAMP}.txt \
			| awk '{print $1}')

	# RUN MD5 IN PARALLEL USING 90% OF THE CPU PROCESSORS ON THE PIPELINE RESOURCE FILES

		# RUN_MD5_PARALLEL_RESOURCE_FILES ()
		# {
		# 	find ${SCRIPT_DIR}/../resources/ \
		# 		-type f \
		# 	| cut -f 2 \
		# 	| singularity exec ${ALIGNMENT_CONTAINER} parallel \
		# 		--no-notice \
		# 		-j ${THREADS} \
		# 		md5sum {} \
		# 	> ${CORE_PATH}/${PROJECT}/REPORTS/md5_pipeline_resources_${PROJECT}_${TIMESTAMP}.txt
		# }

# IF THERE ARE NO FAILED JOBS and there was no md5 diff generated from the MD5 VALIDATE TASK
## THEN DELETE TEMP FILES STARTING WITH SM_TAG OR PLATFORM_UNIT
# AFTER TEMP FILES ARE DELETED RUN MD5 IN PARALLEL

# IF THERE ARE NO FAILED JOBS, BUT THERE WAS A DIFFERENCE IN THE MD5 FOR PIPELINE FILES
## STILL DELETE TEMP FILES STARTING WITH SM_TAG OR PLATFORM_UNIT AND SEND NOTIFICATION ABOUT MD5 DIFFERENCES
# AFTER TEMP FILES ARE DELETED RUN MD5 IN PARALLEL

# IF THERE ARE FAILED JOBS AND THERE WAS A DIFFERENCE IN THE MD5 FOR PIPELINE FILES
## DON'T DELETE TEMP FILES, SEND NOTIFICATION SUMMARIZING WHAT FAILED AND ABOUT THE MD5 FILE DIFFERENCES

# ELSE; DON'T DELETE ANYTHING BUT SUMMARIZE WHAT FAILED.

	if
		[[ ! -f ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt \
		&& ${MD5_DIFF} -eq 1 ]]
	then
		echo rm -rf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/{KING,PLINK,VCF_PREP,CONTROL*}
		echo rm -rf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/{KING,PLINK,VCF_PREP,CONTROL*} | bash

		echo rm -rf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${OUTPUT_DIR}*
		echo rm -rf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${OUTPUT_DIR}* | bash

		for SM_TAG in \
			$(awk 1 ${SAMPLE_SHEET} \
				| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
				| awk 'BEGIN {FS=","} \
					{print $8}' \
				| sort \
				| uniq)
		do
			CREATE_SAMPLE_ARRAY_FOR_FILE_CLEANUP
			DELETION_PATH=" ${CORE_PATH}/${PROJECT_FILE_CLEANUP}/TEMP/"

			echo rm -rf ${CORE_PATH}/${PROJECT_FILE_CLEANUP}/TEMP/${SM_TAG_FILE_CLEANUP}*
			echo rm -rf ${CORE_PATH}/${PROJECT_FILE_CLEANUP}/TEMP/${SM_TAG_FILE_CLEANUP}* | bash

			echo rm -rf ${CORE_PATH}/${PROJECT_FILE_CLEANUP}/TEMP/${PLATFORM_UNIT} | sed "s|,|$DELETION_PATH|g"
			echo rm -rf ${CORE_PATH}/${PROJECT_FILE_CLEANUP}/TEMP/${PLATFORM_UNIT} | sed "s|,|$DELETION_PATH|g" | bash
		done

		for FAMILY in \
			$(awk 1 ${PED_FILE} \
				| sed 's/\r//g' \
				| sort -k 2,2 \
				| cut -f 1 \
				| uniq)
		do
			echo rm -rf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}*
			echo rm -rf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}* | bash
		done

		RUN_MD5_PARALLEL_OUTPUT_FILES
		# RUN_MD5_PARALLEL_RESOURCE_FILES

		printf "\n${PERSON_NAME} Was The Submitter\n\n \
			REPORTS ARE AT:\n ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/QC_REPORTS\n\n \
			BATCH QC REPORT:\n ${SAMPLE_SHEET_NAME}.QC_REPORT.csv\n\n \
			FILE MD5 HASHSUMS:\n md5_output_files_${OUTPUT_DIR}_${TIMESTAMP}.txt\n \
			md5_pipeline_resources_${OUTPUT_DIR}_${TIMESTAMP}.txt\n\n \
			NO JOBS FAILED: TEMP FILES DELETED" \
		| mail -s "${SAMPLE_SHEET} FOR ${OUTPUT_DIR} has finished processing SUBMITTER_JHG_Clinical_Joint_Caller.sh" \
			${SEND_TO}
	elif
		[[ ! -f ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt \
		&& ${MD5_DIFF} -gt 1 ]]
	then
		echo rm -rf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/{KING,PLINK,VCF_PREP,CONTROL*}
		echo rm -rf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/{KING,PLINK,VCF_PREP,CONTROL*} | bash

		echo rm -rf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${PROJECT}*
		echo rm -rf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${PROJECT}* | bash

		for SM_TAG in \
			$(awk 1 ${SAMPLE_SHEET} \
				| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
				| awk 'BEGIN {FS=","} \
					{print $8}' \
				| sort \
				| uniq)
		do
			CREATE_SAMPLE_ARRAY_FOR_FILE_CLEANUP
			DELETION_PATH=" ${CORE_PATH}/${PROJECT_FILE_CLEANUP}/TEMP/"

			echo rm -rf ${CORE_PATH}/${PROJECT_FILE_CLEANUP}/TEMP/${SM_TAG_FILE_CLEANUP}*
			echo rm -rf ${CORE_PATH}/${PROJECT_FILE_CLEANUP}/TEMP/${SM_TAG_FILE_CLEANUP}* | bash

			echo rm -rf ${CORE_PATH}/${PROJECT_FILE_CLEANUP}/TEMP/${PLATFORM_UNIT} | sed "s|,|$DELETION_PATH|g"
			echo rm -rf ${CORE_PATH}/${PROJECT_FILE_CLEANUP}/TEMP/${PLATFORM_UNIT} | sed "s|,|$DELETION_PATH|g" | bash
		done

		for FAMILY in \
			$(awk 1 ${PED_FILE} \
				| sed 's/\r//g' \
				| sort -k 2,2 \
				| cut -f 1 \
				| uniq)
		do
			echo rm -rf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}*
			echo rm -rf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}* | bash
		done

		RUN_MD5_PARALLEL_OUTPUT_FILES
		# RUN_MD5_PARALLEL_RESOURCE_FILES

		printf "\n${PERSON_NAME} Was The Submitter\n\n \
			WARNING! PIPELINE RESOURCE FILES ARE NOT WHAT THEY ARE EXPECTED TO BE.\n\n \
			PIPELINE RESOURCE FILES DIFFERENCES ARE AT:\n \
				${CORE_PATH}/${OUTPUT_DIR}/REPORTS/md5_diff_JHG_Clinical_Exome_Pipeline_${SUBMIT_STAMP}.txt\n\n \
			REPORTS ARE AT:\n ${CORE_PATH}/${PROJECT}/REPORTS/QC_REPORTS\n\n \
			BATCH QC REPORT:\n ${SAMPLE_SHEET_NAME}.QC_REPORT.csv\n\n \
			FILE MD5 HASHSUMS:\n md5_output_files_${OUTPUT_DIR}_${TIMESTAMP}.txt\n \
			md5_pipeline_resources_${OUTPUT_DIR}_${TIMESTAMP}.txt\n\n \
			NO JOBS FAILED: TEMP FILES DELETED" \
		| mail -s "${SAMPLE_SHEET} FOR ${OUTPUT_DIR} has finished processing SUBMITTER_JHG_Clinical_Joint_Caller.sh" \
			${SEND_TO}

	elif
		[[ -f ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt \
		&& ${MD5_DIFF} -gt 1 ]]
	then
		# CONSTRUCT MESSAGE TO BE SENT SUMMARIZING THE FAILED JOBS
		# ALSO NOTE THAT THE MD5 FILES DIFFERED AS WELL.
			printf "SO BAD THINGS HAPPENED AND THE TEMP FILES WILL NOT BE DELETED FOR:\n" \
				>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "${SAMPLE_SHEET}\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "FOR PROJECT:\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "${OUTPUT_DIR}\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "###################################################################\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "WARNING! PIPELINE RESOURCE FILES ARE NOT WHAT THEY ARE EXPECTED TO BE.\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "REPORT OF FILES WITH DIFFERENT MD5 HASHSUMS ARE AT:\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "${CORE_PATH}/$PROJECT/REPORTS/md5_diff_JHG_Clinical_Exome_Pipeline_${SUBMIT_STAMP}.txt:\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "RESOURCE FILE MD5 HASHSUMS:\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "md5_pipeline_resources_${PROJECT}_${SUBMIT_STAMP}.txt\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "###################################################################\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "SOMEWHAT FULL LISTING OF FAILED JOBS ARE HERE:\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "###################################################################\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "BELOW ARE THE SAMPLES AND THE MINIMUM NUMBER OF JOBS THAT FAILED PER SAMPLE:\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "###################################################################\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			egrep -v "CONCORDANCE" ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt \
				| awk 'BEGIN {OFS="\t"} \
					NF==6 \
					{print $1}' \
				| sort \
				| singularity exec ${ALIGNMENT_CONTAINER} datamash \
					-g 1 \
					count 1 \
			>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "###################################################################\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "FOR THE SAMPLES THAT HAVE FAILED JOBS, THIS IS ROUGHLY THE FIRST JOB THAT FAILED FOR EACH SAMPLE:\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "###################################################################\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "SM_TAG NODE JOB_NAME USER EXIT LOG_FILE\n" \
				| sed 's/ /\t/g' \
			>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

		for sample in \
			$(awk 'BEGIN {OFS="\t"} \
				NF==6 \
				{print $1}' \
			${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt \
				| sort \
				| uniq);
		do
			awk '$1=="'${sample}'" \
				{print $0 "\n" "\n"}' \
			${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt \
				| head -n 1 \
			>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt
		done

		sleep 2s

		mail -s "FAILED JOBS: ${OUTPUT_DIR}: ${SAMPLE_SHEET_FILE_NAME}" \
			${SEND_TO} \
		< ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

	else
		# CONSTRUCT MESSAGE TO BE SENT SUMMARIZING THE FAILED JOBS
			printf "SO BAD THINGS HAPPENED AND THE TEMP FILES WILL NOT BE DELETED FOR:\n" \
				>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "${SAMPLE_SHEET}\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "FOR PROJECT:\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "${OUTPUT_DIR}\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "SOMEWHAT FULL LISTING OF FAILED JOBS ARE HERE:\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "###################################################################\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "BELOW ARE THE SAMPLES AND THE MINIMUM NUMBER OF JOBS THAT FAILED PER SAMPLE:\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "###################################################################\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			egrep -v "CONCORDANCE" ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt \
				| awk 'BEGIN {OFS="\t"} \
					NF==6 \
					{print $1}' \
				| sort \
				| singularity exec ${ALIGNMENT_CONTAINER} datamash \
					-g 1 \
					count 1 \
			>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "###################################################################\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "FOR THE SAMPLES THAT HAVE FAILED JOBS, THIS IS ROUGHLY THE FIRST JOB THAT FAILED FOR EACH SAMPLE:\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "###################################################################\n" \
				>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			printf "SM_TAG NODE JOB_NAME USER EXIT LOG_FILE\n" \
				| sed 's/ /\t/g' \
			>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

		for sample in \
			$(awk 'BEGIN {OFS="\t"} \
				NF==6 \
				{print $1}' \
			${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt \
				| sort \
				| uniq);
		do
			awk '$1=="'${sample}'" \
				{print $0 "\n" "\n"}' \
			${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt \
				| head -n 1 \
			>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt
		done

		sleep 2s

		mail -s "FAILED JOBS: ${OUTPUT_DIR}: ${SAMPLE_SHEET_FILE_NAME}" \
			${SEND_TO} \
		< ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

	fi

	sleep 2s

####################################################
##### Clean up the Wall Clock minutes tracker. #####
####################################################

	# clean up records that are malformed
	# only keep jobs that ran longer than 3 minutes

		awk 'BEGIN {FS=",";OFS=","} \
			$1~/^[A-Z 0-9]/&&$2!=""&&$3!=""&&$4!=""&&$5!=""&&$6!=""&&$7==""&&$5!~/A-Z/&&$6!~/A-Z/&&($6-$5)>180 \
		{print $1,$2,$3,$4,$5,$6,($6-$5)/60,strftime("%F",$5),strftime("%F",$6),strftime("%F.%H-%M-%S",$5),strftime("%F.%H-%M-%S",$6)}' \
		${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}".WALL.CLOCK.TIMES.csv" \
		| sed 's/_'"${OUTPUT_DIR}"'/,'"${OUTPUT_DIR}"'/g' \
		| awk 'BEGIN {print "SAMPLE,PROJECT,TASK_GROUP,TASK,HOST,EPOCH_START,EPOCH_END,WC_MIN,START_DATE,END_DATE,TIMESTAMP_START,TIMESTAMP_END"} \
		{print $0}' \
		>| ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.WALL.CLOCK.TIMES.FIXED.csv

# put a stamp as to when the run was done

	echo Project finished at `date` >> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/PROJECT_START_END_TIMESTAMP.txt

# this is black magic that I don't know if it really helps. was having problems with getting the emails to send so I put a little delay in here.

	sleep 2s
