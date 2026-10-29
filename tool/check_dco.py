#!/usr/bin/env python3
"""Fails when a commit of a merge request is not signed off by its author.

  python3 -I tool/check_dco.py [--repository PATH] BASE HEAD
  python3 -I tool/check_dco.py --self-test

Checks every commit in BASE..HEAD, merge commits included (a merge can carry
changes of its own): its message needs a line "Signed-off-by: Name <email>"
with the commit's author name and email (letter case aside), as
`git commit -s` and `git merge --signoff` write it. That line certifies the
Developer Certificate of Origin in CONTRIBUTING.md. History before BASE is
not checked. The repository is the one this script is in unless --repository
names another, so that CI can run the target branch's copy of the script over
a merge request. --self-test runs the check over commits made in a temporary
repository.
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIGN_OFF = re.compile(r'^signed-off-by:[ \t]*(.*?)[ \t]*<([^<>\n]*)>[ \t]*$', re.IGNORECASE | re.MULTILINE)
FIELDS = 5


def commits(base, head, repository=ROOT):
    output = subprocess.run(
        ['git', 'log', '-z', '--format=%H%x00%P%x00%an%x00%ae%x00%B', '--end-of-options', f'{base}..{head}'],
        cwd=repository, check=True, capture_output=True, text=True).stdout
    fields = output.split('\0')[:-1]
    return [fields[i:i + FIELDS] for i in range(0, len(fields), FIELDS)]


def signed_off_by_author(name, email, message):
    return any(signer.lower() == name.lower() and address.lower() == email.lower()
               for signer, address in SIGN_OFF.findall(message))


def check(base, head, repository=ROOT):
    checked, problems = 0, []
    for sha, _, name, email, message in commits(base, head, repository):
        checked += 1
        if not signed_off_by_author(name, email, message):
            subject = message.split('\n', 1)[0]
            problems.append(f'{sha[:12]} {subject} (no "Signed-off-by: {name} <{email}>")')
    return checked, problems


def self_test():
    ada = ('Ada Lovelace', 'ada@example.org')
    bob = ('Bob Babbage', 'bob@example.org')
    sign_off = lambda person: f'Signed-off-by: {person[0]} <{person[1]}>'
    with tempfile.TemporaryDirectory() as repository:
        def git(*arguments, author=ada):
            environment = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
            environment.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1',
                               GIT_AUTHOR_NAME=author[0], GIT_AUTHOR_EMAIL=author[1],
                               GIT_COMMITTER_NAME='CI', GIT_COMMITTER_EMAIL='ci@example.org')
            return subprocess.run(['git', *arguments], cwd=repository, env=environment, check=True,
                                  capture_output=True, text=True).stdout.strip()

        git('init', '-q')
        tree = git('write-tree')

        def commit(message, parents, author=ada):
            return git('commit-tree', tree, *[a for p in parents for a in ('-p', p)], '-m', message, author=author)

        base = commit('Before the pull request, not signed off', [])
        signed = commit(f'Signed off\n\n{sign_off(ada)}', [base])
        unsigned = commit('Not signed off', [base])
        side = commit(f'Signed off by Bob\n\n{sign_off(bob)}', [base], author=bob)
        cases = [
            ('nothing new', base, True),
            ('signed off by the author', signed, True),
            ('the sign-off in other letter case', commit('Case\n\nsigned-off-by: ada lovelace <ADA@Example.org>', [base]),
             True),
            ('the author after a forwarder', commit(f'Forwarded\n\n{sign_off(bob)}\n{sign_off(ada)}', [base]), True),
            ('several commits, all signed off', commit(f'Second\n\n{sign_off(ada)}', [signed]), True),
            ('a signed-off merge of signed-off commits', commit(f'Merge\n\n{sign_off(ada)}', [signed, side]), True),
            ('an unsigned merge of signed-off commits', commit('Merge', [signed, side]), False),
            ('not signed off', unsigned, False),
            ('signed off by someone else', commit(f'Other\n\n{sign_off(bob)}', [base]), False),
            ('signed off with another email', commit('Email\n\nSigned-off-by: Ada Lovelace <ada@example.com>', [base]),
             False),
            ('the sign-off inside a line', commit(f'Inline\n\nSee {sign_off(ada)}', [base]), False),
            ('an empty sign-off', commit('Empty\n\nSigned-off-by:', [base]), False),
            ('one commit not signed off among signed-off ones',
             commit(f'Third\n\n{sign_off(ada)}', [commit(f'Second\n\n{sign_off(ada)}', [unsigned])]), False),
            ('an unsigned commit brought in by a merge', commit('Merge', [signed, unsigned]), False),
        ]
        failed = 0
        for description, head, passes in cases:
            _, problems = check(base, head, repository)
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
    if arguments == ['--self-test']:
        return self_test()
    repository = ROOT
    if len(arguments) == 4 and arguments[0] == '--repository':
        repository, arguments = arguments[1], arguments[2:]
    if len(arguments) != 2:
        print(__doc__)
        return 2
    base, head = arguments
    try:
        checked, problems = check(base, head, repository)
    except subprocess.CalledProcessError as error:
        print(f'git log {base}..{head} failed: {error.stderr.strip()}')
        return 2
    if problems:
        print('Commits without a Signed-off-by line of their author:')
        for problem in problems:
            print(f'  {problem}')
        print('Sign off with `git commit -s`, and merges with `git merge --signoff`. To sign off the commits\n'
              f'of a merge request, run `git rebase --signoff {base[:12]}` (it also replaces merges by\n'
              'rebased commits) and push with --force-with-lease. CONTRIBUTING.md has the Developer\n'
              'Certificate of Origin that the sign-off certifies.')
        return 1
    print(f'Commits signed off by their authors: {checked}.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
