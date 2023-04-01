#!/bin/bash

app=geoip
uuid=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)
case $1 in
remote)
    iex --name ${uuid}_geo@robot.sh --remsh ${app}@robot.sh --erl "-setcookie nopass"
    ;;
test)
    CONFIG_FILE=priv/${app}.config mix test --no-start
    ;;
*)
    CONFIG_FILE=priv/${app}.config iex --name ${app}@robot.sh --erl "-setcookie nopass" -S mix
    ;;
esac
