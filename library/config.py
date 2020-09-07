import configparser
import pathlib
import os
import subprocess

def read_config(reference = "b37", conda_env = "bp"):
    lib_home = os.path.dirname(os.path.realpath(__file__))
    pipe_home = os.path.normpath(lib_home + "/..")
    env_dir = subprocess.check_output("conda info -e | grep -w ^{} | awk '{{print $NF}}'".format(conda_env),
                                      shell=True, universal_newlines=True).strip()
    config = configparser.ConfigParser()
    config["PATH"] = {
        "pipe_home": pipe_home,
        "env_dir": env_dir
    }

    config.read(pipe_home + ("/config.hg19.ini" if reference == "hg19" else "/config.hg38.ini" if reference == "hg38" else "/config.ini"))
    for section in ["TOOLS", "RESOURCES"]:
        for key in config[section]:
            # config[section][key] = pipe_home + "/" + config[section][key]
            config[section][key] = config[section][key].format(ENVDIR=env_dir, PIPEHOME=pipe_home)

    return config

def run_info(fname, reference, conda_env = "bp"):
    config = read_config(reference, conda_env)
    pathlib.Path(os.path.dirname(fname)).mkdir(parents=True, exist_ok=True)
    with open(fname, "w") as run_file:
        run_file.write("#PATH\nPIPE_HOME={}\nENV_DIR={}\n".format(config["PATH"]["pipe_home"], config["PATH"]["env_dir"]))
        for section in ["TOOLS", "RESOURCES"]:
            run_file.write("\n#{section}\n".format(section=section))
            for key in config[section]:
                run_file.write("{key}={val}\n".format(
                    key=key.upper(), val=config[section][key]))

def run_info_append(fname, line):
    with open(fname, "a") as run_file:
        run_file.write(line + "\n")

def log_dir(sample):
    log_dir = sample+"/logs"
    pathlib.Path(log_dir).mkdir(parents=True, exist_ok=True)
    return log_dir

def save_hold_jid(fname, jid):
    os.makedirs(os.path.dirname(fname), exist_ok=True)
    with open(fname, 'w') as f:
        print(jid, file=f)
