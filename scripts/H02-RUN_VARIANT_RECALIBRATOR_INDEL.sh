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
	MILLS_1KG_GOLD_INDEL=$7
	SAMPLE_SHEET=$8
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=$9

# RUN THE VQSR SNP MODEL

START_VARIANT_RECALIBRATOR_INDEL=`date '+%s'`

	# construct command line

		CMD="singularity exec ${GATK_3_7_0_CONTAINER} java -jar"
			CMD=${CMD}" /usr/GenomeAnalysisTK.jar"
		CMD=${CMD}" --analysis_type VariantRecalibrator"
			CMD=${CMD}" --reference_sequence ${REF_GENOME}"
			CMD=${CMD}" --disable_auto_index_creation_and_locking_when_reading_rods"
			CMD=${CMD}" --resource:mills,known=true,training=true,truth=true,prior=12.0 ${MILLS_1KG_GOLD_INDEL}"
			CMD=${CMD}" --mode INDEL"
			CMD=${CMD}" --use_annotation QD"
			CMD=${CMD}" --use_annotation MQRankSum"
			CMD=${CMD}" --use_annotation ReadPosRankSum"
			CMD=${CMD}" --use_annotation FS"
			CMD=${CMD}" --use_annotation SOR"
			CMD=${CMD}" --maxGaussians 4"
			CMD=${CMD}" --TStranche 100.0"
			CMD=${CMD}" --TStranche 99.9"
			CMD=${CMD}" --TStranche 99.8"
			CMD=${CMD}" --TStranche 99.7"
			CMD=${CMD}" --TStranche 99.6"
			CMD=${CMD}" --TStranche 99.5"
			CMD=${CMD}" --TStranche 99.4"
			CMD=${CMD}" --TStranche 99.3"
			CMD=${CMD}" --TStranche 99.2"
			CMD=${CMD}" --TStranche 99.1"
			CMD=${CMD}" --TStranche 99.0"
			CMD=${CMD}" --TStranche 98.0"
			CMD=${CMD}" --TStranche 97.0"
			CMD=${CMD}" --TStranche 96.0"
			CMD=${CMD}" --TStranche 95.0"
			CMD=${CMD}" --TStranche 90.0"
			CMD=${CMD}" --input:VCF ${CORE_PATH}/${OUTPUT_DIR}/TEMP/CONTROLS_PLUS_${FAMILY}.RAW.vcf"
		CMD=${CMD}" --recal_file ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/VCF/VQSR/CONTROLS_PLUS_${FAMILY}.HC.INDEL.recal"
		CMD=${CMD}" --tranches_file ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/VCF/VQSR/CONTROLS_PLUS_${FAMILY}.HC.INDEL.tranches"
		CMD=${CMD}" --rscript_file ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/VCF/VQSR/CONTROLS_PLUS_${FAMILY}.HC.INDEL.R"

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

END_VARIANT_RECALIBRATOR_INDEL=`date '+%s'`

# write out timing metrics to file

	echo ${FAMILY}_${OUTPUT_DIR},H01,VARIANT_RECALIBRATOR_INDEL,${HOSTNAME},${START_VARIANT_RECALIBRATOR_INDEL},${END_VARIANT_RECALIBRATOR_INDEL} \
	>> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.WALL.CLOCK.TIMES.csv

# exit with the signal from the program

	exit ${SCRIPT_STATUS}
