#!/bin/bash

##########################
##### Data variables #####
##########################
DEBUG=0;

API=$( head -n1 /home/leprasmurf/.do_api_key )
API_URL="https://api.digitalocean.com/v2/";
CONFIRM='n';
IMAGE="";
MIN_DISK_SIZE="";
NAME="";
QUERY_SIZE="100"
REGION="";
SIZE="";
SLUG="";
TYPE='';

#############################
##### Command variables #####
#############################
AWK=$( which awk || echo "/usr/bin/awk" );
CURL=$( which curl || echo "/usr/bin/curl" )" -s -H 'Content-Type: application/json'";
ECHO=$( which echo || echo "/usr/bin/echo" )" -e";
GREP=$( which grep || echo "/usr/bin/grep" );
MV=$( which mv || echo "/bin/mv" );
SED=$( which sed || echo "/usr/bin/sed" )
TR=$( which tr || echo "/usr/bin/tr" );

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

#############################
##### Support Functions #####
#############################
#TODO
function helpme {
	${ECHO} "";
	${ECHO} "${TXT_GREEN}Usage${TXT_RESET}: $0 [options]";
	${ECHO} "\t-a|--api [key]\t\t- The API key to authenticate with";
	${ECHO} "\t-h|--help\t\t- Display this help";
	${ECHO} "\t-i|--image [id]\t\t- The ID of the image to use for building the droplet";
	${ECHO} "\t-n|--name [name]\t- The name of the droplet to be built";
	${ECHO} "\t-r|--region [name]\t- The region name to build your droplet in (e.g., lon1, nyc3, ams2)";
	${ECHO} "\t-s|--size [mem]\t\t- The droplet size to build (e.g., 1gb, 512mb, 48gb)";
	${ECHO} "";
}

function get_image_details {
	${CURL} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images?page=1&per_page=${QUERY_SIZE}&${1}" | ${GREP} -Po '"slug":(\d*?,|.*?[^\\]",)' | ${AWK} -F'"' 'BEGIN {counter = 1 } { { print counter " - " $4 } { counter++ } }'

	while [ -z ${SLUG} ];
	do
		${ECHO} -n "${TXT_YELLOW}Please select an image:${TXT_RESET} ";
		read SLUG;

		SLUG=$( ${ECHO} ${SLUG} | ${SED} -e 's/[^0-9]//g' );
	done

	record=$( ${CURL} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images?page=${SLUG}&per_page=1&${1}" );

	IMAGE=$( ${ECHO} ${record} | ${GREP} -Po '"id":(\d*?,|.*?[^\\]",)' | ${AWK} -F'[:,]' '{print $2}' );

	if [ -z ${IMAGE} ];
	then
		${ECHO} "${TXT_RED}No image id found for your selection (${TXT_RESET}${SLUG}${TXT_RED}).${TXT_RESET}";
		exit 1;
	fi

	${ECHO} "${TXT_BLUE}Image ID:${TXT_RESET} ${IMAGE}";
}

