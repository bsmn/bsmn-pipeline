import glob
import pandas as pd
import os
import os.path
import synapseclient

maind = '/home/attila/projects/software/bsmn-pipeline/downloads'
# ID of Files > bsmn-pipeline > downloads folder in BSM Chess Lab synapse project
parentID = 'syn21781102'
syn = synapseclient.Synapse()
syn.login()

def files2synapse(subd):
    # create or update synapse folder named subd
    folder = synapseclient.Folder(subd, parent=parentID)
    folder = syn.store(folder)
    # full path to subdir
    fullsubd = maind + os.sep + subd
    # list of filepaths under subdir
    path = glob.glob(fullsubd + os.sep + '*')
    # create manifest file
    manifest = pd.DataFrame({'path': path, 'parent': folder.id})
    csv = maind + os.sep + subd + '.csv'
    manifest.to_csv(csv, index=False, header=True)
    return(manifest)


def main():
    paths = glob.glob(maind + os.sep + '*')
    subdirs = [os.path.basename(p) for p in paths if os.path.isdir(p)]
    manifests = [files2synapse(s) for s in subdirs]
    return(manifests)
