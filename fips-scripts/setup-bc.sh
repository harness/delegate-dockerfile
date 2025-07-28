#!/bin/bash
# Copyright 2025 Harness Inc. All rights reserved.
# Use of this source code is governed by the PolyForm Free Trial 1.0.0 license
# that can be found in the licenses directory at the root of this repository, also available at
# https://polyformproject.org/wp-content/uploads/2020/05/PolyForm-Free-Trial-1.0.0.txt.

# Default FIPS_ENABLED to false if not set
FIPS_ENABLED=${FIPS_ENABLED:-false}

# This script sets up the Bouncy Castle FIPS libraries and configures the Java environment for FIPS mode
if [ "$FIPS_ENABLED" = "true" ]; then
  echo "FIPS mode enabled, configuring Bouncy Castle FIPS setup"

  # Configure module exports for internal JDK APIs (needed by some security providers)
  export JDK_JAVA_OPTIONS="--add-exports=java.base/sun.security.internal.spec=ALL-UNNAMED --add-exports=java.base/sun.security.provider=ALL-UNNAMED"

  # Configure Java security properties - this is critical for registering the BC FIPS provider
  export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS} -Djava.security.properties==$JAVA_HOME/conf/security/java.security.fips"

  # Configure truststore settings - use BCFKS type with the correct provider
  if [ -f "$JAVA_HOME/lib/security/cacerts-bcfks" ] && [ -s "$JAVA_HOME/lib/security/cacerts-bcfks" ]; then
    echo "Using BCFKS truststore"
    export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS} -Djavax.net.ssl.trustStore=$JAVA_HOME/lib/security/cacerts-bcfks"
    export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS} -Djavax.net.ssl.trustStoreType=BCFKS"
    export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS} -Djavax.net.ssl.trustStorePassword=changeit"
    export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS} -Djavax.net.ssl.trustStoreProvider=BCFIPS"
  else
    echo "BCFKS truststore not found or empty, cannot proceed with FIPS mode"
    exit 1
  fi

  # Add BC FIPS jars to classpath - make sure they're available at runtime
  export CLASSPATH=/usr/share/java/bc-fips/*:/opt/harness-delegate/*
  echo "FIPS mode configuration complete"
else
  echo "FIPS mode not enabled, configuring Bouncy Castle setup"
  export CLASSPATH=/usr/share/java/bc/*:/opt/harness-delegate/*
  echo "NON FIPS mode configuration complete"
fi

exec "$@"