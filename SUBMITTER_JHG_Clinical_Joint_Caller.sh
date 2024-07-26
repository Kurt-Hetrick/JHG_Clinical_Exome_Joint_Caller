#!/usr/bin/env bash

###################
# INPUT VARIABLES #
###################

	SAMPLE_SHEET=$1
	PED_FILE=$2
	OUTPUT_LOCATION=$3
		OUTPUT_DIR=$(basename ${OUTPUT_LOCATION})

	VALIDATE_PIPELINE_SCRIPTS=$4 # optional. if you want to validate whether there are any changes to the pipeline directory
		# can turn it off, if testing changes before committing and pushing to git repo
		# if null, then value is "y"
		# if not null, then value HAS to be either "y" or "n" or program will exit with message

			if
				[[ ! ${VALIDATE_PIPELINE_SCRIPTS} ]]
			then
				VALIDATE_PIPELINE_SCRIPTS="y"
			elif
				# if VALIDATE_PIPELINE_SCRIPTS is not null AND not "y" or "n" then exit and print message to screen
				[[ -n ${VALIDATE_PIPELINE_SCRIPTS} ]] && ! ([[ ${VALIDATE_PIPELINE_SCRIPTS} = "y" ]] || [[ ${VALIDATE_PIPELINE_SCRIPTS} = "n" ]])
			then
				printf "echo\n"
				printf "echo FATAL ERROR: IF SETTING 3rd ARGUMENT \(WHETHER TO VALIDATE THE PIPELINE SCRIPT DIRECTORY\)\n"
				printf "echo THEN IT MUST BE SET AS \(y\) FOR YES OR \(n\) FOR NO. DO NO USE THE PARENTHESES\n"
				printf "echo SUBMISSION ABORTED\n"
				printf "echo\n"
				exit 1
			else
				VALIDATE_PIPELINE_SCRIPTS=${VALIDATE_PIPELINE_SCRIPTS}
			fi

	VALIDATE_GIT_LFS=$5 # optional. if you want to validate whether there are any changes to the git lfs directory
		# can turn it off, if testing changes before committing and pushing to git repo
		# if null, then value is "y"
		# if not null, then value HAS to be either "y" or "n" or program will exit with message
		# if you want to set this argument then you have to set the 3rd as well, even to the default value

			if
				[[ ! ${VALIDATE_GIT_LFS} ]]
			then
				VALIDATE_GIT_LFS="y"
			elif
				# if VALIDATE_GIT_LFS is not null AND not "y" or "n" then exit and print message to screen
				[[ -n ${VALIDATE_GIT_LFS} ]] && ! ([[ ${VALIDATE_GIT_LFS} = "y" ]] || [[ ${VALIDATE_GIT_LFS} = "n" ]])
			then
				printf "echo\n"
				printf "echo FATAL ERROR: IF SETTING 4th ARGUMENT \(WHETHER TO VALIDATE THE GIT LFS DIRECTORY\)\n"
				printf "echo THEN IT MUST BE SET AS \(y\) FOR YES OR \(n\) FOR NO. DO NO USE THE PARENTHESES\n"
				printf "echo SUBMISSION ABORTED\n"
				printf "echo\n"
				exit 1
			else
				VALIDATE_GIT_LFS=${VALIDATE_GIT_LFS}
			fi

	PADDING_LENGTH=$6 # optional. if no 5th argument present then the default is 10
	# THIS PAD IS FOR SLICING
		# if you want to set this then you need to set the 3rd and 4th argument as well (even to the default)

		if [[ ! ${PADDING_LENGTH} ]]
			then
			PADDING_LENGTH="10"
		fi

	QUEUE_LIST=$7 # optional. if no 6th argument present then the default is cgc.q
		# if you want to set this then you need to set the 3rd, 4th and 5th argument as well (even to the default)

		if [[ ! ${QUEUE_LIST} ]]
			then
			QUEUE_LIST="cgc.q"
		fi

	PRIORITY=$8 # optional. if no 7th argument present then the default is -15.
		# if you want to set this then you need to set the 3rd, 4th, 5th, 6th and 7th argument as well (even to the default)

			if [[ ! ${PRIORITY} ]]
				then
				PRIORITY="-15"
			fi

	THREADS=$9 # optional. if no 8th argument present then default is 6.
		# if you want to set this then you need to set 3rd,4th,5th,6th and 7th argument as well (even to default)

			if [[ ! ${THREADS} ]]
				then
				THREADS="6"
			fi

########################################################################
# CHANGE SCRIPT DIR TO WHERE YOU HAVE HAVE THE SCRIPTS BEING SUBMITTED #
########################################################################

	SUBMITTER_SCRIPT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

	SCRIPT_DIR=${SUBMITTER_SCRIPT_PATH}/scripts

##################
# CORE VARIABLES #
##################

	# PIPELINE FILE REPOSITORY DIRECTORY

		GIT_LFS_DIR="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES"

		# dev repository. just here for convenience for me so I can comment it in and out

			# GIT_LFS_DIR="/mnt/clinical/ddl/NGS/Kurt_Test/GIT_LFS"

	# GVCF PAD. CURRENTLY KEEPING THIS AS A STATIC VARIABLE

		GVCF_PAD="250"

	## This will always put the current working directory in front of any directory for PATH
	## added /bin for RHEL6

		export PATH=".:${PATH}:/bin"

	# where the input/output sequencing data will be located.

		CORE_PATH="/mnt/clinical/ddl/NGS/Exome_Data"

	# Directory where NovaSeqa runs are located.

		NOVASEQ_REPO="/mnt/instrument_files/novaseq"

	# grab the git short hash for the pipeline scripts
	# to be used for tracking in the read group header of the cram file and written to the QC report

		PIPELINE_VERSION=$(git \
							--git-dir=${SCRIPT_DIR}/../.git \
							--work-tree=${SCRIPT_DIR}/.. \
							log \
							--pretty=format:'%h' \
							-n 1)

	# grab the git short hash for the pipeline files used
	# to be written to the QC report

		GIT_LFS_VERSION=$(singularity \
							exec \
						-B ${GIT_LFS_DIR}:/opt \
						${GIT_LFS_DIR}/git_utils/git-lfs-2.7.2.simg git \
						-C /opt \
							log \
							--pretty=format:'%h' \
							-n 1)

	# load gcc for programs like verifyBamID
	## this will get pushed out to all of the compute nodes since I specify env var to pushed out with qsub

		module load gcc/7.2.0

	# explicitly setting this b/c not everybody has had the $HOME directory transferred
	# and I'm not going to through and figure out who does and does not have this set correctly

		umask 0007

	# SUBMIT TIMESTAMP

		SUBMIT_STAMP=$(date '+%s')

	# SUBMITTER_ID

		SUBMITTER_ID=$(whoami)

	# grab submitter's name

		PERSON_NAME=$(getent passwd | awk 'BEGIN {FS=":"} $1=="'${SUBMITTER_ID}'" {print $5}')

	# grab email addy

		SEND_TO=$(cat ${SCRIPT_DIR}/../email_lists.txt)

	# bind the host file system /mnt to the singularity container. in case I use it in the submitter.

		export SINGULARITY_BINDPATH="/mnt:/mnt"

	# QSUB ARGUMENTS LIST
		# set shell on compute node
		# start in current working directory
		# transfer submit node env to compute node
		# set SINGULARITY BINDPATH
		# set queues to submit to
		# set priority
		# combine stdout and stderr logging to same output file

			QSUB_ARGS="-S /bin/bash" \
				QSUB_ARGS=${QSUB_ARGS}" -cwd" \
				QSUB_ARGS=${QSUB_ARGS}" -V" \
				QSUB_ARGS=${QSUB_ARGS}" -v SINGULARITY_BINDPATH=/mnt:/mnt" \
				QSUB_ARGS=${QSUB_ARGS}" -q ${QUEUE_LIST}" \
				QSUB_ARGS=${QSUB_ARGS}" -p ${PRIORITY}" \
				QSUB_ARGS=${QSUB_ARGS}" -j y"

			# qsub args for magick package in R (imgmagick_merge.r)
			# image packages will use all cpu threads by default.
			# to configure set env variable to desired thread count.

				IMGMAGICK_QSUB_ARGS=${QSUB_ARGS}" -v MAGICK_THREAD_LIMIT=${THREADS}"

