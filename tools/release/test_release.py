"""Offline release tests. All network and publishing calls are mocked."""
import io
import json
import os
from pathlib import Path
import re
import tempfile
import shutil
import subprocess
import sys
import textwrap
import unittest
from unittest.mock import patch
import urllib.error
import zipfile

import release


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.work = self.root / 'build/release'
        self.work.mkdir(parents=True)
        self.config = release.read_json(release.CONFIG)
        self.request = {'project': 'minimap', 'version': '1.7.0', 'commit': 'a' * 40,
                        'notes': 'Fix arrows.\n\n- Keep Unicode ↔ and $HOME / `code` / $(literal).\n', 'dry_run': False}
        self.plan = release.validate_request(self.request, self.config)
        self.patches = [patch.object(release, 'ROOT', self.root), patch.object(release, 'WORK', self.work)]
        for item in self.patches:
            item.start()
        self.addCleanup(lambda: [item.stop() for item in self.patches])
        self.addCleanup(self.temp.cleanup)

    def package(self, project='minimap'):
        package = self.root / 'package'
        mod = package / f'hlx/mods/{project}/{project}.hl'
        mod.parent.mkdir(parents=True)
        mod.write_bytes(b'compiled test module')
        return package

    def existing(self):
        return {'name': self.plan['title'], 'body': self.plan['notes'], 'prerelease': False,
                'draft': False, 'html_url': 'https://github.com/xWink/farever-mods/releases/tag/minimap/v1.7.0',
                'assets': [{'name': self.plan['archive']}, {'name': 'release-manifest.json'}]}

    def test_preserve_supplied_notes_and_multiline_output(self):
        output_path = self.root / 'output'
        with patch.dict(os.environ, {'GITHUB_OUTPUT': str(output_path)}):
            release.output('plan', self.plan)
        line = output_path.read_text()
        self.assertEqual(len(line.splitlines()), 1)
        self.assertEqual(json.loads(line.removeprefix('plan='))['notes'], self.request['notes'])

    def nexus_upload_inputs(self):
        # Check the actual workflow binding, so a correct plan cannot hide a
        # regression that passes the GitHub release title to Nexus again.
        workflow = Path(__file__).resolve().parents[2] / '.github/workflows/release-mod.yml'
        upload = workflow.read_text().split('uses: Nexus-Mods/upload-action@', 1)[1]
        upload = upload.split('\n      - ', 1)[0]
        return dict(re.findall(r'^          (\w+): (.+)$', upload, re.MULTILINE))

    def test_nexus_upload_uses_plain_mod_name_and_separate_version(self):
        inputs = self.nexus_upload_inputs()
        fields = {}
        for key in ('display_name', 'version'):
            binding = re.fullmatch(r'\$\{\{ fromJSON\(needs.prepare.outputs.plan\)\.(\w+) \}\}', inputs[key])
            self.assertIsNotNone(binding, f'{key} must come from the validated release plan')
            fields[key] = binding[1]
        for project, mod in self.config.items():
            for version in ('1.8.0', '2.0.1'):
                with self.subTest(project=project, version=version):
                    plan = release.validate_request({**self.request, 'project': project, 'version': version}, self.config)
                    self.assertEqual(plan[fields['display_name']], mod['title'])
                    self.assertEqual(plan[fields['version']], version)
                    self.assertEqual(plan['title'], f"{mod['title']} {version}")

    def test_nexus_upload_archives_previous_version(self):
        self.assertEqual(self.nexus_upload_inputs()['archive_existing_version'], "'true'")

    def test_validation_rejects_bad_versions_and_paths(self):
        for version in ['v1.2.3', '1.02.3', '1.2', '1.2.3\nEVIL=1', '1.2.3;echo bad', '1.2.3-rc.01']:
            with self.subTest(version=version), self.assertRaises(ValueError):
                release.validate_request({**self.request, 'version': version}, self.config)
        for key, value in [('project', '../minimap'), ('commit', 'main'), ('notes', ''), ('dry_run', 'false')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                release.validate_request({**self.request, key: value}, self.config)

    def test_explicit_dry_run_required(self):
        request = dict(self.request)
        del request['dry_run']
        with self.assertRaises(ValueError):
            release.validate_request(request, self.config)

    def test_request_identity_changes_with_notes_or_source(self):
        for key, value in [('notes', 'Other notes'), ('commit', 'b' * 40), ('version', '1.7.1')]:
            other = release.validate_request({**self.request, key: value}, self.config)
            self.assertNotEqual(self.plan['fingerprint'], other['fingerprint'])

    def test_prerelease_does_not_become_stable(self):
        plan = release.validate_request({**self.request, 'version': '1.7.0-rc.1'}, self.config)
        self.assertTrue(plan['prerelease'])
        self.assertIsNone(release.stable_version(plan['version']))

    def test_plain_releases_follow_historical_capped_versions(self):
        historical = '1.7.0-max0.3.1.31995'
        old = release.validate_request({**self.request, 'version': historical}, self.config)
        self.assertFalse(old['prerelease'])
        self.assertEqual(old['tag'], 'minimap/v' + historical)
        self.assertEqual(release.stable_version(historical), (1, 7, 0))
        for version in ('1.6.9', '1.7.0', '1.7.1'):
            plan = release.validate_request({**self.request, 'version': version}, self.config)
            self.assertFalse(plan['prerelease'])
            self.assertEqual(plan['tag'], 'minimap/v' + version)
            with self.subTest(version=version), patch.object(release, 'api', side_effect=self.nexus_responses(historical)):
                if version == '1.7.1':
                    self.assertEqual(release.nexus_target(plan)['nexus_file_id'], 'file-uuid')
                else:
                    with self.assertRaises(ValueError):
                        release.nexus_target(plan)
        # Retrying an already published release retains its stable identity.
        with patch.object(release, 'api', side_effect=self.nexus_responses(historical)):
            self.assertEqual(release.nexus_target(old, completed=True)['nexus_file_id'], 'file-uuid')

    def test_new_requests_use_plain_versions(self):
        notes = self.root / 'notes.txt'
        notes.write_text(self.request['notes'])
        request = self.root / 'request.json'
        for version in ('1.7.1', '1.7.1-rc.1', '1.7.1-max0.3.1.31995', '1.7.1-min0.3'):
            args = ['release.py', 'request', '--project', 'minimap', '--version', version,
                    '--commit', 'a' * 40, '--notes-file', str(notes)]
            with self.subTest(version=version), patch.object(sys, 'argv', args), patch.object(release, 'REQUEST', request):
                request.unlink(missing_ok=True)
                if '-max' in version or '-min' in version:
                    with self.assertRaises(ValueError):
                        release.main()
                    self.assertFalse(request.exists())
                else:
                    release.main()
                    self.assertEqual(release.read_json(request)['version'], version)

    def test_invalid_or_ambiguous_game_ranges_are_rejected(self):
        for version in ['1.2.3-max0.3.1.31995.1', '1.2.3-max', '1.2.3-max00.3',
                        '1.2.3-max2147483647', '1.2.3-min0.4-max0.3',
                        '1.2.3-max0.3-min0.2', '1.2.3-rc.1-max0.3.1.31995']:
            with self.subTest(version=version), self.assertRaises(ValueError):
                release.validate_request({**self.request, 'version': version}, self.config)

    def test_production_packagers_remove_game_version_metadata(self):
        source = Path(__file__).resolve().parents[2]
        workflow = (source / '.github/workflows/_build-mod.yml').read_text()
        script = workflow.split('      - name: Package\n', 1)[1].split('        run: |\n', 1)[1].split('\n      - name:', 1)[0]
        script = textwrap.dedent(script)
        for project in self.config:
            with self.subTest(project=project):
                folder = self.root / project
                build = folder / 'build' / project
                (build / 'implementation').mkdir(parents=True)
                (build / f'{project}.hl').write_bytes(b'HLB bootstrap')
                (build / 'implementation' / f'{project}.hl').write_bytes(b'HLB implementation')
                (folder / 'configFormats.json').write_text('{}')
                (folder / 'README.md').write_text('Test package')
                self.assertFalse((source / project / 'mod.info').exists())
                # Repackaging must also remove limits left by an older build.
                for kind in ('mods', 'plugins'):
                    stale = folder / f'package/hlx/{kind}/{project}/mod.info'
                    stale.parent.mkdir(parents=True)
                    stale.write_text('maxGameVersion=0.3.1.31995\n')
                plugins = {'dps-meter': 'dps_meter_desktop.hdll',
                           'trade-and-marketplace': 'trade_marketplace_desktop.hdll',
                           'group-finder': 'group_finder_desktop.hdll'}
                if project in plugins:
                    (folder / 'build/native').mkdir()
                    plugin = plugins[project]
                    (folder / 'build/native' / plugin).write_bytes(b'Native test plugin')
                if project == 'dps-meter':
                    (folder / 'tools').mkdir()
                    shutil.copy2(source / project / 'tools/package.py', folder / 'tools/package.py')
                    subprocess.run([sys.executable, 'tools/package.py'], cwd=folder, check=True, capture_output=True)
                else:
                    env = {**os.environ, 'PROJECT':project, 'MODULE':project, 'REQUIRED_SETTINGS':'true', 'REQUIREMENTS':'Test'}
                    subprocess.run(['bash', '-e', '-c', script], cwd=folder, env=env, check=True, capture_output=True)
                plan = release.validate_request({**self.request, 'project':project, 'version':'1.0.0'}, self.config)
                self.assertFalse(plan['prerelease'])
                archive = release.make_archive(folder / 'package', plan)
                with zipfile.ZipFile(archive) as zipped:
                    self.assertFalse(any(name.endswith('/mod.info') for name in zipped.namelist()))
                    self.assertIn(f'hlx/mods/{project}/{project}.hl', zipped.namelist())
                    if project in plugins:
                        self.assertIn(f'hlx/plugins/{project}/{plugin}', zipped.namelist())

    def test_zip_has_installable_root_and_stable_bytes(self):
        package = self.package()
        archive = release.make_archive(package, self.plan)
        first = archive.read_bytes()
        os.utime(package / 'hlx/mods/minimap/minimap.hl', (5, 5))
        self.assertEqual(first, release.make_archive(package, self.plan).read_bytes())
        with zipfile.ZipFile(archive) as file:
            self.assertEqual(file.namelist(), ['hlx/mods/minimap/minimap.hl'])
            self.assertEqual(file.read(file.namelist()[0]), b'compiled test module')

    def test_rejects_cross_mod_files_and_user_config(self):
        package = self.package()
        for name in ['hlx/mods/minimap/config.json', 'hlx/mods/minimap/uploader.ini', 'hlx/mods/minimap/.env', 'secret.txt', 'hlx/mods/dps-meter/dps-meter.hl']:
            file = package / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text('not releasable')
            with self.subTest(name=name), self.assertRaises(ValueError):
                release.make_archive(package, self.plan)
            file.unlink()

    def test_rejects_symlink_payload(self):
        package = self.package()
        (package / 'hlx/mods/minimap/leak.txt').symlink_to(self.root / 'outside.txt')
        (self.root / 'outside.txt').write_text('outside artifact')
        with self.assertRaises(ValueError):
            release.make_archive(package, self.plan)

    def test_dps_native_plugin_is_required(self):
        with self.assertRaises(ValueError):
            release.validate_package(self.package('dps-meter'), 'dps-meter')

    def test_group_finder_release_requires_complete_installation(self):
        plan = release.validate_request({**self.request, 'project': 'group-finder', 'version': '1.0.0'}, self.config)
        self.assertEqual(plan['nexus_url'], 'https://www.nexusmods.com/farever/mods/37')
        self.assertEqual(plan['tag'], 'group-finder/v1.0.0')
        package = self.package('group-finder')
        implementation = package / 'hlx/mods/group-finder/implementation/group-finder.hl'
        plugin = package / 'hlx/plugins/group-finder/group_finder_desktop.hdll'
        implementation.parent.mkdir(parents=True)
        plugin.parent.mkdir(parents=True)
        plugin.write_bytes(b'Native test plugin')
        with self.assertRaisesRegex(ValueError, 'Missing Group Finder implementation'):
            release.make_archive(package, plan)
        implementation.write_bytes(b'HLB implementation')
        plugin.unlink()
        with self.assertRaisesRegex(ValueError, 'Missing Group Finder desktop plugin'):
            release.make_archive(package, plan)
        plugin.write_bytes(b'Native test plugin')
        with zipfile.ZipFile(release.make_archive(package, plan)) as archive:
            self.assertEqual(len(archive.namelist()), 3)
            self.assertEqual(archive.read(plugin.relative_to(package).as_posix()), b'Native test plugin')

    def test_more_settings_no_longer_requires_an_audio_plugin(self):
        self.assertTrue(release.validate_package(self.package('more-settings'), 'more-settings'))

    def test_dry_run_makes_zip_without_any_publishing_call(self):
        self.package()
        with patch.object(release, 'api') as api, patch.object(release.subprocess, 'run') as command:
            release.publish_github({**self.plan, 'dry_run': True})
            api.assert_not_called()
            command.assert_not_called()
        self.assertTrue((self.work / self.plan['archive']).exists())

    def test_select_primary_file_among_optional_downloads(self):
        files = [{'id': 'main-file'}, {'id': 'optional-file'}]
        versions = [{'file': {'id': 'main-file'}, 'category': 'main', 'is_primary': True},
                    {'file': {'id': 'optional-file'}, 'category': 'optional'}]
        self.assertEqual(release.select_nexus_file(files, versions), 'main-file')

    def test_single_main_file_without_primary(self):
        versions = [{'file': {'id': 'main-file'}, 'category': 'main'},
                    {'file': {'id': 'old-file'}, 'category': 'old_version'}]
        self.assertEqual(release.select_nexus_file([{'id': 'main-file'}, {'id': 'old-file'}], versions), 'main-file')

    def test_ambiguous_file_selection_requires_configuration(self):
        files = [{'id': 'one'}, {'id': 'two'}]
        versions = [{'file': f, 'category': 'main'} for f in files]
        with self.assertRaises(ValueError):
            release.select_nexus_file(files, versions)
        self.assertEqual(release.select_nexus_file(files, versions, 'two'), 'two')
        with self.assertRaises(ValueError):
            release.select_nexus_file(files, versions, 'another-mod-file')

    def nexus_responses(self, version='1.6.0'):
        return [{'data': {'id': 'mod-uuid'}}, {'data': {'mod_files': [{'id': 'file-uuid'}]}},
                {'data': {'versions': [{'id': 'version-uuid', 'file': {'id': 'file-uuid'}, 'version': version,
                                       'category': 'main', 'is_primary': True}]}}]

    def test_v3_ids_are_resolved_from_page_id(self):
        with patch.object(release, 'api', side_effect=self.nexus_responses()) as api:
            self.assertEqual(release.nexus_target(self.plan), {'nexus_mod_id': 'mod-uuid', 'nexus_file_id': 'file-uuid'})
        self.assertEqual(api.call_args_list[0].args, ('nexus', 'games/farever/mods/15'))
        self.assertEqual(api.call_args_list[1].args, ('nexus', 'mods/mod-uuid/files'))

    def test_nexus_duplicate_and_downgrade_are_stopped(self):
        for existing in ['1.7.0', '2.0.0']:
            with self.subTest(existing=existing), patch.object(release, 'api', side_effect=self.nexus_responses(existing)):
                with self.assertRaises(ValueError):
                    release.nexus_target(self.plan)

    def test_completed_receipt_allows_idempotent_retry(self):
        with patch.object(release, 'api', side_effect=self.nexus_responses('1.7.0')):
            self.assertEqual(release.nexus_target(self.plan, completed=True)['nexus_file_id'], 'file-uuid')

    def test_wrong_existing_tag_never_moves(self):
        with patch.object(release, 'api', return_value={'object': {'type': 'commit', 'sha': 'b' * 40}}) as api:
            with self.assertRaises(ValueError):
                release.verify_tag(self.plan)
            self.assertEqual(api.call_count, 1)

    def test_annotated_tag_uses_user_notes_and_exact_source(self):
        with patch.object(release, 'api', side_effect=[None, {'sha': 'tag-sha'}, {}]) as api:
            release.verify_tag(self.plan)
        tag_body = api.call_args_list[1].args[2]
        self.assertEqual(tag_body['message'], self.request['notes'])
        self.assertEqual(tag_body['object'], self.request['commit'])
        self.assertEqual(api.call_args_list[2].args[2]['ref'], 'refs/tags/minimap/v1.7.0')

    def test_conflicting_existing_notes_are_not_overwritten(self):
        existing = self.existing()
        existing['body'] = 'Someone else wrote this'
        with patch.object(release, 'download_asset') as download, self.assertRaises(ValueError):
            release.verify_existing(self.plan, existing)
        download.assert_not_called()

    def test_retry_reuses_published_zip_instead_of_rebuild(self):
        self.package()
        old_zip = self.work / 'old.zip'
        old_zip.write_bytes(b'previously published artifact')
        existing = self.existing()
        manifest = {'sha256': release.digest(old_zip)}
        def download(plan, record, name):
            target = self.work / name
            target.write_bytes(old_zip.read_bytes())
            return target
        with patch.object(release, 'verify_tag'), patch.object(release, 'github_release', return_value=existing), \
             patch.object(release, 'verify_existing', return_value=manifest), patch.object(release, 'download_asset', side_effect=download), \
             patch.object(release, 'receipt_exists', return_value=True), patch.object(release.subprocess, 'run') as command:
            release.publish_github(self.plan)
            command.assert_not_called()
        self.assertEqual((self.work / self.plan['archive']).read_bytes(), old_zip.read_bytes())

    def test_find_draft_when_tag_endpoint_returns_404(self):
        draft = {**self.existing(), 'tag_name': self.plan['tag'], 'draft': True}
        first_page = [{'tag_name': f'other/v{i}'} for i in range(100)]
        with patch.object(release, 'api', side_effect=[None, first_page, [draft]]) as api:
            self.assertEqual(release.github_release(self.plan), draft)
        self.assertEqual(api.call_args_list[-1].args, ('github', 'releases?per_page=100&page=2'))

    def test_missing_release_checks_drafts_before_returning_none(self):
        with patch.object(release, 'api', side_effect=[None, []]) as api:
            self.assertIsNone(release.github_release(self.plan))
        self.assertEqual(api.call_args_list[-1].args, ('github', 'releases?per_page=100&page=1'))

    def test_published_release_does_not_need_draft_listing(self):
        with patch.object(release, 'api', return_value=self.existing()) as api:
            self.assertEqual(release.github_release(self.plan), self.existing())
        self.assertEqual(api.call_count, 1)

    def test_retry_publishes_existing_draft_without_replacing_assets(self):
        self.package()
        old_zip = self.work / 'old.zip'
        old_zip.write_bytes(b'original draft artifact')
        draft = {**self.existing(), 'id': 42, 'draft': True, 'html_url': 'draft-url'}
        published = {**draft, 'draft': False, 'html_url': 'published-url'}
        with patch.object(release, 'verify_tag'), patch.object(release, 'github_release', return_value=draft), \
             patch.object(release, 'verify_existing', return_value={'sha256': release.digest(old_zip)}), \
             patch.object(release, 'download_asset', return_value=old_zip), \
             patch.object(release, 'receipt_exists', return_value=False), \
             patch.object(release, 'api', return_value=published) as api, \
             patch.object(release, 'output') as output, patch.object(release.subprocess, 'run') as command:
            release.publish_github(self.plan)
        command.assert_called_once_with(['gh', 'release', 'edit', self.plan['tag'], '--repo', release.REPO,
                                        '--draft=false', '--latest=false'], check=True, cwd=self.root)
        api.assert_called_once_with('github', 'releases/42')
        output.assert_any_call('url', 'published-url')
        output.assert_any_call('archive', str(old_zip))
        self.assertEqual(old_zip.read_bytes(), b'original draft artifact')

    def test_hash_mismatch_stops_retry(self):
        self.package()
        bad = self.work / 'bad.zip'
        bad.write_bytes(b'wrong asset')
        with patch.object(release, 'verify_tag'), patch.object(release, 'github_release', return_value=self.existing()), \
             patch.object(release, 'verify_existing', return_value={'sha256': 'wrong'}), patch.object(release, 'download_asset', return_value=bad), \
             patch.object(release.subprocess, 'run') as command, self.assertRaises(ValueError):
            release.publish_github(self.plan)
        command.assert_not_called()

    def test_only_404_is_treated_as_absent(self):
        with patch.dict(os.environ, {'GH_TOKEN': 'test-token'}):
            for status in [401, 403, 500]:
                error = urllib.error.HTTPError('https://example.invalid', status, 'failed', {}, io.BytesIO(b'private response'))
                with self.subTest(status=status), patch.object(release.urllib.request, 'urlopen', side_effect=error), self.assertRaises(ValueError):
                    release.github_release(self.plan)
            error = urllib.error.HTTPError('https://example.invalid', 404, 'missing', {}, io.BytesIO())
            with patch.object(release.urllib.request, 'urlopen', side_effect=error):
                self.assertIsNone(release.api('github', 'releases/tags/missing', missing_ok=True))

    def test_no_local_or_branch_publishing(self):
        for env in [{}, {'GITHUB_ACTIONS': 'true', 'GITHUB_REPOSITORY': release.REPO, 'GITHUB_REF': 'refs/heads/test'}]:
            with patch.dict(os.environ, env, clear=True), self.assertRaises(ValueError):
                release.require_actions()


if __name__ == '__main__':
    unittest.main()
