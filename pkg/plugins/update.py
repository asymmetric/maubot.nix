#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p git nurl "(python3.withPackages (ps: with ps; [ toml gitpython requests ruamel-yaml ]))"

import git
import json
import os
import requests
import subprocess
import ruamel.yaml
import toml

from typing import List

yaml = ruamel.yaml.YAML(typ='safe')

def version_newer_than(a_s: str, b_s: str) -> bool:
    a = a_s.split('.')
    b = b_s.split('.')
    while len(a) < len(b):
        a.append('0')
    while len(b) < len(a):
        b.append('0')
    return a < b

def next_incomp(ver_s: str) -> str:
    ver = ver_s.split('.')
    zero = False
    for i in range(len(ver)):
        try:
            seg = int(ver[i])
        except ValueError:
            if zero:
                ver = ver[:i]
                break
            continue
        if zero:
            ver[i] = '0'
        elif seg:
            ver[i] = str(seg + 1)
            zero = True
    return '.'.join(ver)

def poetry_to_pep(ver_req: str) -> List[str]:
    if '*' in ver_req:
        raise NotImplementedError('Wildcard poetry versions not implemented!')
    if ver_req.startswith('^'):
        return ['>=' + ver_req[1:], '<' + next_incomp(ver_req[1:])]
    if ver_req.startswith('~'):
        return ['~=' + ver_req[1:]]
    return [ver_req]


script_dir = os.path.dirname(os.path.realpath(__file__))
plugin_list = filter(lambda s: s, map(lambda s: s.strip(), open(os.path.join(script_dir, 'plugin-list'), 'rt').readlines()))

generated: List[dict] = []

for plugin in plugin_list:
    if not plugin or plugin.startswith('#'):
        continue
    print(f'Updating {plugin}...')
    comps = plugin.split(':')
    ret: dict = {
        'manifest': { },
        'attrs': { },
    }
    argc = None
    ret_key = None
    repo = None
    raw_url = None
    human_url = None
    if comps[0] == 'break':
        break
    elif comps[0] == 'gitlab':
        argc = 4
        ret_key = 'gitlab'
        ret[ret_key] = {
            'owner': comps[2],
            'repo': comps[3],
        }

        domain = comps[1]
        if domain:
            ret[ret_key]['domain'] = domain
        else:
            domain = 'gitlab.com'

        repo = f'https://{domain}/{comps[2]}/{comps[3]}.git'
        raw_url = f'https://{domain}/{comps[2]}/{comps[3]}/-/raw/%COMMIT%'
        human_url = f'https://{domain}/{comps[2]}/{comps[3]}/-/blob/%COMMIT%'
    elif comps[0] == 'gitea':
        argc = 4
        ret_key = 'gitea'
        ret[ret_key] = {
            'domain': comps[1],
            'owner': comps[2],
            'repo': comps[3],
        }

        repo = f'https://{comps[1]}/{comps[2]}/{comps[3]}.git'
        raw_url = f'https://{comps[1]}/{comps[2]}/{comps[3]}/raw/commit/%COMMIT%'
        human_url = f'https://{comps[1]}/{comps[2]}/{comps[3]}/src/commit/%COMMIT%'
    elif comps[0] == 'github':
        argc = 3
        ret_key = 'github'
        ret[ret_key] = {
            'owner': comps[1],
            'repo': comps[2],
        }

        repo = f'https://github.com/{comps[1]}/{comps[2]}.git'
        raw_url = f'https://raw.githubusercontent.com/{comps[1]}/{comps[2]}/%COMMIT%'
        human_url = f'https://github.com/{comps[1]}/{comps[2]}/blob/%COMMIT%'
    else:
        raise ValueError(f'{comps[0]} plugins not supported!')

    refs = {}
    latest_tag = None
    for sha, name in map(lambda ref: ref.split('\t'), git.cmd.Git().ls_remote(repo, refs=True).split('\n')):
        refs[name] = sha
        if name.startswith('refs/tags/'):
            tag = name[10:]
            if not latest_tag or version_newer_than(latest_tag, tag):
                latest_tag = tag

    if latest_tag:
        ret[ret_key]['rev'] = latest_tag
        if ret_key == 'github':
            ref = latest_tag
        else:
            ref = refs['refs/tags/' + latest_tag]
    else:
        ref = None
        for branch_name in ['master', 'main', 'trunk']:
            ref = 'refs/heads/' + branch_name
            if ref in refs.keys():
                ref = refs[ref]
                ret[ret_key]['rev'] = ref
                break

    # read metadata
    ret['attrs']['genPassthru'] = { 'repoBase': human_url.replace('%COMMIT%', ref) }
    if argc < len(comps) and comps[argc] == 'poetry.toml':
        ret['attrs']['genPassthru']['isPoetry'] = True
        url = raw_url.replace('%COMMIT%', ref) + '/pyproject.toml'
        data = toml.loads(requests.get(url).text)
        deps = []
        for key, val in data['tool']['poetry'].get('dependencies', {}).items():
            if key in ['maubot', 'mautrix', 'python']:
                continue
            reqs = []
            for req in val.split(','):
                reqs.extend(poetry_to_pep(req))
            deps.append(key + ', '.join(reqs))
        ret['manifest'] = data['tool']['maubot']
        ret['manifest']['id'] = data['tool']['poetry']['name']
        ret['manifest']['version'] = data['tool']['poetry']['version']
        ret['manifest']['license'] = data['tool']['poetry']['license']
        if deps:
            ret['manifest']['dependencies'] = deps
    elif argc < len(comps):
        url = raw_url.replace('%COMMIT%', ref) + '/' + comps[argc] + '/maubot.yaml'
        data = requests.get(url).text
        ret['manifest'] = yaml.load(data)
        ret['attrs']['preBuild'] = f'cd {comps[argc]}'
    else:
        url = raw_url.replace('%COMMIT%', ref) + '/maubot.yaml'
        data = requests.get(url).text
        ret['manifest'] = yaml.load(data)
    
    assert('id' in ret['manifest'].keys())

    ret[ret_key]['hash'] = subprocess.run([
        'nurl',
        '--hash',
        repo,
        ret[ret_key]['rev']
    ], capture_output=True).stdout.decode('utf-8')

    generated.append(ret)

with open(os.path.join(script_dir, 'generated.json'), 'wt') as file:
    json.dump(generated, file, indent='  ', separators=(',', ': '))
    file.write('\n')
