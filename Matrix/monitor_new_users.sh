#!/bin/bash

# set -x

# temp file
user_cache='/tmp/chat_users'

# server details
home_server='https://matrix.org'
room_id='<room id to notify of new users>'
API_TOKEN='<user API token>'

message=''

# Pull the list of known users from the database
function chat_users() {
  su --login -c 'psql -d synapse -c "SELECT name FROM users"' postgres | awk -F'[@:]*' '/example.com/ {if($2 !~ /^[0-9]+$/){print $2}}'
}

# Send the message to _matrix
function send_message() {
  /usr/bin/curl --header "Content-Type: application/json" --header "Accept: application/json" -X PUT -d '{"msgtype": "m.text", "body": "'"${1}"'"}' "${home_server}/_matrix/client/r0/rooms/${room_id}/send/m.room.message/$( date '+%s' )?access_token=${API_TOKEN}"
  
  # sleep so the transaction ID can iterate if there are multiple notifications going out
  sleep 1;
}

# If the cache file doesn't exist create it with the current data
if [ ! -f ${user_cache} ];
then
  chat_users > ${user_cache};
  # Nothing to compare to, wait for next invocation
  exit 0;
fi

# Get the current data for comparison
chat_users > ${user_cache}.compare;

# Check for new users
diff -q ${user_cache} ${user_cache}.compare;

# If none found, exit
if [ $? -ne 1 ];
then
  echo "No new users"
  exit 0;
fi

# Otherwise send a message with the new user name(s)
new_users=( $( diff ${user_cache} ${user_cache}.compare | awk '/^[><] .*/ {print $2}' ) );

# Loop through the list of users
for user in ${new_users[@]};
do
  # Compile and send the message regarding the new user
  message="New user added to the home server: ${user}"
  send_message "${message}"
done

# Replace the old data with the newest version
mv ${user_cache}.compare ${user_cache};

