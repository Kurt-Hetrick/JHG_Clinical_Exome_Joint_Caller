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
	PCA_RELATEDNESS_CONTAINER=$2
	CORE_PATH=$3

	PROJECT=$4
	OUTPUT_DIR=$5
	FAMILY=$6
	REF_GENOME=$7
	PED_FILE=$8
	CONTROL_PED_FILE=$9
	SAMPLE_SHEET=${10}
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=${11}

# Format the control ped file in case molly or somebody ever changes it and screws up the format

	awk 1 ${CONTROL_PED_FILE} \
		| sed 's/\r//g' \
		| sed -r 's/[[:space:]]+/\t/g' \
	>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/CONTROL_PED_FILE_FOR_${FAMILY}.ped

# Concatenate the control ped file with the ped information for the family

	awk 1 ${PED_FILE} \
		| sed 's/\r//g' \
		| sed -r 's/[[:space:]]+/\t/g' \
		| awk '$1=="'${FAMILY}'" \
			{print $0}' \
		| cat ${CORE_PATH}/${OUTPUT_DIR}/TEMP/CONTROL_PED_FILE_FOR_${FAMILY}.ped /dev/stdin \
	>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/VCF_PREP/CONTROLS_PLUS_${FAMILY}.ped

#############################################################################
##### 01. Subset BiAllelic SNVs with global MAF from 1000 genomes > 0.1 #####
#############################################################################

### First Reformat the OneKGP.AF tag to OneKGP_AF
### b/c GATK will not recognize foo.bar correctly and will just look for foo.

	# construct command line

		CMD="sed 's/OneKGP.AF/OneKGP_AF/g'"
			CMD=${CMD}" ${CORE_PATH}/${OUTPUT_DIR}/TEMP/VCF_PREP/CONTROLS_PLUS_${FAMILY}.VQSR.ANNOTATED.SNV_ONLY.PASS.BIALLELIC.vcf"
		CMD=${CMD}" >| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/VCF_PREP/${FAMILY}.VQSR.PASS.SNV.reformat.vcf"

			# write command line to file and execute the command line

				echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo ${CMD} | bash

			# check the exit signal at this point.

				SCRIPT_STATUS=`echo $?`

### Extract SNVS with One thousand genome MAF > 0.1 (10 percent)

	# construct command line

		CMD="singularity exec ${GATK_3_7_0_CONTAINER} java -jar"
			CMD=${CMD}" /usr/GenomeAnalysisTK.jar"
		CMD=${CMD}" --analysis_type SelectVariants"
			CMD=${CMD}" --reference_sequence ${REF_GENOME}"
			CMD=${CMD}" --selectexpressions 'OneKGP_AF > 0.1'"
			CMD=${CMD}" --variant ${CORE_PATH}/${OUTPUT_DIR}/TEMP/VCF_PREP/${FAMILY}.VQSR.PASS.SNV.reformat.vcf"
		CMD=${CMD}" --out ${CORE_PATH}/${OUTPUT_DIR}/TEMP/VCF_PREP/${FAMILY}.VQSR.PASS.SNV.OneKG_AF.vcf"

			# write command line to file and execute the command line

				echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo ${CMD} | bash

			# check the exit signal at this point (not sure if this actually works the way i hope).

				SCRIPT_STATUS=$((SCRIPT_STATUS + $?))

#########################################
##### 02. Convert vcf to PLINK file #####
#########################################

	# construct command line

		CMD="singularity exec ${PCA_RELATEDNESS_CONTAINER} vcftools"
			CMD=${CMD}" --vcf ${CORE_PATH}/${OUTPUT_DIR}/TEMP/VCF_PREP/${FAMILY}.VQSR.PASS.SNV.OneKG_AF.vcf"
			CMD=${CMD}" --plink-tped"
		CMD=${CMD}" --out ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV"

			# write command line to file and execute the command line

				echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo ${CMD} | bash

			# check the exit signal at this point (not sure if this actually works the way i hope).

				SCRIPT_STATUS=$((SCRIPT_STATUS + $?))

