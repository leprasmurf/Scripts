#!/bin/bash

##########################
##### Data variables #####
##########################

API=$( head -n1 /home/leprasmurf/.do_api_key )
API_URL="https://api.digitalocean.com/v2/";
CONFIRM='n';
IMAGE="";
NAME="";
QUERY_SIZE="100"
REGION="";
SIZE="";
SLUG="";
TYPE='';

#############################
##### Command variables #####
#############################
CURL=$( which curl || echo "/usr/bin/curl" )" -s -H 'Content-Type: application/json'";
ECHO=$( which echo || echo "/usr/bin/echo" )" -e";
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
function helpme {
	${ECHO} "";
	${ECHO} "${TXT_GREEN}Usage${TXT_RESET}: $0 [options]";
	${ECHO} "\t-f|--file\t- Set the absolute path of the new swap file (default: /swapfile1)";
	${ECHO} "\t-s|--size\t- Set swap size in Megabytes (default: 512M)";
	${ECHO} "";
}

function bla_bla {
	${CURL} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images?page=1&per_page=${QUERY_SIZE}&${1}" | grep -Po '"slug":(\d*?,|.*?[^\\]",)' | awk -F'"' 'BEGIN {counter = 1 } { { print counter,$4 } { counter++ } }'

	while [ -z ${SLUG} ];
	do
		${ECHO} -n "${TXT_YELLOW}Please select an image:${TXT_RESET} ";
		read SLUG;

		SLUG=$( ${ECHO} ${SLUG} | ${SED} -e 's/[^0-9]//g' );
	done

	IMAGE=$( ${CURL} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images?page=${SLUG}&per_page=1&type=distribution" | grep -Po '"id":(\d*?,|.*?[^\\]",)' | awk -F'[:,]' '{print $2}' );

	if [ -z ${IMAGE} ];
	then
		${ECHO} "${TXT_RED}No image id found for your selection (${SLUG})${TXT_RESET}.";
		exit 1;
	fi

	${ECHO} "${TXT_BLUE}Image ID:${TXT_RESET} ${IMAGE}";
}

# Function to get the Image ID for the selected distro
function get_distro {
	${ECHO} "${TXT_CYAN}Retrieving the list of images...${TXT_RESET}";

	bla_bla "type=distribution";

#	${CURL} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images?page=1&per_page=${QUERY_SIZE}&type=distribution" | grep -Po '"slug":(\d*?,|.*?[^\\]",)' | awk -F'"' 'BEGIN {counter = 1 } { { print counter,$4 } { counter++ } }'
#
#	while [ -z ${SLUG} ];
#	do
#		${ECHO} -n "${TXT_YELLOW}Please select an image:${TXT_RESET} ";
#		read SLUG;
#
#		SLUG=$( ${ECHO} ${SLUG} | ${SED} -e 's/[^0-9]//g' );
#	done
#
#	IMAGE=$( ${CURL} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images?page=${SLUG}&per_page=1&type=distribution" | grep -Po '"id":(\d*?,|.*?[^\\]",)' | awk -F'[:,]' '{print $2}' );
#
#	if [ -z ${IMAGE} ];
#	then
#		${ECHO} "${TXT_RED}No image id found for your selection (${SLUG})${TXT_RESET}.";
#		exit 1;
#	fi
#
#	${ECHO} "${TXT_BLUE}Image ID:${TXT_RESET} ${IMAGE}";
}

#TODO
function get_app {
	${ECHO} "${TXT_CYAN}Retrieving the list of applications...${TXT_RESET}";
	${CURL} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images?page=1&per_page=${QUERY_SIZE}&type=application" | grep -Po '"slug":(\d*?,|.*?[^\\]",)' | awk -F'"' 'BEGIN {counter = 1 } { { print counter,$4 } { counter++ } }'

	while [ -z ${SLUG} ];
	do
		${ECHO} -n "${TXT_YELLOW}Please select an image:${TXT_RESET} ";
		read SLUG;

		SLUG=$( ${ECHO} ${SLUG} | ${SED} -e 's/[^0-9]//g' );
	done

	IMAGE=$( ${CURL} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images?page=${SLUG}&per_page=1&type=application" | grep -Po '"id":(\d*?,|.*?[^\\]",)' | awk -F'[:,]' '{print $2}' );

	if [ -z ${IMAGE} ];
	then
		${ECHO} "${TXT_RED}No image id found for your selection (${SLUG})${TXT_RESET}.";
		exit 1;
	fi

	${ECHO} "${TXT_BLUE}Image ID:${TXT_RESET} ${IMAGE}";
}

#TODO
function get_snapshot {
	${ECHO} "${TXT_CYAN}Retrieving the list of snapshots...${TXT_RESET}";
	${CURL} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images?page=1&per_page=${QUERY_SIZE}&private=true" | grep -Po '"slug":(\d*?,|.*?[^\\]",)' | awk -F'"' 'BEGIN {counter = 1 } { { print counter,$4 } { counter++ } }'

	while [ -z ${SLUG} ];
	do
		${ECHO} -n "${TXT_YELLOW}Please select an image:${TXT_RESET} ";
		read SLUG;

		SLUG=$( ${ECHO} ${SLUG} | ${SED} -e 's/[^0-9]//g' );
	done

	IMAGE=$( ${CURL} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images?page=${SLUG}&per_page=1&private=true" | grep -Po '"id":(\d*?,|.*?[^\\]",)' | awk -F'[:,]' '{print $2}' );

	if [ -z ${IMAGE} ];
	then
		${ECHO} "${TXT_RED}No image id found for your selection (${SLUG})${TXT_RESET}.";
		exit 1;
	fi

	${ECHO} "${TXT_BLUE}Image ID:${TXT_RESET} ${IMAGE}";
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

while [ -z ${NAME} ];
do
	${ECHO} "Please provide a name for your new instance:";
	read NAME;
done

#REGION="";
#curl -X GET -H 'Content-Type: application/json' -H 'Authorization: Bearer b7d03a6947b217efb6f3ec3bd3504582' "https://api.digitalocean.com/v2/regions" 
# should be pulled from the image info (because snapshots are only available in a specific region)
#SIZE="";
#curl -X GET -H 'Content-Type: application/json' -H 'Authorization: Bearer b7d03a6947b217efb6f3ec3bd3504582' "https://api.digitalocean.com/v2/sizes" 


#curl -X POST "https://api.digitalocean.com/v2/droplets" \
#    -d'{"name":"My-Droplet","region":"nyc2","size":"512mb","image":3240036}' \
#    -H "Authorization: Bearer ${API}" \
#    -H "Content-Type: application/json" 

REGION="nyc3";
SIZE="1gb";

curl -X POST "https://api.digitalocean.com/v2/droplets" -d '{"name":"My-Droplet","region":"nyc2","size":"512mb","image":'${IMAGE}'}' -H "Authorization: Bearer ${API}" -H "Content-Type: application/json";

${ECHO} "Image: ${IMAGE}; Name: ${NAME}; API: ${API};";
#${ECHO} -n "Create a droplet named ${NAME} with API token \"${API}\" (y/n)? ";
#read CONFIRM;

