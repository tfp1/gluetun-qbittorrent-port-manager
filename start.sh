#!/bin/bash

COOKIES="/tmp/cookies.txt"

# Function to get the forwarded port
get_port () {
  if [ "$GLUETUN_AUTH_METHOD" == "apikey" ]; then
    # Use Bearer token if GLUETUN_AUTH_METHOD is 'apikey'
    PORT_FORWARDED=$(curl -H "Authorization: Bearer $GLUETUN_APIKEY" -s http://$GLUETUN_SERVER:$GLUETUN_CONTROL_PORT/v1/openvpn/portforwarded | jq -r '.port')
  elif [ "$GLUETUN_AUTH_METHOD" == "basic" ]; then
    # Use Basic Auth if GLUETUN_AUTH_METHOD is 'basic'
    PORT_FORWARDED=$(curl -u $GLUETUN_USERNAME:$GLUETUN_PASSWORD -s http://$GLUETUN_SERVER:$GLUETUN_CONTROL_PORT/v1/openvpn/portforwarded | jq -r '.port')
  else
    echo "Unsupported authentication method: $GLUETUN_AUTH_METHOD"
    exit 1
  fi
}

# Function to update the port in qBittorrent
update_port () {
  PORT=$PORT_FORWARDED
  rm -f $COOKIES
  curl -s -c $COOKIES --data "username=$QBITTORRENT_USER&password=$QBITTORRENT_PASS" ${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}/api/v2/auth/login > /dev/null
  curl -s -b $COOKIES --data 'json={"listen_port": "'"$PORT"'"}' ${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}/api/v2/app/setPreferences > /dev/null
  rm -f $COOKIES
  echo "Successfully updated qbittorrent to port $PORT"
}

# Initial port check
get_port
LAST_PORT=$PORT_FORWARDED

# Loop to check every 60 seconds and update if the port has changed
while true; do
  get_port  # Get the latest port
  if [ "$PORT_FORWARDED" != "$LAST_PORT" ]; then
    echo "Port has changed from $LAST_PORT to $PORT_FORWARDED"
    update_port  # Update if the port has changed
    LAST_PORT=$PORT_FORWARDED  # Store the new port as the last known port
  fi
  sleep 60  # Wait for 60 seconds before checking again
done
