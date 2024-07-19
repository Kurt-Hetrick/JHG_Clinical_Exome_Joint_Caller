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
	TARGET_BED=$6
		TARGET_BED_NAME=$(basename ${TARGET_BED} .bed)
		TARGET_MD5=$(md5sum ${TARGET_BED} | cut -c 1-7)
	PADDING_LENGTH=$7
	SAMPLE_SHEET=$8
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=$9

## gather up vcf files that have had extra annotations added to them

START_FILTER_FAMILY_TO_TARGET_PLUS_PAD=`date '+%s'`

	# construct command line

		CMD="singularity exec ${ALIGNMENT_CONTAINER} bedtools"
		CMD=${CMD}" intersect"
			CMD=${CMD}" -header"
			CMD=${CMD}" -a ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}.VQSR.ANNOTATED.JUST_FAMILY.vcf.gz"
			CMD=${CMD}" -b ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}_${TARGET_BED_NAME}-${PADDING_LENGTH}-BP-PAD.bed"
		CMD=${CMD}" | singularity exec ${ALIGNMENT_CONTAINER} bgzip"
			CMD=${CMD}" -@ ${THREADS}"
			CMD=${CMD}" -c"
		CMD=${CMD}" >| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}.VQSR.ANNOTATED.ALL.SITES.TARGET.vcf.gz"
		CMD=${CMD}" &&"
		CMD=${CMD}" singularity exec ${ALIGNMENT_CONTAINER} tabix"
			CMD=${CMD}" -p vcf"
			CMD=${CMD}" -f"
		CMD=${CMD}" ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}.VQSR.ANNOTATED.ALL.SITES.TARGET.vcf.gz"

	# write command line to file and execute the command line

		echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
		echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
		echo ${CMD} | bash

	# check the exit signal at this point.

		SCRIPT_STATUS=`echo $?`

		# if exit does not equal 0 then exit with whatever the exit signal is at the end.
		# also write to file that this job failed

			if [ "${SCRIPT_STATUS}" -ne 0 ]
				then
					echo ${FAMILY} ${HOSTNAME} ${JOB_NAME} ${USER} ${SCRIPT_STATUS} ${SGE_STDERR_PATH} \
					>> ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt
					exit ${SCRIPT_STATUS}
			fi

END_FILTER_FAMILY_TO_TARGET_PLUS_PAD=`date '+%s'`

# write out timing metrics to file

	echo ${FAMILY}_${OUTPUT_DIR},N01,FILTER_FAMILY_TO_TARGET_PLUS_PAD,${HOSTNAME},${START_FILTER_FAMILY_TO_TARGET_PLUS_PAD},${END_FILTER_FAMILY_TO_TARGET_PLUS_PAD} \
	>> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.WALL.CLOCK.TIMES.csv

# exit with the signal from the program

	exit ${SCRIPT_STATUS}
