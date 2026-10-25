#!/usr/bin/bash
# echo switching user 'pi' for user 'klipper'
cd ~/YUMI_PLR
echo directory replace; for file in *; do echo $file; sed -i -e 's%/pi%/klipper%' $file ; done
echo owner replace; for file in *; do echo $file; sed -i -e 's%OWNER="pi"%OWNER="klipper"%' $file; done
echo replace  install in moonraker.conf ;  sed -i -e 's%install_script: install.sh%install_script: /home/klipper/install-plr-as-klipper.sh%' install.sh     
./install.sh
