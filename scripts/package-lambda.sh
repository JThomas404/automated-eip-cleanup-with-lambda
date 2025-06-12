#!/bin/bash

set -e

echo "Zipping Lambda function..."

cd "$(dirname "$0")/../lambda" || exit 1

zip -r lambda_function.zip lambda_function.py > /dev/null

echo "Lambda function zipped as lambda/lambda_function.zip"