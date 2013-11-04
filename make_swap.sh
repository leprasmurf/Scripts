#!/bin/bash

################################
##### Variable Declaration #####
################################
FILE="/swapfile1";
SIZE=524288;

#############################
##### Command Variables #####
#############################
BC="/usr/bin/bc";
CHOWN="/bin/chown";
CHMOD="/bin/chmod";
DD="/bin/dd";
ECHO="/bin/echo -e";
MKSWAP="/sbin/mkswap";
SWAPON="/sbin/swapon";

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
function help {
	${ECHO} "";
	${ECHO} "${TXT_GREEN}Usage${TXT_RESET}: $0 [options]";
	${ECHO} "\t-f|--file\t- Set the absolute path of the new swap file (default: /swapfile1)";
	${ECHO} "\t-s|--size\t- Set swap size in Megabytes (default: 512M)";
	${ECHO} "";
}

# Ensure we have root privileges
if [[ ${EUID} -ne 0 ]];
then
	${ECHO} "${TXT_RED}Script must be run as root${TXT_RESET}";
	exit 1;
fi

###########################
##### Read in Options #####
###########################
while [ $# -ne 0 ]; do
	case "$1" in
		-h|--help)
			help;
			exit 0;
			;;
		-s|--size)
			SIZE=$( ${ECHO} "${2} * 1024"|${BC} );
			shift;
			;;
		-f|--file)
			FILE=$2;
			shift;
			;;
		*)
			${ECHO} "Invalid Option: ${TXT_RED}$1${TXT_RESET}";
			help;
			exit 0;
			;;
	esac
	shift;
done

# Check if file already exists
if [ -f ${FILE} ];
then
	${ECHO} "${TXT_RED}Swapfile exists.${TXT_RESET}";
	exit 1;
fi

# Create the initial file with the requested size
${DD} if=/dev/zero of=${FILE} bs=1024 count=${SIZE};

# Instantiate the new file as a swap file
${MKSWAP} ${FILE};

# Set the correct permissions
${CHOWN} root:root ${FILE};
${CHMOD} 0600 ${FILE};

# Turn on the new swap file
${SWAPON} ${FILE};

# Add new swap file to fstab
${ECHO} "${FILE}\tswap\tswap\tdefaults\t0 0" >> /etc/fstab;

${ECHO} "${TXT_GREEN}New Swapfile Created.${TXT_RESET}";
