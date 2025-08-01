#!/bin/bash

# Update the first Raspberry Pi
ssh braydenchaffee@192.168.1.85 'sudo apt-get update && sudo apt-get upgrade -y'
echo "Raspberry Pi B-4: Updated"

# Update the second Raspberry Pi
ssh braydenchaffee@192.168.1.78 'sudo apt-get update && sudo apt-get upgrade -y'
echo "Raspberry Pi W-0: Updated"
