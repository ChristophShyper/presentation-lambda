#!/usr/bin/env python

import hcl
import sys
import os

"""
Script for loading .tf and .tfvars HCL files with variables
and echoing their content for bash parsing as env variables.
Reads default property from .tf files or direct value from .tfvars.
Example output:
    TF_VAR_string_variable=some_string
    TF_VAR_list_of_strings='["one", "two"]'
"""


# this list needs to be in line with values set via Makefile
special_variables = [
    "TF_VAR_aws_default_region",
    "TF_VAR_aws_default_region_short",
    "TF_VAR_aws_fallback_region",
    "TF_VAR_aws_fallback_region_short",
    "TF_VAR_deploy_environment",
    "TF_VAR_product",
    "TF_VAR_product_short",
    "TF_VAR_repository",
    "TF_VAR_team",
    "TF_VAR_account_long",
    "TF_VAR_account_short",
    "TF_VAR_environment",
]


def handler(file):
    if file is not None:
        # handle default values from .tf file
        file_tf = file + ".tf"
        if os.path.isfile(file_tf):
            parse_tf_file(file_tf)
        # overwrite them with values from .tfvars file
        file_tfvars = file + ".tfvars"
        if os.path.isfile(file_tfvars):
            parse_tfvars_file(file_tfvars)


def echo_tf_var(key, value, value_str):
    # don't overwrite values from Makefile
    var_name = 'TF_VAR_' + key
    if var_name not in special_variables:
        if isinstance(value, dict) or isinstance(value, list):
            print("{}=\'{}\'".format(var_name, value_str))
        else:
            print("{}={}".format(var_name, value_str))


def read_obj_from_hcl(file):
    with open(file) as fp:
        obj = hcl.load(fp)
        return obj


def parse_tf_file(file):
    obj = read_obj_from_hcl(file)
    if obj is not None:
        if 'variable' in obj:
            variables = obj['variable']
            for k, v in variables.items():
                if 'default' in v:
                    echo_tf_var(k, v['default'], hcl.dumps(v['default']))


def parse_tfvars_file(file):
    obj = read_obj_from_hcl(file)
    if obj is not None:
        for k, v in obj.items():
            echo_tf_var(k, v, hcl.dumps(v))


if __name__ == '__main__':
    if len(sys.argv) == 1:
        file = None
    else:
        file = sys.argv[1]
    handler(file)
