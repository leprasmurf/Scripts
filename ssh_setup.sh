# Bash function to add in .bashrc or .profile to idempotently setup an SSH agent for the current user

function setup_ssh {
  # set -x
  cagent=$( pidof -s ssh-agent );

  if [ -z ${cagent} ];
  then
    # Start a new ssh-agent with 24h expiration of keys
    eval $( /usr/bin/ssh-agent -t 86400 -s );
  else
    # Connect to the most recent ssh-agent
    SSH_AUTH_SOCK=$(
      find /tmp -maxdepth 2 -iname 'agent*' -uid $( id -u ) -print0 2>/dev/null | \
      xargs -0 stat -c "%Y %n" | \
      sort -nr | \
      awk '{print $2; exit}'
    )
    export SSH_AGENT_PID=${cagent};
    echo "Agent PID: ${SSH_AGENT_PID}";
  fi

  # Check if a key is already listed
  if ssh-add -l > /dev/null;
  then
    echo "Identity present in agent";
  else
    # Add default key to agent
    /usr/bin/ssh-add -t 43200;
  fi

  echo "Done"
}