function get_region {
	record=$( ${CURL} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images/${IMAGE}" );

	avail_regions=( $( ${ECHO} ${record} | ${GREP} -Po '"regions":(\d*?,|.*?[^\\]],)' | ${AWK} -F'[][]' '{print $2}' | ${SED} -e 's/"//g' -e 's/,/ /g' ) );

	if [ -z ${avail_regions} ];
	then
		${ECHO} "${TXT_RED}No regions available for this image.${TXT_RESET}";
	fi

	counter=0;
	for region in ${avail_regions[@]};
	do
		${ECHO} "${counter} - ${region}";
		let counter++;
	done

	while [ -z ${region_id} ];
	do
		${ECHO} -n "${TXT_YELLOW}Please select a region:${TXT_RESET} ";
		read region_id;

		region_id=$( ${ECHO} ${region_id} | ${SED} -e 's/[^0-9]//g' );

		if [ ${region_id} -gt ${#avail_regions[@]} ];
		then
			${ECHO} "${TXT_RED}Your entry (${TXT_RESET}${region_id}${TXT_RED}) is beyond the available selections.";
			unset region_id;
		fi
	done

	REGION=${avail_regions[${region_id}]};
	${ECHO} "${TXT_BLUE}Building in:${TXT_RESET} ${REGION}";

	MIN_DISK_SIZE=$( ${ECHO} ${record} | ${GREP} -Po '"min_disk_size":(\d*)' | ${AWK} -F":" '{print $2}' );
}

# Get the Image ID for the Base Distro 
function get_distro {
	${ECHO} "${TXT_CYAN}Retrieving the list of images...${TXT_RESET}";

	get_image_details "type=distribution";
}

# Get the Image ID for an Application
function get_app {
	${ECHO} "${TXT_CYAN}Retrieving the list of applications...${TXT_RESET}";

	get_image_details "type=application";
}

# Get the Image ID for a Snapshot
function get_snapshot {
	${ECHO} "${TXT_CYAN}Retrieving the list of snapshots...${TXT_RESET}";

	get_image_details "private=true";
}

function get_size {
	${ECHO} "${TXT_CYAN}Retrieving sizes available...${TXT_RESET}";

	sizes=( $( ${CURL} -X GET -H "Authorization: Bearer ${API}" "https://api.digitalocean.com/v2/sizes" | ${GREP} -Po '"slug":(\d*?,|.*?[^\\]",)' | ${AWK} -F'[:,]' '{print $2}' | ${SED} -e 's/"//g' ) )

	counter=0;

	for size in ${sizes[@]};
	do
		${ECHO} "${counter} - ${size}";
		let counter++;
	done

	while [ -z ${size_selection} ];
	do
		${ECHO} -n "${TXT_YELLOW}Please select a size:${TXT_RESET} ";
		read size_selection;

		size_selection=$( ${ECHO} ${size_selection} | ${SED} -e 's/[^0-9]//g' );

		if [ ${size_selection} -gt ${#sizes[@]} ];
		then
			${ECHO} "${TXT_RED}You're entry (${TXT_RESET}${size_selection}${TXT_RED}) is beyond the available selection.";
			unset size_selection;
		fi
	done

	SIZE=${sizes[${size_selection}]};
}

######################################
##### Parse command line options #####
######################################
while [ $# -ne 0 ];
do
	case "$1" in
		-h|--help)
			helpme;
			exit 0;
			;;
		-a|--api)
			API=$2;
			shift;
			;;
		-i|--image)
			IMAGE=$2;
			shift;
			;;
		-n|--name)
			NAME=$2;
			shift;
			;;
		-r|--region)
			REGION=$2;
			shift;
			;;
		-s|--size)
			SIZE=$2;
			shift;
			;;
		*)
			${ECHO} "Invalid option: ${TXT_RED}$1${TXT_RESET}";
			helpme;
			exit0;
			;;
	esac
	shift;
done

#############################
##### Application Logic #####
#############################

# Get the API key if it hasn't been set yet
while [ -z ${API} ];
do
	${ECHO} -n "${TXT_YELLOW}Please provide API token:${TXT_RESET} ";
	read API;
done

if [ -z ${IMAGE} ];
then
	# Check if the user wants to create a droplet from a personal snapshot, DO base image, or DO application
	while [ -z ${TYPE} ];
	do
		${ECHO} "${TXT_YELLOW}Do you want to build from a distribution, application, or snapshot ${TXT_BLUE}(d/a/s)${TXT_YELLOW}?${TXT_RESET} ";
		read TYPE;
		TYPE=$( ${ECHO} ${TYPE} | ${TR} [:upper:] [:lower:] );
	done

	case "$TYPE" in
		d)
			# distribution image
			get_distro;
			;;
		a)
			# application image
			get_app;
			;;
		s)
			# snapshot
			get_snapshot;
			;;
	esac
fi

if [ -z ${REGION} ];
then
	get_region;
fi

if [ -z ${SIZE} ];
then
	get_size;
fi

while [ -z ${NAME} ];
do
	${ECHO} "Please provide a name for your new instance:";
	read NAME;
done

if [ ${DEBUG} -eq 1 ];
then
	${ECHO} "${CURL} -X POST \"${API_URL}/droplets\" -d '{\"name\":\"${NAME}\",\"region\":\"'${REGION}'\",\"size\":\"'${SIZE}'\",\"image\":'${IMAGE}'}' -H \"Authorization: Bearer ${API}\";";
else
	${CURL} -X POST "${API_URL}/droplets" -d '{"name":"${NAME}","region":"'${REGION}'","size":"'${SIZE}'","image":'${IMAGE}'}' -H "Authorization: Bearer ${API}";
fi
