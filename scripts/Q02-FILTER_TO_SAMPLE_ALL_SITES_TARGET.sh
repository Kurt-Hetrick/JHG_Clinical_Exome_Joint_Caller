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
	TARGET_BED=$7
		TARGET_BED_NAME=$(basename ${TARGET_BED} .bed)
	PADDING_LENGTH=$8
	SAMPLE_SHEET=$9
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=${10}

# filter to on target variants for a sample

START_FILTER_TO_SAMPLE_ALL_SITES_TARGET=`date '+%s'`

	# construct command line

		CMD="singularity exec ${ALIGNMENT_CONTAINER} bedtools"
		CMD=${CMD}" intersect"
			CMD=${CMD}" -header"
			CMD=${CMD}" -a ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/VCF/FILTERED_ON_BAIT/${SM_TAG}.ALL_SITES.vcf.gz"
			CMD=${CMD}" -b ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}_${TARGET_BED_NAME}-${PADDING_LENGTH}-BP-PAD.bed"
		CMD=${CMD}" | singularity exec ${ALIGNMENT_CONTAINER} bgzip"
			CMD=${CMD}" -@ ${THREADS}"
			CMD=${CMD}" -c"
		CMD=${CMD}" >| ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/VCF/FILTERED_ON_TARGET/${SM_TAG}.ALL_SITES.TARGET.vcf.gz"
		CMD=${CMD}" &&"
		CMD=${CMD}" singularity exec ${ALIGNMENT_CONTAINER} tabix"
			CMD=${CMD}" -p vcf"
			CMD=${CMD}" -f"
		CMD=${CMD}" ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/VCF/FILTERED_ON_TARGET/${SM_TAG}.ALL_SITES.TARGET.vcf.gz"

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

END_FILTER_TO_SAMPLE_ALL_SITES_TARGET=`date '+%s'`

# write out timing metrics to file

	echo ${FAMILY}_${OUTPUT_DIR},Q01,FILTER_TO_SAMPLE_ALL_SITES_TARGET,${HOSTNAME},${START_FILTER_TO_SAMPLE_ALL_SITES_TARGET},${END_FILTER_TO_SAMPLE_ALL_SITES_TARGET} \
	>> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.WALL.CLOCK.TIMES.csv

# exit with the signal from the program

	exit ${SCRIPT_STATUS}
