#!/usr/bin/env python3
"""Builds the website (D76) from site/ into public/, the folder GitLab Pages
publishes: a language chooser and, in English and German, the home page, the
privacy policy, the legal notice, support and account deletion.

  python3 -I tool/build_site.py                  build into public/
  python3 -I tool/build_site.py --out DIR        build into DIR
  python3 -I tool/build_site.py --preview        missing values as marked placeholders,
                                                 into build/site-preview/ unless --out
  python3 -I tool/build_site.py --check          build into a temporary folder, check, keep nothing
  python3 -I tool/build_site.py --check --preview

The owner's values come from site/site.json, the optional store and source
links from site/links.json. Without --preview the build refuses while a value
of site.json is empty, so the Pages job fails until the owner has filled it.
Every build checks what it wrote: every page in both languages with the same
anchors, each page linking its counterpart, the privacy policy and the legal
notice, internal links and anchors that resolve, no script and nothing loaded
from another server, and without --preview no placeholder left.
"""
import argparse
import datetime
import html
import json
import os
import posixpath
import re
import shutil
import sys
import tempfile
import urllib.parse
from html.parser import HTMLParser

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'site')
DEFAULT_OUT = os.path.join(ROOT, 'public')
PREVIEW_OUT = os.path.join(ROOT, 'build', 'site-preview')
LANGUAGES = ('en', 'de')
PAGES = {'home': '', 'privacy': 'privacy/', 'legal': 'legal/', 'support': 'support/',
         'delete-account': 'delete-account/'}
VALUES = ('site_url', 'contact_email', 'legal_name', 'address_lines', 'country')
LINKS = ('source_code_url', 'google_play_url', 'app_store_url')
STRINGS = {'language_name', 'skip', 'pages', 'unofficial', 'preview', 'date', 'months', 'google_play', 'app_store',
           'apk', 'coming_soon', 'source_code', 'source_code_pending', 'issues', 'issues_pending'}
FRONT_MATTER = {'title', 'nav', 'description'}
OPTIONAL_FRONT_MATTER = {'updated'}
TOKEN = re.compile(r'\{\{\s*([a-z_]+)\s*\}\}')
EMAIL = re.compile(r'[^@\s<>"\'()\[\],;:]+@[^@\s<>"\'()\[\],;:]+\.[^@\s<>"\'()\[\],;:]+')


class SiteError(Exception):
    pass


def relative(path):
    return os.path.relpath(path, ROOT) if path.startswith(ROOT + os.sep) else path


def read_text(path):
    try:
        with open(path, encoding='utf-8') as f:
            return f.read()
    except OSError as error:
        raise SiteError(f'{relative(path)}: {error.strerror}') from error


def read_json(path):
    try:
        data = json.loads(read_text(path))
    except ValueError as error:
        raise SiteError(f'{relative(path)}: {error}') from error
    if not isinstance(data, dict):
        raise SiteError(f'{relative(path)}: not a JSON object')
    return data


def https_url_problem(value, base=True):
    """Why `value` is no https address; a base, to which paths are added, has no query and no final slash."""
    try:
        parts = urllib.parse.urlsplit(value)
    except ValueError:
        return 'must be an https address'
    if parts.scheme != 'https' or not parts.hostname:
        return 'must be an https address'
    if parts.username or parts.password:
        return 'must not carry a user'
    if base and (parts.query or parts.fragment):
        return 'must not carry a query or fragment'
    if base and value.endswith('/'):
        return 'must not end with a slash'
    return None


def missing_values(values):
    """The names of the empty values in site.json; raises on a malformed one."""
    problems, missing = [], []
    for name in VALUES:
        if name not in values:
            problems.append(f'{name} is missing')
            continue
        value = values[name]
        if name == 'address_lines':
            if not isinstance(value, list) or not all(isinstance(line, str) for line in value):
                problems.append('address_lines must be a list of strings')
            elif not value:
                missing.append(name)
            elif any(not line.strip() or line != line.strip() for line in value):
                problems.append('address_lines must not hold empty lines or spaces around a line')
            elif len(value) < 2:
                problems.append('address_lines needs at least two lines, such as the street and the town')
            continue
        if not isinstance(value, str):
            problems.append(f'{name} must be a string')
        elif not value:
            missing.append(name)
        elif value != value.strip():
            problems.append(f'{name} has spaces around it')
        elif name == 'site_url' and https_url_problem(value):
            problems.append(f'site_url {https_url_problem(value)}, such as https://rurana.example')
        elif name == 'contact_email' and not EMAIL.fullmatch(value):
            problems.append('contact_email is not an email address')
    if problems:
        raise SiteError('site/site.json: ' + '; '.join(problems) + '.')
    return missing


