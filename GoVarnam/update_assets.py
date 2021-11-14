#!/usr/bin/env python3

import gzip
import json
from os.path import basename
from pathlib import Path
import shutil
from urllib import request

# Copies .vst, .vlf from schemes folder to assets
# You need to build inside schemes first before running this script
# Use build_all_packs.sh script to do that

def copyScheme(schemeID):
    programDir = str(Path(__file__).parent.absolute())
    source = programDir + '/schemes/schemes/' + schemeID
    target = programDir + '/assets'

    packsInfo = []

    for path in Path(source + '/').rglob('*'):
        if basename(path) == schemeID + '.vst':
            shutil.copy2(path, target)
            continue

        for packPath in Path(path).rglob('*'):
            if basename(packPath) == 'pack.json':
                packsInfo.append(json.load(open(packPath, 'r')))
                continue
            
            if ".vlf" not in basename(packPath):
                continue

            with open(
                packPath, 'rb'
            ) as f_in, open(
                target + '/' + basename(packPath),
                'wb'
            ) as f_out:
                f_out.writelines(f_in)

    with open(target + '/packs.json', 'w') as f:
        json.dump(packsInfo, f, ensure_ascii=False)

# For now just Malayalam, Kannada for govarnam-macOS
for schemeID in ["ml", "kn", "hi"]:
    copyScheme(schemeID)
