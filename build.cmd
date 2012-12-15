@echo off
dmd -lib src/dzmq.d src/zctx.d src/zframe.d src/zloop.d src/zmsg.d src/zsocket.d src/zsockopt.d src/zstr.d -I%1 -oflib/libdzmq.lib
