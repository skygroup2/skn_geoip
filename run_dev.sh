#!/bin/bash

uuid=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)
case $1 in
remsh)
    iex --sname ${uuid}_geoip@erlnode1 --remsh geoip@erlnode1 --erl "-setcookie ctun"
    ;;
*)
    iex --sname geoip@erlnode1 --erl "-setcookie vps" -S mix
    ;;
esac
