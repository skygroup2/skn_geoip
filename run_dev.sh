#!/bin/bash

uuid=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)
case $1 in
remsh)
    iex --name ${uuid}_geoip@robot.h --remsh geoip@robot.sh --erl "-setcookie ctun"
    ;;
*)
    iex --name geoip@robot.sh --erl "-setcookie vps" -S mix
    ;;
esac
