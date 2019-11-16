import os

some_var = os.environ.get('SOME_VAR')


def handler(event, context):
    print("Welcome to AWS Lambda")
    print("Var: {}".format(some_var))
    print("Event: {}".format(event))
    # return event to force update


if __name__ == '__main__':
    handler({}, {})
