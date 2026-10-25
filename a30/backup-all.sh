#!/usr/bin/bash
/usr/bin/tar --xz --exclude="*gcode*" --exclude="*.gcode" --exclude="*.xz" -cvf /srv/truenas/data/transfer/3D-print/a30/klipper-kompett-a30.tar.xz /home/klipper/
