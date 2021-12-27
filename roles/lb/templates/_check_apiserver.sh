#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl --silent --max-time 2 --insecure https://localhost:{{ apiserver_lb_port }}/ -o /dev/null || errorExit "Error GET https://localhost:{{ apiserver_lb_port }}/"

if ip ad | grep -q {{ keepalived_vip }}; then
    curl --silent --max-time 2 --insecure https://{{ keepalived_vip }}:{{ apiserver_lb_port }}/ -o /dev/null || errorExit "Error GET https://{{ keepalived_vip }}:{{ apiserver_lb_port }}/"
fi