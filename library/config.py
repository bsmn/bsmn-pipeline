import configparser
import os

def read_config():
    lib_home = os.path.dirname(os.path.realpath(__file__))
    pipe_home = os.path.normpath(lib_home + "/..")
    config = configparser.ConfigParser()
    config["PATH"] = {"pipe_home": pipe_home}

    config.read(pipe_home + "/config.ini")
    for section in ["TOOLS", "RESOURCES"]:
        for key in config[section]:
            config[section][key] = pipe_home + "/" + config[section][key]

    return config

def run_info():
    config = read_config()

    with open("run_info", "w") as run_file:
        run_file.write("#PATH\nPIPE_HOME={}\n".format(config["PATH"]["pipe_home"]))
        for section in ["TOOLS", "RESOURCES"]:
            run_file.write("\n#{section}\n".format(section=section))
            for key in config[section]:
                run_file.write("{key}={val}\n".format(
                    key=key.upper(), val=config[section][key]))

def run_info_append(line):
    with open("run_info", "a") as run_file:
        run_file.write(line + "\n")
