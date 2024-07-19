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
	CODING_BED=$7
		CODING_BED_NAME=$(basename ${CODING_BED} .bed)
		CODING_MD5=$(md5sum ${CODING_BED} | cut -c 1-7)
	SAMPLE_SHEET=$8
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=$9

# FILTER TO PASSING BIALLELIC SNVS IN THE CONTROLS PLUS FAMILY SET

START_FILTER_COHORT_SNV_PASS=`date '+%s'`

	# construct command line

		CMD="singularity exec ${ALIGNMENT_CONTAINER} java -jar"
			CMD=${CMD}" /gatk/gatk.jar"
		CMD=${CMD}" SelectVariants"
			CMD=${CMD}" --reference ${REF_GENOME}"
			CMD=${CMD}" --exclude-filtered"
			CMD=${CMD}" --select-type-to-include SNP"
			CMD=${CMD}" --restrict-alleles-to BIALLELIC"
			CMD=${CMD}" --intervals ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}-${CODING_BED_NAME}-${CODING_MD5}.bed"
			CMD=${CMD}" --variant ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/VCF/RAW/CONTROLS_PLUS_${FAMILY}.VQSR.ANNOTATED.vcf.gz"
		CMD=${CMD}" --output ${CORE_PATH}/${OUTPUT_DIR}/TEMP/VCF_PREP/CONTROLS_PLUS_${FAMILY}.VQSR.ANNOTATED.SNV_ONLY.PASS.BIALLELIC.vcf"

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

END_FILTER_COHORT_SNV_PASS=`date '+%s'`

# write out timing metrics to file

	echo ${FAMILY}_${OUTPUT_DIR},M01,FILTER_COHORT_SNV_ONLY_PASS_BIALLELEIC,${HOSTNAME},${START_FILTER_COHORT_SNV_PASS},${END_FILTER_COHORT_SNV_PASS} \
	>> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.WALL.CLOCK.TIMES.csv

# exit with the signal from the program

	exit ${SCRIPT_STATUS}