def checked_links(links):
    problems = []
    for name in LINKS:
        value = links.get(name, '')
        if not isinstance(value, str):
            problems.append(f'{name} must be a string')
        elif value and https_url_problem(value, base=name == 'source_code_url'):
            problems.append(f'{name} {https_url_problem(value, base=name == "source_code_url")}')
    if problems:
        raise SiteError('site/links.json: ' + '; '.join(problems) + '.')
    return {name: links.get(name, '') for name in LINKS}


def refusal(missing):
    return (f'site/site.json has no value yet for: {", ".join(missing)}.\n'
            'The privacy policy and the legal notice name the publisher from these values, so the site is not '
            'built without them. Fill them in as site/README.md describes; for a marked preview without them, run '
            'python3 -I tool/build_site.py --preview')


def read_page(path):
    text = read_text(path)
    head, separator, body = text.partition('\n---\n')
    if not separator:
        raise SiteError(f'{relative(path)}: no front matter ending in a line "---"')
    meta = {}
    for line in head.splitlines():
        key, colon, value = line.partition(':')
        key, value = key.strip(), value.strip()
        if not colon or not key or not value:
            raise SiteError(f'{relative(path)}: front matter line {line!r} is not "key: value"')
        if key not in FRONT_MATTER | OPTIONAL_FRONT_MATTER:
            raise SiteError(f'{relative(path)}: unknown front matter key {key!r}')
        meta[key] = value
    if FRONT_MATTER - meta.keys():
        raise SiteError(f'{relative(path)}: front matter lacks {", ".join(sorted(FRONT_MATTER - meta.keys()))}')
    if 'updated' in meta:
        try:
            datetime.date.fromisoformat(meta['updated'])
        except ValueError as error:
            raise SiteError(f'{relative(path)}: updated is not a date (YYYY-MM-DD)') from error
    return meta, body


def render(template, tokens, where):
    """Replaces each {{name}} by tokens[name] in one pass, so a value is never read as a template."""
    if '{{' in TOKEN.sub('', template) or '}}' in TOKEN.sub('', template):
        raise SiteError(f'{where}: "{{{{" or "}}}}" outside a {{{{name}}}}')

    def replace(match):
        if match.group(1) not in tokens:
            raise SiteError(f'{where}: unknown value {{{{{match.group(1)}}}}}')
        return tokens[match.group(1)]

    return TOKEN.sub(replace, template)


def escape(value):
    return html.escape(value, quote=True)


def placeholder(name):
    return f'<mark class="placeholder">[site.json: {name}]</mark>'


def value_tokens(values):
    def shown(name, text):
        return text if values[name] else placeholder(name)

    email = escape(values['contact_email'])
    return {
        'legal_name': shown('legal_name', escape(values['legal_name'])),
        'country': shown('country', escape(values['country'])),
        'contact_email': shown('contact_email', email),
        'contact_email_link': shown('contact_email', f'<a href="mailto:{email}">{email}</a>'),
        'address': shown('address_lines', '<br>\n'.join(escape(line) for line in values['address_lines'])),
        'site_host': shown('site_url', escape(urllib.parse.urlsplit(values['site_url']).netloc)),
    }


def link_tokens(links, strings):
    source = links['source_code_url']
    downloads = []
    for key, url in (('google_play', links['google_play_url']), ('app_store', links['app_store_url']),
                     ('apk', source and source + '/-/releases')):
        if url:
            downloads.append(f'<li><a href="{escape(url)}">{strings[key]}</a></li>')
        else:
            downloads.append(f'<li>{strings["coming_soon"].format(name=strings[key])}</li>')
    return {
        'downloads': '<ul>\n' + '\n'.join(downloads) + '\n</ul>',
        'source_code': strings['source_code'].format(url=escape(source)) if source
        else strings['source_code_pending'],
        'issues': strings['issues'].format(url=escape(source + '/-/issues')) if source
        else strings['issues_pending'],
    }


