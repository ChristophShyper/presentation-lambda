import os

some_var = os.environ.get('SOME_VAR')


def handler(event, context):
    print("{} {}".format(some_var, event))


if __name__ == '__main__':
    handler({}, {})
