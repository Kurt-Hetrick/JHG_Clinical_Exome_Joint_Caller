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
	OUTPUT_DIR=$3
	GIT_LFS_DIR=$4
	THREADS=$5
	SEND_TO=$6
	SUBMIT_STAMP=$7

# RUN md5sum in parallel and write to file

	RUN_MD5_PARALLEL_GIT_LFS_DIR ()
	{
		find ${GIT_LFS_DIR}/JHG_Clinical_Exome_Pipeline/GRCh37 -type f \
			| cut -f 2 \
			| singularity exec ${ALIGNMENT_CONTAINER} parallel \
				--no-notice \
				-j ${THREADS} \
				md5sum {} \
		> ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/md5_pipeline_resources_${OUTPUT_DIR}_${SUBMIT_STAMP}.txt
	}

	RUN_MD5_PARALLEL_GIT_LFS_DIR

# concatenate file generated above with the file generated in the git lfs backed directory previously generated
# sort on the filename and the subfolder that it is in
# then sort on the hash
# group by hash and filename/subfolder and count number of occurences of each combination.
# if a hash/filename/subfolder combo is not seen twice then output what files are seen either once or more than twice.

	cat \
	${CORE_PATH}/${OUTPUT_DIR}/REPORTS/md5_pipeline_resources_${OUTPUT_DIR}_${SUBMIT_STAMP}.txt \
	${GIT_LFS_DIR}/JHG_Clinical_Exome_Pipeline_md5.txt \
		| awk 'BEGIN {OFS="\t"} \
			{print $1,$2}' \
		| awk 'BEGIN {FS="/"} \
			{print $(NF-1) "/" $NF "\t" $0}' \
		| sort \
			-k 1,1 \
			-k 2,2 \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			-g 1,2 \
			count 1 \
			collapse 3 \
		| awk 'BEGIN {print "md5_hash" "\t" "FILES_THAT_ARE_DIFFERENT"} $3!=2 {print $2,$4}' \
	>| ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/md5_diff_JHG_Clinical_Exome_Pipeline_${SUBMIT_STAMP}.txt

# count the number of records in the log file and store a variable to be used in if statement.

	MD5_DIFF=$(wc -l ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/md5_diff_JHG_Clinical_Exome_Pipeline_${SUBMIT_STAMP}.txt \
		| awk '{print $1}')

# If there is a difference (diff file has more lines than just the header)
# send a notification to teams and output the difference to teams.
# Otherwise just print a message to the log file that everything is ok

	if
		[ ${MD5_DIFF} -gt 1 ]
	then
		echo
		echo "there was more than the header line in the diff file. a teams notification should have been sent."
		echo

		mail \
			-v \
			-s "WARNING! THE PIPELINES FILES DO NOT MATCH WHAT IS EXPECTED." \
			${SEND_TO} \
		< ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/md5_diff_JHG_Clinical_Exome_Pipeline_${SUBMIT_STAMP}.txt

		echo
		echo "AUTHOR'S NOTE: the \"Mail Delivery Status Report\" message above means that the mail message was sent to a file "
		echo "on the server where this program ran. In addition to being sent to a teams channel."
		echo "Since this takes up space on that server, that file is purged every time the email that a difference in pipelines files"
		echo "is detected is sent to avoid filling up that servers disk space"
		echo

		# that's right. i'm doing this. the possibility of collisions is extremely small.
		# would have to access file at the same time on the same server for a file that should only exist in unusual circumstances.
		# i have no idea why this email is not being sent unless it is verbose.
		# i use mail in if statements everywhere else and it works without being verbose and I have no idea why it won't here.
		
			cat /dev/null >| ${MAIL}
	else
		echo
		echo "EVERYTHING CHECKS OUT. NO DIFFERENCES DETECTED."
	fi
