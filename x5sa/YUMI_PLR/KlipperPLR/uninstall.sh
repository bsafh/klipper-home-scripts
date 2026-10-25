#!/bin/bash

# Get the path & user from env
if [ -n "$SUDO_USER" ]; then
    echo "shell script execute by with sudo :  user is $SUDO_USER"
    if [ "$SUDO_USER" = "runner" ]; then
        USER_HOME="/home/pi"
    else
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    fi
else
    USER_HOME=$(getent passwd "$USER" | cut -d: -f6)
    echo "shell script execute without sudo : user is $USER"
fi

echo "User's home directory: $USER_HOME"

# Remove include plr.cfg in printer.cfg
sed -i '/\[include plr.cfg\]/d' $USER_HOME/printer_data/config/printer.cfg
if [ -f "$USER_HOME/printer_data/config/plr.cfg" ]; then
    rm "$USER_HOME/printer_data/config/plr.cfg"
fi

# Remove include update_plr.cfg in moonraker.conf
sed -i '/\[include update_plr.cfg\]/d' $USER_HOME/printer_data/config/moonraker.conf
if [ -f "$USER_HOME/printer_data/config/update_plr.cfg" ]; then
    rm "$USER_HOME/printer_data/config/update_plr.cfg"
fi

if [ -d "$USER_HOME/printer_data/plr" ]; then
    rm -r "$USER_HOME/printer_data/plr"
fi

if [ -d "$USER_HOME/printer_data/gcodes/plr/" ]; then
    rm -r "$USER_HOME/printer_data/gcodes/plr/"
fi

# Print a message to the user
echo "Uninstallation complete"

#end of script
