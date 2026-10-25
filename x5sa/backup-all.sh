#!/usr/bin/bash
/usr/bin/tar --xz --exclude="*gcode*" --exclude="*.gcode" --exclude="*.xz" -cvf /srv/truenas/data/transfer/3D-print/x5sa/klipper-komplett-x5sa.tar.xz /home/klipper/
