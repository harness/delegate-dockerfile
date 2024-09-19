#!/bin/bash -e
# Copyright 2021 Harness Inc. All rights reserved.
# Use of this source code is governed by the PolyForm Free Trial 1.0.0 license
# that can be found in the licenses directory at the root of this repository, also available at
# https://polyformproject.org/wp-content/uploads/2020/05/PolyForm-Free-Trial-1.0.0.txt.

# url-encodes a given input string - used to encode the proxy password for curl commands.
# Note:
#   - We implement the functionality ourselves to avoid dependencies on new packages.
#   - We encode a superset of the characters defined in the specification, which is explicitly
#     allowed: https://www.ietf.org/rfc/rfc1738.txt
url_encode () {
    local input=$1
    for (( i=0; i<${#input}; i++ )); do
        local c=${input:$i:1}
        case $c in
            [a-zA-Z0-9-_\.\!\*]) printf "$c" ;;
            *) printf '%%%02X' "'$c"
        esac
    done
}

if [[ $KUBERNETES_SERVICE_HOST != "" ]]; then
  if [[ $NO_PROXY == "" ]]; then
    export NO_PROXY=$KUBERNETES_SERVICE_HOST
  else
    export NO_PROXY="$NO_PROXY,$KUBERNETES_SERVICE_HOST"
  fi
fi

PROXY_CONFIG_FILE=${PROXY_CONFIG_FILE:-"/run/secrets/proxy.config"}
if [ -e "$PROXY_CONFIG_FILE" ]; then
  echo "Loading proxy config from file ""$PROXY_CONFIG_FILE"
  source "$PROXY_CONFIG_FILE"
fi

if [ -e proxy.config ]; then
  echo "Loading proxy.config"
  source proxy.config
fi

if [[ $PROXY_HOST != "" ]]; then
  echo "Using $PROXY_SCHEME proxy $PROXY_HOST:$PROXY_PORT"
  if [[ $PROXY_USER != "" ]]; then
    echo "using proxy auth config"
    export PROXY_USER
    export PROXY_PASSWORD
    export PROXY_CURL="-x "$PROXY_SCHEME"://"$PROXY_USER:$(url_encode "$PROXY_PASSWORD")@$PROXY_HOST:$PROXY_PORT
  else
    export PROXY_CURL="-x "$PROXY_SCHEME"://"$PROXY_HOST:$PROXY_PORT
    export http_proxy=$PROXY_SCHEME://$PROXY_HOST:$PROXY_PORT
    export https_proxy=$PROXY_SCHEME://$PROXY_HOST:$PROXY_PORT
  fi
  PROXY_SYS_PROPS="-DproxyScheme=$PROXY_SCHEME -Dhttp.proxyHost=$PROXY_HOST -Dhttp.proxyPort=$PROXY_PORT -Dhttps.proxyHost=$PROXY_HOST -Dhttps.proxyPort=$PROXY_PORT"
fi

if [[ $PROXY_MANAGER == "true" || $PROXY_MANAGER == "" ]]; then
  export MANAGER_PROXY_CURL=$PROXY_CURL
else
  HOST_AND_PORT_ARRAY=(${MANAGER_HOST_AND_PORT//:/ })
  MANAGER_HOST="${HOST_AND_PORT_ARRAY[1]}"
  MANAGER_HOST="${MANAGER_HOST:2}"
  echo "No proxy for Harness manager at $MANAGER_HOST"
  if [[ $NO_PROXY == "" ]]; then
    NO_PROXY=$MANAGER_HOST
  else
    NO_PROXY="$NO_PROXY,$MANAGER_HOST"
  fi
fi

if [[ $NO_PROXY != "" ]]; then
  echo "No proxy for domain suffixes $NO_PROXY"
  export no_proxy=$NO_PROXY
  SYSTEM_PROPERTY_NO_PROXY=`echo $NO_PROXY | sed "s/\,/|*/g"`
  PROXY_SYS_PROPS=$PROXY_SYS_PROPS" -Dhttp.nonProxyHosts=*$SYSTEM_PROPERTY_NO_PROXY"
fi

export PROXY_SYS_PROPS
