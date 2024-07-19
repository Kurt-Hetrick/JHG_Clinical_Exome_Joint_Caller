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

	CODING_BED=$6
		CODING_BED_NAME=$(basename ${CODING_BED} .bed)
		CODING_MD5=$(md5sum ${CODING_BED} | cut -c 1-7)
	# note: since the coding bed file is supposed to be static.
	# i'm tracking it by creating a md5 and applying it to the file name
	# which gets captured by the command line output
	# i don't care how the bed file is tracked when changes are made, just that it is tracked.
	TARGET_BED=$7
		TARGET_BED_NAME=$(basename ${TARGET_BED} .bed)
	BAIT_BED=$8
		BAIT_BED_NAME=$(basename ${BAIT_BED} .bed)
	TITV_BED=$9
		TITV_BED_NAME=$(basename ${TITV_BED} .bed)
	CYTOBAND_BED=${10}
	REF_GENOME=${11}
	REF_DICT=${12}
	PADDING_LENGTH=${13}
	GVCF_PAD=${14}

# FIX AND PAD THE CODING BED FILE
	# make sure that there is EOF
	# remove CARRIAGE RETURNS
	# CONVERT VARIABLE LENGTH WHITESPACE FIELD DELIMETERS TO SINGLE TAB.
	# PAD THE REFSEQ CODING BED FILE BY THE PADDING LENGTH
	# remove chr prefix
	# filter to karyotypic chromosomes
	# remove annotation fields

		awk 1 ${CODING_BED} \
			| sed 's/\r//g' \
			| sed -r 's/[[:space:]]+/\t/g' \
			| awk 'BEGIN {OFS="\t"} \
				{print $1,$2-"'${PADDING_LENGTH}'",$3+"'${PADDING_LENGTH}'"}' \
			| sed 's/^chr//g' \
			| egrep "^[0-9]|^X|^Y" \
		>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}_${CODING_BED_NAME}-${CODING_MD5}-${PADDING_LENGTH}-BP-PAD.bed

# FIX AND PAD THE TARGET BED FILE
	# make sure that there is EOF
	# remove CARRIAGE RETURNS
	# CONVERT VARIABLE LENGTH WHITESPACE FIELD DELIMETERS TO SINGLE TAB.
	# PAD THE TARGET BED FILE BY THE PADDING LENGTH
	# remove chr prefix
	# filter to karyotypic chromosomes
	# THIS IS FOR SLICING

		awk 1 ${TARGET_BED} \
			| sed 's/\r//g' \
			| sed -r 's/[[:space:]]+/\t/g' \
			| awk 'BEGIN {OFS="\t"} \
				{print $1,$2-"'${PADDING_LENGTH}'",$3+"'${PADDING_LENGTH}'"}' \
			| sed 's/^chr//g' \
			| egrep "^[0-9]|^X|^Y" \
		>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}_${TARGET_BED_NAME}-${PADDING_LENGTH}-BP-PAD.bed

# FIX THE CODING BED FILE. THIS IS TO BE COMBINED WITH THE CODING BED FILE
# AND THEN PADDED BY 250 BP AND THEN MERGED (FOR OVERLAPPING INTERVALS) FOR GVCF CREATION.
	# FOR DATA PROCESSING AND METRICS REPORTS AS WELL.
		# make sure that there is EOF
		# remove CARRIAGE RETURNS
		# CONVERT VARIABLE LENGTH WHITESPACE FIELD DELIMETERS TO SINGLE TAB.
		# remove chr prefix
		# filter to karyotypic chromosomes

			awk 1 ${CODING_BED} \
				| sed 's/\r//g' \
				| sed -r 's/[[:space:]]+/\t/g' \
				| sed 's/^chr//g' \
				| egrep "^[0-9]|^X|^Y" \
			>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}-${CODING_BED_NAME}-${CODING_MD5}.bed

# FIX AND PAD THE ANNOTATED CODING BED FILE
	# make sure that there is EOF
	# remove CARRIAGE RETURNS
	# CONVERT VARIABLE LENGTH WHITESPACE FIELD DELIMETERS TO SINGLE TAB.
	# remove chr prefix
	# filter to karyotypic chromosomes

		awk 1 ${CODING_BED} \
			| sed 's/\r//g' \
			| sed -r 's/[[:space:]]+/\t/g' \
			| sed 's/^chr//g' \
			| egrep "^[0-9]|^X|^Y" \
			| awk 'BEGIN {OFS="\t"} \
				{print $1,$2-"'${PADDING_LENGTH}'",$3+"'${PADDING_LENGTH}'",$4,$5,$6,$7}' \
		>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}_${CODING_BED_NAME}-${CODING_MD5}-${PADDING_LENGTH}-BP-PAD-ANNOTATED.bed

