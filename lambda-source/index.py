import os

some_var = os.environ.get('SOME_VAR')


def handler(event, context):
    print("Hello {}".format(some_var))


if __name__ == '__main__':
    handler({}, {})
