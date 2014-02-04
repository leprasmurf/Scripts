#!/bin/bash

### Command Variables
YUM="/usr/bin/yum";
APT-GET="/usr/bin/apt-get";
AUTHCONFIG="/usr/bin/authconfig";

### Script Variables

SUDOERS="/etc/sudoers";
UBUNTU="/etc/debian_version";
REDHAT="/etc/redhat-release";

### Domain Variables ###
                                                                                                                           
WG="";
REALM="";
HOMEDIR="/home";
SHELL="/bin/bash";
SECURITY="ADS";
SUDO="n";
SUDOADD="";

### Packages ###
                                                                                                                           
PAM_KRB="pam_krb5";
SAMBA="samba";
WIN_BIND="samba-winbind";

### Functions ###

function f_yum() {
	${YUM} install ${PAM_KRB} ${SAMBA} ${WIN_BIND};
}

function f_aptget() {
	${APT-GET} install ${PAM_KRB} ${SAMBA} ${WIN_BIND};
}

function f_input() {
	read -p "Please enter the FQDN of the domain you wish to join [${REALM}]: ";
	REPLY=${REPLY:-${REALM}};
																													   
	read -p "Please enter the Samba workgroup (Think Windows workgroups) [${WG}]: ";
	REPLY=${REPLY:-${WG}};
																													   
	read -p "Please enter the preferred path for user profiles [${HOMEDIR}] : ";
	REPLY=${REPLY:-${HOMEDIR}};
																													   
	read -p "Please enter the preferred shell for the users [${SHELL}] : ";
	REPLY=${REPLY:-${SHELL}};
																													   
	read -p "Please enter the preferred security model (If unsure use default) [${SECURITY}] : ";
	REPLY=${REPLY:-${SECURITY}};
																													   
	echo "Installing Required Packages";
        
	if [ -f ${REDHAT} ];
	then
		f_yum;
		echo "Configuring Packages";
	elif [ -f ${UBUNTU} ];
	then
		f_aptget;
		echo "Configuring Packages";
	else
		echo "No Package Manager Found";
		exit 2;
	fi
}

function f_sudoers() {
	read -p "Please enter the name of the group you wish to add [$sudoadd] : " REPLY;
	REPLY=${REPLY:-${SUDOADD}};

	if grep -q "%${SUDOADD} ALL=(ALL) ALL" ${SUDOERS}
	then
		echo "Group already in Sudoers";
	else
		echo "%${SUDOADD} ALL=(ALL) ALL" >> ${SUDOERS};
	fi
}

### Begin Script ###

echo -n "This will script will automatically configure the host to authenticate against a Windows domain controller of your choosing. Please use your admin account when joining the domain. Would you like to continue? [y/n] : ";
read ANSWER;

ANSWER=$( echo ${ANSWER} | tr '[:upper:]' '[:lower:]' );

if [ ${ANSWER} == "y*" ];
then
	f_input;

	${AUTHCONFIG} --disablecache --enablewinbind --enablewinbindauth --smbsecurity=${SECURITY} --smbworkgroup="${WG}" --enablewinbindusedefaultdomain --winbindtemplatehomedir="${HOMEDIR}/%U" --winbindtemplateshell="${shell}" --enablekrb5 --krb5realm=${REALM} --enablekrb5kdcdns --enablekrb5realmdns --enablelocauthorize --enablemkhomedir --enablepamaccess --updateall;

	echo -n "Would you like to add a group to sudoers now? [$SUDO] :";
	read SUDO;

	SUDO=$( echo ${SUDO} | tr '[:upper:]' '[:lower:]' );
	
	if [ ${SUDO} == "y*" ];
	then
		f_sudoers;
	else
		echo "Skipping Sudoers";
	fi

	echo "auth requisite pam_succeed_if.so user in group ${SUDOADD}" >> /etc/pam.d/password-auth;

	echo -n "Please provide a user with sufficient privilege to join the domain : ";
	read USER;

	net ads join -U "${USER}";
else
	echo "Script aborted";
	exit 1;
fi

exit 0;
