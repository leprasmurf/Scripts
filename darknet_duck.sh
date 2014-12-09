#!/bin/bash

# Check for the requesite number of arguments
if [[ $# -lt 2 || $# -gt 2 ]];
then
	echo "";
	echo "Invalid number of arguments: $0 $@";
	echo "usage: ${0} <host> <port>";
	exit -1;
fi

HOST=${1};
PORT=${2};
TCP_TIMEOUT=1;

# Create a subshell for the commands
# Using () instead of $() or `` is important because the script continues without waiting for the output
# http://stackoverflow.com/questions/19462291/bash-subshell-parenthese-vs-dollar-parenthese
(
	# Sleep for the timeout and kill the process if it still exists
	(
		sleep ${TCP_TIMEOUT};

		if [ -d /proc/$$ ];
		then
			logger "****** Darknet unavailable *******";
			logger "Killing any instances of tincd";
			pkill tincd;
			sleep 2;
			logger "Starting tincd*";
			/sbin/tincd -n hades;
			logger "${0} is done";
			kill $$;
		fi
	) &

	# Nifty tcp check bash builtin
	# http://stackoverflow.com/questions/23421917/bash-script-telnet-to-test-multiple-addresses-and-ports
	exec 3<> /dev/tcp/${HOST}/${PORT};
) 2>/dev/null

# Evaluate the return code of the subshell
case $? in
0) # tcp connection succeeded
	logger "Darknet is functional";
	exit 0;
	;;
1) # tcp connection was refused
	logger "Darknet is up, ${HOST} refused connection";
	exit 1;
	;;
esac
