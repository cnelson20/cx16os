shell -p < child.sh &
sendmsg -h 1 -c $$ -c 1
