#!/bin/bash

### Script Variables

sudoers="/etc/sudoers"
ubuntu="/etc/debian_version"
redhat="/etc/redhat-release"

### Domain Variables ###                                                                                                   
                                                                                                                           
wg=""                                                                                                                
realm=""                                                                                                       
homedir="/home"                                                                                                            
shell="/bin/bash"                                                                                                          
security="ADS"                                                                                                             
sudo="n"                                                                                                                   
sudoadd=""   

### Packages ###                                                                                                           
                                                                                                                           
pam_krb="pam_krb5"                                                                                                         
samba="samba"                                                                                                              
win_bind="samba-winbind"

### Functions ###

f_yum() {
yum install ${pam_krb} ${samba} ${win_bind}
}

f_aptget() {
apt-get install ${pam_krb} ${samba} ${win_bind}
}

f_input() {
        read -p "Please enter the FQDN of the domain you wish to join [$realm]: "                                          
        REPLY=${REPLY:-$realm}                                                                                             
                                                                                                                           
        read -p "Please enter the Samba workgroup (Think Windows workgroups) [$wg]: "                                      
        REPLY=${REPLY:-$wg}                                                                                                
                                                                                                                           
        read -p "Please enter the preferred path for user profiles [$homedir] : "                                          
        REPLY=${REPLY:-$homedir}                                                                                           
                                                                                                                           
        read -p "Please enter the preferred shell for the users [$shell] : "                                               
        REPLY=${REPLY:-$shell}                                                                                             
                                                                                                                           
        read -p "Please enter the preferred security model (If unsure use default) [$security] : "                         
        REPLY=${REPLY:-$security}                                                                                          
                                                                                                                           
        echo "Installing Required Packages"                                                                                
        
  if [ ${redhat} ];
	then
		f_yum
        	echo "Configuring Packages"
	elif [ ${ubuntu} ];
	then
		f_aptget
	        echo "Configuring Packages"
	else
		echo "No Package Manager Found"
		exit 2
        fi                                                                                                                 
}

f_sudoers() {
	read -p "Please enter the name of the group you wish to add [$sudoadd] : " REPLY                           
	REPLY=${REPLY:-$sudoadd}                                                                                   

	if grep -q "%${sudoadd} ALL=(ALL)       ALL" ${sudoers}                                                    
		then                                                                                                       			echo "Group already in Sudoers"
		else
			echo "%${sudoadd}       ALL=(ALL)       ALL"  >> ${sudoers}
	fi
}

### Begin Script ###

echo -n "This will script will automatically configure the host to authenticate against a Windows domain controller of your choosing. Please use your admin account when joining the domain. Would you like to continue? [y/n] : "
read answer

if [ $answer = "y" -o $answer = "yes" -o $answer = "YES" -o $answer = "Y" ];
then
	f_input

	authconfig --disablecache --enablewinbind --enablewinbindauth --smbsecurity=${security} --smbworkgroup="${wg}" --enablewinbindusedefaultdomain --winbindtemplatehomedir="${homedir}/%U" --winbindtemplateshell="${shell}" --enablekrb5 --krb5realm=${realm} --enablekrb5kdcdns --enablekrb5realmdns --enablelocauthorize --enablemkhomedir --enablepamaccess --updateall

	echo -n "Would you like to add a group to sudoers now? [$sudo] :"
	read sudo

	if [ $sudo = "y" -o $sudo = "yes" -o $sudo = "YES" -o $sudo = "Y" ];
	then
		f_sudoers
	else
		echo "Skipping Sudoers"
	fi

	echo "auth	requisite	pam_succeed_if.so user ingroup ${sudoadd}" >> /etc/pam.d/password-auth

	echo -n "Please provide a user with sufficient privelage to join the domain : "
	read user

	net ads join -U "${user}"
else
	echo "Script aborted"
    exit 0
fi
exit 0
