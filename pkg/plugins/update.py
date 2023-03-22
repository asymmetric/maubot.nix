#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p nurl "(python3.withPackages (ps: with ps; [ requests ruamel-yaml ]))"

import json
import os
import requests
import subprocess
import ruamel.yaml

yaml = ruamel.yaml.YAML(typ='safe')

script_dir = os.path.dirname(os.path.realpath(__file__))
plugin_list = filter(lambda s: s, map(lambda s: s.strip(), open(os.path.join(script_dir, 'plugin-list'), 'rt').readlines()))

generated = []

for plugin in plugin_list:
    comps = plugin.split(':')
    ret: dict = {}
    if comps[0] == 'break':
        break
    elif comps[0] == 'saved':
        ret = eval(plugin.split(':', 1)[1])
    elif comps[0] == 'github':
        ret = {
            'manifest': { },
            'github': {
                'owner': comps[1],
                'repo': comps[2],
            },
        }
        # get latest version
        url = f'https://api.github.com/repos/{comps[1]}/{comps[2]}/releases'
        data = requests.get(url).json()
        try:
            tag = data[0]['tag_name']
            ret['github']['rev'] = tag
        except IndexError:
            # build from master
            url = f'https://api.github.com/repos/{comps[1]}/{comps[2]}/commits/master'
            data = requests.get(url).json()
            ret['github']['rev'] = data['sha']
        # read metadata
        if 3 < len(comps):
            base = comps[3] + '/'
            ret['attrs'] = { 'preBuild': f'cd {comps[2]}' }
        else:
            base = ''
        url = f'https://raw.githubusercontent.com/{comps[1]}/{comps[2]}/{ret["github"]["rev"]}/{base}maubot.yaml'
        data = requests.get(url).text
        ret['manifest'] = yaml.load(data)
        ret['github']['hash'] = subprocess.run([
            'nurl',
            '--hash',
            f'https://github.com/{ret["github"]["owner"]}/{ret["github"]["repo"]}',
            ret['github']['rev']
        ], capture_output=True).stdout.decode('utf-8')
    else:
        raise ValueError(f'{comps[0]} plugins not supported!')

    generated.append(ret)

with open(os.path.join(script_dir, 'generated.json'), 'wt') as file:
    json.dump(generated, file)
