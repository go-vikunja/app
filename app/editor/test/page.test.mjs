import assert from 'node:assert/strict'
import {createHash} from 'node:crypto'
import {mkdtemp, rm, writeFile} from 'node:fs/promises'
import {tmpdir} from 'node:os'
import {join} from 'node:path'
import {before, describe, test} from 'node:test'
import {JSDOM} from 'jsdom'
import {buildEditor, licenseText} from '../build.mjs'
import {loadPage, waitFor} from './helpers.mjs'

let built

before(async () => {
  built = await buildEditor()
})

describe('the built page', () => {
  test('is one file whose only script is allowed by its hash', () => {
    const {document} = new JSDOM(built.html).window
    const scripts = document.querySelectorAll('script')
    assert.equal(scripts.length, 1)
    assert.equal(scripts[0].hasAttribute('src'), false)
    assert.equal(document.querySelectorAll('link, iframe, img, object, embed').length, 0)

    const csp = document.querySelector('meta[http-equiv="Content-Security-Policy"]').getAttribute('content')
    const hash = createHash('sha256').update(scripts[0].textContent, 'utf8').digest('base64')
    assert.equal(
      csp,
      `default-src 'none'; script-src 'sha256-${hash}'; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'`,
    )
  })

  // The hash is over the UTF-8 text, and the bundle has non-ASCII
  // characters in regular expressions.
  test('declares UTF-8 before anything else', () => {
    assert.ok(built.html.indexOf('<meta charset="utf-8">') < built.html.indexOf('<meta', built.html.indexOf('<meta') + 1))
    assert.ok(built.html.indexOf('<meta charset="utf-8">') < 1024)
  })

  test('announces itself, then answers with the token from init', async () => {
    const page = loadPage(built.html)
    await waitFor(page.posted, message => message.type === 'ready')
    assert.deepEqual(page.posted, [{type: 'ready'}])

    page.receive({type: 'init', token: 'abc', html: '<p>Hello</p>', links: {}})
    page.receive({type: 'getHtml', token: 'abc', requestId: 1})
    const reply = await waitFor(page.posted, message => message.type === 'html')
    assert.deepEqual(reply, {type: 'html', requestId: 1, html: '<p>Hello</p>', dirty: false, token: 'abc'})
  })

  test('window.rurana cannot be replaced by page script', async () => {
    const page = loadPage(built.html)
    await waitFor(page.posted, message => message.type === 'ready')
    const receive = page.window.rurana.receive
    page.window.eval('try { window.rurana = {receive() {}} } catch {}; try { window.rurana.receive = null } catch {}')
    assert.equal(page.window.rurana.receive, receive)
  })

  test('waits for a channel the WebView injects late', async () => {
    const posted = []
    const dom = new JSDOM(built.html, {runScripts: 'dangerously', pretendToBeVisual: true})
    await new Promise(resolve => setTimeout(resolve, 20))
    dom.window.RuranaEditor = {postMessage: text => posted.push(JSON.parse(text))}
    await waitFor(posted, message => message.type === 'ready')
  })

  test('runs where Array#at and Array#findLast are missing (iOS before 15.4)', async () => {
    const posted = []
    const dom = new JSDOM(built.html, {
      runScripts: 'dangerously',
      pretendToBeVisual: true,
      beforeParse(window) {
        delete window.Array.prototype.at
        delete window.Array.prototype.findLast
        window.Range.prototype.getClientRects = () => []
        window.Range.prototype.getBoundingClientRect = () => new window.DOMRect(0, 0, 0, 0)
        window.RuranaEditor = {postMessage: text => posted.push(JSON.parse(text))}
      },
    })
    await waitFor(posted, message => message.type === 'ready')
    const receive = message => dom.window.rurana.receive(message)
    receive({type: 'init', token: 'old', html: '<ul><li><p>a</p></li></ul>', links: {}})
    receive({type: 'command', token: 'old', name: 'horizontalRule'})
    receive({type: 'getHtml', token: 'old', requestId: 1})
    const reply = await waitFor(posted, message => message.type === 'html')
    assert.equal(reply.html, '<ul><li><p>a</p><hr><p></p></li></ul><p></p>')
    assert.equal(posted.some(message => message.type === 'error'), false)
  })

  test('the notices name every bundled package with its licence text', () => {
    for (const name of ['@tiptap/core', '@tiptap/pm', 'prosemirror-model', 'prosemirror-view', 'linkifyjs', '@floating-ui/dom']) {
      assert.match(built.notices, new RegExp(`^- ${name.replace('/', '\\/')} \\d+\\.\\d+\\.\\d+ \\(MIT\\)$`, 'm'))
    }
    assert.match(built.notices, /Permission is hereby granted, free of charge/)
    assert.doesNotMatch(built.notices, /highlight\.js|lowlight|nanoid|marked/)
  })

  test("a licence with a line starting with ``` is refused, because it would end the app's licence text", async () => {
    const dir = await mkdtemp(join(tmpdir(), 'licence-'))
    try {
      await writeFile(join(dir, 'LICENSE.md'), 'MIT License\n\n```\ncode\n```\n')
      await assert.rejects(licenseText(dir, 'fenced'), /fenced's licence file has a line starting with ```/)
      await writeFile(join(dir, 'LICENSE.md'), 'MIT License\n\nInline ``` is fine.\n')
      assert.equal(await licenseText(dir, 'plain'), 'MIT License\n\nInline ``` is fine.')
    } finally {
      await rm(dir, {recursive: true, force: true})
    }
  })
})
