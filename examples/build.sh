#!bin/bash
dmd hwclient.d -I../import -L-lzmq -ofhwclient
dmd hwserver.d -I../import -L-lzmq -ofhwserver
dmd zhelpers.d wuserver.d -I../import -L-lzmq -ofwuserver
dmd zhelpers.d wuclient.d -I../import -L-lzmq -ofwuclient

