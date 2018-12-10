import os
import synapseclient
import subprocess
from .config import read_config

config = read_config()
SYNAPSE = config["TOOLS"]["SYNAPSE"]
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
