# Understanding AWS Lambda
* Started November 2014 / AWS since March 2006 (July 2002)
* Event-driven serverless high-availability computing platform
* For small and quick stateless applications (functions)
* Scales automatically, zero administration
* Runs on Amazon Linux and Amazon Linux 2
* Free for first 1 M requests and 400'000 GB-sec per month
* Triggered by API, console, CloudWatch event, SNS, event source mapping (SQS, DynamoDB, Kinesis), etc.

_(https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)_
_(https://aws.amazon.com/lambda/pricing/)_
_(https://docs.aws.amazon.com/lambda/latest/dg/intro-invocation-modes.html)_

---
# Limits
* Concurrent executions: 1000
* Storage: 75 GB
* Memory allocation: 128 - 3'008 MB (64 MB increments)
* Timeout: 1 - 900 seconds
* Environment variables: 4 KB
* Policy: 20 KB
* Invocation frequency (per sec): 
    * 10 x limit for all synchronous
    * 10 x limit for non-AWS asynchronous
* Payloads:
    * 6 MB synchronous
    * 256 KB asynchronous
* Test events: 10
* /tmp storage: 512 MB
* File descriptors: 1'024
* Processes/threads: 1'024

_(https://docs.aws.amazon.com/lambda/latest/dg/limits.html)_
_(https://docs.aws.amazon.com/lambda/latest/dg/scaling.html)_
_(https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-limits.html)_
_(https://docs.aws.amazon.com/lambda/latest/dg/invocation-options.html)_

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
* **CAN** maintain database connections, clients, etc.
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
* Handler vs global scope
* Limits and costs (GB-sec)
* Limits and performance (lower can be faster) 
* Timeout and memory limit (may need adjustment in future)
* Warming-up (time variable)
* CloudWatch logging (not fully reliable)
* Runtime deprecation
* Can be run again for the same event (e.g. 3 times for asynchronous) when failed
    * May require SQS dead letter queue to assure all failed events are stored
    * Will block new events from DynamoDB or Kinesis (up to 7 days)
    * Will return event to SQS (up to 12 hours)

_(https://aws.amazon.com/lambda/pricing/)_
_(https://docs.aws.amazon.com/lambda/latest/dg/runtime-support-policy.html)_
_(https://docs.aws.amazon.com/lambda/latest/dg/retries-on-errors.html)_


---
# Good practices
* Use environment variables for values that can change - for ease of adjustment without re-deployment
* Reuse context, global scope, and /tmp whenever possible - for speed-up of execution
* Add only necessary files and dependencies to deployment package - for speed-up of startup
* Add all needed dependencies to deployment package - for stability
* Use simpler dependencies if possible - for speed-up of startup
* Avoid recursively calling the same function - can generate costs fast
* Use layers to simplify deployment packages - your code separated from dependencies

---