#!/bin/bash -e
# Copyright 2021 Harness Inc. All rights reserved.
# Use of this source code is governed by the PolyForm Free Trial 1.0.0 license
# that can be found in the licenses directory at the root of this repository, also available at
# https://polyformproject.org/wp-content/uploads/2020/05/PolyForm-Free-Trial-1.0.0.txt.

# Arguments
filename=${1:-/tmp/recording.jfr} #location where the recording should be dumped
duration=${2:-5m} #duration for which the recording needs to be taken
maxsize=${3:-250M} #maxSize of the recording

# Step 1: Get the PID of the Java process
pid=$(ps -ef | grep delegate | grep -v grep | awk 'NR==1 {print $2}')

# Step 2: Run the jattach command with provided arguments
jattach $pid jcmd "JFR.start name=tmp_recording filename=$filename duration=$duration settings=profile maxsize=$maxsize"