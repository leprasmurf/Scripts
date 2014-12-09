#!/bin/bash

################################
##### Variable Declaration #####
################################
FPS=8;
VID_WIDTH=800;
VID_HEIGHT=600;
# /path/to/events/cam/year/month/day/hour
EVENTS="/export/zoneminder/events/?/??/??/??";
# /path/to/videos
VIDEO_PATH="/export/zoneminder/videos"
MENCODER_OPTIONS="-mf w=${VID_WIDTH}:h=${VID_HEIGHT}:fps=${FPS}:type=jpg -ovc lavc -lavcopts vcodec=mpeg4:mbd=2:trell -oac copy";

#############################
##### Command Variables #####
#############################
ECHO="/bin/echo";
FIND="/usr/bin/find";
MENCODER="/usr/bin/mencoder";
MKTEMP="/bin/mktemp";
SORT="/usr/bin/sort";

###########################
##### Color Variables #####
###########################
# src: http://linux.101hacks.com/ps1-examples/prompt-color-using-tput/
TXT_BLACK=$( tput setaf 0 );
TXT_RED=$( tput setaf 1 );
TXT_GREEN=$( tput setaf 2 );
TXT_YELLOW=$( tput setaf 3 );
TXT_BLUE=$( tput setaf 4 );
TXT_MAGENTA=$( tput setaf 5 );
TXT_CYAN=$( tput setaf 6 );
TXT_WHITE=$( tput setaf 7 );
TXT_DIM=$( tput dim );
TXT_RESET=$( tput sgr0 );

###########################
###### Help function ######
###########################
function help {
	${ECHO} "";
	${ECHO} "${TXT_GREEN}Usage${TXT_RESET}: $0 [options]";
	${ECHO} "\t-d|--days\t- Combine all images into one video per day (default)";
	${ECHO} "\t-f|--fast\t- Use fastest mencoder options, result is larger";
	${ECHO} "\t-m|--month\t- Combine all images into one video per month";
	${ECHO} "\t-o|--hours\t- Combine all images into one video per hour";
	${ECHO} "\t-s|--slow\t- Use compression mencoder options, result is smaller but takes more time (default)";
	${ECHO} "";
}

###########################
###### Read in flags ######
###########################
while [ $# -ne 0 ]; do
	case "$1" in
		-h|--help)
			help;
			exit 0;
			;;
		-d|--days)
			EVENTS="/export/zoneminder/events/?/??/??/??";
			;;
		-f|--fast)
			MENCODER_OPTIONS="-mf w=${VID_WIDTH}:h=${VID_HEIGHT}:fps=${FPS}:type=jpg -ovc copy -oac copy";
			;;
		-o|--hour)
			EVENTS="/export/zoneminder/events/?/??/??/??/??";
			;;
		-m|--month)
			EVENTS="/export/zoneminder/events/?/??/??";
			;;
		-s|--slow)
			MENCODER_OPTIONS="-mf w=${VID_WIDTH}:h=${VID_HEIGHT}:fps=${FPS}:type=jpg -ovc lavc -lavcopts vcodec=mpeg4:mbd=2:trell -oac copy";
			;;
		*)
			${ECHO} "Invalid Option: ${TXT_RED}$1${TXT_RESET}";
			help;
			exit 1;
			;;
	esac
	shift
done

########################
##### Script Logic #####
########################
# Cycle through all the instances of Year/Month/Day/Hour
for i in ${EVENTS};
do
  # Split out the variables for the output name
  #   Variable will be blank if option selected doesn't include specific unit of time
  #   (i.e., if --days is passed HOUR will be blank)
  CAM=`echo ${i}|awk -F'/' '{print $5}'`;
  YEAR=`echo ${i}|awk -F'/' '{print $6}'`;
  MONTH=`echo ${i}|awk -F'/' '{print $7}'`;
  DAY=`echo ${i}|awk -F'/' '{print $8}'`;
  HOUR=`echo ${i}|awk -F'/' '{print $9}'`;

  # Create a temp file to hold a list of all the images
  TMP_FILE=`${MKTEMP} --suffix=.zoneminder`;

  # Find all the images and pipe the output to the temp file
  ${FIND} ${i} -iname '*capture*' -type f > ${TMP_FILE};

  # Sort the temp file into a new file
  ${SORT} -o "${TMP_FILE}.sorted" ${TMP_FILE};

  # Encode the images into a movie
  ${MENCODER} mf://@/${TMP_FILE}.sorted ${MENCODER_OPTIONS} -o ${VIDEO_PATH}/${CAM}/20${YEAR}${MONTH}${DAY}${HOUR}.avi
done
