#! /usr/bin/env python3
import glob
import pandas as pd
import os
import os.path
import synapseclient
import synapseutils
import argparse

# Upload bsmn-pipeline's dependencies (tools and resources) to Synapse

# This script was created as a utility supporting the "installfix" branch of
# development of the bsmn-pipeline project.  This fix was necessary because
# some of the URLs of the pipeline's dependencies changed from their earlier
# values that the install_tools.sh and download_resources.sh used previously.

# To deal with the impermanence of the impermanence of URLs to some of the
# resources the current fix gathered all resources and stored them on Synapse
# in a single folder called bsmn-pipeline-dependencies (syn21782058).  Under
# this main folder, actually, resources and tools are stored in their
# corresponding subfolders (resources: syn21782062, tools: syn21782261).

# The present script was used for that operation.  Its usage is as follows:
#
# > dependencies_to_synapse.py maindir synapseParentID
#
# "maindir" is the path to a local directory with its resources and tools
# subdirectories, each containing dependencies packaged in file archives.
# "synapseParentID" is the Synapse project or folder where the
# bsmn-pipeline-dependencies Synapse folder will be created with its own
# resources and tools Synapse subfolders.
#
# maindir
# |--resources
# |--tools

def files2synapse(subd, maind, downloadsFolder, syn):
    '''
    Upload all files in subdirectory to Synapse

    Parameters
    subd: (basename of) subdirectory
    maind: path to main directory
    downloadsFolder: the object of "bsmn-pipeline-dependencies" Synapse folder
    syn: a synapseclient.Synapse object with logged in state

    Value: subd and list of file paths
    '''
    # create or update synapse folder named subd
    folder = synapseclient.Folder(subd, parent=downloadsFolder)
    folder = syn.store(folder)
    # full path to subdir
    fullsubd = maind + os.sep + subd
    # list of filepaths under subdir
    description = 'Used by the BSMN pipeline'
    flist = list()
    for s in glob.glob(fullsubd + os.sep + '*'):
        print('Checking', s)
        flist.append(s)
        f = synapseclient.File(s, description=description, parent=folder)
        syn.store(f)
    return(subd, flist)

def main(maind, mainFolderID, syn):
    '''
    Upload subdirectories of main dir together with their contents to Synapse

    Parameters
    maind: path to main directory
    mainFolderID: the ID of the Synapse folder or project to contain the "bsmn-pipeline-dependencies" folder
    syn: a synapseclient.Synapse object with logged in state

    Value: the list of file lists; each file list corresponds to a subdirectory under maind

    Details
    The source is all the files in all subdirectories under "maind".  The
    target is the "bsmn-pipeline-dependencies" Synapse folder to be created or
    updated under "mainFolderID"
    '''
    # create or update synapse folder named subd
    downloadsFolder = synapseclient.Folder('bsmn-pipeline-dependencies', parent=mainFolderID)
    downloadsFolder = syn.store(downloadsFolder)
    # get the name of subdirectories in maindir
    paths = glob.glob(maind + os.sep + '*')
    subdirs = [os.path.basename(p) for p in paths if os.path.isdir(p)]
    # apply files2synapse to each subdir
    flists = [files2synapse(subdir, maind, downloadsFolder, syn) for
            subdir in subdirs]
    return(flists)

if __name__ == '__main__':
    syn = synapseclient.Synapse()
    syn.login()
    parser = argparse.ArgumentParser()
    parser.add_argument('maindir', help='path to "downloads" directory to be \
            uploaded to Synapse')
    parser.add_argument('synapseParentID', help='ID of Synapse Folder where \
            the "bsmn-pipeline-dependencies" folder should be created or \
            updated')
    args = parser.parse_args()
    main(maind=args.maindir, mainFolderID=args.synapseParentID, syn=syn)
