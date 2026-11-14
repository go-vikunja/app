import os
import subprocess
import sys
import unittest

from key_properties import PropertiesError, parse

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'key_properties.py')
VARIABLE = 'TEST_KEY_PROPERTIES'


def run(text=None, name=VARIABLE):
    env = {key: value for key, value in os.environ.items() if key != VARIABLE}
    if text is not None:
        env[VARIABLE] = text
    return subprocess.run([sys.executable, '-I', SCRIPT, name], env=env, capture_output=True)


class ParseTest(unittest.TestCase):
    def test_plain_file(self):
        text = 'storePassword=store\nkeyPassword=key\nkeyAlias=upload\nstoreFile=keystore.jks\n'
        self.assertEqual(parse(text), {'storePassword': 'store', 'keyPassword': 'key', 'keyAlias': 'upload',
                                       'storeFile': 'keystore.jks'})

    def test_separators(self):
        self.assertEqual(parse('a = b'), {'a': 'b'})
        self.assertEqual(parse('a:b'), {'a': 'b'})
        self.assertEqual(parse('a : b'), {'a': 'b'})
        self.assertEqual(parse('a b'), {'a': 'b'})
        self.assertEqual(parse('a\t\fb'), {'a': 'b'})
        self.assertEqual(parse('a==b'), {'a': '=b'})
        self.assertEqual(parse('a = = b'), {'a': '= b'})
        self.assertEqual(parse('a'), {'a': ''})
        self.assertEqual(parse('   a=b'), {'a': 'b'})

    def test_trailing_whitespace_stays(self):
        self.assertEqual(parse('a=b  '), {'a': 'b  '})

    def test_comments_and_blank_lines(self):
        text = '# a comment\n  ! another\n\n   \nkey=value\n#key=other\n'
        self.assertEqual(parse(text), {'key': 'value'})

    def test_comment_does_not_continue(self):
        self.assertEqual(parse('# comment \\\nkey=value'), {'key': 'value'})

    def test_continuations(self):
        self.assertEqual(parse('key=one \\\n    two\\\n\tthree'), {'key': 'one twothree'})
        self.assertEqual(parse('key=a\\\\\nother=b'), {'key': 'a\\', 'other': 'b'})
        self.assertEqual(parse('key=a\\\\\\\n  b'), {'key': 'a\\b'})
        self.assertEqual(parse('key=a\\\n#b'), {'key': 'a#b'})
        self.assertEqual(parse('key=a\\'), {'key': 'a'})

    def test_escapes(self):
        self.assertEqual(parse(r'key=\u0041\u00e9\t\n\r\f\\\q'), {'key': 'A\u00e9\t\n\r\f\\q'})
        self.assertEqual(parse(r'k\=e\:y\ x=v'), {'k=e:y x': 'v'})

    def test_malformed_unicode_escape(self):
        with self.assertRaises(PropertiesError):
            parse(r'key=\u00g1')
        with self.assertRaises(PropertiesError):
            parse(r'key=\u00')

    def test_passwords_with_special_characters(self):
        text = 'storePassword=a=b:c#d!e\\\\f g \nkeyPassword = \\ leading space\n'
        self.assertEqual(parse(text), {'storePassword': 'a=b:c#d!e\\f g ', 'keyPassword': ' leading space'})

    def test_line_ends(self):
        expected = {'a': '1', 'b': '2', 'c': '3 4'}
        self.assertEqual(parse('a=1\r\nb=2\r\nc=3 \\\r\n  4\r\n'), expected)
        self.assertEqual(parse('a=1\rb=2\rc=3 \\\r  4\r'), expected)
        self.assertEqual(parse('a=1\nb=2\r\nc=3 \\\r  4'), expected)

    def test_later_keys_win(self):
        self.assertEqual(parse('a=1\na=2'), {'a': '2'})


class MainTest(unittest.TestCase):
    def test_prints_the_three_values_in_order(self):
        text = ('storeFile=../keystore.jks\r\nkeyPassword=k#y pass\r\nkeyAlias=upload\r\n'
                'storePassword=st=re:pass\\\\\r\n')
        result = run(text)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'st=re:pass\\\0upload\0k#y pass\0')
        self.assertEqual(result.stderr, b'')

    def test_non_ascii_value(self):
        result = run('storePassword=\\u00e9t\u00e9\nkeyAlias=a\nkeyPassword=b\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '\u00e9t\u00e9\0a\0b\0'.encode())

    def test_missing_keys_named_without_values(self):
        result = run('keyPassword=secret-one\nstoreFile=secret-two\nkeyAlias=\n')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b'')
        self.assertEqual(result.stderr, f'error: {VARIABLE} has no storePassword, keyAlias\n'.encode())

    def test_empty_or_unset_variable(self):
        for text in ('', None):
            with self.subTest(text=text):
                result = run(text)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(result.stdout, b'')
                self.assertEqual(result.stderr, f'error: {VARIABLE} is empty\n'.encode())

    def test_malformed_escape_names_no_value(self):
        result = run('storePassword=secret\\u12\nkeyAlias=a\nkeyPassword=b\n')
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(b'secret', result.stderr)
        self.assertEqual(result.stdout, b'')

    def test_nul_in_a_value(self):
        result = run('storePassword=se\\u0000cret\nkeyAlias=a\nkeyPassword=b\n')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stderr, f'error: {VARIABLE}: storePassword contains a NUL character\n'.encode())
        self.assertEqual(result.stdout, b'')

    def test_usage(self):
        result = subprocess.run([sys.executable, '-I', SCRIPT], capture_output=True)
        self.assertEqual(result.returncode, 2)


if __name__ == '__main__':
    unittest.main()
