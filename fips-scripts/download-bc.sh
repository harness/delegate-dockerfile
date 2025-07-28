#!/bin/bash
# Copyright 2025 Harness Inc. All rights reserved.
# Use of this source code is governed by the PolyForm Free Trial 1.0.0 license
# that can be found in the licenses directory at the root of this repository, also available at
# https://polyformproject.org/wp-content/uploads/2020/05/PolyForm-Free-Trial-1.0.0.txt.

# Default FIPS_ENABLED to false if not set
FIPS_ENABLED=${FIPS_ENABLED:-false}

# This script sets up the Bouncy Castle FIPS libraries and configures the Java environment for FIPS mode
if [ "$FIPS_ENABLED" = "true" ]; then
  echo "FIPS mode enabled, configuring environment..."

  # Setup FIPS security files
  cp /opt/harness-delegate/java.policy.fips $JAVA_HOME/conf/security/java.policy.fips
  cp /opt/harness-delegate/java.security.fips $JAVA_HOME/conf/security/java.security.fips
 # Create directory for BC FIPS libraries
  mkdir -p /usr/share/java/bc-fips/

  # Download BC FIPS libraries if they don't exist
  curl -L -o /usr/share/java/bc-fips/bc-fips.jar https://repo1.maven.org/maven2/org/bouncycastle/bc-fips/2.1.0/bc-fips-2.1.0.jar
  curl -L -o /usr/share/java/bc-fips/bcutil-fips.jar https://repo1.maven.org/maven2/org/bouncycastle/bcutil-fips/2.1.4/bcutil-fips-2.1.4.jar
  curl -L -o /usr/share/java/bc-fips/bcpkix-fips.jar https://repo1.maven.org/maven2/org/bouncycastle/bcpkix-fips/2.1.9/bcpkix-fips-2.1.9.jar
  curl -L -o /usr/share/java/bc-fips/bctls-fips.jar https://repo1.maven.org/maven2/org/bouncycastle/bctls-fips/2.1.20/bctls-fips-2.1.20.jar
  curl -L -o /usr/share/java/bc-fips/bcpg-fips.jar https://repo1.maven.org/maven2/org/bouncycastle/bcpg-fips/2.1.11/bcpg-fips-2.1.11.jar

  # Import BCFKS truststore
  keytool -importkeystore \
    -srckeystore "$JAVA_HOME/lib/security/cacerts" \
    -srcstoretype JKS \
    -srcstorepass changeit \
    -destkeystore "$JAVA_HOME/lib/security/cacerts-bcfks" \
    -deststoretype BCFKS \
    -deststorepass changeit \
    -providerclass org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider \
    -providerpath /usr/share/java/bc-fips/bc-fips.jar \
    -providername BCFIPS
else
    echo "Non FIPS mode enabled, configuring environment..."
    mkdir -p /usr/share/java/bc/
    # Download BC libs
    curl -L -o /usr/share/java/bc/bcpg-jdk18on.jar https://repo1.maven.org/maven2/org/bouncycastle/bcpg-jdk18on/1.78/bcpg-jdk18on-1.78.jar
    curl -L -o /usr/share/java/bc/bcpkix-jdk18on.jar https://repo1.maven.org/maven2/org/bouncycastle/bcpkix-jdk18on/1.78/bcpkix-jdk18on-1.78.jar
    curl -L -o /usr/share/java/bc/bcprov-ext-jdk18on.jar https://repo1.maven.org/maven2/org/bouncycastle/bcprov-ext-jdk18on/1.78/bcprov-ext-jdk18on-1.78.jar
    curl -L -o /usr/share/java/bc/bcprov-jdk18on.jar https://repo1.maven.org/maven2/org/bouncycastle/bcprov-jdk18on/1.78/bcprov-jdk18on-1.78.jar
fi