import subprocess
import xml.etree.ElementTree as ET
import time
import re
import os
from collections import defaultdict


class GridEngineQueue:

    def __init__(self):
        self.run_jid = None

    def num_run_jid_in_queue(self, fname):
        if os.path.exists(fname):
            jid = ",".join([line.strip() for line in open(fname)])
            if jid == "":
                n = 0
            else:
                n = int(subprocess.run("squeue -h --jobs {jid} |wc -l".format(jid=jid), 
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                       shell=True, encoding='utf-8').stdout)
        else:
            n = 0
        return n

    def set_run_jid(self, fname, new=False):
        if new:
            os.makedirs(os.path.dirname(fname), exist_ok=True)
            open(fname, 'w').close()
        self.run_jid = fname

    def _append_run_jid(self, jid):
        if self.run_jid is not None:
            with open(self.run_jid, "a") as f:
                print(jid, file=f)

    def submit(self, q_opt_str, cmd_str):
        #print("{cmd}".format(cmd=cmd_str))
        qsub_cmd_list = ["sbatch"] + q_opt_str.split() + cmd_str.split()
        jid = subprocess.run(qsub_cmd_list, 
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, 
            encoding='utf-8').stdout.rstrip()

        print("Your job {jid} has been submitted".format(jid=jid))

        self._append_run_jid(jid)
        return jid
