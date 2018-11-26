import configparser
import os
import synapseclient
import subprocess

lib_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(lib_home + "/..")
config = configparser.ConfigParser()
config.read(pipe_home + "/config.ini")

SYNAPSE = pipe_home + "/" + config["TOOLS"]["SYNAPSE"]

def synapse_login():
    print("- Check synapse login")
    try:
        synapseclient.login()
    except:
        subprocess.run([SYNAPSE, 'login', '--remember-me'])
