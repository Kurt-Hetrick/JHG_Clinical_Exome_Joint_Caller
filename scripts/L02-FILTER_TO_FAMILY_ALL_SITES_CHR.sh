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
	REF_GENOME=$6
	CHROMOSOME=$7
	SAMPLE_SHEET=$8
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=$9

# Filter to just on all of the variants all

START_FILTER_TO_FAMILY_ALL_SITES=`date '+%s'`

	# construct command line

		CMD="singularity exec ${ALIGNMENT_CONTAINER} java -jar"
			CMD=${CMD}" /gatk/gatk.jar"
		CMD=${CMD}" SelectVariants"
			CMD=${CMD}" --remove-unused-alternates"
			CMD=${CMD}" --keep-original-ac"
			CMD=${CMD}" --keep-original-dp"
			CMD=${CMD}" --variant ${CORE_PATH}/${OUTPUT_DIR}/TEMP/CONTROLS_PLUS_${FAMILY}.VQSR.ANNOTATED.${CHROMOSOME}.vcf"
			CMD=${CMD}" --sample-name ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${FAMILY}.sample.args"
		CMD=${CMD}" --output ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}.VQSR.ANNOTATED.JUST_FAMILY.${CHROMOSOME}.vcf"

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

END_FILTER_TO_FAMILY_ALL_SITES=`date '+%s'`

# write out timing metrics to file

	echo ${FAMILY}_${OUTPUT_DIR},L01,FILTER_TO_FAMILY_ALL_SITES_${CHROMOSOME},${HOSTNAME},${START_FILTER_TO_FAMILY_ALL_SITES},${END_FILTER_TO_FAMILY_ALL_SITES} \
	>> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.WALL.CLOCK.TIMES.csv

# exit with the signal from the program

	exit ${SCRIPT_STATUS}
