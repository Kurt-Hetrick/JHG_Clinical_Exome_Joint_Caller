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
	BAIT_BED=$7
	SAMPLE_SHEET=$8
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=$9

# gather up per chromosome family only all sites vcf.

START_GATHER_FAMILY_ALL_SITES=`date '+%s'`

	# construct command line

		CMD="singularity exec ${GATK_3_7_0_CONTAINER} java -cp"
			CMD=${CMD}" /usr/GenomeAnalysisTK.jar"
		CMD=${CMD}" org.broadinstitute.gatk.tools.CatVariants"
			CMD=${CMD}" --reference ${REF_GENOME}"
			CMD=${CMD}" --assumeSorted"

			# grab uniq list of chromosomes from bait bed file and sort by karyotype (natural) order (sort -V)

			for CHROMOSOME in $(sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' ${BAIT_BED} \
									| sed -r 's/[[:space:]]+/\t/g' \
									| sed 's/chr//g' \
									| egrep "^[0-9]|^X|^Y" \
									| cut -f 1 \
									| sort \
									| uniq \
									| sort -V) ;
			do
				CMD=${CMD}" --variant ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}.VQSR.ANNOTATED.JUST_FAMILY.${CHROMOSOME}.vcf"
			done

		CMD=${CMD}" --outputFile ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}.VQSR.ANNOTATED.JUST_FAMILY.vcf.gz"

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

END_GATHER_FAMILY_ALL_SITES=`date '+%s'`

# write out timing metrics to file

	echo ${FAMILY}_${OUTPUT_DIR},M01,GATHER_FAMILY_ALL_SITES,${HOSTNAME},${START_GATHER_FAMILY_ALL_SITES},${END_GATHER_FAMILY_ALL_SITES} \
	>> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/${OUTPUT_DIR}.WALL.CLOCK.TIMES.csv

# exit with the signal from the program

	exit ${SCRIPT_STATUS}
