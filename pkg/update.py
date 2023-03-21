#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p nurl "(python3.withPackages (ps: with ps; [ requests ]))"

import os
import requests

script_dir = os.path.dirname(os.path.realpath(__file__))
plugin_list = filter(lambda s: s, map(lambda s: s.strip(), open(os.path.join(script_dir, 'plugin-list'), 'rt').readlines()))

for plugin in plugin_list:
    comps = plugin.split(':')
    if comps[0] == 'github':
        ret: dict = {
            'src': {
                'owner': comps[1],
                'repo': comps[2],
            },
        }
        # get latest version
        url = f'https://api.github.com/repos/{comps[1]}/{comps[2]}/releases'
        data = requests.get(url).json()
        try:
            tag = data[0]['tag_name']
            ret['version'] = tag.lstrip('v')
            ret['src']['rev'] = tag
        except IndexError:
            # build from master
            url = f'https://api.github.com/repos/{comps[1]}/{comps[2]}/commits/master'
            data = requests.get(url).json()
            ret['src']['rev'] = data['sha']
        # read metadata
        if len(comps) > 3:
            base = comps[2] + '/'
            ret['preBuild'] = f'cd {comps[2]}'
        else:
            base = ''
        url = f'https://raw.githubusercontent.com/{comps[1]}/{comps[2]}/{ret["src"]["rev"]}/{base}maubot.yaml'
        data = requests.get(url).text
        for line in data.split('\n'):
            line = line.strip()
            if line.startswith('id:'):
                ret['pname'] = line.split(None, 1)[1]
            elif line.startswith('license:'):
                ret['meta']['license'] = line.split(None, 1)[1]
            elif line.startswith('version'):
                ret['version'] = line.split(None, 1)[1]
        print(ret)
        raise NotImplementedError()
    else:
        raise ValueError(f'{comps[0]} plugins not supported!')

