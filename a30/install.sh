#!/bin/sh

#
# OctoEverywhere for Klipper!
# This script is used to start the install process of OctoEverywhere on Klipper/Moonraker/Mainsail/Fluidd setups.
#

# Note - This file is very similar to ~./install.sh and ./bambu.sh
# THEY MUST STAY IN SYNC!!

# Start at the user home. Our repo should be here for most setups, but it's technically not required by our plugin. (mileage may vary)
cd ~

echo -e "${c_yellow}You might be asked for your system password - this is required to install the required system packages.${c_default}"

# Some hardware systems have out of date root CA certs, which might cuase issues.
# Thus we will attempt to update the existing root CA certs on the box.
# This DOES NOT add any OctoEvereywhere specific certs, it just ensures that the already configured system CA certs are up-to-date.
sudo update-ca-certificates 1>/dev/null 2>/dev/null || true

# Some systems don't have git, so make sure it's installed
sudo apt update
sudo apt install git -y

# For printers running MKS, they often don't have modern CA certs, so we will add the OctoEverywhere CA cert to the system when it runs.
if [ $USER == "mks" ]; then
	echo "MKS-PI detected."
	git config --global http.sslverify false
fi

# We have seen that some user's clocks seem to be incorrect, which then cause the clone to fail due to TLS issues.
# It seems a lot of printer control systems don't have the date and time set correctly, and then the fail
# getting packages and other downstream things. We will use our HTTP API to set the current UTC time.
# Note that since cloudflare will auto force http -> https, we use https, but ignore cert errors, that could be
# caused by an incorrect date.
sudo date -s `curl --insecure 'https://octoeverywhere.com/api/util/date' 2>/dev/null` || true

# Clone the repo using a shorter name, if it doesn't exist
# We added the git config set to suppress the git error message that shows up, because usually git is not configured.
git config pull.rebase false
[ -d "./octoeverywhere" ] && echo "OctoEverywhere repo already exists, skipping clone." || git clone https://github.com/QuinnDamerell/OctoPrint-OctoEverywhere.git octoeverywhere

# Get into the repo.
cd ~/octoeverywhere

# Fetch the repo and find the latests tag
git fetch --tags
latestTaggedCommit=$(git rev-list --tags --max-count=1)
latestTag=$(git describe --tags ${latestTaggedCommit})
currentGitStatus=$(git describe)
echo "Latest git tag found ${latestTag}, current status ${currentGitStatus}"

# Reset any local changes, make sure we are on master, and pull
# Note! We must be on the master branch, or the Moonraker updater will fail.
# So we CAN'T checkout to a tag, because then the head is detached.
git reset --hard --quiet
git checkout master --quiet
git pull --quiet

cd ..

# Run the main installer!
~/octoeverywhere/install.sh
