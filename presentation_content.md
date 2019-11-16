# Understanding AWS Lambda

---
# What is AWS Lambda
* Started November 2014
* Event-driven serverless high-availability computing platform
* For small and quick stateless applications (FaaS)
* Scales automatically, zero administration
* Runs on Amazon Linux and Amazon Linux 2
* Free for first 1 M requests and 400'000 GB-sec per month
* Triggered by API Gateway, console, CloudWatch, SNS, event source mapping (SQS, DynamoDB, Kinesis), etc.
* Can access internal resources via ENI from your VPC

_(https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)_
_(https://docs.aws.amazon.com/lambda/latest/dg/intro-invocation-modes.html)_
_(https://aws.amazon.com/lambda/pricing/)_

---
# Limits
* Memory allocation: 128 - 3'008 MB (64 MB increments)
* Timeout: 1 - 900 seconds (15 minutes)
* Concurrent executions: 1000
* Storage: 75 GB
* Environment variables: 4 KB
* Payloads:
    * 6 MB synchronous
    * 256 KB asynchronous
* Deployment package:
    * 50 MB zipped
    * 250 MB unzipped, including layers
    * 3 MB for console editor
* /tmp storage: 512 MB
* File descriptors: 1'024
* Processes/threads: 1'024
* Layers: 5
* Policy: 20 KB
* Test events: 10
* Invocation frequency (per sec): 
    * 10 x limit for all synchronous
    * 10 x limit for non-AWS asynchronous
* ENIs per VPC: 160
* 2 async retries (in 1 min and 3 min after first run)

_(https://docs.aws.amazon.com/lambda/latest/dg/limits.html)_
_(https://docs.aws.amazon.com/lambda/latest/dg/scaling.html)_
_(https://docs.aws.amazon.com/lambda/latest/dg/invocation-options.html)_
_(https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-limits.html)_

---
# Runtimes
* Node.js 10 (runs on Amazon Linux 2)
* Node.js 8.10
* Python 3.7
* Python 3.6
* Python 2.7
* Ruby 2.5
* Java 8
* Go 1.x
* .NET Core 2.1 (C#, including PowerShell Core 6.0)
* .NET Core 1.0 (C#)

_(https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html)_
_(https://docs.aws.amazon.com/lambda/latest/dg/programming-model-v2.html)_

---
# Execution context
* Bootstrapping of temporary runtime environment
* Download code, setup container, initialize
* Reusable
* Provides 512 MB of space in /tmp for caching
* **CAN** maintain database connections, clients, variables, etc.
* **CAN** resume unfinished processes from previous execution

_(https://docs.aws.amazon.com/lambda/latest/dg/running-lambda-code.html)_
_(https://docs.aws.amazon.com/lambda/latest/dg/programming-model-v2.html)_

---
# Environment variables
* _HANLDER - handler (file.method)
* AWS_REGION - region
* AWS_EXECUTION_ENV - runtime identifier (e.g. AWS_Lambda_java8)
* AWS_LAMBDA_FUNCTION_NAME - function name
* AWS_LAMBDA_FUNCTION_MEMORY_SIZE - memory limit set
* AWS_LAMBDA_LOG_GROUP_NAME - function's log group
* AWS_LAMBDA_LOG_STREAM_NAME - current execution's log stream
* AWS_ACCESS_KEY_ID - credentials obtained from IAM execution role
* AWS_SECRET_ACCESS_KEY - credentials obtained from IAM execution role
* AWS_SESSION_TOKEN - credentials obtained from IAM execution role
* LAMBDA_TASK_ROOT - path to function code
* LAMBDA_RUNTIME_DIR - path to runtime
    
_(https://docs.aws.amazon.com/lambda/latest/dg/lambda-environment-variables.html)_

---
# Runtime caveats
* Cold-start vs warm-start (timeout unknown)
* Used memory (last max for current lifetime)
* Handler vs global scope
* Limits and costs (GB-sec)
* Limits and performance (lower can be faster) 
* Timeout and memory limit (may need adjustment in future)
* Warming-up (time variable)
* CloudWatch logging (not fully reliable)
* Runtime deprecation
* Can be run again for the same event when failed (e.g. total of 3 times for asynchronous)
    * May require SQS dead letter queue to assure all failed events are stored
    * Will block new events from DynamoDB or Kinesis (up to 7 days)
    * Will return event to SQS (up to 12 hours)
* Using VPC-enabled may use up all ENIs (160)

_(https://aws.amazon.com/lambda/pricing/)_
_(https://docs.aws.amazon.com/lambda/latest/dg/runtime-support-policy.html)_
_(https://docs.aws.amazon.com/lambda/latest/dg/retries-on-errors.html)_

---
# Debugging
* Simulate locally - e.g. with LambCI or SAM
* CloudWatch logs - out of the box, async, no impact on performance
* X-Ray - additional costs may apply over free tier
* Own logging - sync, possible timeouts
* Another Lambda to forward CloudWatch logs to ELK, etc. - another layer of logging, many executions, may fail 
* Console metrics // TODO: screeenshot

---
# Good practices and tricks

* Start small and grow
* Try SAM for Lambda lifecycle (now supports CI/CD)
* Use environment variables for values that can change - for ease of adjustment without redeployment
* Reuse context, global scope, and /tmp whenever possible, but only if you're certain how and why - for execution speed-up
* Add only necessary files and dependencies to deployment package - for startup speed-up
* Use layers to simplify deployment packages - your code separated from dependencies
* Split larger tasks and run them in parallel
* Recursively calling the same function may create Denial-of-wallet - use alarms on billing and executions
* When being called by API Gateway don't use timeouts longer than 30 s
* Use compiled code to increase execution time - Go being fastest in benchmarks
* Don't sent larger payloads (see limits) but rather put them on S3
* To pass sensitive values in env vars use KMS encryption and decrypt them on run time
* For heavier tasks use Step Functions, Fargete ECS, Batch, Glue, etc.
* Enable VPC only if necessary - longer start, routing costs, ENI limit
* For calling endpoints secured with whitelisted IPs use VPC-enabled option and refer to NAT gateway EIP
* Hyperplane ANI is in rollout - will make it faster and easier
* Setting limits start high, ensure cold execution and then adjust
* Watch out for timeouts and retries in methods - prevent execution timeout
* Can return binary data to API Gateway if request had proper `Accept` header
* To ensure one-time processing of requests log its id, e.g. in DynamoDB
* If used heavily may reach limits on dependent resources - no. of connections, etc.

---
# Example usage
* Serverless applications
* CloudWatch logs forwarding
* CloudWatch alarms forwarding
* Scheduled infra scanning
