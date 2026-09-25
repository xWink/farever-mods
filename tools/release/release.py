#!/usr/bin/env python3
"""Release orchestration. User text stays data; publishing runs only in Actions."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / 'tools/release/mods.json'
REQUEST = ROOT / '.github/release-request.json'
WORK = ROOT / 'build/release'
REPO = 'xWink/farever-mods'
SEMVER = re.compile(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?\Z', re.ASCII)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def run(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def output(key, value):
    text = json.dumps(value, ensure_ascii=True) if not isinstance(value, str) else value
    require('\n' not in text and '\r' not in text, 'Output must be a single line')
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as file:
            file.write(f'{key}={text}\n')


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def save_json(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def validate_request(request, config):
    require(set(request) == {'project', 'version', 'commit', 'notes', 'dry_run'}, 'Unexpected/missing release request fields')
    require(request['project'] in config, 'Unknown mod project')
    version = request['version']
    match = SEMVER.fullmatch(version) if isinstance(version, str) else None
    require(match, 'Use a version like 1.2.3 or 1.2.3-rc.1, without a v prefix')
    if match[4]:
        require(all(not (x.isdigit() and len(x) > 1 and x[0] == '0') for x in match[4].split('.')), 'Invalid prerelease identifier')
    require(isinstance(request['commit'], str) and re.fullmatch('[0-9a-f]{40}', request['commit']), 'Source must be a full commit SHA')
    require(type(request['dry_run']) is bool, 'dry_run must be true or false')
    notes = request['notes']
    require(isinstance(notes, str) and notes.strip() and len(notes.encode('utf-8')) <= 16000, 'Supply nonempty release notes, up to 16 KB')
    require(not any(ord(c) < 32 and c not in '\r\n\t' for c in notes), 'Release notes contain control characters')
    mod = config[request['project']]
    require(type(mod['nexus_page_id']) is int and mod['nexus_page_id'] > 0, 'Configure the Nexus page ID')
    identity = {key: request[key] for key in ('project', 'version', 'commit', 'notes')}
    fingerprint = hashlib.sha256(json.dumps(identity, sort_keys=True, ensure_ascii=True).encode()).hexdigest()
    return {**request, **mod, 'tag': f"{request['project']}/v{version}",
            'mod_name': mod['title'],
            'title': f"{mod['title']} {version}", 'fingerprint': fingerprint,
            'archive': f"farever-{request['project']}.zip", 'prerelease': bool(match[4]),
            'nexus_url': f"https://www.nexusmods.com/farever/mods/{mod['nexus_page_id']}"}


def api(service, path, data=None, missing_ok=False):
    if service == 'github':
        url = f'https://api.github.com/repos/{REPO}/{path}'
        headers = {'Authorization': 'Bearer ' + os.environ['GH_TOKEN'], 'Accept': 'application/vnd.github+json'}
    else:
        url = f'https://api.nexusmods.com/v3/{path}'
        headers = {'apikey': os.environ['NEXUSMODS_API_KEY']}
    headers.update({'Content-Type': 'application/json', 'User-Agent': 'Farever-Mod-Release'})
    request = urllib.request.Request(url, headers=headers, data=None if data is None else json.dumps(data).encode())
    try:
        with urllib.request.urlopen(request, timeout=40) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if missing_ok and error.code == 404:
            return None
        # Do not dump server replies, auth headers, or tokens into build logs.
        raise ValueError(f'{service} request failed: HTTP {error.code} ({path})') from None


def github_release(plan):
    release = api('github', 'releases/tags/' + urllib.parse.quote(plan['tag'], safe=''), missing_ok=True)
    if release:
        return release
    # The tag endpoint does not return drafts. Authenticated release listings
    # do, so recover a draft (and its original assets) before creating anything.
    page = 1
    while True:
        releases = api('github', f'releases?per_page=100&page={page}')
        matches = [record for record in releases if record['tag_name'] == plan['tag']]
        require(len(matches) <= 1, 'Multiple releases match this tag; inspect them before retrying')
        if matches:
            return matches[0]
        if len(releases) < 100:
            return None
        page += 1


def asset(release, name):
    matches = [a for a in release['assets'] if a['name'] == name]
    require(len(matches) <= 1, f'Duplicate GitHub release asset: {name}')
    return matches[0] if matches else None


def download_asset(plan, release, name):
    require(asset(release, name), f'Existing release is missing {name}; inspect it before retrying')
    destination = WORK / name
    subprocess.run(['gh', 'release', 'download', plan['tag'], '--repo', REPO,
                    '--pattern', name, '--output', str(destination), '--clobber'], check=True, cwd=ROOT)
    return destination


def verify_existing(plan, release):
    require(release['name'] == plan['title'] and release['body'] == plan['notes'], 'Existing GitHub release has different title or notes; do not overwrite it')
    require(release['prerelease'] == plan['prerelease'], 'Existing GitHub release has a different release type')
    manifest = read_json(download_asset(plan, release, 'release-manifest.json'))
    require(manifest.get('fingerprint') == plan['fingerprint'], 'Existing release belongs to a different request')
    return manifest


def receipt_exists(plan, release):
    if not release or not asset(release, 'nexus-receipt.json'):
        return False
    receipt = read_json(download_asset(plan, release, 'nexus-receipt.json'))
    require(receipt.get('fingerprint') == plan['fingerprint'] and receipt.get('version_id'), 'Nexus receipt does not match the release request')
    return True


def select_nexus_file(files, versions, override=None):
    ids = {f['id'] for f in files}
    if override:
        require(override in ids, 'Configured Nexus file ID is not on this mod page')
        return override
    active = [v for v in versions if v['category'] in ('main', 'update')]
    primary = {v['file']['id'] for v in active if v.get('is_primary')}
    if len(primary) == 1:
        return primary.pop()
    main = {v['file']['id'] for v in active if v['category'] == 'main'}
    require(len(primary) == 0 and len(main) == 1, 'Cannot select a unique Nexus main file. Set nexus_file_id in tools/release/mods.json using Files > Advanced')
    return main.pop()


def stable_version(version):
    match = SEMVER.fullmatch(version)
    return tuple(map(int, match.group(1, 2, 3))) if match and not match[4] else None


def nexus_target(plan, completed=False):
    mod = api('nexus', f"games/farever/mods/{plan['nexus_page_id']}")['data']
    mod_id = mod['id']
    encoded = urllib.parse.quote(mod_id, safe='')
    files = api('nexus', f'mods/{encoded}/files')['data']['mod_files']
    versions = []
    for file in files:
        versions.extend(api('nexus', 'mod-files/' + urllib.parse.quote(file['id'], safe='') + '/versions')['data']['versions'])
    file_id = select_nexus_file(files, versions, plan.get('nexus_file_id'))
    if not completed:
        require(not any(v['version'] == plan['version'] for v in versions), 'This version already exists on Nexus. Inspect the previous upload before retrying; no duplicate will be uploaded')
        target = stable_version(plan['version'])
        advertised = [stable_version(v['version']) for v in versions if v['category'] in ('main', 'update') and v.get('is_primary')]
        require(all(v is None or target > v for v in advertised), 'Requested version must be newer than the primary stable Nexus download')
    return {'nexus_mod_id': mod_id, 'nexus_file_id': file_id}


def require_actions():
    require(os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('GITHUB_REPOSITORY') == REPO,
            'Publishing commands run only in the farever-mods GitHub workflow')
    require(os.environ.get('GITHUB_REF') == 'refs/heads/main', 'Run the release workflow from main')


def prepare():
    require_actions()
    plan = validate_request(read_json(REQUEST), read_json(CONFIG))
    # Only build committed source already included in this main-branch request.
    subprocess.run(['git', 'merge-base', '--is-ancestor', plan['commit'], os.environ['GITHUB_SHA']], check=True, cwd=ROOT)
    WORK.mkdir(parents=True, exist_ok=True)
    if not plan['dry_run']:
        release = github_release(plan)
        if release:
            verify_existing(plan, release)
        if not plan['prerelease']:
            require(os.environ.get('NEXUSMODS_API_KEY', '').strip(), 'Add NEXUSMODS_API_KEY to GitHub Actions repository secrets before releasing')
            plan.update(nexus_target(plan, completed=receipt_exists(plan, release)))
    output('plan', plan)
    output('project', plan['project'])
    output('source', plan['commit'])
    print(f"Validated {plan['title']} at {plan['commit']} (dry_run={plan['dry_run']})")


def validate_package(package, project):
    files = sorted(p for p in package.rglob('*') if p.is_file())
    require(files, 'The build artifact is empty')
    allowed = (f'hlx/mods/{project}/', f'hlx/plugins/{project}/')
    names = []
    for file in files:
        relative = file.relative_to(package).as_posix()
        require(not file.is_symlink() and not any(p.is_symlink() for p in file.parents), 'Symlinks are not allowed in release packages')
        require(relative.startswith(allowed), f'Unexpected packaged path: {relative}')
        require(file.name not in ('config.json', 'uploader.ini') and not file.name.startswith('.'), f'User/private file in package: {relative}')
        names.append(relative)
    require(f'hlx/mods/{project}/{project}.hl' in names, 'Missing compiled mod')
    if project == 'dps-meter':
        require('hlx/plugins/dps-meter/dps_meter_desktop.hdll' in names, 'Missing DPS Meter desktop plugin')
    if project == 'more-settings':
        require('hlx/plugins/more-settings/more_settings_audio.hdll' in names, 'Missing More Settings audio plugin')
    return files


def make_archive(package, plan):
    files = validate_package(package, plan['project'])
    destination = WORK / plan['archive']
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
        for file in files:
            # Stable paths/timestamps for reproducible packaging of a given build.
            info = zipfile.ZipInfo(file.relative_to(package).as_posix(), (2020, 1, 1, 0, 0, 0))
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, file.read_bytes())
    return destination


def verify_tag(plan):
    ref = api('github', 'git/ref/tags/' + urllib.parse.quote(plan['tag'], safe=''), missing_ok=True)
    if not ref:
        tag = api('github', 'git/tags', {'tag': plan['tag'], 'message': plan['notes'], 'object': plan['commit'], 'type': 'commit'})
        api('github', 'git/refs', {'ref': 'refs/tags/' + plan['tag'], 'sha': tag['sha']})
        return
    obj = ref['object']
    for _ in range(10):
        if obj['type'] != 'tag':
            break
        obj = api('github', 'git/tags/' + obj['sha'])['object']
    require(obj['type'] == 'commit' and obj['sha'] == plan['commit'], 'Release tag points at different source; never move it')


def publish_github(plan):
    WORK.mkdir(parents=True, exist_ok=True)
    archive = make_archive(ROOT / 'package', plan)
    manifest = {'fingerprint': plan['fingerprint'], 'project': plan['project'], 'version': plan['version'],
                'commit': plan['commit'], 'sha256': digest(archive)}
    if plan['dry_run']:
        save_json(WORK / 'release-manifest.json', manifest)
        output('nexus_done', 'true')
        print(f'Dry run passed: {archive.name}. No tags, releases or Nexus uploads created.')
        return
    verify_tag(plan)
    release = github_release(plan)
    if release:
        manifest = verify_existing(plan, release)
        archive = download_asset(plan, release, plan['archive'])
        require(digest(archive) == manifest['sha256'], 'Existing release ZIP does not match its manifest')
    else:
        save_json(WORK / 'release-manifest.json', manifest)
        (WORK / 'notes.md').write_text(plan['notes'], encoding='utf-8')
        args = ['gh', 'release', 'create', plan['tag'], str(archive), str(WORK / 'release-manifest.json'),
                '--repo', REPO, '--verify-tag', '--draft', '--title', plan['title'],
                '--notes-file', str(WORK / 'notes.md'), '--latest=false']
        if plan['prerelease']:
            args.append('--prerelease')
        subprocess.run(args, check=True, cwd=ROOT)
        release = github_release(plan)
        require(release is not None, 'Created release could not be found; inspect the draft before retrying')
    if release['draft']:
        subprocess.run(['gh', 'release', 'edit', plan['tag'], '--repo', REPO, '--draft=false', '--latest=false'], check=True, cwd=ROOT)
        # A draft has an untagged URL. Refresh the same release by ID so the
        # workflow reports its published URL and confirms publication succeeded.
        release = api('github', f"releases/{release['id']}")
        require(not release['draft'], 'GitHub release is still a draft after publishing')
    output('nexus_done', 'true' if receipt_exists(plan, release) or plan['prerelease'] else 'false')
    output('url', release['html_url'])
    output('archive', str(archive))


def verify_nexus(plan, version_id):
    versions = api('nexus', 'mod-files/' + urllib.parse.quote(plan['nexus_file_id'], safe='') + '/versions')['data']['versions']
    require(any(v['id'] == version_id and v['version'] == plan['version'] for v in versions), 'Uploaded Nexus file version could not be verified')


def finish_nexus(plan):
    version_id = os.environ.get('NEXUS_VERSION_ID', '')
    require(version_id, 'Nexus Action did not return a version ID')
    verify_nexus(plan, version_id)
    save_json(WORK / 'nexus-receipt.json', {'fingerprint': plan['fingerprint'], 'version_id': version_id,
              'mod_id': plan['nexus_mod_id'], 'file_id': plan['nexus_file_id'], 'url': plan['nexus_url']})
    subprocess.run(['gh', 'release', 'upload', plan['tag'], str(WORK / 'nexus-receipt.json'), '--repo', REPO], check=True, cwd=ROOT)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    request = sub.add_parser('request', help='Write a release request; does not publish until pushed to main')
    request.add_argument('--project', required=True)
    request.add_argument('--version', required=True)
    request.add_argument('--commit', required=True)
    request.add_argument('--notes-file', required=True)
    request.add_argument('--dry-run', action='store_true')
    for command in ('check', 'prepare', 'github', 'nexus-check', 'nexus-finish'):
        sub.add_parser(command)
    args = parser.parse_args()
    if args.command == 'request':
        value = {'project': args.project, 'version': args.version, 'commit': args.commit,
                 'notes': Path(args.notes_file).read_text(encoding='utf-8'), 'dry_run': args.dry_run}
        validate_request(value, read_json(CONFIG))
        save_json(REQUEST, value)
        print('Wrote .github/release-request.json. Pushing this file to main starts the workflow.')
    elif args.command == 'check':
        plan = validate_request(read_json(REQUEST), read_json(CONFIG))
        print(f"Valid request for {plan['title']} (dry_run={plan['dry_run']})")
    elif args.command == 'prepare':
        prepare()
    else:
        require_actions()
        plan = json.loads(os.environ['RELEASE_PLAN'])
        require(validate_request({k: plan[k] for k in ('project', 'version', 'commit', 'notes', 'dry_run')}, read_json(CONFIG))['fingerprint'] == plan['fingerprint'], 'Release plan was altered')
        if args.command == 'github':
            publish_github(plan)
        else:
            require(not plan['dry_run'] and not plan['prerelease'], 'Nexus publishing is only for stable releases')
            if args.command == 'nexus-check':
                target = nexus_target(plan)
                require(target['nexus_mod_id'] == plan['nexus_mod_id'] and target['nexus_file_id'] == plan['nexus_file_id'], 'Nexus target changed during the build')
            else:
                finish_nexus(plan)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, subprocess.CalledProcessError, urllib.error.URLError) as error:
        print(f'Release stopped: {error}', file=sys.stderr)
        sys.exit(1)
