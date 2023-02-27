#!/bin/bash -e

QUEUE_NAME="$1"

if [ -z "$QUEUE_NAME" ];then
   echo "ERROR: Usage: $0 QUEUE_NAME"
   exit 1
fi

# Create the queue
QUEUE_URL=$(aws sqs list-queues --queue-name-prefix $QUEUE_NAME | jq -r .QueueUrls[])

# consume all the messages
while true;
do
	# Stop when empty
	messagesLeft_quoted=$(aws sqs get-queue-attributes --queue-url "${QUEUE_URL}" --attribute-name ApproximateNumberOfMessages | jq .Attributes.ApproximateNumberOfMessages)
	messagesLeft=$(eval echo "$messagesLeft_quoted")
	if [ "$messagesLeft" = 0 ]; then
		echo "QUEUE EMPTY"
		break
	fi

	# Consume next message, whatever its Group ID
	MESSAGE=$(aws sqs receive-message --queue-url "${QUEUE_URL}" --attribute-names MessageGroupId)

	# Nothing to consume, will try later
	if [ -z "$MESSAGE" ]; then
		echo "NO MESSAGE"
		continue
	fi

	# Decode Message
	ReceiptHandle=$(echo "$MESSAGE" | jq -r .Messages[].ReceiptHandle)
	Body=$(echo "$MESSAGE" | jq -r .Messages[].Body)
	MessageGroupId=$(echo "$MESSAGE" | jq -r .Messages[].Attributes.MessageGroupId)

	echo "RECEIVE: $Body (GROUP: $MessageGroupId)"

	# This block goes in a thread
	# Fake a message processing by waiting randomly some seconds
	(
		sleep $(( RANDOM % 10 ))
		echo "$Body (GROUP: $MessageGroupId)" >> "/tmp/receive_group_${MessageGroupId}.txt"
		echo "AKNEWLEDGE $Body (GROUP: $MessageGroupId)"
		aws sqs delete-message --queue-url "${QUEUE_URL}" --receipt-handle "$ReceiptHandle"
	) &

done


wait
echo "FINISHED"
