#!/bin/bash -e

QUEUE_NAME="test_queue"

# Create the queue
QUEUE_URL=$(aws sqs create-queue --queue-name "$QUEUE_NAME".fifo --attributes FifoQueue=true,ContentBasedDeduplication=false | jq -r .QueueUrl)

# delete files from previous run
rm receive_group_* || true

# Send a lot of message in the queue
for i in $(seq 0 99);
do
	# group by ten
	groupid=$(( i / 10 ))

	echo "SEND $i (GROUP: $groupid)"
	aws sqs send-message --queue-url "${QUEUE_URL}" --message-body "number: $i" --message-group-id $groupid --message-deduplication-id "$(date +%s)-$i"
done


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

	echo "RECEIVE: $Body (GROUP: $MessageGroupId)" | tee -a "receive_group_${MessageGroupId}.txt"

	# This block is asynchronuous
	# Fake a message processing by waiting randomly some seconds
	(
		sleep $(( RANDOM % 10 ))
		echo "AKNEWLEDGE $Body (GROUP: $MessageGroupId)"
		aws sqs delete-message --queue-url "${QUEUE_URL}" --receipt-handle "$ReceiptHandle"
	) &

done


wait
echo "FINISHED"

aws sqs delete-queue --queue-url "$QUEUE_URL"
