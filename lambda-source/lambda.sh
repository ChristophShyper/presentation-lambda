#!/usr/bin/env bash

# AWS Lambda provisioning script for Python.
# Creates and deploys package or runs it inside Docker container.
# Prerequisites:
#   - main Lambda code in 'index.py' file
#   - handler method called 'handler'
#   - required packages in 'requirements.txt'

# changes back files ownership after they were created by root in docker container
function copy_ownership() {
    SOURCE=$1
    TARGET=$2
    SOURCE_UID=$(stat -c %u ${SOURCE})
    SOURCE_GID=$(stat -c %g ${SOURCE})
    chown -R ${SOURCE_UID}:${SOURCE_GID} ${TARGET}
}

# creates deployment package and sends it to S3
function package_host_part() {
    echo "===>   Preparing Lambda package: ${FUNCTION_NAME}"
    # copy files that must be added to package
    mkdir -p ${HOST_WORKING_DIR}/package/
    cp ${HOST_SOURCE_DIR}/lambda.sh ${HOST_WORKING_DIR}/
    cp ${HOST_SOURCE_DIR}/requirements.txt ${HOST_SOURCE_DIR}/index.py ${HOST_WORKING_DIR}/package/
    # any other copying or file modifications goes here
    # they all should be put in ${HOST_WORKING_DIR}/package/ dir

    DOCKER_DIR=$(echo ${HOST_SOURCE_DIR} | sed 's/://')
    DOCKER_DIR="${DOCKER_DIR}/.dist"

    echo "===>   Mounting Docker dir: ${DOCKER_DIR}"
    # run container_part
    docker run \
        --rm \
        --user $(id -u):$(id -g) \
        --volume /${DOCKER_DIR}:${CONT_MOUNT_DIR} \
        --workdir ${CONT_MOUNT_DIR} \
        lambci/lambda:build-python3.7 ./lambda.sh package ${FUNCTION_NAME} ${S3_BUCKET} ${S3_KEY}

    if [[ ${S3_BUCKET} != "" && ${S3_KEY} != "" ]]; then
        echo "===>   Uploading to: s3://${S3_BUCKET}/${S3_KEY}"
        FILEBASE64SHA256=`openssl dgst -sha256 -binary ${HOST_WORKING_DIR}/${FUNCTION_NAME}.zip | openssl base64`
        TAG_SET="TagSet=[{Key=filebase64sha256,Value=${FILEBASE64SHA256}}]"
        aws s3 cp ${HOST_WORKING_DIR}/${FUNCTION_NAME}.zip s3://${S3_BUCKET}/${S3_KEY}
        aws s3api put-object-tagging --bucket ${S3_BUCKET} --key ${S3_KEY} --tagging ${TAG_SET}
    fi

    copy_ownership ${HOST_SOURCE_DIR} ${HOST_WORKING_DIR}
    echo "===>   Finished preparing Lambda: ${FUNCTION_NAME}"
}

# installs native libraries for Lambda
function package_container_part() {
    # install requirements and copy files from source/ dir
    mkdir -p ${CONT_WORKING_DIR}
    cd ${CONT_WORKING_DIR}
    echo "===>   Installing requirements"
    pip install --no-cache-dir -t . -r ${CONT_MOUNT_DIR}/package/requirements.txt
    find . -type f -name "*.py[co]" -exec rm {} +
    mv ${CONT_MOUNT_DIR}/package/* .
    echo "===>   Creating package ${FUNCTION_NAME}.zip"
    zip --recurse-paths ${FUNCTION_NAME}.zip * >>/dev/null
    mv ${FUNCTION_NAME}.zip ${CONT_MOUNT_DIR}/
}

# runs function from package
function run_host_part() {
    echo "===>   Running Lambda: ${FUNCTION_NAME}"

    DOCKER_DIR=$(echo ${HOST_SOURCE_DIR} | sed 's/://')
    DOCKER_DIR="${DOCKER_DIR}/.dist"

    echo "===>   Mounting Docker dir: ${DOCKER_DIR}"
    # run container_part
    docker run \
        --rm \
        --user $(id -u):$(id -g) \
        --volume /${DOCKER_DIR}:${CONT_MOUNT_DIR} \
        --workdir ${CONT_MOUNT_DIR} \
        lambci/lambda:build-python3.7 ./lambda.sh run ${FUNCTION_NAME} ${EVENT}

    echo "===>   Finished running Lambda: ${FUNCTION_NAME}"
}

function run_container_part() {
    # install requirements and copy files from source/ dir
    mkdir -p ${CONT_WORKING_DIR}
    cd ${CONT_WORKING_DIR}
    echo "===>   Unzipping package"
    unzip -o ${CONT_MOUNT_DIR}/${FUNCTION_NAME}.zip -d ${CONT_WORKING_DIR}/
    echo "===>   Running function"
    python ${CONT_WORKING_DIR}/index.py ${EVENT}
}

# parameters
ACTION=$1
FUNCTION_NAME=$2
EVENT=$3
S3_BUCKET=$3
S3_KEY=$4

# main execution
CONT_WORKING_DIR=/tmp/work
CONT_MOUNT_DIR=/tmp/install
HOST_SOURCE_DIR=$(dirname "$(readlink -f "$0")")
HOST_WORKING_DIR=${HOST_SOURCE_DIR}/.dist

if [[ ${ACTION} == "package" ]]; then
    if [[ ${PWD} == ${CONT_MOUNT_DIR} ]]; then
        package_container_part
    else
        package_host_part
    fi
else
    if [[ ${PWD} == ${CONT_MOUNT_DIR} ]]; then
        run_container_part
    else
        run_host_part
    fi
fi
