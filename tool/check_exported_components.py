#!/usr/bin/env python3
"""Fails when the app's exported Android components differ from ALLOWED.

Reads the merged release manifest, so the plugins' components count too
(after `flutter build apk --release`):

  python3 -I tool/check_exported_components.py [manifest]
  python3 -I tool/check_exported_components.py --self-test

Default manifest:
  app/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml

A component counts as exported with android:exported="true", or with an
intent filter and no android:exported="false"; any other exported value
(a resource reference) fails. Each entry pins what another app or a web page
can reach: the permission that guards it, and each intent filter on its own,
with its actions, categories and every attribute of its data elements. Any
addition, removal or change fails: review what the new manifest exposes,
then update ALLOWED (--print shows the found entries in its format). Also
asserts that backups stay off (allowBackup="false" and the data extraction
rules). --self-test checks the checker against manifests made from ALLOWED.
"""
import os
import sys
import xml.etree.ElementTree as ElementTree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_MANIFEST = os.path.join(
    ROOT, 'app/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml')
ANDROID = '{http://schemas.android.com/apk/res/android}'
COMPONENTS = ('activity', 'activity-alias', 'receiver', 'service', 'provider')
RULES = '@xml/data_extraction_rules'

APP = 'dev.coderoftime.vikunja'
SCHEME = 'vikunja-dev.coderoftime.vikunja'
VIEW = 'android.intent.action.VIEW'
DEFAULT = 'android.intent.category.DEFAULT'
BROWSABLE = 'android.intent.category.BROWSABLE'
APPWIDGET_UPDATE = 'android.appwidget.action.APPWIDGET_UPDATE'


def intent_filter(actions=(), categories=(), data=()):
    return (tuple(sorted(actions)), tuple(sorted(categories)),
            tuple(sorted(tuple(sorted(d.items())) for d in data)))


def entry(permission=None, filters=()):
    return (permission, tuple(sorted(filters)))


# (tag, name) -> entry. The app's own entry points first, then the plugins'.
ALLOWED = {
    # The launcher activity; Flutter routes the data of any intent sent to
    # it, which the router drops unless it is on the app's scheme (G1).
    ('activity', f'{APP}.MainActivity'): entry(filters=[
        intent_filter(['android.intent.action.MAIN'], ['android.intent.category.LAUNCHER'])]),
    ('activity', f'{APP}.TaskLinkActivity'): entry(filters=[
        intent_filter([VIEW], [BROWSABLE, DEFAULT], [{'scheme': SCHEME, 'host': 'task'}])]),
    ('activity', f'{APP}.ShareTargetActivity'): entry(filters=[
        intent_filter(['android.intent.action.SEND'], [DEFAULT],
                      [{'mimeType': '*/*'}, {'mimeType': 'image/*'}, {'mimeType': 'text/*'},
                       {'mimeType': 'video/*'}]),
        intent_filter(['android.intent.action.SEND_MULTIPLE'], [DEFAULT],
                      [{'mimeType': '*/*'}, {'mimeType': 'image/*'}, {'mimeType': 'video/*'}])]),
    ('activity', 'com.linusu.flutter_web_auth_2.CallbackActivity'): entry(filters=[
        intent_filter([VIEW], [BROWSABLE, DEFAULT],
                      [{'scheme': SCHEME, 'host': 'oauth', 'path': '/callback'}])]),
    # The launcher's widget setup; it checks that the id is one of the
    # app's widgets before it opens anything.
    ('activity', f'{APP}.widgets.WidgetConfigureActivity'): entry(filters=[
        intent_filter(['android.appwidget.action.APPWIDGET_CONFIGURE'])]),
    # The system sends APPWIDGET_UPDATE; any app can too, which only redraws.
    ('receiver', f'{APP}.widgets.TasksWidgetReceiver'): entry(filters=[intent_filter([APPWIDGET_UPDATE])]),
    ('receiver', f'{APP}.widgets.QuickAddWidgetReceiver'): entry(filters=[intent_filter([APPWIDGET_UPDATE])]),
    # Bound by the system only.
    ('service', 'androidx.glance.appwidget.GlanceRemoteViewsService'): entry(
        permission='android.permission.BIND_REMOTEVIEWS'),
    ('service', 'androidx.work.impl.background.systemjob.SystemJobService'): entry(
        permission='android.permission.BIND_JOB_SERVICE'),
    ('receiver', 'androidx.work.impl.diagnostics.DiagnosticsReceiver'): entry(
        permission='android.permission.DUMP',
        filters=[intent_filter(['androidx.work.diagnostics.REQUEST_DIAGNOSTICS'])]),
    ('receiver', 'androidx.profileinstaller.ProfileInstallReceiver'): entry(
        permission='android.permission.DUMP',
        filters=[intent_filter([f'androidx.profileinstaller.action.{action}'])
                 for action in ('BENCHMARK_OPERATION', 'INSTALL_PROFILE', 'SAVE_PROFILE', 'SKIP_FILE')]),
}


