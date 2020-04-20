import configparser
import pathlib
import os

def read_config():
    lib_home = os.path.dirname(os.path.realpath(__file__))
    pipe_home = os.path.normpath(lib_home + "/..")
    config = configparser.ConfigParser()
    config["PATH"] = {"pipe_home": pipe_home}

    config.read(pipe_home + "/config.ini")
    # these tools are not installed under pipe_home (i.e the bsmn-pipeline directory)
    global_tools = ['python3', 'synapse', 'aws']
    for section in ["TOOLS", "RESOURCES"]:
        for key in config[section]:
            if key not in global_tools:
                config[section][key] = pipe_home + "/" + config[section][key]

    return config

def run_info(fname):
    config = read_config()
    pathlib.Path(os.path.dirname(fname)).mkdir(parents=True, exist_ok=True)
    with open(fname, "w") as run_file:
        run_file.write("#PATH\nPIPE_HOME={}\n".format(config["PATH"]["pipe_home"]))
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
