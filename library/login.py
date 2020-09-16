import os
import synapseclient
import subprocess
from .config import read_config

LIB_DIR = os.path.dirname(os.path.realpath(__file__))
PIPE_HOME = os.path.normpath(LIB_DIR + "/..")
NDA_TOKEN = PIPE_HOME + "/utils/nda_aws_token.sh"

# By default, use a synapse in PATH.
SYNAPSE = shutil.which("synapse")

def load_config(reference, conda_env):
    global SYNAPSE;
    global NDA_TOKEN;
    config = read_config(reference, conda_env)
    SYNAPSE = config["TOOLS"]["SYNAPSE"]
    if not os.path.isfile(SYNAPSE) or not os.access(SYNAPSE, os.X_OK):
        SYNAPSE = shutil.which("synapse")
    NDA_TOKEN = config["PATH"]["pipe_home"] + "/utils/nda_aws_token.sh"

def synapse_login():
    print("- Check synapse login")
    try:
        synapseclient.login()
    except:
        while True:
            subprocess.run([SYNAPSE, 'login', '--remember-me'])
            try:
                synapseclient.login(silent=True)
                break
            except:
                pass

def nda_login():
    print("- Check NDA login")
    nda_cred_f = os.path.expanduser("~/.nda_credential")
    if not os.path.isfile(nda_cred_f):
        subprocess.run([NDA_TOKEN, '-s', nda_cred_f])
    while True:
        run_token = subprocess.run([NDA_TOKEN, '-r', nda_cred_f], stdout=subprocess.PIPE, encoding="utf-8")
        if run_token.returncode == 0:
            print("Requesting token succeeded!\n")
            break
        else:
            print(run_token.stdout)
            subprocess.run([NDA_TOKEN, '-s', nda_cred_f])