def attribute(element, name):
    return element.get(ANDROID + name)


def attributes(element):
    return {name[len(ANDROID):] if name.startswith(ANDROID) else name: value
            for name, value in element.attrib.items()}


def exported_components(application):
    found, problems = {}, []
    for element in application:
        if element.tag not in COMPONENTS:
            continue
        filters = element.findall('intent-filter')
        exported = attribute(element, 'exported')
        name = attribute(element, 'name')
        if exported not in (None, 'true', 'false'):
            problems.append(f'{element.tag} {name}: android:exported is {exported!r}, not "true" or "false"')
        if exported == 'false' or (exported is None and not filters):
            continue
        found[(element.tag, name)] = entry(attribute(element, 'permission'), [
            intent_filter([attribute(a, 'name') for a in f.findall('action')],
                          [attribute(c, 'name') for c in f.findall('category')],
                          [attributes(d) for d in f.findall('data')])
            for f in filters])
    return found, problems


def describe(value):
    permission, filters = value
    described = ', '.join(
        f'intent_filter({list(actions)!r}, {list(categories)!r}, {[dict(d) for d in data]!r})'
        for actions, categories, data in filters)
    return f'entry(permission={permission!r}, filters=[{described}])'


def check(manifest):
    application = manifest.find('application')
    problems = []
    if attribute(application, 'allowBackup') != 'false':
        problems.append('application: android:allowBackup is not "false"')
    if attribute(application, 'dataExtractionRules') != RULES:
        problems.append(f'application: android:dataExtractionRules is not "{RULES}"')
    found, export_problems = exported_components(application)
    problems += export_problems
    for key in sorted(found.keys() - ALLOWED.keys()):
        problems.append(f'newly exported: {key[0]} {key[1]}\n    {describe(found[key])}')
    for key in sorted(ALLOWED.keys() - found.keys()):
        problems.append(f'no longer exported: {key[0]} {key[1]}')
    for key in sorted(found.keys() & ALLOWED.keys()):
        if found[key] != ALLOWED[key]:
            problems.append(f'changed: {key[0]} {key[1]}\n    allowed {describe(ALLOWED[key])}'
                            f'\n    found   {describe(found[key])}')
    return found, problems


def manifest_from_allowed():
    manifest = ElementTree.Element('manifest')
    application = ElementTree.SubElement(
        manifest, 'application', {ANDROID + 'allowBackup': 'false', ANDROID + 'dataExtractionRules': RULES})
    for (tag, name), (permission, filters) in ALLOWED.items():
        component = ElementTree.SubElement(application, tag, {ANDROID + 'name': name, ANDROID + 'exported': 'true'})
        if permission:
            component.set(ANDROID + 'permission', permission)
        for actions, categories, data in filters:
            element = ElementTree.SubElement(component, 'intent-filter')
            for action in actions:
                ElementTree.SubElement(element, 'action', {ANDROID + 'name': action})
            for category in categories:
                ElementTree.SubElement(element, 'category', {ANDROID + 'name': category})
            for d in data:
                ElementTree.SubElement(element, 'data', {ANDROID + k: v for k, v in d})
    return manifest


