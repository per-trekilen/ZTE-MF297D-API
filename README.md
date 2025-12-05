This is a example shell script that will login to your ZTE MF297D router and interact with it.
zte.sh can be used to send and receive SMS-messages

for more functionality use dev-tools in router pages to see what gets sent and received to the following url's
```
http://router-ip/goform/goform_set_cmd_process
http://router-ip/goform/goform_get_cmd_process
```
I use the zte.sh script in HomeAssistant to send SMS-messages from automations.
save the file zte.sh in /config/scripts/ and create a shell command in counfiguration.yaml like this:
```
shell_command:
  zte: '/bin/bash /config/scripts/zte.sh {{ arguments }}'
```

It can then be called from automations like this in automations.yaml:
This is a test message that gets sent dayly at 18:00 
´´´
- id: '1234567890'
  alias: Test message
  triggers:
  - trigger: time
    at: '18:00:00'
  actions:
  - action: shell_command.zte
    data:
      arguments: -action send_sms -nr 123456789 -msg "The message"
  mode: single
´´´


 
