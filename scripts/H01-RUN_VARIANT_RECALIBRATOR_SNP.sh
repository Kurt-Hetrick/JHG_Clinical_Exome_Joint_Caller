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
	HAPMAP=$8
	OMNI_1KG=$9
	HI_CONF_1KG_PHASE1_SNP=${10}
	SEND_TO=${11}
	SAMPLE_SHEET=${12}
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=${13}

# explicitly state the maximum number of gaussians to start of with
# this is so if vqsr fails, it can be decremented automatically and reattempted.

	MAX_GAUSSIANS="8"

# RUN THE VQSR SNP MODEL

START_VARIANT_RECALIBRATOR_SNP=`date '+%s'`

	# construct command line

		CMD="singularity exec ${GATK_3_7_0_CONTAINER} java -jar"
			CMD=${CMD}" /usr/GenomeAnalysisTK.jar"
		CMD=${CMD}" --analysis_type VariantRecalibrator"
			CMD=${CMD}" --reference_sequence ${REF_GENOME}"
			CMD=${CMD}" --disable_auto_index_creation_and_locking_when_reading_rods"
			CMD=${CMD}" --resource:hapmap,known=false,training=true,truth=true,prior=15.0 ${HAPMAP}"
			CMD=${CMD}" --resource:omni,known=false,training=true,truth=true,prior=12.0 ${OMNI_1KG}"
			CMD=${CMD}" --resource:1000G,known=false,training=true,truth=false,prior=10.0 ${HI_CONF_1KG_PHASE1_SNP}"
			CMD=${CMD}" --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 ${DBSNP}"
			CMD=${CMD}" --mode SNP"
			CMD=${CMD}" --use_annotation QD"
			CMD=${CMD}" --use_annotation MQ"
			CMD=${CMD}" --use_annotation MQRankSum"
			CMD=${CMD}" --use_annotation ReadPosRankSum"
			CMD=${CMD}" --use_annotation FS"
			CMD=${CMD}" --use_annotation SOR"
			CMD=${CMD}" --maxGaussians ${MAX_GAUSSIANS}"
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
		CMD=${CMD}" --recal_file ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/VCF/VQSR/CONTROLS_PLUS_${FAMILY}.HC.SNV.recal"
		CMD=${CMD}" --tranches_file ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/VCF/VQSR/CONTROLS_PLUS_${FAMILY}.HC.SNV.tranches"
		CMD=${CMD}" --rscript_file ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/VCF/VQSR/CONTROLS_PLUS_${FAMILY}.HC.SNV.R"
		# Move the tranches PDF to TEMP so that it can be trashed.
		CMD=${CMD}" &&"
		CMD=${CMD}" mv -v"
			CMD=${CMD}" ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/VCF/VQSR/CONTROLS_PLUS_${FAMILY}.HC.SNV.tranches.pdf"
			CMD=${CMD}" ${CORE_PATH}/${OUTPUT_DIR}/TEMP"

	# execute the command line

		echo ${CMD} | bash

	# capture the exit status

		SCRIPT_STATUS=`echo $?`

	# if vqsr fails then retry by decrementing the number of max gaussians by 1 until you get to 1
	# if it still does not work after setting it to 1 then stop trying

		if [ ${SCRIPT_STATUS} -ne 0 ]
			then
				until [[ ${SCRIPT_STATUS} -eq 0 || ${MAX_GAUSSIANS} -le 1 ]]
				do
					NEW_MAX_GAUSSIANS=$[${MAX_GAUSSIANS}-1]
					CMD=$(echo ${CMD} | sed 's/ --maxGaussians '"${MAX_GAUSSIANS}"'/ --maxGaussians '"${NEW_MAX_GAUSSIANS}"'/g')
					MAX_GAUSSIANS=${NEW_MAX_GAUSSIANS}
					# CMD=${CMD}" --maxGaussians ${MAX_GAUSSIANS}"
					echo ${CMD} | bash
					SCRIPT_STATUS=`echo $?`
				done
		fi

	# if it fails the first time but ultimately works send a notification saying that the parameter has changed and that the methods document needs to change for release
	# if it ends up failing altogether send a notification saying that I need to look at it.
	# will probably have to start with removing the MQ annotation and go from there.

		if [[ ${SCRIPT_STATUS} -eq 0 && ${MAX_GAUSSIANS} -ge 1 && ${MAX_GAUSSIANS} -lt 8 ]]
			then
				printf "The number of max Gaussians has been changed to ${MAX_GAUSSIANS} for\n \
				OUTPUT_DIR:\n \
				${OUTPUT_DIR}\n \
				FAMILY:\n \
				${FAMILY}" \
				| mail -s "SNP VariantRecalibrator parameter changed for ${OUTPUT_DIR} for ${FAMILY}" \
				${SEND_TO}
			elif [ ${SCRIPT_STATUS} -ne 0 ]
				then
					printf "This has failed SNP VariantRecalibrator and Kurt needs to look at this for:\n \
					OUTPUT_DIR:\n \
					${OUTPUT_DIR}\n \
					FAMILY:\n \
					${FAMILY}" \
					| mail -s "SNP VariantRecalibrator FAILED for ${OUTPUT_DIR} for ${FAMILY}" \
					${SEND_TO}
			else
			:
		fi

	# write command line to file and execute the command line

		echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
		echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt

END_VARIANT_RECALIBRATOR_SNP=`date '+%s'`

# write out timing metrics to file

	echo ${FAMILY}_${OUTPUT_DIR},H01,VARIANT_RECALIBRATOR_SNP,${HOSTNAME},${START_VARIANT_RECALIBRATOR_SNP},${END_VARIANT_RECALIBRATOR_SNP} \
	>> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.WALL.CLOCK.TIMES.csv

# exit with the signal from the program

	exit ${SCRIPT_STATUS}