def formatted_date(iso, strings):
    date = datetime.date.fromisoformat(iso)
    return strings['date'].format(day=date.day, month=strings['months'][date.month - 1], year=date.year)


def href(from_dir, to_dir):
    return posixpath.relpath(to_dir or '.', from_dir or '.') + '/'


def read_sources(source):
    strings = read_json(os.path.join(source, 'strings.json'))
    if set(strings) != set(LANGUAGES):
        raise SiteError(f'site/strings.json: needs exactly the languages {", ".join(LANGUAGES)}')
    for lang in LANGUAGES:
        if not isinstance(strings[lang], dict) or set(strings[lang]) != STRINGS:
            raise SiteError(f'site/strings.json: {lang} needs exactly the texts {", ".join(sorted(STRINGS))}')
        if not isinstance(strings[lang]['months'], list) or len(strings[lang]['months']) != 12:
            raise SiteError(f'site/strings.json: {lang} needs twelve months')
    pages = {}
    for page in PAGES:
        metas = {}
        for lang in LANGUAGES:
            path = os.path.join(source, 'pages', lang, f'{page}.html')
            pages[lang, page] = read_page(path)
            metas[lang] = pages[lang, page][0]
        if metas['en'].keys() != metas['de'].keys() or metas['en'].get('updated') != metas['de'].get('updated'):
            raise SiteError(f'site/pages/*/{page}.html: en and de must have the same front matter keys and the '
                            'same updated date, since the German text is binding and the English one translates it')
    return strings, pages


def render_site(source, values, links, preview):
    """The site's files as {published path: text}."""
    strings, pages = read_sources(source)
    layout = read_text(os.path.join(source, 'templates', 'layout.html'))
    common = value_tokens(values)
    robots = '<meta name="robots" content="noindex">\n' if preview else ''
    files = {'style.css': read_text(os.path.join(source, 'style.css'))}
    files['index.html'] = render(read_text(os.path.join(source, 'templates', 'index.html')), {
        'robots': robots,
        'preview_banner': f'<p class="preview">{strings["en"]["preview"]}</p>\n' if preview else '',
    }, 'site/templates/index.html')
    for lang in LANGUAGES:
        other = next(language for language in LANGUAGES if language != lang)
        texts = strings[lang]
        tokens = dict(common, **link_tokens(links, texts))
        for page, path in PAGES.items():
            meta, body = pages[lang, page]
            here = f'{lang}/{path}'.rstrip('/')
            where = f'site/pages/{lang}/{page}.html'
            page_tokens = dict(tokens)
            if 'updated' in meta:
                page_tokens['updated'] = formatted_date(meta['updated'], texts)
            footer = []
            for target, target_path in PAGES.items():
                current = ' aria-current="page"' if target == page else ''
                footer.append(f'<li><a href="{href(here, f"{lang}/{target_path}".rstrip("/"))}"{current}>'
                              f'{escape(pages[lang, target][0]["nav"])}</a></li>')
            files[f'{lang}/{path}index.html'] = render(layout, {
                'lang': lang,
                'robots': robots,
                'page_title': escape(meta['title'] if page == 'home' else f'{meta["title"]} · Rurana'),
                'description': escape(meta['description']),
                'root': href(here, ''),
                'preview_banner': f'<p class="preview" lang="{lang}">{texts["preview"]}</p>\n' if preview else '',
                'skip': texts['skip'],
                'home': href(here, lang),
                'other_page': href(here, f'{other}/{path}'.rstrip('/')),
                'other_lang': other,
                'other_language_name': strings[other]['language_name'],
                'content': render(body, page_tokens, where).strip(),
                'pages': texts['pages'],
                'footer_links': '\n'.join(footer),
                'unofficial': texts['unofficial'],
            }, 'site/templates/layout.html')
    return files


