#!/usr/bin/bash
#rsync -avxAXUHogDhP /home/klipper/printer_data/config/* root@192.168.80.17:/mnt/tank/alldata/data/transfer/3D-print/x5sa/config/
rsync -avxAXUHogDhP ~/*.sh ~/printer_data/logs ~/printer_data/config root@192.168.80.17:/mnt/tank/alldata/data/transfer/3D-print/x5sa-happyhare/