# vcftools does not know the information here since it is just parsing the vcf file...
# so Hua is just moving this file out of the way
# The next step after this is really reordering the ped file (here it is called tfam)
# to match the sample order in the vcf file

	mv -v ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.tfam \
	${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.tfam.bak

# Storing the path to concantenated ped file as a variable

	CONTROL_PED_FILE_FOR_FAMILY=`echo ${CORE_PATH}/${OUTPUT_DIR}/TEMP/VCF_PREP/CONTROLS_PLUS_${FAMILY}.ped`

## Replace the tfam file with right pedigree info and in the sample order in the vcf file ##

	zgrep -m 1 "^#CHROM" ${CORE_PATH}/${OUTPUT_DIR}/TEMP/VCF_PREP/CONTROLS_PLUS_${FAMILY}.VQSR.ANNOTATED.SNV_ONLY.PASS.BIALLELIC.vcf \
		| sed 's/\t/\n/g' \
		| awk 'NR>9' \
		| awk '{print "awk \x27 $2==\x22"$0"\x22 \x27","'${CONTROL_PED_FILE_FOR_FAMILY}'"}' \
		| bash \
	>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.tfam

####################################################
##### 03.A Run Relatedness check using KING1.9 #####
####################################################

##	Pedigree file needs to be modified, a final list of Coriell samples needs to be considered ##

	# construct command line

		CMD="singularity exec ${PCA_RELATEDNESS_CONTAINER} plink"
			CMD=${CMD}" --noweb"
			CMD=${CMD}" --tfile ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV"
			CMD=${CMD}" --maf 0.1"
			CMD=${CMD}" --make-bed"
		CMD=${CMD}" --out ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.bin"

			# write command line to file and execute the command line

				echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo ${CMD} | bash

			# check the exit signal at this point (not sure if this actually works the way i hope).

				SCRIPT_STATUS=$((SCRIPT_STATUS + $?))

	# construct command line

		CMD="singularity exec ${PCA_RELATEDNESS_CONTAINER} king"
			CMD=${CMD}" -b ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.bin.bed"
			CMD=${CMD}" --kinship"
			CMD=${CMD}" --IBS"
		CMD=${CMD}" --prefix ${CORE_PATH}/${OUTPUT_DIR}/TEMP/KING/${FAMILY}.VQSR.PASS.SNV.KinshipIBS"

			# write command line to file and execute the command line

				echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo ${CMD} | bash

			# check the exit signal at this point (not sure if this actually works the way i hope).

				SCRIPT_STATUS=$((SCRIPT_STATUS + $?))

# this is for homogenous populations, but this will never be the case

	# construct command line

		CMD="singularity exec ${PCA_RELATEDNESS_CONTAINER} king"
			CMD=${CMD}" -b ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.bin.bed"
			CMD=${CMD}" --homo"
			CMD=${CMD}" --showIBD"
			CMD=${CMD}" --minMAF 0.1"
		CMD=${CMD}" --prefix ${CORE_PATH}/${OUTPUT_DIR}/TEMP/KING/${FAMILY}.VQSR.PASS.SNV.HomoIBD"

			# write command line to file and execute the command line

				echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo ${CMD} | bash

			# check the exit signal at this point (not sure if this actually works the way i hope).

				SCRIPT_STATUS=$((SCRIPT_STATUS + $?))

awk '$4!=0 {print $0}' ${CORE_PATH}/${OUTPUT_DIR}/TEMP/KING/${FAMILY}.VQSR.PASS.SNV.HomoIBD.kin \
>| ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/RELATEDNESS/${FAMILY}.VQSR.PASS.SNV.HomoIBD.kin.final.txt

awk '$4!=0 {print $0}' ${CORE_PATH}/${OUTPUT_DIR}/TEMP/KING/${FAMILY}.VQSR.PASS.SNV.HomoIBD.kin0 \
>| ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/RELATEDNESS/${FAMILY}.VQSR.PASS.SNV.HomoIBD.kin0.final.txt

# format and concatenate kinship ibs output

	(awk 'BEGIN {print "FID1","ID1","FID2","ID2","Phi","N_IBS0","N_IBS1","N_IBS2","IBS","SE_IBS",\
		"N_HetHet","N_Het1","N_Het2","Distance","SE_Dist","Kinship","Error"} \
		NR>1 \
		{print $1,$2,$1,$3,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17}' \
	${CORE_PATH}/${OUTPUT_DIR}/TEMP/KING/${FAMILY}.VQSR.PASS.SNV.KinshipIBS.ibs ;
	awk 'NR>1' ${CORE_PATH}/${OUTPUT_DIR}/TEMP/KING/${FAMILY}.VQSR.PASS.SNV.KinshipIBS.ibs0 \
		| awk '$15>0.06 \
			{print $1,$2,$3,$4,"0",$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,"1"} \
			$15<=0.06 \
			{print $1,$2,$3,$4,"0",$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,"0"}') \
		| sed 's/ /\t/g' \
	>| ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/RELATEDNESS/${FAMILY}.VQSR.PASS.SNV.KinshipIBS.txt

###########################################
##### Try PLINK for relatedness check #####
###########################################

	# construct command line

		CMD="singularity exec ${PCA_RELATEDNESS_CONTAINER} plink"
			CMD=${CMD}" --noweb"
			CMD=${CMD}" --maf 0.1"
			CMD=${CMD}" --genome"
			CMD=${CMD}" --genome-full"
			CMD=${CMD}" --bfile ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.bin"
		CMD=${CMD}" --out ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.genome"

			# write command line to file and execute the command line

				echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo ${CMD} | bash

			# check the exit signal at this point (not sure if this actually works the way i hope).

				SCRIPT_STATUS=$((SCRIPT_STATUS + $?))

############################################################
##### Reformat output to make a better delimited table #####
############################################################

	sed -r 's/^ *//g ; s/[[:space:]]+/\t/g' \
		${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.genome.genome \
	>| ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/RELATEDNESS/${FAMILY}.VQSR.PASS.SNV.PLINK2.final.txt

##################################################
##### 03.B Run PCA using KING1.9 on sunrhel4 #####
##################################################

	# construct command line

		CMD="singularity exec ${PCA_RELATEDNESS_CONTAINER} plink"
			CMD=${CMD}" --noweb"
			CMD=${CMD}" --maf 0.1"
			CMD=${CMD}" --genome"
			CMD=${CMD}" --genome-full"
			CMD=${CMD}" --bfile ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.bin"
		CMD=${CMD}" --out ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.genome"

			# write command line to file and execute the command line

				echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo ${CMD} | bash

			# check the exit signal at this point (not sure if this actually works the way i hope).

				SCRIPT_STATUS=$((SCRIPT_STATUS + $?))

	# construct command line

		CMD="singularity exec ${PCA_RELATEDNESS_CONTAINER} king"
			CMD=${CMD}" -b ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.bin.bed"
			CMD=${CMD}" --mds"
			CMD=${CMD}" --ibs"
		CMD=${CMD}" --prefix ${CORE_PATH}/${OUTPUT_DIR}/TEMP/KING/${FAMILY}.VQSR.PASS.SNV.MDS_IBS"

			# write command line to file and execute the command line

				echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo ${CMD} | bash

			# check the exit signal at this point (not sure if this actually works the way i hope).

				SCRIPT_STATUS=$((SCRIPT_STATUS + $?))

# format and rename output file

	sed -r 's/^ *//g ; s/[[:space:]]+/\t/g' \
		${CORE_PATH}/${OUTPUT_DIR}/TEMP/KING/${FAMILY}.VQSR.PASS.SNV.MDS_IBSpc.ped \
	>| ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/PCA/${FAMILY}.VQSR.PASS.SNV.MDS_IBSpc.ped.final.txt

#############################
##### Try PLINK for PCA #####
#############################

	# construct command line

		CMD="singularity exec ${PCA_RELATEDNESS_CONTAINER} plink"
			CMD=${CMD}" --noweb"
			CMD=${CMD}" --bfile ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.bin"
			CMD=${CMD}" --read-genome ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.genome.genome"
			CMD=${CMD}" --cluster"
			CMD=${CMD}" --mds-plot 4"
		CMD=${CMD}" --out ${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.mds"

			# write command line to file and execute the command line

				echo ${CMD} >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo >> ${CORE_PATH}/${OUTPUT_DIR}/COMMAND_LINES/${FAMILY}_command_lines.txt
				echo ${CMD} | bash

			# check the exit signal at this point (not sure if this actually works the way i hope).

				SCRIPT_STATUS=$((SCRIPT_STATUS + $?))

############################################################
##### Reformat output to make a better delimited table #####
############################################################

	sed -r 's/^ *//g ; s/[[:space:]]+/\t/g' \
		${CORE_PATH}/${OUTPUT_DIR}/TEMP/PLINK/${FAMILY}.VQSR.PASS.SNV.mds.mds \
	>| ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/PCA/${FAMILY}.VQSR.PASS.SNV.mds.PLINK2.final.txt

# exit with the signal from the program

	exit ${SCRIPT_STATUS}
