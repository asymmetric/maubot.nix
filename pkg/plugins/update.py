#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p git nurl "(python3.withPackages (ps: with ps; [ toml gitpython requests ruamel-yaml ]))"

import git
import json
import os
import subprocess
import ruamel.yaml
import toml
import zipfile

from typing import List

name_rewrites = {
    'LDAP/AD inviter bot': 'ldap-ad-inviter-bot',
}

hostnames = {
    'git.skeg1.se': 'gitlab',
    'edugit.org': 'gitlab',
    'codeberg.org': 'gitea',
}

yaml = ruamel.yaml.YAML(typ='safe')

if not os.path.exists('/tmp/maubot-plugins'):
    os.makedirs('/tmp/maubot-plugins')
    git.Repo.clone_from('https://github.com/maubot/plugins.maubot.xyz', '/tmp/maubot-plugins/_repo')
else:
    pass # repo = git.Repo('/tmp/maubot-plugins/repo')

repodir = '/tmp/maubot-plugins/_repo'

plugins = {}

def process_repo(path, official):
    global plugins
    with open(p, 'rt') as f:
        data = yaml.load(f)
    name, repourl, license, desc = data['name'], data['repo'], data['license'], data['description']
    origurl = repourl
    if '/' in name:
        name = os.path.split(p)[-1].removesuffix('.yaml')
    repodir = f'/tmp/maubot-plugins/{name}'
    plugindir = repodir
    if '/tree/' in repourl:
        repourl, rev_path = repourl.split('/tree/')
        rev, subdir = rev_path.strip('/').split('/')
        plugindir = os.path.join(plugindir, subdir)
    else:
        rev = None
        subdir = None

    if repourl.startswith('http:'):
        repourl = 'https' + repourl[4:]
    repourl = repourl.rstrip('/')
    if not os.path.exists(repodir):
        print('Fetching', name)
        repo = git.Repo.clone_from(repourl + '.git', repodir)
    else:
        repo = git.Repo(repodir)
    tags = sorted(repo.tags, key=lambda t: t.commit.committed_datetime)
    tags = list(filter(lambda x: 'rc' not in str(x), tags))
    if tags:
        repo.git.checkout(tags[-1])
        rev = str(tags[-1])
    else:
        rev = str(repo.commit('HEAD'))
    ret = {'attrs':{}}
    if subdir:
        ret['attrs']['postPatch'] = f'cd {subdir}'
    domain, query = repourl.removeprefix('https://').split('/', 1)
    hash = subprocess.run([
        'nurl',
        '--hash',
        f'file://{repodir}',
        rev
    ], capture_output=True, check=True).stdout.decode('utf-8')
    ret['attrs']['meta'] = {
        'description': desc,
        'homepage': origurl,
    }
    if domain.endswith('github.com'):
        owner, repo = query.split('/')
        ret['github'] = {
            'owner': owner,
            'repo': repo,
            'rev': rev,
            'hash': hash,
        }
        ret['attrs']['meta']['downloadPage'] = f'{repourl}/releases'
        ret['attrs']['meta']['changelog'] = f'{repourl}/releases'
        repobase = f'{repourl}/blob/{rev}'
    elif hostnames.get(domain, 'gitea' if 'gitea.' in domain else None) == 'gitea':
        owner, repo = query.split('/')
        ret['gitea'] = {
            'domain': domain,
            'owner': owner,
            'repo': repo,
            'rev': rev,
            'hash': hash,
        }
        repobase = f'{repourl}/src/commit/{rev}'
        ret['attrs']['meta']['downloadPage'] = f'{repourl}/releases'
        ret['attrs']['meta']['changelog'] = f'{repourl}/releases'
    elif hostnames.get(domain, 'gitlab' if 'gitlab.' in domain else None) == 'gitlab':
        owner, repo = query.split('/')
        ret['gitlab'] = {
            'owner': owner,
            'repo': repo,
            'rev': rev,
            'hash': hash,
        }
        if domain != 'gitlab.com':
            ret['gitlab']['domain'] = domain
        repobase = f'{repourl}/-/blob/{rev}'
    else:
        raise ValueError(f'Is {domain} Gitea or Gitlab, or something else? Please specify in the Python script!')
    if os.path.exists(os.path.join(plugindir, 'CHANGELOG.md')):
        ret['attrs']['meta']['changelog'] = f'{repobase}/CHANGELOG.md'
    if os.path.exists(os.path.join(plugindir, 'maubot.yaml')):
        with open(os.path.join(plugindir, 'maubot.yaml'), 'rt') as f:
            ret['manifest'] = yaml.load(f)
    elif os.path.exists(os.path.join(plugindir, 'pyproject.toml')):
        ret['isPoetry'] = True
        with open(os.path.join(plugindir, 'pyproject.toml'), 'rt') as f:
            data = toml.load(f)
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
    else:
        raise ValueError(f'No maubot.yaml or pyproject.toml found in {repodir}')
    # normalize non-spdx-conformant licenses this way
    # (and fill out missing license info)
    if 'license' not in ret['manifest'] or ret['manifest']['license'] in ['GPLv3', 'AGPL 3.0']:
        ret['attrs']['meta']['license'] = license
    elif ret['manifest']['license'] != license:
        print(f"Warning: licenses for {repourl} don't match! {ret['manifest']['license']} != {license}")
    if official:
        ret['isOfficial'] = official
    plugins[name] = ret

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

for plugin_name in os.listdir(os.path.join(repodir, 'data', 'plugins', 'official')):
    p = os.path.join(repodir, 'data', 'plugins', 'official', plugin_name)
    process_repo(p, True)

for plugin_name in os.listdir(os.path.join(repodir, 'data', 'plugins', 'thirdparty')):
    p = os.path.join(repodir, 'data', 'plugins', 'thirdparty', plugin_name)
    process_repo(p, False)

script_dir = os.path.dirname(os.path.realpath(__file__))
with open(os.path.join(script_dir, 'generated.json'), 'wt') as file:
    json.dump(plugins, file, indent='  ', separators=(',', ': '))
    file.write('\n')
