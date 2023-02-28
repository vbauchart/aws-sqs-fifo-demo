#!/bin/bash -e

USAGE="$0 [-n number] queue_url"

receive_batch_size=1
while getopts 'n:' arg; do
  case ${arg} in
    n)
      receive_batch_size=${OPTARG}
      ;;
    *)
      echo "$USAGE"
      exit 1
      ;;
	esac
done
shift $(( OPTIND - 1 ))

QUEUE_NAME="$1"

if [ -z "$QUEUE_NAME" ];then
   echo "ERROR: Usage: $0 QUEUE_NAME"
   exit 1
fi


function process_message {
	local message="$1"
	local queue_url="$2"

	# Decode Message
	ReceiptHandle=$(echo "$message" | jq -r .ReceiptHandle)
	Body=$(echo "$message" | jq -r .Body)
	MessageGroupId=$(echo "$message" | jq -r .Attributes.MessageGroupId)

	# Fake a message processing by waiting randomly some seconds
	# sleep $(( RANDOM % 10 ))

	# We process files by Group ID by appending to a file
	echo "$Body (GROUP: $MessageGroupId)" >> "/tmp/receive_group_${MessageGroupId}.txt"
	
	# Process is finished, we delete the message in the queue to free the GroupID lock
	echo "AKNEWLEDGE $Body (GROUP: $MessageGroupId)"
	aws sqs delete-message --queue-url "${queue_url}" --receipt-handle "$ReceiptHandle"

}

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
	MESSAGE=$(aws sqs receive-message --queue-url "${QUEUE_URL}" --max-number-of-messages "$receive_batch_size" --attribute-names MessageGroupId)

	# Nothing to consume, will try later
	if [ -z "$MESSAGE" ]; then
		echo "NO MESSAGE"
		continue
	fi

	# Print content of messages from batch and their Group ID
	echo "${MESSAGE}" | jq -r '.Messages[]| "RECEIVE: \(.Body) (\(.Attributes.MessageGroupId))"'

	# Process messages one by one
	echo "${MESSAGE}" | jq -r '.Messages[]|@base64' | while read -r msg_base64
	do
		msg=$(echo "$msg_base64" | base64 -d)
		process_message "$msg" "${QUEUE_URL}" 
	done


done


wait
echo "FINISHED"