####################################################################################################################
##### VALIDATE THAT THERE ARE NO UNTRACKED, UNCOMMITTED AND/OR UNPUSHED CHANGES TO PIPELINE SCRIPTS REPOSITORY #####
##### ABORT SUBMISSION IF THERE ARE ################################################################################
####################################################################################################################

		if
			[[ ${VALIDATE_PIPELINE_SCRIPTS} = "y" ]]
		then
			printf "echo\n"
			printf "echo VALIDATING THAT THERE ARE NO UNTRACKED AND/OR UNCOMMITTED CHANGES TO PIPELINE SCRIPTS REPOSITORY...\n"
			printf "echo\n"
		else
			printf "echo\n"
			printf "echo SKIPPING VALIDATIONS FOR PIPELINE SCRIPTS REPOSITORY...\n"
			printf "echo\n"
		fi

	##########################################################################################
	# VALIDATE THAT THERE ARE NO UNTRACKED AND/OR UNCOMMITTED TO PIPELINE SCRIPTS REPOSITORY #
	##########################################################################################

		# DO A SIMPLE STATUS CHECK THAT THERE ARE NO CHANGES AND STORE AS VARIABLE

			LOCAL_CHANGES_SCRIPTS=$(git \
										--git-dir=${SUBMITTER_SCRIPT_PATH}/.git \
										--work-tree=${SUBMITTER_SCRIPT_PATH} \
										status \
											--porcelain)

		# FUNCTION FOR FULL STATUS CHECK IN THE EVENT THAT THERE ARE UNTRACKED AND/OR UNCOMMITTED CHANGES

			RUN_GIT_STATUS_SCRIPTS ()
			{
				git \
					--git-dir=${SUBMITTER_SCRIPT_PATH}/.git \
					--work-tree=${SUBMITTER_SCRIPT_PATH} \
					status
			}

	# IF THERE ARE UNTRACKED AND/OR UNCOMMITED CHANGES AND VALIDATE_PIPELINE_SCRIPTS IS SET TO "y"
	# PRINT git STATUS MESSAGE TO SCREEN AND TO TEAMS AND ABORT SUBMISSION SCRIPT
	# EXIT STATUS = 1

		if
			[[ -n ${LOCAL_CHANGES_SCRIPTS} && ${VALIDATE_PIPELINE_SCRIPTS} = "y" ]]
		then
			# print message to screen

				printf "echo SUBMISSION ABORTED: PIPELINE - JHG_Clinical_Exome_Pipeline: SCRIPTS REPOSITORY HAS UNTRACKED AND/OR UNCOMMITTED CHANGES AT ${SUBMITTER_SCRIPT_PATH}.\n"
				printf "echo\n"

				printf "git --git-dir=${SUBMITTER_SCRIPT_PATH}/.git --work-tree=${SUBMITTER_SCRIPT_PATH} status"

			# send message to teams

				RUN_GIT_STATUS_SCRIPTS \
					| mail \
						-s "SUBMISSION ABORTED: PIPELINE - JHG_Clinical_Exome_Pipeline: SCRIPTS REPOSITORY HAS UNTRACKED AND/OR UNCOMMITTED CHANGES AT ${SUBMITTER_SCRIPT_PATH}." \
						${SEND_TO}
			exit 1
		fi

	################################################################################################
	# VALIDATE THAT THERE ARE NO COMMITS IN THE LOCAL REPO THAT HAVE NOT BEEN PUSHED TO THE REMOTE #
	################################################################################################

		if
			[[ ${VALIDATE_PIPELINE_SCRIPTS} = "y" ]]
		then
			printf "echo COMPLETED: THERE WERE NO UNTRACKED AND/OR UNCOMMITTED CHANGES TO PIPELINE SCRIPTS REPOSITORY\n"
			printf "echo\n"
			printf "echo NOW VALIDATING THAT THERE ARE NO DIFFERENCES BETWEEN REMOTE AND LOCAL REPOSITORIES FOR THE PIPELINE SCRIPTS REPOSITORY...\n"
			printf "echo\n"
		fi

		# GRAB LOCAL BRANCH AND STORE AS A VARIABLE FOR MESSAGING

			CURRENT_LOCAL_BRANCH_SCRIPTS=$(git \
					--git-dir=${SUBMITTER_SCRIPT_PATH}/.git \
					--work-tree=${SUBMITTER_SCRIPT_PATH} \
					branch \
			| awk '$1=="*" {print $2}')

		# CHECK THAT THERE ARE NO DIFFERENCES BETWEEN REMOTE AND LOCAL BRANCH. STORE AS A VARIABLE.

			CHECK_LOCAL_VS_REMOTE_SCRIPTS=$(git \
					--git-dir=${SUBMITTER_SCRIPT_PATH}/.git \
					--work-tree=${SUBMITTER_SCRIPT_PATH} \
					diff \
					origin/${CURRENT_LOCAL_BRANCH_SCRIPTS})

		# FUNCTION TO RUN GIT DIFF FOR TEAMS MESSAGING IN THE EVENT THAT THERE ARE DIFFERENCES BETWEEEN LOCAL AND REMOTE

			RUN_GIT_DIFF_LOCAL_VS_REMOTE_SCRIPTS ()
			{
				git \
					--git-dir=${SUBMITTER_SCRIPT_PATH}/.git \
					--work-tree=${SUBMITTER_SCRIPT_PATH} \
					diff \
					--name-status \
					origin/${CURRENT_LOCAL_BRANCH_SCRIPTS}
			}

	# IF THERE ARE LOCAL COMMITTED CHANGES THAT HAVE NOT BEEN PUSHED TO REMOTE AND VALIDATE_PIPELINE_SCRIPTS IS SET TO "y"
	# PRINT git diff MESSAGE TO SCREEN AND TO TEAMS AND ABORT SUBMISSION SCRIPT
	# EXIT STATUS = 1

		if
			[[ -n ${CHECK_LOCAL_VS_REMOTE_SCRIPTS} && ${VALIDATE_PIPELINE_SCRIPTS} = "y" ]]
		then
			# print message to screen

				printf "echo SUBMISSION ABORTED: PIPELINE - JHG_Clinical_Exome_Pipeline: GIT BRANCH - ${CURRENT_LOCAL_BRANCH_SCRIPTS}: LOCAL SCRIPTS REPOSITORY, ${SUBMITTER_SCRIPT_PATH}, HAS COMMITS NOT PUSHED TO REMOTE.\n"
				printf "echo\n"
				printf "echo BELOW ARE THE MODIFIED AND/OR NEW FILES THAT HAVE NOT BEEN PUSHED TO THE REMOTE REPOSITORY\n"
				printf "echo \(M\): file has been modified but not commited to the remote repository\n"
				printf "echo \(A\): new file has been added but not commited to the remote repository\n"
				printf "echo\n"

				printf "git --git-dir=${SUBMITTER_SCRIPT_PATH}/.git --work-tree=${SUBMITTER_SCRIPT_PATH} diff --name-status origin/${CURRENT_LOCAL_BRANCH_SCRIPTS}"

			# send message to teams

				RUN_GIT_DIFF_LOCAL_VS_REMOTE_SCRIPTS \
					| mail \
						-s "SUBMISSION ABORTED: PIPELINE - JHG_Clinical_Exome_Pipeline: GIT BRANCH - ${CURRENT_LOCAL_BRANCH_SCRIPTS}: LOCAL SCRIPTS REPOSITORY, ${SUBMITTER_SCRIPT_PATH}, HAS COMMITS NOT PUSHED TO REMOTE." \
						${SEND_TO}
			exit 1
		fi

	###########################################################################################################
	# IF VALIDATING PIPELINE SCRIPTS REPOSITORY AND IF THERE WERE NO ISSUES THAN SAY SO ON SCREEN #############
	# ALSO ALERT SUBMITTER THAT NOT ALL FILES CAN BE VALIDATED HERE BUT IF THERE WERE ISSUES WITH OTHER FILES #
	# THAT NOTIFICATION WILL COME WITH THE NOTIFICATION WHEN THE PIPELINE HAS COMPLETED PROCESSING ############
	###########################################################################################################

		if
			[[ ${VALIDATE_PIPELINE_SCRIPTS} = "y" ]]
		then
			printf "echo COMPLETED: THERE WERE NO ISSUES WITH PIPELINE SCRIPTS REPOSITORY.\n"
			printf "echo\n"
			printf "echo NOW CONTINUING WITH THE PIPELINE SUBMISSION\n"
			printf "echo\n"
		fi

#################################################################################################################
##### VALIDATE THAT THERE ARE NO UNTRACKED, UNCOMMITTED AND/OR UNPUSHED CHANGES TO PIPELINE FILE REPOSITORY #####
##### ABORT SUBMISSION IF THERE ARE #############################################################################
#################################################################################################################

		if
			[[ ${VALIDATE_GIT_LFS} = "y" ]]
		then
			printf "echo\n"
			printf "echo VALIDATING THAT THERE ARE NO UNTRACKED AND/OR UNCOMMITTED CHANGES TO PIPELINE FILE REPOSITORY...\n"
			printf "echo\n"
		else
			printf "echo\n"
			printf "echo SKIPPING VALIDATIONS FOR GIT LFS BACKED PIPELINE FILE REPOSITORY...\n"
			printf "echo\n"
		fi

	#######################################################################################
	# VALIDATE THAT THERE ARE NO UNTRACKED AND/OR UNCOMMITTED TO PIPELINE FILE REPOSITORY #
	#######################################################################################

		# DO A SIMPLE STATUS CHECK THAT THERE ARE NO CHANGES AND STORE AS VARIABLE

			LOCAL_CHANGES_LFS=$(singularity \
				exec \
					-B ${GIT_LFS_DIR}:/opt \
				${GIT_LFS_DIR}/git_utils/git-lfs-2.7.2.simg git \
						-C /opt \
					status \
						--porcelain)

		# FUNCTION FOR FULL STATUS CHECK IN THE EVENT THAT THERE ARE UNTRACKED AND/OR UNCOMMITTED CHANGES

			RUN_GIT_STATUS_LFS ()
			{
				singularity \
				exec \
					-B ${GIT_LFS_DIR}:/opt \
				${GIT_LFS_DIR}/git_utils/git-lfs-2.7.2.simg git \
						-C /opt \
					status
			}

	# IF THERE ARE UNTRACKED AND/OR UNCOMMITED CHANGES AND VALIDATE_GIT_LFS IS SET TO "y"
	# PRINT git STATUS MESSAGE TO SCREEN AND TO TEAMS AND ABORT SUBMISSION SCRIPT
	# EXIT STATUS = 1

		if
			[[ -n ${LOCAL_CHANGES_LFS} && ${VALIDATE_GIT_LFS} = "y" ]]
		then
			# print message to screen

				printf "echo SUBMISSION ABORTED: PIPELINE - JHG_Clinical_Exome_Pipeline: FILE REPOSITORY HAS UNTRACKED AND/OR UNCOMMITTED CHANGES AT ${GIT_LFS_DIR}.\n"
				printf "echo\n"

				printf "singularity exec -B ${GIT_LFS_DIR}:/opt ${GIT_LFS_DIR}/git_utils/git-lfs-2.7.2.simg git -C /opt status"

			# send message to teams

				RUN_GIT_STATUS_LFS \
					| mail \
						-s "SUBMISSION ABORTED: PIPELINE - JHG_Clinical_Exome_Pipeline: FILE REPOSITORY HAS UNTRACKED AND/OR UNCOMMITTED CHANGES AT ${GIT_LFS_DIR}." \
						${SEND_TO}
			exit 1
		fi

	################################################################################################
	# VALIDATE THAT THERE ARE NO COMMITS IN THE LOCAL REPO THAT HAVE NOT BEEN PUSHED TO THE REMOTE #
	################################################################################################

		if
			[[ ${VALIDATE_GIT_LFS} = "y" ]]
		then
			printf "echo COMPLETED: THERE WERE NO UNTRACKED AND/OR UNCOMMITTED CHANGES TO PIPELINE FILE REPOSITORY\n"
			printf "echo\n"
			printf "echo NOW VALIDATING THAT THERE ARE NO DIFFERENCES BETWEEN REMOTE AND LOCAL REPOSITORIES FOR THE PIPELINE FILE REPOSITORY...\n"
			printf "echo\n"
		fi

		# GRAB LOCAL BRANCH AND STORE AS A VARIABLE FOR MESSAGING

			CURRENT_LOCAL_BRANCH_LFS=$(singularity \
				exec \
					-B ${GIT_LFS_DIR}:/opt \
				${GIT_LFS_DIR}/git_utils/git-lfs-2.7.2.simg git \
						-C /opt \
					branch \
			| awk '$1=="*" {print $2}')

		# CHECK THAT THERE ARE NO DIFFERENCES BETWEEN REMOTE AND LOCAL BRANCH. STORE AS A VARIABLE.

			CHECK_LOCAL_VS_REMOTE_LFS=$(singularity \
				exec \
					-B ${GIT_LFS_DIR}:/opt \
				${GIT_LFS_DIR}/git_utils/git-lfs-2.7.2.simg git \
						-C /opt \
					diff \
					origin/${CURRENT_LOCAL_BRANCH_LFS})

		# FUNCTION TO RUN GIT DIFF FOR TEAMS MESSAGING IN THE EVENT THAT THERE ARE DIFFERENCES BETWEEEN LOCAL AND REMOTE

			RUN_GIT_DIFF_LOCAL_VS_REMOTE_LFS ()
			{
				singularity \
				exec \
					-B ${GIT_LFS_DIR}:/opt \
				${GIT_LFS_DIR}/git_utils/git-lfs-2.7.2.simg git \
						-C /opt \
					diff \
					--name-status \
					origin/${CURRENT_LOCAL_BRANCH_LFS}
			}

	# IF THERE ARE LOCAL COMMITTED CHANGES THAT HAVE NOT BEEN PUSHED TO REMOTE AND VALIDATE_GIT_LFS IS SET TO "y"
	# PRINT git diff MESSAGE TO SCREEN AND TO TEAMS AND ABORT SUBMISSION SCRIPT
	# EXIT STATUS = 1

		if
			[[ -n ${CHECK_LOCAL_VS_REMOTE_LFS} && ${VALIDATE_GIT_LFS} = "y" ]]
		then
			# print message to screen

				printf "echo SUBMISSION ABORTED: PIPELINE - JHG_Clinical_Exome_Pipeline: GIT LFS BRANCH - ${CURRENT_LOCAL_BRANCH_LFS}: LOCAL FILE REPOSITORY, ${GIT_LFS_DIR}, HAS COMMITS NOT PUSHED TO REMOTE.\n"
				printf "echo\n"
				printf "echo BELOW ARE THE MODIFIED AND/OR NEW FILES THAT HAVE NOT BEEN PUSHED TO THE REMOTE REPOSITORY\n"
				printf "echo \(M\): file has been modified but not commited to the remote repository\n"
				printf "echo \(A\): new file has been added but not commited to the remote repository\n"
				printf "echo\n"

				printf "singularity exec -B ${GIT_LFS_DIR}:/opt ${GIT_LFS_DIR}/git_utils/git-lfs-2.7.2.simg git -C /opt diff --name-status origin/${CURRENT_LOCAL_BRANCH_LFS}"

			# send message to teams

				RUN_GIT_DIFF_LOCAL_VS_REMOTE_LFS \
					| mail \
						-s "SUBMISSION ABORTED: PIPELINE - JHG_Clinical_Exome_Pipeline: GIT LFS BRANCH - ${CURRENT_LOCAL_BRANCH_LFS}: LOCAL FILE REPOSITORY, ${GIT_LFS_DIR}, HAS COMMITS NOT PUSHED TO REMOTE." \
						${SEND_TO}
			exit 1
		fi

	###########################################################################################################
	# IF VALIDATING GIT LFS REPOSITORY AND IF THERE WERE NO ISSUES THAN SAY SO ON SCREEN ######################
	# ALSO ALERT SUBMITTER THAT NOT ALL FILES CAN BE VALIDATED HERE BUT IF THERE WERE ISSUES WITH OTHER FILES #
	# THAT NOTIFICATION WILL COME WITH THE NOTIFICATION WHEN THE PIPELINE HAS COMPLETED PROCESSING ############
	###########################################################################################################

		if
			[[ ${VALIDATE_GIT_LFS} = "y" ]]
		then
			printf "echo COMPLETED: THERE WERE NO ISSUES WITH PIPELINE FILE REPOSITORY FOR FILES TRACKED BY GIT LFS.\n"
			printf "echo\n"
			printf "echo IF THERE ARE ISSUES WITH FILES THAT ARE TOO BIG TO BE TRACKED BY GIT LFS,\n"
			printf "echo THEN A WARNING WILL BE ISSED WITH DETAILS IN THE PIPELINE COMPLETED TEAMS NOTIFICATION SUMMARY.\n"
			printf "echo\n"
			printf "echo NOW CONTINUING WITH THE PIPELINE SUBMISSION\n"
			printf "echo\n"
		fi

