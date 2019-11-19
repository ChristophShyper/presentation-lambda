# presentation-lamda

## Understanding AWS Lambda
Presentation about what AWS Lambda is and how to use it effectively.

## DevOps Community Poland meetup #1
November 18th, 2019
EPAM,
Opolska 114,
Kraków, Poland

# Live demo example

## Prerequisites
- Bash
- Docker
- Python
- AWS CLI
- Terraform
* Can be run from WSL, requires only `export DOCKER_HOST=tcp://localhost:2375` to connect to Docker running on Windows host.

## Development
Example Python source code is in `lambda-source/index.py`.

To run it simply execute `./lambda.sh run example python3.7 '{"key": "value"}' 'my_value'` in that directory.

## Deployment
To see what will change go to `lambda-infra` directory and run `terraform plan`. Don't forget to run `terraform init` before that, but it's required only once. 

To apply changes run `terraform apply -parallelism=1`.

## Update
Uncomment line 10 in `lambda-source/index.py` so Lambda can return back the event that triggered it.

Run it locally to see how it will behave (as described above).

Run `terraform plan` to see what will be changed.
You will always see Terraform needing to read package tags from data `aws_s3_bucket_object` source and `aws_lambda_function` needing to check `source_code_hash`. 
But when you apply it without any changes in Terrform log you'll see it actually did nothing.

To deploy your changes run `terraform apply -parallelism=1` again.

## Cleanup
After testing and playing with it cleanup all created resources by running `terraform destroy` and confirm with `yes`.
