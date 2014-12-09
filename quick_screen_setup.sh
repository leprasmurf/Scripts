#!/bin/bash
# Script to setup a screen session for multiple servers quickly.
# Ideally, use SSH keys to allow all screens to log in to remote servers.

SCREEN="/usr/bin/screen";

${SCREEN} -AdmS myScreen -t Server1 ssh 10.0.0.1
${SCREEN} -S myScreen -X screen -t Server2 ssh 10.0.0.2
${SCREEN} -S myScreen -X screen -t Server3 ssh 10.0.0.3
${SCREEN} -S myScreen -X screen -t Server4 ssh 10.0.0.4
${SCREEN} -S myScreen -X screen -t Server5 ssh 10.0.0.5
${SCREEN} -S myScreen -X screen -t Server6 ssh 10.0.0.6

${SCREEN} -x