#####################
# PIPELINE PROGRAMS #
#####################

	############################
	# BASE PIPELINE CONTAINERS #
	############################

		ALIGNMENT_CONTAINER="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/containers/ddl_ce_control_align-0.0.4.simg"
		# contains the following software and is on Ubuntu 16.04.5 LTS
			# gatk 4.0.11.0 (base image). also contains the following.
				# Python 3.6.2 :: Continuum Analytics, Inc.
					# samtools 0.1.19
					# bcftools 0.1.19
					# bedtools v2.25.0
					# bgzip 1.2.1
					# tabix 1.2.1
					# samtools, bcftools, bgzip and tabix will be replaced with newer versions.
					# R 3.2.5
						# dependencies = c("gplots","digest", "gtable", "MASS", "plyr", "reshape2", "scales", "tibble", "lazyeval")    # for ggplot2
						# getopt_1.20.0.tar.gz
						# optparse_1.3.2.tar.gz
						# data.table_1.10.4-2.tar.gz
						# gsalib_2.1.tar.gz
						# ggplot2_2.2.1.tar.gz
					# openjdk version "1.8.0_181"
					# /gatk/gatk.jar -> /gatk/gatk-package-4.0.11.0-local.jar
			# added
				# picard.jar 2.17.0 (as /gatk/picard.jar)
				# samblaster-v.0.1.24
				# sambamba-0.6.8
				# bwa-0.7.15
				# datamash-1.6
				# verifyBamID v1.1.3
				# samtools 1.10
				# bgzip 1.10
				# tabix 1.10
				# bcftools 1.10.2

		GATK_3_7_0_CONTAINER="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/containers/gatk3-3.7-0.simg"
		# singularity pull docker://broadinstitute/gatk3:3.7-0
		# used for generating the depth of coverage reports.
			# comes with R 3.1.1 with appropriate packages needed to create gatk pdf output
			# also comes with some version of java 1.8
			# jar file is /usr/GenomeAnalysisTK.jar

	################################################################
	# MITOCHONDRIA ANALYSIS CONTAINERS AND AUXILIARY SCRIPTS/FILES #
	################################################################

		MITO_MUTECT2_CONTAINER="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/containers/mito_mutect2-4.1.3.0.0.simg"
			# uses broadinstitute/gatk:4.1.3.0 as the base image (as /gatk/gatk.jar)
				# added
					# bcftools-1.10.2
					# haplogrep-2.1.20.jar (as /jars/haplogrep-2.1.20.jar)
					# annovar

		MITO_EKLIPSE_CONTAINER="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/containers/mito_eklipse-master-c25931b.0.simg"
			# https://github.com/dooguypapua/eKLIPse AND all of its dependencies

		MITO_MAGICK_CONTAINER="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/containers/mito_magick-6.8.9.9.0.simg"
			# magick package for R. see dockerfile for details.

		EKLIPSE_CIRCOS_LEGEND="${SCRIPT_DIR}/circos_legend.png"

		EKLIPSE_FORMAT_CIRCOS_PLOT_R_SCRIPT="${SCRIPT_DIR}/imgmagick_merge.r"

		MT_COVERAGE_R_SCRIPT="${SCRIPT_DIR}/mito_coverage_graph.r"

		# gatk 4.2.5.0 (log4j fixed version) does not work on rhel6 host os b/c the kernel is too old.

			# GATK_4_2_5_0_CONTAINER="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/containers/gatk-4.2.5.0.simg"

		# GATK_CONTAINER_4_2_2_0="/mnt/research/tools/LINUX/00_GIT_REPO_KURT/CIDR_EXOME_MITO/containers/gatk-4.2.2.0.simg"

	#################################
	# PCA AND RELATEDNESS CONTAINER #
	#################################

		PCA_RELATEDNESS_CONTAINER="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/containers/pca-relatedness-0.0.1.simg"

##################
# PIPELINE FILES #
##################

	# Core Pipeline

		GENE_LIST="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/bed_files/RefSeqGene.GRCh37.rCRS.MT.bed"
			# md5 dec069c279625cfb110c2e4c5480e036
		VERIFY_VCF="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/Omni25_genotypes_1525_samples_v2.b37.PASS.ALL.sites.vcf.gz"
		CODING_BED="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/bed_files/GRCh37_Mane-RefSeqSelect_OMIM_CDS_exon_primary_assembly_HGNC_annotated.bed"
		CYTOBAND_BED="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/bed_files/GRCh37.Cytobands.bed"
		HAPMAP="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/hapmap_3.3.b37.vcf.gz"
		OMNI_1KG="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/1000G_omni2.5.b37.vcf.gz"
		HI_CONF_1KG_PHASE1_SNP="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/1000G_phase1.snps.high_confidence.b37.vcf.gz"
		MILLS_1KG_GOLD_INDEL="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/Mills_and_1000G_gold_standard.indels.b37.vcf.gz"
		PHASE3_1KG_AUTOSOMES="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/ALL.autosomes.phase3_shapeit2_mvncall_integrated_v5.20130502.sites.vcf.gz"
		DBSNP_129="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/dbsnp_138.b37.excluding_sites_after_129.vcf.gz"
		UCSC_REPEATMASK="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/bed_files/ucsc_grch37_repeatmasker.sorted_no_alt_MT.bed"
			# sortBed -i ucsc_grch37_repeatmasker.bed \
			# | awk '$1!~"_"&&$1!~"chrM"' \
			# | sed 's/^chr//g' \
			# > ucsc_grch37_repeatmasker.sorted_no_alt_MT.bed
		MDUST_REPEATMASK="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/bed_files/LCR-hs37d5.bed"
			# https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4271055/
			# https://github.com/lh3/varcmp/tree/master/scripts

	# where the control data set resides.

		CONTROL_REPO="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37"
		CONTROL_PED_FILE="${CONTROL_REPO}/CONTROL_SET.ped"

	# CONTROL DATA SET GENOME VCF FILE TO MERGE WITH FAMILY/SAMPLE GVCF FILES FOR JOINT CALLING.

		CONTROL_DATA_SET_FILE="CGC_CONTROL_SET_3_7.g.vcf.gz"

	# CNV calling workflow

		## REF_PANEL_COUNTS USED IN EXOME DEPTH IS SEX SPECIFIC.
		## DETERMINED WHEN PARSING GENDER FROM PED FILE DURING CREATE_SAMPLE_ARRAY
		## THE THREE RDA FILES BELOW GET REASSIGNED TO ${REF_PANEL_COUNTS} depending on what the gender is.

			# read count from female reference panel, won't need to change unless changes in bed file or reference samples

				REF_PANEL_FEMALE_READ_COUNT_RDA="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/cnv/refCountFemaleUniqBed.rda"

			# read count from male reference panel, won't need to change unless changes in bed file or reference samples

				REF_PANEL_MALE_READ_COUNT_RDA="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/cnv/refCountMaleUniqBed.rda"

			# if subject sex is not specified as 'm' or 'f', it will use count of all sample

				REF_PANEL_ALL_READ_COUNT_RDA="/mnt/clinical/ddl/NGS/NGS_PIPELINE_RESOURCES/JHG_Clinical_Exome_Pipeline/GRCh37/cnv/refCountAllUniqBed.rda"

