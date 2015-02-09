#!/bin/bash

##########################
##### Data variables #####
##########################
#set -vx;
DEBUG=0;

API=$( head -n1 ~/.do_api_key )
API_URL="https://api.digitalocean.com/v2";
CONFIRM='n';
IMAGE="";
KEY="";
MIN_DISK_SIZE="";
NAME="";
QUERY_SIZE="100"
REGION="";
SIZE="";
TYPE='';

#############################
##### Command variables #####
#############################
AWK=$( which awk || echo "/usr/bin/awk" );
CURL=$( which curl || echo "/usr/bin/curl" );
CURL_OPTS="-s -H 'Content-Type: application/json'";
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
function helpme {
	${ECHO} "";
	${ECHO} "${TXT_GREEN}Usage${TXT_RESET}: $0 [options]";
	${ECHO} "\t-a|--api [key]\t\t- The API key to authenticate with";
	${ECHO} "\t-h|--help\t\t- Display this help";
	${ECHO} "\t-i|--image [id]\t\t- The ID of the image to use for building the droplet";
	${ECHO} "\t-k|--key [id]\t\t- The ID or fingerprint of the ssh key to use with this droplet";
	${ECHO} "\t-K|--nokey\t\t- Do not specify an SSH key for this droplet";
	${ECHO} "\t-n|--name [name]\t- The name of the droplet to be built";
	${ECHO} "\t-r|--region [name]\t- The region name to build your droplet in (e.g., lon1, nyc3, ams2)";
	${ECHO} "\t-s|--size [mem]\t\t- The droplet size to build (e.g., 1gb, 512mb, 48gb)";
	${ECHO} "";
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

# Pull the list of available images based on type and retrieve ID based on user selection
function get_image_details {
	# Pull list of images based on query size and type, grab the slug and number each entry
	${CURL} ${CURL_OPTS} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images?page=1&per_page=${QUERY_SIZE}&${1}" | ${GREP} -Po '"slug":"([^"]*)' | ${AWK} -F'"' 'BEGIN {counter = 1 } { { print counter " - " $4 } { counter++ } }'

	# Get user input
	while [ -z ${image_selection} ];
	do
		${ECHO} -n "${TXT_YELLOW}Please select an image:${TXT_RESET} ";
		read image_selection;

		# Strip out anything but numbers
		image_selection=$( ${ECHO} ${image_selection} | ${SED} -e 's/[^0-9]//g' );

		# While not perfect, this will at least check that the selection is not an extreme
		if [ ${image_selection} -gt ${QUERY_SIZE} ];
		then
			${ECHO} "${TXT_RED}Your entry (${TXT_RESET}${image_selection}${TXT_RED}) is beyond the available selection.";
		fi
	done

	# Retrieve the image by page number of selection
	record=$( ${CURL} ${CURL_OPTS} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images?page=${image_selection}&per_page=1&${1}" );

	# Grab just the Image ID of selection
	IMAGE=$( ${ECHO} ${record} | ${GREP} -Po '"id":(\d*?,|.*?[^\\]",)' | ${AWK} -F'[:,]' '{print $2}' );

	# Check for null results
	if [ -z ${IMAGE} ];
	then
		${ECHO} "${TXT_RED}No image id found for your selection (${TXT_RESET}${image_selection}${TXT_RED}).${TXT_RESET}";
		exit 1;
	fi

	# Display image ID, can be passed as an argument next time
	${ECHO} "${TXT_BLUE}Image ID:${TXT_RESET} ${IMAGE}";
}

# Find the available regions for the image selected
# Data returned sometimes has duplications
function get_region {
	# Get the record of the image selected
	record=$( ${CURL} ${CURL_OPTS} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/images/${IMAGE}" );

	# Parse out the available regions
	avail_regions=( $( ${ECHO} ${record} | ${GREP} -Po '"regions":(\d*?,|.*?[^\\]],)' | ${AWK} -F'[][]' '{print $2}' | ${SED} -e 's/"//g' -e 's/,/ /g' ) );

	# Null check available regions
	if [ -z ${avail_regions} ];
	then
		${ECHO} "${TXT_RED}No regions available for this image.${TXT_RESET}";
	fi

	# Start a counter
	counter=0;
	# Cycle through the regions and display the list
	for region in ${avail_regions[@]};
	do
		${ECHO} "${counter} - ${region}";
		let counter++;
	done

	# Get user input on which region to use
	while [ -z ${region_id} ];
	do
		${ECHO} -n "${TXT_YELLOW}Please select a region:${TXT_RESET} ";
		read region_id;

		# Strip out the non digits
		region_id=$( ${ECHO} ${region_id} | ${SED} -e 's/[^0-9]//g' );

		# Boundary check the selection
		if [ ${region_id} -gt ${#avail_regions[@]} ];
		then
			${ECHO} "${TXT_RED}Your entry (${TXT_RESET}${region_id}${TXT_RED}) is beyond the available selections.";
			unset region_id;
		fi
	done

	# Grab and display the selected region
	REGION=${avail_regions[${region_id}]};
	${ECHO} "${TXT_BLUE}Building in:${TXT_RESET} ${REGION}";

	# Grab minimum disk requirements
	# TODO: ensure size selection fits min disk requirements
	MIN_DISK_SIZE=$( ${ECHO} ${record} | ${GREP} -Po '"min_disk_size":(\d*)' | ${AWK} -F":" '{print $2}' );
}

function get_size {
	${ECHO} "${TXT_CYAN}Retrieving sizes available...${TXT_RESET}";

	# Pull available sizes from the API
	sizes=( $( ${CURL} ${CURL_OPTS} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/sizes" | ${GREP} -Po '"slug":(\d*?,|.*?[^\\]",)' | ${AWK} -F'[:,]' '{print $2}' | ${SED} -e 's/"//g' ) )

	# Start a counter
	counter=0;
	# Cycle through the sizes and display the list
	for size in ${sizes[@]};
	do
		${ECHO} "${counter} - ${size}";
		let counter++;
	done

	# Get user input on size
	while [ -z ${size_selection} ];
	do
		${ECHO} -n "${TXT_YELLOW}Please select a size:${TXT_RESET} ";
		read size_selection;

		# Strip out non-digits
		size_selection=$( ${ECHO} ${size_selection} | ${SED} -e 's/[^0-9]//g' );

		# Bound check size selection
		if [ ${size_selection} -gt ${#sizes[@]} ];
		then
			${ECHO} "${TXT_RED}Your entry (${TXT_RESET}${size_selection}${TXT_RED}) is beyond the available selection.";
			unset size_selection;
		fi
	done

	# Display size selected
	SIZE=${sizes[${size_selection}]};
	${ECHO} "${TXT_BLUE}Building size:${TXT_RESET} ${SIZE}";
}

function get_key {
	${ECHO} "${TXT_CYAN}Retrieving available keys...${TXT_RESET}";

	# Query the API for a list of available SSH keys
	key_list=$( ${CURL} ${CURL_OPTS} -X GET -H "Authorization: Bearer ${API}" "${API_URL}/account/keys" );

	# Assign the Key IDs to an array
	key_ids=( $( ${ECHO} ${key_list} | ${GREP} -Po '"id":\d*' | ${AWK} -F":" '{print $2}' ) );
	# Assign the Key Names to a parallel array
	key_names=( $( ${ECHO} ${key_list} | ${GREP} -Po '"name":"[^"]*' | ${AWK} -F"\"" '{print $4}' ) );

	# Start a counter
	counter=0;
	# Cycle through the keys and display the list
	for id in ${key_ids[@]};
	do
		${ECHO} "${counter} - ${key_names[${counter}]} (${id})";
		let counter++;
	done

	# Get user input
	while [ -z ${key_selection} ];
	do
		${ECHO} -n "${TXT_YELLOW}Please select a key:${TXT_RESET} ";
		read key_selection;

		# Strip out non-digits
		key_selection=$( ${ECHO} ${key_selection} | ${SED} -e 's/[^0-9]//g' );

		# Bound check selection
		if [ ${key_selection} -gt ${#key_ids[@]} ];
		then
			${ECHO} "${TXT_RED}Your entry (${TXT_RESET}${key_selection}${TXT_RED}) is beyond the available selection.";
			unset key_selection;
		fi
	done

	# Pull key ID from array based on user selection
	KEY=${key_ids[${key_selection}]};
	${ECHO} "${TXT_BLUE}Using key:${TXT_RESET} ${KEY}";
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
		-k|--key)
			KEY=$2;
			shift;
			;;
		-K|--nokey)
			KEY="null";
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

# Get the Image if it hasn't been set yet
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

# Get the Region ID if it hasn't been set yet
if [ -z ${REGION} ];
then
	get_region;
fi

# Get the Size if it hasn't been set yet
if [ -z ${SIZE} ];
then
	get_size;
fi

# Get the Name for the instance if it hasn't been set yet
while [ -z ${NAME} ];
do
	${ECHO} "${TXT_YELLOW}Please provide a name for your new instance:${TXT_RESET}";
	read NAME;
done

# Ask if the user wants to use a key
while [ -z ${KEY} ];
do
	${ECHO} -n "${TXT_YELLOW}Would you like to add an SSH key (y/n)?${TXT_RESET} ";
	read ssh_add;

	ssh_add=$( ${ECHO} "${ssh_add}" | ${TR} [:upper:] [:lower:] );

	if [ "${ssh_add}" == "y" ];
	then
		get_key;
	else
		break;
	fi
done

# This is needed if a user supplies the -K flag
if [ "${KEY}" == "null" ];
then
	unset KEY;
fi

# Curl command will vary based on if a key is used or not
if [ -z ${KEY} ];
then
	read -r -d '' api_command <<-EOF
		{
			"name":"${NAME}",
			"region":"${REGION}",
			"size":"${SIZE}",
			"image":"${IMAGE}"
		}
	EOF
else
	read -r -d '' api_command <<-EOF
		{
			"name":"${NAME}",
			"region":"${REGION}",
			"size":"${SIZE}",
			"ssh_keys":["${KEY}"],
			"image":"${IMAGE}"
		}
	EOF
fi

# Display all the data one last time
${ECHO} "Name: \"${NAME}\"";
${ECHO} "Region: \"${REGION}\"";
${ECHO} "Size: \"${SIZE}\"";
${ECHO} "Key ID: \"${KEY}\"";
${ECHO} "Image ID: \"${IMAGE}\"";

# If DEBUG is set, only echo the command
if [ ${DEBUG} -eq 1 ];
then
	${ECHO} "${CURL} ${CURL_OPTS} -X POST -H \"Authorization: Bearer ${API}\" -d \"${api_command}\"  \"${API_URL}/droplets\"";
else
	# Working
	${CURL} -s -H 'Content-Type: application/json' -X POST -H "Authorization: Bearer ${API}" -d "${api_command}"  "${API_URL}/droplets";
	# Not working
	#${CURL} ${CURL_OPTS} -X POST -H "Authorization: Bearer ${API}" -d "${api_command}"  "${API_URL}/droplets";
fi
