# aws-sqs-fifo-demo

A sample script that demonstrate the FIFO property of an SQS queue.

It use the free tier, so you will not be charged for the demo.

## How to run the demo

Ensure the AWS credentials are configured:

```sh
$ aws configure
```

Open **one terminal** and run the populate script:

```sh
$ multi-consumer/populate.sh myqueue
```

Wait for the queue to be filled up by 100 messages. Keep the session open as it will show the number of messages remaining in the queue.

Then, open **several terminals** with each ìts own consumer:

```sh
$ multi-consumer/consumer.sh myqueue
```

When all the scripts finished, check that all the files has content correctly sorted:

```sh
$ cat /tmp/receive_group_1.txt
$ cat /tmp/receive_group_5.txt
$ cat /tmp/receive_group_8.txt
```