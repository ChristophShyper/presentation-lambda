#!/usr/bin/env bash

function host_part() {
    echo "===>   Preparing Lambda: ${FUNCTION_NAME}"
    rm -rf ${FULL_DIR}/dist || true
    mkdir -p ${FULL_DIR}/dist/package
    cp -r ${FULL_DIR}/setup.sh ${FULL_DIR}/dist/
    cp -r ${FULL_DIR}/requirements.txt ${FULL_DIR}/index.py ${FULL_DIR}/dist/package/

    DOCKER_DIR=$(echo ${DOCKER_DIR} | sed 's/://')
    DOCKER_DIR="${DOCKER_DIR}/lambdas/${FUNCTION_NAME}/dist"
    echo "===>   Mounting Docker dir: ${DOCKER_DIR}"
    docker run \
        --rm \
        --user $(id -u):$(id -g) \
        --volume /${DOCKER_DIR}:${DIST_DIR} \
        --workdir ${DIST_DIR} \
        lambci/lambda:build-python3.7 ./setup.sh ${FUNCTION_NAME} ${DOCKER_DIR} ${S3_BUCKET} ${S3_KEY}

    echo "===>   Uploading to: s3://${S3_BUCKET}/${S3_KEY}"
    FILEBASE64SHA256=`openssl dgst -sha256 -binary ${FULL_DIR}/dist/${FUNCTION_NAME}.zip | openssl base64`
    TAG_SET="TagSet=[{Key=filebase64sha256,Value=${FILEBASE64SHA256}}]"
    aws s3 cp ${FULL_DIR}/dist/${FUNCTION_NAME}.zip s3://${S3_BUCKET}/${S3_KEY}
    aws s3api put-object-tagging --bucket ${S3_BUCKET} --key ${S3_KEY} --tagging ${TAG_SET}

    echo "===>   Finished preparing Lambda: ${FUNCTION_NAME}"
    cd ${FULL_DIR}
    rm -rf dist || true
}

function container_part() {
    mkdir -p ${WORKING_DIR}
    cd ${WORKING_DIR}
    pip install --no-cache-dir -t . -r ${DIST_DIR}/package/requirements.txt
    find . -type f -name "*.py[co]" -exec rm {} +
    mv ${DIST_DIR}/package/* .
    zip --recurse-paths ${FUNCTION_NAME}.zip * >>/dev/null
    mv ${FUNCTION_NAME}.zip ${DIST_DIR}/
}

# main execution
WORKING_DIR=/tmp/work
DIST_DIR=/tmp/install

FULL_DIR=$(dirname "$(readlink -f "$0")")
FUNCTION_NAME=$1
DOCKER_DIR=$2
S3_BUCKET=$3
S3_KEY=$4

if [[ ${PWD} == ${DIST_DIR} ]]; then
    container_part
else
    host_part
fi
