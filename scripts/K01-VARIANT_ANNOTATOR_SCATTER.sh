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
	PED_FILE=$3

	PROJECT=$4
	OUTPUT_DIR=$5
	FAMILY=$6
	REF_GENOME=$7
	CHROMOSOME=$8
	PHASE3_1KG_AUTOSOMES=$9
	THREADS=${10}
	SAMPLE_SHEET=${11}
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=${12}

START_ADD_MORE_ANNOTATION=`date '+%s'`

	# construct command line

		CMD="singularity exec ${GATK_3_7_0_CONTAINER} java -jar"
			CMD=${CMD}" -XX:ParallelGCThreads=${THREADS}"
			CMD=${CMD}" /usr/GenomeAnalysisTK.jar"
		CMD=${CMD}" --analysis_type VariantAnnotator"
			CMD=${CMD}" --reference_sequence ${REF_GENOME}"
			CMD=${CMD}" --disable_auto_index_creation_and_locking_when_reading_rods"
			CMD=${CMD}" --annotation AlleleBalance"
			CMD=${CMD}" --annotation AlleleBalanceBySample"
			CMD=${CMD}" --annotation AlleleCountBySample"
			CMD=${CMD}" --annotation GCContent"
			CMD=${CMD}" --annotation GenotypeSummaries"
			CMD=${CMD}" --annotation HomopolymerRun"
			CMD=${CMD}" --annotation MVLikelihoodRatio"
			CMD=${CMD}" --annotation SampleList"
			CMD=${CMD}" --annotation TandemRepeatAnnotator"
			CMD=${CMD}" --annotation VariantType"
			CMD=${CMD}" --resource:OneKGP ${PHASE3_1KG_AUTOSOMES}"
			CMD=${CMD}" --expression OneKGP.AF"
			CMD=${CMD}" --expression OneKGP.EAS_AF"
			CMD=${CMD}" --expression OneKGP.AMR_AF"
			CMD=${CMD}" --expression OneKGP.AFR_AF"
			CMD=${CMD}" --expression OneKGP.EUR_AF"
			CMD=${CMD}" --expression OneKGP.SAS_AF"
			CMD=${CMD}" --resourceAlleleConcordance"
			CMD=${CMD}" --pedigree ${PED_FILE}"
			CMD=${CMD}" --pedigreeValidationType SILENT"
			CMD=${CMD}" --variant ${CORE_PATH}/${OUTPUT_DIR}/TEMP/CONTROLS_PLUS_${FAMILY}.VQSR.SNP_INDEL.vcf"
			CMD=${CMD}" --intervals ${CORE_PATH}/${OUTPUT_DIR}/TEMP/CONTROLS_PLUS_${FAMILY}.VQSR.SNP_INDEL.vcf"
			CMD=${CMD}" --intervals ${CHROMOSOME}"
			CMD=${CMD}" --interval_set_rule INTERSECTION"
		CMD=${CMD}" --out ${CORE_PATH}/${OUTPUT_DIR}/TEMP/CONTROLS_PLUS_${FAMILY}.VQSR.ANNOTATED.${CHROMOSOME}.vcf"

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

END_ADD_MORE_ANNOTATION=`date '+%s'`

# write out timing metrics to file

	echo ${FAMILY}_${OUTPUT_DIR},K01,VARIANT_ANNOTATOR_${CHROMOSOME},${HOSTNAME},${START_ADD_MORE_ANNOTATION},${END_ADD_MORE_ANNOTATION} \
	>> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.WALL.CLOCK.TIMES.csv

# exit with the signal from the program

	exit ${SCRIPT_STATUS}
