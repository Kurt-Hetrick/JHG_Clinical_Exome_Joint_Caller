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

	GATK_3_7_0_CONTAINER=$1
	CORE_PATH=$2

	PROJECT=$3
	OUTPUT_DIR=$4
	FAMILY=$5
	REF_GENOME=$6
	DBSNP=$7
	CHROMOSOME=$8
	CONTROL_REPO=$9
	CONTROL_DATA_SET_FILE=${10}
	SAMPLE_SHEET=${11}
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=${12}

# start joint calling the family with the controls by intervals per chromosome

START_GENOTYPE_GVCF=`date '+%s'`

	# construct command line

		CMD="singularity exec ${GATK_3_7_0_CONTAINER} java -jar"
			CMD=${CMD}" /usr/GenomeAnalysisTK.jar"
		CMD=${CMD}" --analysis_type GenotypeGVCFs"
			CMD=${CMD}" --reference_sequence ${REF_GENOME}"
			CMD=${CMD}" --disable_auto_index_creation_and_locking_when_reading_rods"
			CMD=${CMD}" --logging_level ERROR"
			CMD=${CMD}" --intervals ${CHROMOSOME}"
			CMD=${CMD}" --dbsnp ${DBSNP}"
			CMD=${CMD}" --annotateNDA"
			CMD=${CMD}" --includeNonVariantSites"
			CMD=${CMD}" --annotation FractionInformativeReads"
			CMD=${CMD}" --annotation StrandBiasBySample"
			CMD=${CMD}" --annotation StrandAlleleCountsBySample"
			CMD=${CMD}" --variant ${CONTROL_REPO}/${CONTROL_DATA_SET_FILE}"
			CMD=${CMD}" --variant ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${FAMILY}.gvcf.list"
		CMD=${CMD}" --out ${CORE_PATH}/${OUTPUT_DIR}/TEMP/CONTROLS_PLUS_${FAMILY}.RAW.${CHROMOSOME}.vcf"

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

END_GENOTYPE_GVCF=`date '+%s'`

# write out timing metrics to file

	echo ${FAMILY}_${OUTPUT_DIR},F01,GENOTYPE_GVCF_${CHROMOSOME},${HOSTNAME},${START_GENOTYPE_GVCF},${END_GENOTYPE_GVCF} \
	>> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.WALL.CLOCK.TIMES.csv

# exit with the signal from the program

	exit ${SCRIPT_STATUS}
