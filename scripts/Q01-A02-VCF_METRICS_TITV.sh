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
	REF_DICT=$7
	TITV_BED=$8
		TITV_BED_NAME=$(basename ${TITV_BED} .bed)
	DBSNP_129=$9
	THREADS=${10}
	SAMPLE_SHEET=${11}
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=${12}

# filter to variants only for a sample

START_VCF_METRICS_TITV=`date '+%s'`

	# construct command line

		CMD="singularity exec ${ALIGNMENT_CONTAINER} java -jar"
			CMD=${CMD}" /gatk/gatk.jar"
		CMD=${CMD}" CollectVariantCallingMetrics"
			CMD=${CMD}" --INPUT ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/VCF/FILTERED_ON_BAIT/${SM_TAG}.VARIANT_SITES.vcf" \
			CMD=${CMD}" --DBSNP ${DBSNP_129}"
			CMD=${CMD}" --SEQUENCE_DICTIONARY ${REF_DICT}"
			CMD=${CMD}" --TARGET_INTERVALS ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}-${TITV_BED_NAME}-picard.bed"
			CMD=${CMD}" --THREAD_COUNT ${THREADS}"
		CMD=${CMD}" --OUTPUT ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/VCF_METRICS/${SM_TAG}_TITV"
		CMD=${CMD}" &&"
		CMD=${CMD}" mv -v"
			CMD=${CMD}" ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/VCF_METRICS/${SM_TAG}_TITV.variant_calling_detail_metrics"
			CMD=${CMD}" ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/VCF_METRICS/${SM_TAG}_TITV.variant_calling_detail_metrics.txt"
		CMD=${CMD}" &&"
		CMD=${CMD}" mv -v"
			CMD=${CMD}" ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/VCF_METRICS/${SM_TAG}_TITV.variant_calling_summary_metrics"
			CMD=${CMD}" ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/VCF_METRICS/${SM_TAG}_TITV.variant_calling_summary_metrics.txt"

	# write command line to file and execute the command line

		echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${SM_TAG}_command_lines.txt
		echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${SM_TAG}_command_lines.txt
		echo ${CMD} | bash

	# check the exit signal at this point.

		SCRIPT_STATUS=`echo $?`

		# if exit does not equal 0 then exit with whatever the exit signal is at the end.
		# also write to file that this job failed

			if [ "${SCRIPT_STATUS}" -ne 0 ]
				then
					echo ${SM_TAG} ${HOSTNAME} ${JOB_NAME} ${USER} ${SCRIPT_STATUS} ${SGE_STDERR_PATH} \
					>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt
					exit ${SCRIPT_STATUS}
			fi

END_VCF_METRICS_TITV=`date '+%s'`

# write out timing metrics to file

	echo ${SM_TAG}_${OUTPUT_DIR},S.01,VCF_METRICS_TITV,${HOSTNAME},${START_VCF_METRICS_TITV},${END_VCF_METRICS_TITV} \
	>> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.WALL.CLOCK.TIMES.csv

# exit with the signal from the program

	exit ${SCRIPT_STATUS}