def is_previous_build(out):
    # Any <lang>/<page>/index.html counts, so a build from before a page was renamed is still replaced.
    built = re.compile(r'(?:(?:' + '|'.join(LANGUAGES) + r')/(?:[a-z0-9-]+/)?)?index\.html|style\.css')
    for directory, _, names in os.walk(out):
        for name in names:
            path = os.path.relpath(os.path.join(directory, name), out).replace(os.sep, '/')
            if not built.fullmatch(path):
                return False
    return True


def write_files(out, files):
    if os.path.lexists(out):
        if not os.path.isdir(out) or os.path.islink(out) or not is_previous_build(out):
            raise SiteError(f'{out} holds other files than a site build; choose another --out or remove it')
        shutil.rmtree(out)
    for path, text in files.items():
        target = os.path.join(out, *path.split('/'))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, 'w', encoding='utf-8', newline='\n') as f:
            f.write(text)


class PageScan(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.lang = None
        self.ids = []
        self.links = []
        self.resources = []
        self.forbidden = []
        self.h1 = 0
        self.title = ''
        self.placeholders = 0
        self.in_title = False

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == 'html':
            self.lang = attributes.get('lang')
        if attributes.get('id'):
            self.ids.append(attributes['id'])
        if tag in ('script', 'iframe', 'frame', 'object', 'embed', 'base', 'form'):
            self.forbidden.append(tag)
        if tag == 'a' and 'href' in attributes:
            self.links.append((attributes['href'], attributes.get('hreflang')))
        elif tag != 'a':
            for name in ('src', 'href', 'srcset', 'poster', 'data', 'action', 'formaction'):
                if name in attributes:
                    self.resources.append((tag, name, attributes[name] or ''))
        if 'url(' in (attributes.get('style') or ''):
            self.resources.append((tag, 'style', attributes['style']))
        if tag == 'h1':
            self.h1 += 1
        if tag == 'title':
            self.in_title = True
        if tag == 'mark' and 'placeholder' in (attributes.get('class') or '').split():
            self.placeholders += 1

    handle_startendtag = handle_starttag

    def handle_endtag(self, tag):
        if tag == 'title':
            self.in_title = False

    def handle_data(self, data):
        if self.in_title:
            self.title += data


def resolve(page, link):
    """The published file a relative link of `page` opens, with its fragment, or a problem."""
    try:
        parts = urllib.parse.urlsplit(link)
    except ValueError:
        return None, None, f'link {link} cannot be read'
    if parts.scheme or parts.netloc:
        return None, None, f'link {link} is neither relative, https nor mailto'
    if link.startswith('/'):
        return None, None, f'link {link} starts at the domain root; links are relative, so the site works under a path'
    if not parts.path:
        return page, parts.fragment, None
    target = posixpath.normpath(posixpath.join(posixpath.dirname(page), parts.path))
    if target == '..' or target.startswith('../'):
        return None, None, f'link {link} leaves the site'
    if parts.path.endswith('/'):
        target = 'index.html' if target == '.' else f'{target}/index.html'
    return target, parts.fragment, None


def check(out, preview):
    """The problems of a built site, as a list of messages."""
    problems = []
    expected = ['index.html', 'style.css'] + [f'{lang}/{path}index.html' for lang in LANGUAGES
                                              for path in PAGES.values()]
    problems += [f'{path} is missing' for path in expected if not os.path.isfile(os.path.join(out, path))]
    scans = {}
    for directory, _, names in os.walk(out):
        for name in names:
            path = posixpath.relpath(os.path.join(directory, name).replace(os.sep, '/'), out.replace(os.sep, '/'))
            if name.endswith('.html'):
                scan = PageScan()
                with open(os.path.join(directory, name), encoding='utf-8') as f:
                    scan.feed(f.read())
                scan.close()
                scans[path] = scan
    stylesheet = os.path.join(out, 'style.css')
    if os.path.isfile(stylesheet):
        with open(stylesheet, encoding='utf-8') as f:
            css = f.read()
        if 'url(' in css or '@import' in css:
            problems.append('style.css: loads a resource; the site loads nothing but its pages and this file')
    for path, scan in sorted(scans.items()):
        lang = path.split('/')[0] if path.split('/')[0] in LANGUAGES else 'en'
        if scan.lang != lang:
            problems.append(f'{path}: <html lang="{scan.lang}">, expected "{lang}"')
        if scan.h1 != 1:
            problems.append(f'{path}: {scan.h1} <h1> headings, expected one')
        if not scan.title.strip():
            problems.append(f'{path}: no <title>')
        problems += [f'{path}: <{tag}> is not allowed' for tag in sorted(set(scan.forbidden))]
        if len(set(scan.ids)) != len(scan.ids):
            problems.append(f'{path}: an id appears twice')
        if scan.placeholders and not preview:
            problems.append(f'{path}: {scan.placeholders} placeholder(s) for missing values')
        for tag, name, value in scan.resources:
            if (tag, name) != ('link', 'href') or resolve(path, value)[0] != 'style.css':
                problems.append(f'{path}: <{tag} {name}="{value}">: the pages load nothing but style.css')
        targets = set()
        for link, _ in scan.links:
            if (link.startswith('https://') and not https_url_problem(link, base=False)
                    or link.startswith('mailto:') and EMAIL.fullmatch(link[len('mailto:'):])):
                continue
            target, fragment, problem = resolve(path, link)
            if problem:
                problems.append(f'{path}: {problem}')
            elif target not in scans and not os.path.isfile(os.path.join(out, target)):
                problems.append(f'{path}: link {link} leads nowhere'
                                + (' (a folder needs a trailing slash)' if os.path.isdir(os.path.join(out, target))
                                   else ''))
            elif fragment and fragment not in scans.get(target, PageScan()).ids:
                problems.append(f'{path}: link {link} names an anchor that {target} lacks')
            else:
                targets.add(target)
        if path != 'index.html':
            other = next(language for language in LANGUAGES if language != lang)
            counterpart = other + path[len(lang):]
            if not any(hreflang == other and resolve(path, link)[0] == counterpart for link, hreflang in scan.links):
                problems.append(f'{path}: no link with hreflang="{other}" to {counterpart}')
            for required in ('privacy', 'legal'):
                if f'{lang}/{PAGES[required]}index.html' not in targets:
                    problems.append(f'{path}: no link to {lang}/{PAGES[required]}')
            if counterpart in scans and sorted(scans[counterpart].ids) != sorted(scan.ids):
                problems.append(f'{path} and {counterpart}: the anchors differ '
                                f'({sorted(set(scan.ids) ^ set(scans[counterpart].ids))})')
    return problems


def run(source, out, preview, check_only):
    """Builds and checks the site; returns the names of the values shown as placeholders."""
    values = read_json(os.path.join(source, 'site.json'))
    missing = missing_values(values)
    links = checked_links(read_json(os.path.join(source, 'links.json')))
    if missing and not preview:
        raise SiteError(refusal(missing))
    files = render_site(source, values, links, preview)
    with tempfile.TemporaryDirectory() as scratch:
        target = os.path.join(scratch, 'public') if check_only else out
        write_files(target, files)
        problems = check(target, preview)
    if problems:
        raise SiteError('the built site has problems:\n  ' + '\n  '.join(problems))
    return missing


def main(argv=None):
    parser = argparse.ArgumentParser(description='Builds the website from site/ (D76).')
    parser.add_argument('--out', help='the folder to build into (default: public/, or build/site-preview/ with '
                                      '--preview); it must be empty or hold an earlier build')
    parser.add_argument('--preview', action='store_true',
                        help='build with marked placeholders for the values site.json lacks')
    parser.add_argument('--check', action='store_true',
                        help='build into a temporary folder and check it; nothing is kept')
    args = parser.parse_args(argv)
    if args.check and args.out:
        parser.error('--check keeps nothing, so --out has no use with it')
    out = os.path.abspath(args.out or (PREVIEW_OUT if args.preview else DEFAULT_OUT))
    try:
        missing = run(SOURCE, out, args.preview, args.check)
    except SiteError as error:
        print(f'error: {error}', file=sys.stderr)
        return 1
    where = 'checked' if args.check else f'built into {relative(out)}'
    note = f'; placeholders for {", ".join(missing)}' if missing else ''
    print(f'site: {len(LANGUAGES) * len(PAGES)} pages in {" and ".join(LANGUAGES)} {where}{note}.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