############################################################################
##### PIPELINE AND PROJECT SET-UP ##########################################
############################################################################
##### MERGE SAMPLE_SHEET AND PED FILE AND CREATE A SAMPLE LEVEL ARRAY ######
##### ARRAY IS USED TO PASS VARIABLES FOR SAMPLE LEVEL PROCESSES ###########
##### MAKE A DIRECTORY TREE ################################################
##### FIX BED FILES USED FOR EACH SAMPLE ###################################
##### FIX BED FILES USED FOR EACH FAMILY ###################################
##### CREATE LISTS FOR SAMPLES IN A FAMILY (USED FOR JOINT CALLING, ETC) ###
############################################################################

########################################
### MERGE SAMPLE SHEET WITH PED FILE ###
########################################

	# make a directory in user home directory

		mkdir -p ~/JOINT_CALL_TEMP

	# create variables using the base name for the sample sheet and ped file

		MANIFEST_PREFIX=$(basename ${SAMPLE_SHEET} .csv)
		PED_PREFIX=$(basename ${PED_FILE} .ped)

	# fix any commonly seen formatting issues in the sample sheet

		FORMAT_MANIFEST ()
		{
			awk 1 ${SAMPLE_SHEET} \
				| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
				| awk 'NR>1' \
				| sed 's/,/\t/g' \
				| sort -k 8,8 \
			>| ~/JOINT_CALL_TEMP/SORTED.${MANIFEST_PREFIX}.txt
		}

	# merge the sample sheet with the ped file

		MERGE_PED_MANIFEST ()
		{
			awk 1 ${PED_FILE} \
				| sed 's/\r//g' \
				| sort -k 2,2 \
				| join -1 8 -2 2 -e '-'  -t $'\t' \
				-o '1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9,1.10,1.11,1.12,1.13,1.14,1.15,1.16,1.17,1.18,1.19,2.1,2.3,2.4,2.5,2.6' \
			~/JOINT_CALL_TEMP/SORTED.${MANIFEST_PREFIX}.txt /dev/stdin \
			>| ~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt
		}

# run above functions to format sample sheet/manifest and then format ped file and merge with formatted sample sheet/manifest

FORMAT_MANIFEST
MERGE_PED_MANIFEST

#############################################################################
### CREATE_SAMPLE_ARRAY #####################################################
### create an array from values of the merged sample sheet and ped file #####
### set ${REF_PANEL_COUNTS} based on gender #################################
#############################################################################

	CREATE_SAMPLE_ARRAY ()
	{
		SAMPLE_ARRAY=(`awk 'BEGIN {FS="\t"; OFS="\t"} \
			$8=="'${SAMPLE}'" \
			{split($19,INDEL,";"); \
			print $1,$8,$9,$10,$11,$12,$15,$16,$17,$18,INDEL[1],INDEL[2],\
			$20,$21,$22,$23,$24}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq`)

			#  1  Project=the Seq Proj folder name

				PROJECT=${SAMPLE_ARRAY[0]}

					################################################################################
					# 2 SKIP : FCID=flowcell that sample read group was performed on ###############
					# 3 SKIP : Lane=lane of flowcell that sample read group was performed on] ######
					# 4 SKIP : Index=sample barcode ################################################
					# 5 SKIP : Platform=type of sequencing chemistry matching SAM specification ####
					# 6 SKIP : Library_Name=library group of the sample read group #################
					# 7 SKIP : Date=should be the run set up date to match the seq run folder name #
					################################################################################

			#  8  SM_Tag=sample ID

				SM_TAG=${SAMPLE_ARRAY[1]}

					# If there is an @ in the qsub or holdId name it breaks

						SGE_SM_TAG=$(echo ${SM_TAG} | sed 's/@/_/g')

			#  9  Center=the center/funding mechanism

				CENTER=${SAMPLE_ARRAY[2]}

			# 10  Description=Sequencer model and/or setting (setting e.g. "Rapid-Run")
			## Models: “HiSeq-X”,“HiSeq-4000”,“HiSeq-2500”,“HiSeq-2000”,“NextSeq-500”,“MiSeq”

				SEQUENCER_MODEL=${SAMPLE_ARRAY[3]}

			# 11  Seq_Exp_ID=Zoom Gene List for filtering ExomeDepth output by gene symbol

				ZOOM_LIST=${SAMPLE_ARRAY[4]}

					# if the zoom list file exists than the output file prefix is the input file prefix before .GeneList

						if [ -f ${ZOOM_LIST} ]
							then ZOOM_NAME=$(basename ${ZOOM_LIST} | sed 's/.GeneList.[0-9]*.csv//g')
							else ZOOM_NAME="NA"
						fi

			# 12  Genome_Ref=the reference genome used in the analysis pipeline

				REF_GENOME=${SAMPLE_ARRAY[5]}

					# REFERENCE DICTIONARY IS A SUMMARY OF EACH CONTIG. PAIRED WITH REF GENOME

						REF_DICT=$(echo ${REF_GENOME} | sed 's/fasta$/dict/g; s/fa$/dict/g')

				#####################################
				# 13  Operator: SKIP ################
				# 14  Extra_VCF_Filter_Params: SKIP #
				#####################################

			# 15  TS_TV_BED_File=where ucsc coding exons overlap with bait and target bed files

				TITV_BED=${SAMPLE_ARRAY[6]}

			# 16  Baits_BED_File=a super bed file incorporating bait, target, padding and overlap with ucsc coding exons.
			# Used for limited where to run base quality score recalibration on where to create gvcf files.

				BAIT_BED=${SAMPLE_ARRAY[7]}

			# 17  Targets_BED_File=bed file acquired from manufacturer of their targets.

				TARGET_BED=${SAMPLE_ARRAY[8]}

			# 18  KNOWN_SITES_VCF=used to annotate ID field in VCF file. masking in base call quality score recalibration.

				DBSNP=${SAMPLE_ARRAY[9]}

			# 19  KNOWN_INDEL_FILES=used for BQSR masking, sensitivity in local realignment.

				KNOWN_INDEL_1=${SAMPLE_ARRAY[10]}
				KNOWN_INDEL_2=${SAMPLE_ARRAY[11]}

			# 20 family that sample belongs to

				FAMILY=${SAMPLE_ARRAY[12]}

			# 21 MOM

				FATHER=${SAMPLE_ARRAY[13]}

			# 22 DAD

				MOTHER=${SAMPLE_ARRAY[14]}

			# 23 GENDER

				GENDER=${SAMPLE_ARRAY[15]}

				# set ${REF_PANEL_COUNTS} USED IN EXOMEDEPTH TO THE SEX SPECIFIC ONE

					if [[ ${GENDER} = "1" ]];
						then REF_PANEL_COUNTS=${REF_PANEL_MALE_READ_COUNT_RDA}
						elif [[ ${GENDER} = "2" ]];
							then REF_PANEL_COUNTS=${REF_PANEL_FEMALE_READ_COUNT_RDA}
						else
							REF_PANEL_COUNTS=${REF_PANEL_ALL_READ_COUNT_RDA}
					fi

			# 24 PHENOTYPE

				PHENOTYPE=${SAMPLE_ARRAY[16]}
	}