# FIX THE BAIT BED FILE. THIS IS TO BE COMBINED WITH THE BAIT BED FILE AND THEN PADDED BY 250 BP
# AND THEN MERGED (FOR OVERLAPPING INTERVALS) FOR GVCF CREATION.
	# FOR DATA PROCESSING AND METRICS REPORTS AS WELL.
		# make sure that there is EOF
		# remove CARRIAGE RETURNS
		# CONVERT VARIABLE LENGTH WHITESPACE FIELD DELIMETERS TO SINGLE TAB.
		# remove chr prefix
		# filter to karyotypic chromosomes

			awk 1 ${BAIT_BED} \
				| sed 's/\r//g' \
				| sed -r 's/[[:space:]]+/\t/g' \
				| sed 's/^chr//g' \
				| egrep "^[0-9]|^X|^Y" \
			>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}-${BAIT_BED_NAME}.bed

# FIX THE TITV BED FILE FOR DATA PROCESSING AND METRICS REPORTS.
	# make sure that there is EOF
	# remove CARRIAGE RETURNS
	# CONVERT VARIABLE LENGTH WHITESPACE FIELD DELIMETERS TO SINGLE TAB.
	# remove chr prefix
	# filter to karyotypic chromosomes

		awk 1 ${TITV_BED} \
			| sed 's/\r//g' \
			| sed -r 's/[[:space:]]+/\t/g' \
			| sed 's/^chr//g' \
			| egrep "^[0-9]|^X|^Y" \
		>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}-${TITV_BED_NAME}.bed

# THE GVCF BED FILE IS THE CONCATENATION OF THE CIDR TWIST BAIT BED FILE
## AND THE CODING BED FILE WHICH IS REFSEQ SELECT CDS AND MISSING OMIM.
# THIS IS PADDED WITH 250 BP AND THEN MERGED FOR OVERLAPPING REGIONS.

	cat ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}-${CODING_BED_NAME}-${CODING_MD5}.bed \
	${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}-${BAIT_BED_NAME}.bed \
		| sort \
			-k 1,1 \
			-k 2,2n \
			-k 3,3n \
		| awk 'BEGIN {OFS="\t"} \
			{print $1,$2-"'${GVCF_PAD}'",$3+"'${GVCF_PAD}'"}' \
		| singularity exec ${ALIGNMENT_CONTAINER} bedtools \
			merge \
			-i - \
	>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}-${BAIT_BED_NAME}-${CODING_BED_NAME}-${CODING_MD5}-${GVCF_PAD}-BP-PAD-GVCF.bed

# Format the cytoband file.
# strip out the "chr" prefix from the chromsome name
# print the chromsome, start, end, the first character of the cytoband (to get the chromosome arm).
# the file is already sorted correctly so group by chromosome and chromosome arm and print the first start and last end
	# for the chromosome/arm combination
# print CHROMOSOME, START, END, ARM (TAB DELIMITED) TO MAKE A BED FILE.

	sed 's/^chr//g' ${CYTOBAND_BED} \
		| awk 'BEGIN {OFS="\t"} \
			{print $1,$2,$3,substr($4,0,1)}' \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			-s \
			-g 1,4 \
			first 2 \
			last 3 \
		| awk 'BEGIN {OFS="\t"} \
			{print $1,$3,$4,$2}' \
	>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}.CHROM_ARM.bed

# MAKE PICARD INTERVAL FILES (1-based start)
# ti/tv bed is used as the target since it shouldn't change
	# GRAB THE SEQUENCING DICTIONARY FORM THE ".dict" file in the directory where the reference genome is located
	# then concatenate with the fixed bed file.
	# add 1 to the start
	# picard interval needs strand information and a locus name
		# made everything plus stranded b/c i don't think this information is used
		# constructed locus name with chr name, start+1, stop

	# bait bed

		(grep "^@SQ" ${REF_DICT} \
			; awk 'BEGIN {OFS="\t"} \
				{print $1,($2+1),$3,"+",$1"_"($2+1)"_"$3}' \
			${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}-${BAIT_BED_NAME}.bed) \
		>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}-${BAIT_BED_NAME}-picard.bed

	# target-TITV bed

		(grep "^@SQ" ${REF_DICT} \
			; awk 'BEGIN {OFS="\t"} \
				{print $1,($2+1),$3,"+",$1"_"($2+1)"_"$3}' \
			${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}-${TITV_BED_NAME}.bed) \
		>| ${CORE_PATH}/${OUTPUT_DIR}/TEMP/${FAMILY}-${TITV_BED_NAME}-picard.bed
