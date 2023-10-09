#!/bin/bash

userdata="$(grep "^user*" /etc/pve/user.cfg)"
tokendata="$(grep "^token*" /etc/pve/user.cfg)"
groupdata="$(grep "^group*" /etc/pve/user.cfg)"
pooldata="$(grep "^pool*" /etc/pve/user.cfg)"
acldata="$(grep "^acl*" /etc/pve/user.cfg)"
header="Manager by pam account sync"

newuserdata=""
olduserdb='{}'
while read line
do
    if ( ! echo "$line" | awk -F: '{print $2}' | grep '^.\+@pam$' > /dev/null ) || [ "$(echo "$line" | awk -F: '{print $8}')" != "$header" ] 
    then
        newuserdata="$newuserdata
$line"
    else
        olduserdb="$(echo "$olduserdb" | jq -c ". + {\"$(echo "$line" | awk -F: '{print $2}' | awk -F@ '{print $1}')\":\"$line\"}")"
    fi
done < <(echo "$userdata")
userdata="$(echo "$newuserdata" | grep "^user*")"

uri="$(grep '^uri' /etc/nslcd.conf | cut -d' ' -f 2-)"
base="$(grep '^base' /etc/nslcd.conf | cut -d' ' -f 2-)"
binddn="$(grep '^binddn' /etc/nslcd.conf | cut -d' ' -f 2-)"
bindpw="$(grep '^bindpw' /etc/nslcd.conf | cut -d' ' -f 2-)"
filter="$(grep '^filter\s\+passwd' /etc/nslcd.conf | cut -d' ' -f 3-)"

newuserlist='[]'

for user in $(ldapsearch -x -H "$uri" -b "$base" -D "$binddn" -w "$bindpw" -LLL "(&(objectClass=person)$filter)" uid | grep '^uid:' | awk '{print $2}')
do
    email="$(ldapsearch -x -H "$uri" -b "$base" -D "$binddn" -w "$bindpw" -LLL "(&(objectClass=person)(uid=$user))" mail | grep '^mail:' | awk '{print $2}')"
    if $(echo "$olduserdb" | jq "has(\"$user\")")
    then
        tmp="$(echo "$olduserdb" | jq -c ".[\"$user\"] | split(\":\")")"
    else
        tmp="$(echo '"user::1:0::::::"' | jq -c 'split(":")')"
    fi
    tmp="$(echo "$tmp" | jq -c ".[1]=\"$user@pam\"")"
    tmp="$(echo "$tmp" | jq -c ".[6]=\"$email\"")"
    tmp="$(echo "$tmp" | jq -c ".[7]=\"$header\"")"
    userdata="$userdata
$(echo "$tmp" | jq -r 'join(":")')"
    newuserlist="$(echo "$newuserlist" | jq -c ". + [\"$user@pam\"]")"
done

groupdata="$groupdata
group:Administrators:$(echo "$newuserlist" | jq -r 'join(",")')::"

acldata="$acldata
acl:1:/:@Administrators:Administrator:"

echo "$userdata
$tokendata

$groupdata

$pooldata


$acldata" > /etc/pve/user.cfg
