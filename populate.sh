#!/bin/bash -e

QUEUE_NAME="$1"

if [ -z "$QUEUE_NAME" ];then
	echo "ERROR: Usage: $0 QUEUE_NAME"
	exit 1
fi

# Create the queue
QUEUE_URL=$(aws sqs create-queue --queue-name "$QUEUE_NAME".fifo --attributes FifoQueue=true,ContentBasedDeduplication=false | jq -r .QueueUrl)

# delete files from previous run
rm /tmp/receive_group_* || true

# Send a lot of message in the queue
for i in $(seq 0 99);
do
	# /!\ Group ID partitionning /!\
	# Here is the heart of FIFO queue
	# uncomment to try some other method to experiment results

	groupid=$(( i % 10 ))      # ten by ten, same unit
	#groupid=$(( i / 10 ))     # ten by ten, same tens
	#groupid=$(( i ))          # make the FIFO non-FIFO
	#groupid=$(( 1 ))          # no partitionning at all

	echo "SEND $i (GROUP: $groupid)"
	aws sqs send-message --queue-url "${QUEUE_URL}" --message-body "number: $i" --message-group-id $groupid --message-deduplication-id "$(date +%s)-$i"
done


# consume all the messages
while true;
do
	# Stop when empty
	messagesLeft_quoted=$(aws sqs get-queue-attributes --queue-url "${QUEUE_URL}" --attribute-name ApproximateNumberOfMessages | jq .Attributes.ApproximateNumberOfMessages)
	messagesLeft=$(eval echo "$messagesLeft_quoted")
	echo "MESSAGE TOTAL $messagesLeft"
	if [ "$messagesLeft" = 0 ]; then
		echo "QUEUE EMPTY"
		break
	fi
done


sleep 10
echo "FINISHED"

aws sqs delete-queue --queue-url "$QUEUE_URL"
