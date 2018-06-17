#!/usr/bin/env python3

import synapseclient
import sys
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('synid', help='synapse id')
args = parser.parse_args()

synid = args.synid
syn = synapseclient.login(silent=True)
ent = syn.get(synid, downloadFile=False)
fh = syn._getFileHandleDownload(
    fileHandleId=ent.properties.dataFileHandleId, 
    objectId=ent.properties.id)
print("s3://{bucketName}/{key}".format(
    bucketName=fh['fileHandle']['bucketName'], 
    key=fh['fileHandle']['key']))
