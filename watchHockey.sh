#!/bin/bash

sudo pkill lircd
sudo lircd -d /dev/lirc0
irsend SEND_START HockeyGoal KEY_SOUND;sleep 1; irsend SEND_STOP HockeyGoal KEY_SOUND

TRUE=1
while [ $TRUE == 1 ]
do
 ./get_score.pl $1
 sleep 15
done
