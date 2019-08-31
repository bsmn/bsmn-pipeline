import subprocess
import xml.etree.ElementTree as ET
import time
import re
import os
from collections import defaultdict


class GridEngineQueue:
    jstate = defaultdict(list)
    is_1st_print = True

    def __init__(self, q_max=2000):
        self.q_max = q_max
        self.run_jid = None

    @property
    def j_total(self):
        return len(self.__class__.jstate)

    @property
    def j_in_q(self):
        return sum(1 for state in self.__class__.jstate.values()
                   if state != ['done'])

    @property
    def j_done(self):
        return sum(1 for state in self.__class__.jstate.values()
                   if state == ['done'])

    @property
    def q_total(self):
        return sum(len(state) for state in self.qstate.values())

    @property
    def q_run(self):
        return sum(state.count('r') for state in self.qstate.values())

    @property
    def q_wait(self):
        return sum(state.count('qw') + state.count('hqw')
                   for state in self.qstate.values())
        
    def _update(self):
        xmlstr = subprocess.run(['qstat', '-xml'], 
            stdout=subprocess.PIPE, encoding='utf-8').stdout
        root = ET.fromstring(xmlstr)

        self.qstate = defaultdict(list)
        for job in root.findall('./*/job_list'):
            jid = job.find('JB_job_number').text
            state = job.find('state').text
            self.qstate[jid].append(state)

        for jid in self.__class__.jstate:
            self.__class__.jstate[jid] = self.qstate.get(jid, ['done'])

    def _print_summary(self):
        qstat = 'queue status: {:>5} in total  {:>5} in run {:>5} in wait'.format(
            self.q_total, self.q_run, self.q_wait)
        jstat = '  job status: {:>5} submitted {:>5} done   {:>5} in queue'.format(
            self.j_total, self.j_done, self.j_in_q)
        if self.__class__.is_1st_print == True:
            self.__class__.is_1st_print = False
        else:
            print('\x1b[2A', end='\r')
        print('\x1b[2K', end='\r')
        print('-' * 59)
        print('\x1b[2K', end='\r')
        print(qstat)
        print('\x1b[2K', end='\r')
        print(jstat, end='\r')
        
    def _wait(self):
        while True:
            self._update()
            if self.q_total < self.q_max:
                return
            self._print_summary()
            time.sleep(5)

    def num_run_jid_in_queue(self, fname):
        if os.path.exists(fname):
            jid = ",".join([line.strip() for line in open(fname)])
            n = int(subprocess.run("qstat -j {jid}|grep -c job_number".format(jid=jid), 
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
        self._wait()
        qsub_cmd_list = ["qsub"] + q_opt_str.split() + cmd_str.split()
        stdout = subprocess.run(qsub_cmd_list, 
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, 
            encoding='utf-8').stdout
        m = re.search("Your job(?:|-array) (\d+)(?:|.+) \(\"(.+)\"\)", stdout, re.MULTILINE)
        jid = m.group(1)
        jname = m.group(2)

        print("Your job {jid} (\"{jname}\") has been submitted".format(jid=jid, jname=jname))

        self._append_run_jid(jid)
        self.__class__.jstate[jid] = []
        self._update()
        return jid
