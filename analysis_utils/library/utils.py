import sys

def coroutine(func):
    def start(*args, **kwargs):
        g = func(*args, **kwargs)
        g.__next__()
        return g
    return start

def printer(out):
    try:
        print(out, flush=True)
    except BrokenPipeError:
        try:
            sys.stdout.close()
        except BrokenPipeError:
            pass
        try:
            sys.stderr.close()
        except BrokenPipeError:
            pass