def component(manifest, name):
    return next(e for e in manifest.find('application') if attribute(e, 'name') == name)


def add(manifest, tag, name, exported=None, actions=()):
    element = ElementTree.SubElement(manifest.find('application'), tag, {ANDROID + 'name': name})
    if exported is not None:
        element.set(ANDROID + 'exported', exported)
    if actions:
        intent = ElementTree.SubElement(element, 'intent-filter')
        for action in actions:
            ElementTree.SubElement(intent, 'action', {ANDROID + 'name': action})


def regroup_share_filters(manifest):
    first, second = component(manifest, f'{APP}.ShareTargetActivity').findall('intent-filter')
    first_data, second_data = first.findall('data'), second.findall('data')
    for d in first_data:
        first.remove(d)
        second.append(d)
    for d in second_data:
        second.remove(d)
        first.append(d)


def add_data_attribute(name):
    def mutate(manifest):
        component(manifest, f'{APP}.TaskLinkActivity').find('intent-filter/data').set(ANDROID + name, '.*')
    return mutate


def self_test():
    application = lambda m: m.find('application')
    cases = [
        ('the allowed components', lambda m: None, True),
        ('a component exported with "false" and a filter', lambda m: add(m, 'activity', 'x.Hidden', 'false', [VIEW]),
         True),
        ('a new exported receiver', lambda m: add(m, 'receiver', 'x.Leak', 'true'), False),
        ('an export through an intent filter', lambda m: add(m, 'activity', 'x.Implicit', actions=[VIEW]), False),
        ('an export through a resource', lambda m: add(m, 'receiver', 'x.Flag', '@bool/exported'), False),
        ('a component no longer exported', lambda m: application(m).remove(component(m, f'{APP}.TaskLinkActivity')),
         False),
        ('BROWSABLE added', lambda m: ElementTree.SubElement(
            component(m, f'{APP}.MainActivity').find('intent-filter'), 'category', {ANDROID + 'name': BROWSABLE}),
         False),
        ('a permission dropped', lambda m: component(m, 'androidx.work.impl.background.systemjob.SystemJobService')
         .attrib.pop(ANDROID + 'permission'), False),
        ('filters regrouped', regroup_share_filters, False),
        ('backups allowed', lambda m: application(m).set(ANDROID + 'allowBackup', 'true'), False),
        ('no extraction rules', lambda m: application(m).attrib.pop(ANDROID + 'dataExtractionRules'), False),
    ] + [(f'a data element with {name}', add_data_attribute(name), False)
         for name in ('pathSuffix', 'pathAdvancedPattern', 'ssp', 'sspPrefix', 'sspPattern', 'port')]
    failed = 0
    for description, mutate, passes in cases:
        manifest = manifest_from_allowed()
        mutate(manifest)
        _, problems = check(manifest)
        if (not problems) != passes:
            failed += 1
            print(f'FAILED: {description}: expected {"a pass" if passes else "a failure"}')
            for problem in problems:
                print(f'  {problem}')
    if failed:
        return 1
    print(f'Self-test: {len(cases)} cases as expected.')
    return 0


def main(arguments):
    if '--self-test' in arguments:
        return self_test()
    show = '--print' in arguments
    paths = [a for a in arguments if a != '--print']
    path = paths[0] if paths else DEFAULT_MANIFEST
    if not os.path.isfile(path):
        print(f'No merged manifest at {path}; build the release APK first.')
        return 2
    found, problems = check(ElementTree.parse(path).getroot())
    if show:
        for key in sorted(found):
            print(f'{key!r}: {describe(found[key])},')
    if problems:
        print(f'{path} differs from what tool/check_exported_components.py allows:')
        for problem in problems:
            print(f'  {problem}')
        return 1
    print(f'{len(found)} exported components as allowed; backups off.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
