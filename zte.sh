#!/bin/bash

# forked from
# https://github.com/benniven/ZTE-MF297D-API
# curl requests output to /dev/null to keep it quiet to stdout

# usage
# ./zte.sh -action send_sms|delete_sms -nr phone_number -msg "the message"

# some default values
action="send_sms"
msg_in="default message"
receiver="0123456789" #default deceiver number

# parse arguments
for arg in "$@"; do
   shift
   case "$arg"
   in
      "-action" )
         if [[ "$1" != "" ]];
         then
            action="$1"
         fi
         ;;
      "-msg" )
         if [[ "$1" != "" ]];
         then
            msg_in="$1"
         fi
         ;;
      "-nr" )
         if [[ "$1" != "" ]];
         then
            receiver="$1"
         fi
         ;;
   esac
done


#########################
IP="192.168.32.1"
PWD="router password"
REF="Referer: http://$IP/"
URL_GET_CMD="http://$IP/goform/goform_get_cmd_process"
URL_SET_CMD="http://$IP/goform/goform_set_cmd_process"
SMS_NUMBER="$receiver"
SMS_MESSAGE="$msg_in"

py_parse_waiv="import sys, json; print(json.load(sys.stdin)['wa_inner_version'])"
py_parse_crv="import sys, json; print(json.load(sys.stdin)['cr_version'])"
py_parse_LD="import sys, json; print(json.load(sys.stdin)['LD'])"
py_parse_RD="import sys, json; print(json.load(sys.stdin)['RD'])"
py_parse_messages="import sys, json; print(json.load(sys.stdin)['messages'])"
# gets a list of message id's of messages sent (tag=2) to the specific number.
# don't know if it's necessary but i wanted to clear sent messages on a regular basis
py_parse_messages_id="
import sys, json
ids = ''
messages = json.load(sys.stdin)
for message in messages['messages']:
    if message['number'] == '$SMS_NUMBER' and message['tag'] == '2':
        ids += message['id'] + ';';
print(ids)"

# format the message to a string of 4 digit unicodes
length=${#SMS_MESSAGE}
for ((i = 0; i < length; i++)); do
    char="${SMS_MESSAGE:i:1}"
    characters=$characters"$char"
    SMS_MESSAGE_UNICODE=$SMS_MESSAGE_UNICODE"$(printf "$char" | iconv -f utf8 -t utf32be | xxd -c 256 -p | sed -r 's/^0+/0x/' | xargs printf '%04X')"
done

#########################
# Reading LD
LD=$(curl -s -H "$REF" -d "?isTest=false&cmd=LD&_=$(date +%s%3N)" $URL_GET_CMD | python -c "$py_parse_LD")

#########################
# Reading Language Info
LANGINFO=$(curl -s -H "$REF" -d "isTest=false&cmd=Language%2Ccr_version%2Cwa_inner_version&multi_data=1&_=$(date +%s%3N)" $URL_GET_CMD)
cr_version=$( printf "$LANGINFO" | python -c "$py_parse_crv" )
wa_inner_version=$( printf "$LANGINFO" | python -c "$py_parse_waiv" )
a=$(printf "$wa_inner_version$cr_version" | sha256sum | cut -d" " -f 1 | awk '{print toupper($1)}')

function generateAD {
  u=$(curl -s -H "$REF" -d "isTest=false&cmd=RD&_=$(date +%s%3N)" $URL_GET_CMD | python -c "$py_parse_RD" )
  printf "$a$u" | sha256sum | cut -d" " -f 1 | awk '{print toupper($1)}'
}

#########################
# LOGIN
PWDHASH=$(printf $PWD | sha256sum | cut -d" " -f 1 | awk '{print toupper($1)}')
URLPWD=$(printf $PWDHASH$LD | sha256sum | awk '{print toupper($1)}')
curl -o /dev/null -s -c session.txt -H "$REF" -d "isTest=false&goformId=LOGIN&password=$URLPWD" $URL_SET_CMD
ZSIDN=$(cat session.txt | grep zsidn | cut -d\" -f2)
COOKIE="Cookie: zsidn=\"$ZSIDN\""

if [[ "$action" == "send_sms" ]];
then
  ##########################
  # Send SMS
  AD=$(generateAD)
  curl -o /dev/null -s -H "$REF" -H "$COOKIE" -d "goformId=SEND_SMS&isTest=false&notCallback=true&Number=$SMS_NUMBER&MessageBody=$SMS_MESSAGE_UNICODE&ID=-1&encode_type=GSM7_default&AD=$AD" $URL_SET_CMD
fi


if [[ "$action" == "delete_sms" ]];
then
  ##########################
  # Read SMS to get list of ids for deletion
  sms_messages=$(curl -s -H "$REF" -H "$COOKIE" -d "isTest=false&cmd=sms_data_total&page=0&data_per_page=500&mem_store=1&tags=10&order_by=order+by+id+desc&_=$(date +%s%3N)" $URL_GET_CMD)
  ids=$( printf "$sms_messages" | python -c "$py_parse_messages_id" )

  ##########################
  # Delete SMS
  AD=$(generateAD)
  curl -o /dev/null -s -H "$REF" -H "$COOKIE" -d "goformId=DELETE_SMS&isTest=false&notCallback=true&notCallback=true&msg_id=$ids&AD=$AD" $URL_SET_CMD
fi


##########################
# LOGOUT
AD=$(generateAD)
curl -o /dev/null -s -H "$REF" -H "$COOKIE" -d  "isTest=false&goformId=LOGOUT&AD=$AD" $URL_SET_CMD


exit 0