######################################
### PROJECT DIRECTORY TREE CREATOR ###
######################################

	MAKE_PROJ_DIR_TREE ()
	{
		mkdir -p \
		${CORE_PATH}/${OUTPUT_DIR}/{FASTQ,LOGS,COMMAND_LINES,REPORTS} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/{LOGS,PCA,RELATEDNESS,ROH,EMEDGENE} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/VCF/{RAW,VQSR} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/{CNV_OUTPUT,CRAM,GVCF,HC_CRAM,LOGS} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/MT_OUTPUT/{COLLECTHSMETRICS_MT,MUTECT2_MT,HAPLOGROUPS,ANNOVAR_MT,EKLIPSE,VCF_METRICS_MT} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/{ALIGNMENT_SUMMARY,ANEUPLOIDY_CHECK,ANNOVAR,ERROR_SUMMARY,PICARD_DUPLICATES,QC_REPORT_PREP,QUALITY_YIELD,RG_HEADER,TI_TV,VCF_METRICS,VERIFYBAMID,VERIFYBAMID_AUTO} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/BAIT_BIAS/{METRICS,SUMMARY} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/BASE_DISTRIBUTION_BY_CYCLE/{METRICS,PDF} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/BASECALL_Q_SCORE_DISTRIBUTION/{METRICS,PDF} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/COUNT_COVARIATES/{GATK_REPORT,PDF} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/DEPTH_OF_COVERAGE/{TARGET_PADDED,CODING_PADDED} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/GC_BIAS/{METRICS,PDF,SUMMARY} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/HYB_SELECTION/PER_TARGET_COVERAGE \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/INSERT_SIZE/{METRICS,PDF} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/LOCAL_REALIGNMENT_INTERVALS \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/MEAN_QUALITY_BY_CYCLE/{METRICS,PDF} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/REPORTS/PRE_ADAPTER/{METRICS,SUMMARY} \
		${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/VCF/{FILTERED_ON_BAIT,FILTERED_ON_TARGET} \
		${CORE_PATH}/${OUTPUT_DIR}/TEMP/{KING,PLINK,VCF_PREP} \
		${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}_ANNOVAR_MT \
		${CORE_PATH}/${OUTPUT_DIR}/TEMP/${SM_TAG}_ANNOVAR_TARGET
	}

############################################################################
### combine above functions into one...this is probably not necessary... ###
############################################################################

	SETUP_PROJECT ()
	{
		CREATE_SAMPLE_ARRAY
		MAKE_PROJ_DIR_TREE
		echo Project started at `date` >| ${CORE_PATH}/${OUTPUT_DIR}/REPORTS/PROJECT_START_END_TIMESTAMP.txt
	}

###################################################
### fix common formatting problems in bed files ###
### merge bait to target for gvcf creation, pad ###
### create picard style interval files ############
### DO PER SAMPLE #################################
###################################################

	FIX_BED_FILES_SAMPLE ()
	{
		echo \
		qsub \
			${QSUB_ARGS} \
		-N A02-FIX_BED_FILES_${SGE_SM_TAG}_${OUTPUT_DIR} \
			-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/LOGS/${SM_TAG}-FIX_BED_FILES.log \
		${SCRIPT_DIR}/A02-FIX_BED_FILES_SAMPLE.sh \
			${ALIGNMENT_CONTAINER} \
			${CORE_PATH} \
			${PROJECT} \
			${OUTPUT_DIR} \
			${SM_TAG} \
			${CODING_BED} \
			${TARGET_BED} \
			${BAIT_BED} \
			${TITV_BED} \
			${CYTOBAND_BED} \
			${REF_GENOME} \
			${REF_DICT} \
			${PADDING_LENGTH} \
			${GVCF_PAD}
	}

######################################################
### CREATE_FAMILY_ARRAY ##############################
# create an array for each family/sample combination #
######################################################

	CREATE_FAMILY_ARRAY ()
	{
		FAMILY_ARRAY=(`awk 'BEGIN {FS="\t"; OFS="\t"} \
			$20=="'${FAMILY_ONLY}'" \
			{print $1,$8,$12,$15,$16,$17,$18,$20}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq`)

			#  1  Project=the Seq Proj folder name

				PROJECT=${FAMILY_ARRAY[0]}

					################################################################################
					# 2 SKIP : FCID=flowcell that sample read group was performed on ###############
					# 3 SKIP : Lane=lane of flowcell that sample read group was performed on] ######
					# 4 SKIP : Index=sample barcode ################################################
					# 5 SKIP : Platform=type of sequencing chemistry matching SAM specification ####
					# 6 SKIP : Library_Name=library group of the sample read group #################
					# 7 SKIP : Date=should be the run set up date to match the seq run folder name #
					################################################################################

			#  8  SM_Tag=sample ID

				SM_TAG=${FAMILY_ARRAY[1]}

					# "@" in qsub job or holdid is not allowed

						SGE_SM_TAG=$(echo ${SM_TAG} | sed 's/@/_/g')

							####################################################################################
							#  9  SKIP : Center=the center/funding mechanism ###################################
							# 10  SKIP : Description=Sequencer model and/or setting (setting e.g. "Rapid-Run") #
							## Models: “HiSeq-X”,“HiSeq-4000”,“HiSeq-2500”,“HiSeq-2000”,“NextSeq-500”,“MiSeq” ##
							# 11  SKIP : Seq_Exp_ID ############################################################
							####################################################################################

			# 12  Genome_Ref=the reference genome used in the analysis pipeline

				REF_GENOME=${FAMILY_ARRAY[2]}

					# REFERENCE DICTIONARY IS A SUMMARY OF EACH CONTIG. PAIRED WITH REF GENOME

						REF_DICT=$(echo ${REF_GENOME} | sed 's/fasta$/dict/g; s/fa$/dict/g')

					########################################################
					# 13 SKIP : Operator=no standard on this, not captured #
					# 14 SKIP : Extra_VCF_Filter_Params=LEGACY, NOT USED ###
					########################################################

			# 15  TS_TV_BED_File=refseq (select) cds plus other odds and ends (.e.g. missing omim))

				TITV_BED=${FAMILY_ARRAY[3]}

			# 16  Baits_BED_File=a super bed file incorporating bait, target, padding and overlap with ucsc coding exons.
			# Used for limited where to run base quality score recalibration on where to create gvcf files.

				BAIT_BED=${FAMILY_ARRAY[4]}

			# 17  Targets_BED_File=bed file acquired from manufacturer of their targets.

				TARGET_BED=${FAMILY_ARRAY[5]}

			# 18  KNOWN_SITES_VCF=used to annotate ID field in VCF file. masking in BQSR

				DBSNP=${FAMILY_ARRAY[6]}

					#####################################################
					# 19 SKIP : KNOWN_INDEL_FILES=used for BQSR masking #
					#####################################################

			# 20 family that sample belongs to

				FAMILY=${FAMILY_ARRAY[7]}

					#######################
					# 21 SKIP : MOM #######
					# 22 SKIP : DAD #######
					# 23 SKIP : GENDER ####
					# 24 SKIP : PHENOTYPE #
					#######################
	}

#############################################################
### CREATE A GVCF ".list" file for each sample per family ###
#############################################################

	CREATE_GVCF_LIST ()
	{
		awk 'BEGIN {FS="\t"; OFS="/"} \
			$20=="'${FAMILY}'" \
			{print "'${CORE_PATH}'",$1,$20,$8,"GVCF",$8".g.vcf.gz"}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq \
		>| ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${FAMILY}.gvcf.list
	}

################################################
### create a list of all samples in a family ###
### *list is for gatk3, *args is for gatk4 #####
################################################

	CREATE_FAMILY_SAMPLE_LIST ()
	{
		awk 'BEGIN {FS="\t"; OFS="\t"} \
			$20=="'${FAMILY}'" \
			{print $8}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq \
		>| ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${FAMILY}.sample.list \
			&& cp ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${FAMILY}.sample.list \
			${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${FAMILY}.sample.args
	}

#####################################################################################
### fix common formatting problems in bed files to use for family level functions ###
### merge bait to target for gvcf creation, pad #####################################
### create picard style interval files ##############################################
#####################################################################################

	FIX_BED_FILES_FAMILY ()
	{
		echo \
		qsub \
			${QSUB_ARGS} \
		-N A03-FIX_BED_FILES_${FAMILY}_${OUTPUT_DIR} \
			-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}-FIX_BED_FILES.log \
		${SCRIPT_DIR}/A03-FIX_BED_FILES_FAMILY.sh \
			${ALIGNMENT_CONTAINER} \
			${CORE_PATH} \
			${PROJECT} \
			${OUTPUT_DIR} \
			${FAMILY} \
			${CODING_BED} \
			${TARGET_BED} \
			${BAIT_BED} \
			${TITV_BED} \
			${CYTOBAND_BED} \
			${REF_GENOME} \
			${REF_DICT} \
			${PADDING_LENGTH} \
			${GVCF_PAD}
	}

############################################
# RUN STEPS FOR PIPELINE AND PROJECT SETUP #
############################################

	for SAMPLE in $(awk 'BEGIN {FS="\t"; OFS="\t"} \
			{print $8}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq);
	do
		SETUP_PROJECT
		FIX_BED_FILES_SAMPLE
		echo sleep 0.1s
	done

	for FAMILY_ONLY in $(awk 'BEGIN {FS="\t"; OFS="\t"} \
			{print $20}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq);
	do
		CREATE_FAMILY_ARRAY
		CREATE_GVCF_LIST
		CREATE_FAMILY_SAMPLE_LIST
		FIX_BED_FILES_FAMILY
		echo sleep 0.1s
	done

#############################################################################################
##### RUN md5sum ON PIPELINE RESOURCE FILES AND VALIDATE THAT THEY HAVEN'T BEEN CHANGED #####
##### THESE ARE FOR FILES THAT ARE TOO LARGE FOR GIT LFS ####################################
##### A NOTIFICATION IS SENT IF THERE ARE DIFFERENCES IMMEDIATELY AFTER CHECK IS DONE #######
##### AND AGAIN AFTER PIPELINE FINISHES #####################################################
#############################################################################################

	# md5sum ON PIPELINE RESOURCE FILES AND VALIDATE THAT THEY HAVEN'T BEEN CHANGED FOR EACH PROJECT

		MD5_VALIDATION ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N A.00-MD5_VALIDATION_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/LOGS/${OUTPUT_DIR}-MD5_VALIDATION.log \
			${SCRIPT_DIR}/A.00-MD5_VALIDATION.sh \
				${ALIGNMENT_CONTAINER} \
				${CORE_PATH} \
				${OUTPUT_DIR} \
				${GIT_LFS_DIR} \
				${THREADS} \
				${SEND_TO} \
				${SUBMIT_STAMP}
		}

	# RUN MD5 VALIDATION FOR EACH PROJECT IN SAMPLE SHEET

		MD5_VALIDATION

#################################################################################################
### CREATE_PLATFROM_UNIT_ARRAY ##################################################################
### create an array at the platform unit level so that bwa mem can add metadata to the header ###
#################################################################################################

	CREATE_PLATFORM_UNIT_ARRAY ()
	{
		PLATFORM_UNIT_ARRAY=(`awk 'BEGIN {FS="\t"; OFS="\t"} \
			$8$2$3$4=="'${PLATFORM_UNIT}'" \
			{split($19,INDEL,";"); \
			print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$12,$15,$16,$17,$18,INDEL[1],INDEL[2],\
			$20,$21,$22,$23,$24}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq`)

			#  1  Project=the Seq Proj folder name

				PROJECT=${PLATFORM_UNIT_ARRAY[0]}

			#  2  FCID=flowcell that sample read group was performed on

				FCID=${PLATFORM_UNIT_ARRAY[1]}

			#  3  Lane=lane of flowcell that sample read group was performed on

				LANE=${PLATFORM_UNIT_ARRAY[2]}

			#  4  Index=sample barcode

				INDEX=${PLATFORM_UNIT_ARRAY[3]}

			#  5  Platform=type of sequencing chemistry matching SAM specification

				PLATFORM=${PLATFORM_UNIT_ARRAY[4]}

			#  6  Library_Name=library group of the sample read group,
				# Used during Marking Duplicates to determine if molecules are to be considered as part of the same library or not

				LIBRARY=${PLATFORM_UNIT_ARRAY[5]}

			#  7  Date=should be the run set up date, but doesn't have to be

				RUN_DATE=${PLATFORM_UNIT_ARRAY[6]}

			#  8  SM_Tag=sample ID

				SM_TAG=${PLATFORM_UNIT_ARRAY[7]}

					# sge sm tag. If there is an @ in the qsub or holdId name it breaks

						SGE_SM_TAG=$(echo ${SM_TAG} | sed 's/@/_/g')

			#  9  Center=the center/funding mechanism

				CENTER=${PLATFORM_UNIT_ARRAY[8]}

			# 10  Description=Sequencer model and/or setting (setting e.g. "Rapid-Run")
			## Models: “HiSeq-X”,“HiSeq-4000”,“HiSeq-2500”,“HiSeq-2000”,“NextSeq-500”,“MiSeq”

				SEQUENCER_MODEL=${PLATFORM_UNIT_ARRAY[9]}

				########################
				# 11  Seq_Exp_ID: SKIP #
				########################

			# 12  Genome_Ref=the reference genome used in the analysis pipeline

				REF_GENOME=${PLATFORM_UNIT_ARRAY[10]}

				#####################################
				# 13  Operator: SKIP ################
				# 14  Extra_VCF_Filter_Params: SKIP #
				#####################################

			# 15  TS_TV_BED_File=refseq (select) cds plus other odds and ends (.e.g. missing omim))

				TITV_BED=${PLATFORM_UNIT_ARRAY[11]}

			# 16  Baits_BED_File=a super bed file incorporating bait, target, padding and overlap with ucsc coding exons.
			# Used for limited where to run base quality score recalibration on where to create gvcf files.

				BAIT_BED=${PLATFORM_UNIT_ARRAY[12]}

			# 17  Targets_BED_File=bed file acquired from manufacturer of their targets.

				TARGET_BED=${PLATFORM_UNIT_ARRAY[13]}

			# 18  KNOWN_SITES_VCF=used to annotate ID field in VCF file. masking in base call quality score recalibration.

				DBSNP=${PLATFORM_UNIT_ARRAY[14]}

			# 19  KNOWN_INDEL_FILES=used for BQSR masking

				KNOWN_INDEL_1=${PLATFORM_UNIT_ARRAY[15]}
				KNOWN_INDEL_2=${PLATFORM_UNIT_ARRAY[16]}

			# 20 FAMILY

				FAMILY=${PLATFORM_UNIT_ARRAY[17]}

			# 21 MOM

				MOM=${PLATFORM_UNIT_ARRAY[18]}

			# 22 DAD

				DAD=${PLATFORM_UNIT_ARRAY[19]}

			# 23 GENDER

				GENDER=${PLATFORM_UNIT_ARRAY[20]}

			# 24 PHENOTYPE

				PHENOTYPE=${PLATFORM_UNIT_ARRAY[21]}
	}

	#########################################################
	# joint calling per family per chromosome core function #
	#########################################################

		GENOTYPE_GVCF ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N F01-GENOTYPE_GVCF_SCATTER_${FAMILY}_${OUTPUT_DIR}_chr${CHROMOSOME} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.GENOTYPE_GVCF_chr${CHROMOSOME}.log \
			${SCRIPT_DIR}/F01-GENOTYPE_GVCF_SCATTER.sh \
				${GATK_3_7_0_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${REF_GENOME} \
				${DBSNP} \
				${CHROMOSOME} \
				${CONTROL_REPO} \
				${CONTROL_DATA_SET_FILE} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	########################################
	# scatter genotype gvcfs by chromosome #
	########################################

		SCATTER_GENOTYPE_GVCF_PER_CHROMOSOME ()
		{
			for CHROMOSOME in $(sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' ${BAIT_BED} \
				| sed -r 's/[[:space:]]+/\t/g' \
				| sed 's/chr//g' \
				| egrep "^[0-9]|^X|^Y" \
				| cut -f 1 \
				| sort -V \
				| uniq \
				| singularity exec ${ALIGNMENT_CONTAINER} datamash \
					collapse 1 \
				| sed 's/,/ /g');
			do
				GENOTYPE_GVCF
				echo sleep 0.1s
			done
		}

#################################################################################
# RUN STEPS TO DO JOINT CALLING PER FAMILY PER SET OF INTERVALS IN A CHROMOSOME #
#################################################################################

	for FAMILY_ONLY in $(awk 'BEGIN {FS="\t"; OFS="\t"} \
			{print $20}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq);
	do
		CREATE_FAMILY_ARRAY
		# BUILD_HOLD_ID_PATH_GENOTYPE_GVCF
		SCATTER_GENOTYPE_GVCF_PER_CHROMOSOME
		echo sleep 0.1s
	done

########################################################################################
##### GATHER UP THE PER FAMILY PER CHROMOSOME GVCF FILES INTO A SINGLE FAMILY GVCF #####
########################################################################################

	########################################################################
	# create a hold_id variable for genotype gvcfs scatter step per family #
	########################################################################

		BUILD_HOLD_ID_PATH_GENOTYPE_GVCF_GATHER ()
		{
			for JC_PROJECT in \
				$(echo ${OUTPUT_DIR})
			do
				HOLD_ID_PATH="-hold_jid "

				for CHROMOSOME in $(sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' ${BAIT_BED} \
					| sed -r 's/[[:space:]]+/\t/g' \
					| sed 's/chr//g' \
					| egrep "^[0-9]|^X|^Y" \
					| cut -f 1 \
					| sort -V \
					| uniq \
					| singularity exec ${ALIGNMENT_CONTAINER} datamash \
						collapse 1 \
					| sed 's/,/ /g');
				do
					HOLD_ID_PATH="${HOLD_ID_PATH}F01-GENOTYPE_GVCF_SCATTER_${FAMILY}_${JC_PROJECT}_chr${CHROMOSOME},"
				done
			done
		}

	###########################################################
	# gather up per chromosome genotyped vcf files per family #
	###########################################################

		CALL_GENOTYPE_GVCF_GATHER ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N G01-GENOTYPE_GVCF_GATHER_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.GENOTYPE_GVCF_GATHER.log \
			${HOLD_ID_PATH}A03-FIX_BED_FILES_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/G01-GENOTYPE_GVCF_GATHER.sh \
				${GATK_3_7_0_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${REF_GENOME} \
				${BAIT_BED} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

#####################################################
# RUN STEP TO GATHER PER CHROMOSOME PER FAMILY VCFS #
#####################################################

	for FAMILY_ONLY in $(awk 'BEGIN {FS="\t"; OFS="\t"} \
			{print $20}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq)
	do
		CREATE_FAMILY_ARRAY
		BUILD_HOLD_ID_PATH_GENOTYPE_GVCF_GATHER
		CALL_GENOTYPE_GVCF_GATHER
		echo sleep 0.1s
	done

########################################################
##### DO VARIANT QUALITY SCORE RECALIBRATION ###########
# I THINK ALL OF THIS CAN BE MOVED INTO THE LOOP ABOVE #
# BUT I LIKE TO KEEP IT HERE ###########################
########################################################

	##############################################
	# Run Variant Recalibrator for the SNP model #
	##############################################

		RUN_VQSR_SNP ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N H01-RUN_VQSR_SNP_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.RUN_VQSR_SNP.log \
			-hold_jid G01-GENOTYPE_GVCF_GATHER_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/H01-RUN_VARIANT_RECALIBRATOR_SNP.sh \
				${GATK_3_7_0_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${REF_GENOME} \
				${DBSNP} \
				${HAPMAP} \
				${OMNI_1KG} \
				${HI_CONF_1KG_PHASE1_SNP} \
				${SEND_TO} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	################################################
	# Run Variant Recalibrator for the INDEL model #
	################################################

		RUN_VQSR_INDEL ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N H02-RUN_VQSR_INDEL_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.RUN_VQSR_INDEL.log \
			-hold_jid G01-GENOTYPE_GVCF_GATHER_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/H02-RUN_VARIANT_RECALIBRATOR_INDEL.sh \
				${GATK_3_7_0_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${REF_GENOME} \
				${MILLS_1KG_GOLD_INDEL} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	##############################################
	# Run Variant Recalibrator for the SNP model #
	##############################################

		APPLY_VQSR_SNP ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N I01-APPLY_VQSR_SNP_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.APPLY_VQSR_SNP.log \
			-hold_jid H01-RUN_VQSR_SNP_${FAMILY}_${OUTPUT_DIR},H02-RUN_VQSR_INDEL_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/I01-APPLY_VARIANT_RECALIBRATION_SNP.sh \
				${GATK_3_7_0_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${REF_GENOME} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	##############################################
	# Run Variant Recalibrator for the SNP model #
	##############################################

		APPLY_VQSR_INDEL ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N J01-APPLY_VQSR_INDEL_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.APPLY_VQSR_INDEL.log \
			-hold_jid I01-APPLY_VQSR_SNP_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/J01-APPLY_VARIANT_RECALIBRATION_INDEL.sh \
				${GATK_3_7_0_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${REF_GENOME} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

########################
# RUN STEPS TO DO VQSR #
########################

	for FAMILY_ONLY in $(awk 'BEGIN {FS="\t"; OFS="\t"} \
			{print $20}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq)
	do
		CREATE_FAMILY_ARRAY
		RUN_VQSR_SNP
		echo sleep 0.1s
		RUN_VQSR_INDEL
		echo sleep 0.1s
		APPLY_VQSR_SNP
		echo sleep 0.1s
		APPLY_VQSR_INDEL
		echo sleep 0.1s
	done

################################################
##### SCATTER GATHER FOR ADDING ANNOTATION #####
################################################

	CALL_VARIANT_ANNOTATOR ()
	{
		echo \
		qsub \
			${QSUB_ARGS} \
		-N K01-VARIANT_ANNOTATOR_${FAMILY}_${OUTPUT_DIR}_${CHROMOSOME} \
			-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.VARIANT_ANNOTATOR_${CHROMOSOME}.log \
		-hold_jid J01-APPLY_VQSR_INDEL_${FAMILY}_${OUTPUT_DIR} \
		${SCRIPT_DIR}/K01-VARIANT_ANNOTATOR_SCATTER.sh \
			${GATK_3_7_0_CONTAINER} \
			${CORE_PATH} \
			${PED_FILE} \
			${PROJECT} \
			${OUTPUT_DIR} \
			${FAMILY} \
			${REF_GENOME} \
			${CHROMOSOME} \
			${PHASE3_1KG_AUTOSOMES} \
			${THREADS} \
			${SAMPLE_SHEET} \
			${SUBMIT_STAMP}
	}

#####################################
# RUN STEPS TO DO VARIANT ANNOTATOR #
#####################################

	for FAMILY_ONLY in $(awk 'BEGIN {FS="\t"; OFS="\t"} \
			{print $20}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq);
	do
		CREATE_FAMILY_ARRAY

		for CHROMOSOME in $(sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' ${BAIT_BED} \
			| sed -r 's/[[:space:]]+/\t/g' \
			| sed 's/chr//g' \
			| egrep "^[0-9]|^X|^Y" \
			| cut -f 1 \
			| sort -V \
			| uniq \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				collapse 1 \
			| sed 's/,/ /g');
		do
			CALL_VARIANT_ANNOTATOR
			echo sleep 0.1s
		done
	done

##############################################################################################
##### GATHER UP THE PER FAMILY PER CHROMOSOME ANNOTATED VCF FILES INTO A SINGLE VCF FILE #####
##### RUN PCA/RELATEDNESS WORKFLOW ###########################################################
##### RUN ROH ANALYSIS #######################################################################
##############################################################################################

	######################################################
	# generate hold id from scatter of variant annotator #
	######################################################

		BUILD_HOLD_ID_PATH_ADD_MORE_ANNOTATION ()
		{
			for JC_PROJECT in \
				$(echo ${OUTPUT_DIR})
			do
				HOLD_ID_PATH="-hold_jid "

				for CHROMOSOME in $(sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' ${BAIT_BED} \
					| sed -r 's/[[:space:]]+/\t/g' \
					| sed 's/chr//g' \
					| egrep "^[0-9]|^X|^Y" \
					| cut -f 1 \
					| sort -V \
					| uniq \
					| singularity exec ${ALIGNMENT_CONTAINER} datamash \
						collapse 1 \
					| sed 's/,/ /g');
				do
					HOLD_ID_PATH="${HOLD_ID_PATH}K01-VARIANT_ANNOTATOR_${FAMILY}_${JC_PROJECT}_${CHROMOSOME},"
				done
			done
		}

	############################
	# variant annotator gather #
	############################

		CALL_VARIANT_ANNOTATOR_GATHER ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N L01-VARIANT_ANNOTATOR_GATHER_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.MORE_VARIANT_ANNOTATOR_GATHER.log \
			${HOLD_ID_PATH} \
			${SCRIPT_DIR}/L01-VARIANT_ANNOTATOR_GATHER.sh \
				${GATK_3_7_0_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${REF_GENOME} \
				${BAIT_BED} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	#####################################################################
	# FILTER TO JUST PASSING BIALLELIC SNV SITES ON THE CODING BED FILE #
	# TEMPORARY FILE USED FOR PCA AND RELATEDNESS #######################
	#####################################################################

		CALL_PASS_BIALLELIC_SNV_COHORT ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N M01-FILTER_COHORT_SNV_PASS_BIALLELIC_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.FILTER_COHORT_SNV_PASS_BIALLELIC.log \
			-hold_jid L01-VARIANT_ANNOTATOR_GATHER_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/M01-FILTER_COHORT_SNV_PASS_BIALLELIC.sh \
				${ALIGNMENT_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${REF_GENOME} \
				${CODING_BED} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	################################
	# RUN PCA AND KINSHIP WORKFLOW #
	# USES KING AND PLINK ##########
	################################

		CALL_PCA_RELATEDNESS ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N M01-A01-PCA_RELATEDNESS_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.PCA_RELATEDNESS.log \
			-hold_jid M01-FILTER_COHORT_SNV_PASS_BIALLELIC_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/M01-A01-PCA_RELATEDNESS.sh \
				${GATK_3_7_0_CONTAINER} \
				${PCA_RELATEDNESS_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${REF_GENOME} \
				${PED_FILE} \
				${CONTROL_PED_FILE} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	###########################################################
	# FILTER OUT REPEATMASKED REGIONS TO PERFORM ROH ANALYSIS #
	###########################################################

		FILTER_REPEATMASK ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N M01-A02-FILTER_REPEATMASK_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.FILTER_REPEATMASK.log \
			-hold_jid M01-FILTER_COHORT_SNV_PASS_BIALLELIC_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/M01-A02-FILTER_REPEATMASK.sh \
				${ALIGNMENT_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${REF_GENOME} \
				${UCSC_REPEATMASK} \
				${MDUST_REPEATMASK} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	####################
	# RUN ROH ANALYSIS #
	####################

		BCFTOOLS_ROH ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N M01-A02-A01-BCFTOOLS_ROH_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.BCFTOOLS_ROH.log \
			-hold_jid M01-A02-FILTER_REPEATMASK_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/M01-A02-A01-BCFTOOLS_ROH.sh \
				${MITO_MUTECT2_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${THREADS} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

##################################################################
# RUN STEPS TO DO VARIANT ANNOTATOR GATHER, PCA/RELATEDNESS, ROH #
##################################################################

	for FAMILY_ONLY in $(awk 'BEGIN {FS="\t"; OFS="\t"} \
			{print $20}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq)
	do
		CREATE_FAMILY_ARRAY
		BUILD_HOLD_ID_PATH_ADD_MORE_ANNOTATION
		CALL_VARIANT_ANNOTATOR_GATHER
		echo sleep 0.1s
		CALL_PASS_BIALLELIC_SNV_COHORT
		echo sleep 0.1s
		CALL_PCA_RELATEDNESS
		echo sleep 0.1s
		FILTER_REPEATMASK
		echo sleep 0.1s
		BCFTOOLS_ROH
		echo sleep 0.1s
	done

##################################################################
##### RUNNING FILTER TO FAMILY ALL SITES BY CHROMOSOME ###########
# USE GATK4 HERE BECAUSE IT HANDLES SPANNING DELETIONS CORRECTLY #
##################################################################

	CALL_FILTER_TO_FAMILY_ALL_SITES ()
	{
		echo \
		qsub \
			${QSUB_ARGS} \
		-N L02-FILTER_TO_FAMILY_ALL_SITES_${FAMILY}_${OUTPUT_DIR}_${CHROMOSOME} \
			-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.FILTER_TO_FAMILY_ALL_SITES_${CHROMOSOME}.log \
		-hold_jid K01-VARIANT_ANNOTATOR_${FAMILY}_${OUTPUT_DIR}_${CHROMOSOME} \
		${SCRIPT_DIR}/L02-FILTER_TO_FAMILY_ALL_SITES_CHR.sh \
			${ALIGNMENT_CONTAINER} \
			${CORE_PATH} \
			${PROJECT} \
			${OUTPUT_DIR} \
			${FAMILY} \
			${REF_GENOME} \
			${CHROMOSOME} \
			${SAMPLE_SHEET} \
			${SUBMIT_STAMP}
	}

####################################################
# RUN STEPS TO FILTER ALL SITES VCF TO FAMILY ONLY #
####################################################

	for FAMILY_ONLY in $(awk 'BEGIN {FS="\t"; OFS="\t"} \
			{print $20}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq);
	do
		CREATE_FAMILY_ARRAY

		for CHROMOSOME in $(sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' ${BAIT_BED} \
			| sed -r 's/[[:space:]]+/\t/g' \
			| sed 's/chr//g' \
			| egrep "^[0-9]|^X|^Y" \
			| cut -f 1 \
			| sort -V \
			| uniq \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				collapse 1 \
			| sed 's/,/ /g');
		do
			CALL_FILTER_TO_FAMILY_ALL_SITES
			echo sleep 0.1s
		done
	done
	
#####################################################################################################
##### GATHER UP THE PER FAMILY PER CHROMOSOME FILTER TO FAMILY VCF FILES INTO A SINGLE VCF FILE #####
#####################################################################################################

	#################################################################################
	# create job hold id to gather up per chromosome family only all sites vcf file #
	#################################################################################

		BUILD_HOLD_ID_PATH_FILTER_TO_FAMILY_VCF ()
		{
			for JC_PROJECT in \
				$(echo ${OUTPUT_DIR});
			do
				HOLD_ID_PATH="-hold_jid "

				for CHROMOSOME in $(sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' ${BAIT_BED} \
					| sed -r 's/[[:space:]]+/\t/g' \
					| sed 's/chr//g' \
					| egrep "^[0-9]|^X|^Y" \
					| cut -f 1 \
					| sort -V \
					| uniq \
					| singularity exec ${ALIGNMENT_CONTAINER} datamash \
						collapse 1 \
					| sed 's/,/ /g');
				do
					HOLD_ID_PATH="${HOLD_ID_PATH}L02-FILTER_TO_FAMILY_ALL_SITES_${FAMILY}_${JC_PROJECT}_${CHROMOSOME},"
				done
			done
		}

	######################################################
	# gather up per chromosome family only all sites vcf #
	######################################################

		CALL_FILTER_TO_FAMILY_VCF_GATHER ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N M02-FILTER_TO_FAMILY_ALL_SITES_GATHER_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.FILTER_TO_FAMILY_ALL_SITES_GATHER.log \
			${HOLD_ID_PATH} \
			${SCRIPT_DIR}/M02-FILTER_TO_FAMILY_ALL_SITES_GATHER.sh \
				${GATK_3_7_0_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${REF_GENOME} \
				${BAIT_BED} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	############################################################
	# filter family only all sites vcf to coding plus user pad #
	# the output for this might get moved to temp ##############
	############################################################

		CALL_FILTER_FAMILY_TO_CODING_PLUS_PAD ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N N01-FILTER_FAMILY_CODING_PLUS_PAD_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.FILTER_FAMILY_CODING_PLUS_PAD.log \
			-hold_jid M02-FILTER_TO_FAMILY_ALL_SITES_GATHER_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/N01-FILTER_FAMILY_CODING_PLUS_PAD.sh \
				${ALIGNMENT_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${CODING_BED} \
				${PADDING_LENGTH} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	############################################################
	# filter family only all sites vcf to target plus user pad #
	############################################################

		CALL_FILTER_FAMILY_TO_TARGET_PLUS_PAD ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N N02-FILTER_FAMILY_TARGET_PLUS_PAD_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.FILTER_FAMILY_TARGET_PLUS_PAD.log \
			-hold_jid M02-FILTER_TO_FAMILY_ALL_SITES_GATHER_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/N02-FILTER_FAMILY_TARGET_PLUS_PAD.sh \
				${ALIGNMENT_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${TARGET_BED} \
				${PADDING_LENGTH} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	############################################################
	# filter family only all sites vcf to target plus user pad #
	############################################################

		CALL_FILTER_FAMILY_TO_TARGET_PLUS_PAD_VARIANTS ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N N02-A01-FILTER_TO_FAMILY_TARGET_PLUS_PAD_VARIANTS_${FAMILY}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/LOGS/${FAMILY}_${OUTPUT_DIR}.FILTER_TO_FAMILY_TARGET_PLUS_PAD_VARIANTS.log \
			-hold_jid N02-FILTER_FAMILY_TARGET_PLUS_PAD_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/N02-A01-FILTER_TO_FAMILY_TARGET_PLUS_PAD_VARIANTS.sh \
				${GATK_3_7_0_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${REF_GENOME} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

########################################################################
# RUN STEPS TO GATHER UP PER CHROMOSOME FAMILY ONLY ALL SITES VCF FILE #
########################################################################

	for FAMILY_ONLY in $(awk 'BEGIN {FS="\t"; OFS="\t"} \
			{print $20}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq);
	do
		CREATE_FAMILY_ARRAY
		BUILD_HOLD_ID_PATH_FILTER_TO_FAMILY_VCF
		CALL_FILTER_TO_FAMILY_VCF_GATHER
		echo sleep 0.1s
		CALL_FILTER_FAMILY_TO_CODING_PLUS_PAD
		echo sleep 0.1s
		CALL_FILTER_FAMILY_TO_TARGET_PLUS_PAD
		echo sleep 0.1s
		CALL_FILTER_FAMILY_TO_TARGET_PLUS_PAD_VARIANTS
		echo sleep 0.1s
	done

#####################################
##### SUBSETTING TO SAMPLE VCFS #####
#####################################

	#####################################################################################
	# subset sample all sites to from family coding/bait bed file plus user defined pad #
	#####################################################################################

		EXTRACT_SAMPLE_ALL_SITES ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N P01-FILTER_TO_SAMPLE_ALL_SITES_${SGE_SM_TAG}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/LOGS/${SM_TAG}-FILTER_TO_SAMPLE_ALL_SITES.log \
			-hold_jid N01-FILTER_FAMILY_CODING_PLUS_PAD_${FAMILY}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/P01-FILTER_TO_SAMPLE_ALL_SITES.sh \
				${ALIGNMENT_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${SM_TAG} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	##################################################################################
	# subset sample variant sites to from coding/bait bed file plus user defined pad #
	##################################################################################

		EXTRACT_SAMPLE_VARIANTS ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N Q01-FILTER_TO_SAMPLE_VARIANTS_${SGE_SM_TAG}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/LOGS/${SM_TAG}-FILTER_TO_SAMPLE_VARIANTS.log \
			-hold_jid P01-FILTER_TO_SAMPLE_ALL_SITES_${SGE_SM_TAG}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/Q01-FILTER_TO_SAMPLE_VARIANTS.sh \
				${GATK_3_7_0_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${SM_TAG} \
				${REF_GENOME} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	#################################################################################################
	# generate vcf metrics for sample variant sites from coding/bait bed file plus user defined pad #
	#################################################################################################

		VCF_METRICS_BAIT ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N Q01-A01-VCF_METRICS_BAIT_${SGE_SM_TAG}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/LOGS/${SM_TAG}-VCF_METRICS_BAIT.log \
			-hold_jid Q01-FILTER_TO_SAMPLE_VARIANTS_${SGE_SM_TAG}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/Q01-A01-VCF_METRICS_BAIT.sh \
				${ALIGNMENT_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${SM_TAG} \
				${REF_DICT} \
				${DBSNP} \
				${THREADS} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	#####################################################################
	# generate vcf metrics for sample variant sites from ti/tv bed file #
	#####################################################################

		VCF_METRICS_TITV ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N Q01-A02-VCF_METRICS_TITV_${SGE_SM_TAG}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/LOGS/${SM_TAG}-VCF_METRICS_TITV.log \
			-hold_jid Q01-FILTER_TO_SAMPLE_VARIANTS_${SGE_SM_TAG}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/Q01-A02-VCF_METRICS_TITV.sh \
				${ALIGNMENT_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${SM_TAG} \
				${REF_DICT} \
				${TITV_BED} \
				${DBSNP_129} \
				${THREADS} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	#########################################################################
	# subset sample to all sites from target bed file plus user defined pad #
	#########################################################################

		EXTRACT_SAMPLE_ALL_SITES_ON_TARGET ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N Q02-FILTER_TO_SAMPLE_ALL_SITES_TARGET_${SGE_SM_TAG}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/LOGS/${SM_TAG}-FILTER_TO_SAMPLE_ALL_SITES_TARGET.log \
			-hold_jid P01-FILTER_TO_SAMPLE_ALL_SITES_${SGE_SM_TAG}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/Q02-FILTER_TO_SAMPLE_ALL_SITES_TARGET.sh \
				${ALIGNMENT_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${SM_TAG} \
				${TARGET_BED} \
				${PADDING_LENGTH} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	########################################################################
	# subset sample variant sites to target bed file plus user defined pad #
	########################################################################

		EXTRACT_SAMPLE_VARIANTS_ON_TARGET ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N R01-FILTER_TO_SAMPLE_VARIANTS_TARGET_${SGE_SM_TAG}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/LOGS/${SM_TAG}-FILTER_TO_SAMPLE_VARIANTS_TARGET.log \
			-hold_jid Q02-FILTER_TO_SAMPLE_ALL_SITES_TARGET_${SGE_SM_TAG}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/R01-FILTER_TO_SAMPLE_VARIANTS_TARGET.sh \
				${GATK_3_7_0_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${SM_TAG} \
				${REF_GENOME} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	############################################################################################
	# generate vcf metrics for sample variant sites from target bed file plus user defined pad #
	############################################################################################

		VCF_METRICS_TARGET ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N R01-A02-VCF_METRICS_TARGET_${SGE_SM_TAG}_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/LOGS/${SM_TAG}-VCF_METRICS_TARGET.log \
			-hold_jid R01-FILTER_TO_SAMPLE_VARIANTS_TARGET_${SGE_SM_TAG}_${OUTPUT_DIR} \
			${SCRIPT_DIR}/R01-A02-VCF_METRICS_TARGET.sh \
				${ALIGNMENT_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${OUTPUT_DIR} \
				${FAMILY} \
				${SM_TAG} \
				${REF_DICT} \
				${DBSNP} \
				${THREADS} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

######################################
### QC REPORT PREP FOR EACH SAMPLE ###
######################################

QC_REPORT_PREP ()
{
echo \
qsub \
	${QSUB_ARGS} \
-N X01-QC_REPORT_PREP_${SGE_SM_TAG}_${OUTPUT_DIR} \
	-o ${CORE_PATH}/${OUTPUT_DIR}/${FAMILY}/${SM_TAG}/LOGS/${SM_TAG}-QC_REPORT_PREP.log \
-hold_jid \
R01-A02-VCF_METRICS_TARGET_${SGE_SM_TAG}_${OUTPUT_DIR},\
Q01-A02-VCF_METRICS_TITV_${SGE_SM_TAG}_${OUTPUT_DIR},\
Q01-A01-VCF_METRICS_BAIT_${SGE_SM_TAG}_${OUTPUT_DIR} \
${SCRIPT_DIR}/X01-QC_REPORT_PREP.sh \
	${ALIGNMENT_CONTAINER} \
	${CORE_PATH} \
	${PROJECT} \
	${OUTPUT_DIR} \
	${FAMILY} \
	${SM_TAG} \
	${FATHER} \
	${MOTHER} \
	${GENDER} \
	${PHENOTYPE} \
	${GIT_LFS_VERSION}
}

##################################################
# RUN VCF SAMPLE SUBSTEP STEP AND QC REPORT PREP #
##################################################

	for SAMPLE in $(awk 'BEGIN {FS="\t"; OFS="\t"} \
			{print $8}' \
		~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
			| sort \
			| uniq);
	do
		CREATE_SAMPLE_ARRAY
		EXTRACT_SAMPLE_ALL_SITES
		echo sleep 0.1s
		EXTRACT_SAMPLE_VARIANTS
		echo sleep 0.1s
		VCF_METRICS_BAIT
		echo sleep 0.1s
		VCF_METRICS_TITV
		echo sleep 0.1s
		EXTRACT_SAMPLE_ALL_SITES_ON_TARGET
		echo sleep 0.1s
		EXTRACT_SAMPLE_VARIANTS_ON_TARGET
		echo sleep 0.1s
		VCF_METRICS_TARGET
		echo sleep 0.1s
		QC_REPORT_PREP
		echo sleep 0.1s
	done

#############################
##### END PROJECT TASKS #####
#############################

	############################################################
	# build hold id for qc report prep per sample, per project #
	############################################################

		BUILD_HOLD_ID_PATH_PROJECT_WRAP_UP_SAMPLE ()
		{
			HOLD_ID_PATH_QC_REPORT_PREP="-hold_jid "

			for SAMPLE in $(awk 'BEGIN {FS="\t"; OFS="\t"} \
					$1=="'${PROJECT}'" \
					{print $8}' \
				~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
					| sort \
					| uniq);
			do
				CREATE_SAMPLE_ARRAY

				HOLD_ID_PATH_QC_REPORT_PREP="${HOLD_ID_PATH_QC_REPORT_PREP}X01-QC_REPORT_PREP_${SGE_SM_TAG}_${JC_PROJECT},"

				HOLD_ID_PATH_QC_REPORT_PREP=`echo ${HOLD_ID_PATH_QC_REPORT_PREP} | sed 's/@/_/g'`
			done
		}

	###################################################
	# add hold id for PCA/RELATEDNESS FOR EACH FAMILY #
	###################################################

		BUILD_HOLD_ID_PATH_PROJECT_WRAP_UP_FAMILY ()
		{
			HOLD_ID_PATH_PCA=""

			for FAMILY_ONLY in $(awk 'BEGIN {FS="\t"; OFS="\t"} \
					$1=="'${PROJECT}'" \
					{print $20}' \
				~/JOINT_CALL_TEMP/${MANIFEST_PREFIX}.${PED_PREFIX}.join.txt \
					| sort \
					| uniq);
			do
				CREATE_FAMILY_ARRAY

				HOLD_ID_PATH_PCA="${HOLD_ID_PATH_PCA}M01-A01-PCA_RELATEDNESS_${FAMILY}_${JC_PROJECT},M01-A02-A01-BCFTOOLS_ROH_${FAMILY}_${JC_PROJECT},"
			done
		}

	#########################################################################
	# run end project functions (qc report, file clean-up) for each project #
	#########################################################################

		PROJECT_WRAP_UP ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N X01-X01_END_PROJECT_TASKS_${OUTPUT_DIR} \
				-o ${CORE_PATH}/${OUTPUT_DIR}/LOGS/${PROJECT}-END_PROJECT_TASKS.log \
			${HOLD_ID_PATH_QC_REPORT_PREP}${HOLD_ID_PATH_PCA}A.00-MD5_VALIDATION_${PROJECT} \
			${SCRIPT_DIR}/X01-X01-END_PROJECT_TASKS.sh \
				${ALIGNMENT_CONTAINER} \
				${CORE_PATH} \
				${OUTPUT_DIR} \
				${SCRIPT_DIR} \
				${SUBMITTER_ID} \
				${SAMPLE_SHEET} \
				${PED_FILE} \
				${SUBMIT_STAMP} \
				${SEND_TO} \
				${THREADS}
		}

##################
# RUN FINAL LOOP #
##################

	for JC_PROJECT in \
		$(echo ${OUTPUT_DIR});
	do
		BUILD_HOLD_ID_PATH_PROJECT_WRAP_UP_SAMPLE
		BUILD_HOLD_ID_PATH_PROJECT_WRAP_UP_FAMILY
		PROJECT_WRAP_UP
	done

#############################################################
##### MESSAGE THAT SAMPLE SHEET HAS FINISHED SUBMITTING #####
#############################################################

	printf "echo\n"

	printf "echo ${SAMPLE_SHEET} has finished submitting at `date`\n"

######################################
##### EMAIL WHEN DONE SUBMITTING #####
######################################

	printf "${SAMPLE_SHEET}\nhas finished submitting at\n`date`\nby `whoami`" \
		| mail -s "${PERSON_NAME} has submitted SUBMITTER_JHG-Clinical_Joint_Caller.sh" \
			${SEND_TO}
