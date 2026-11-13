import {readFileSync} from 'node:fs'
import {dirname, join} from 'node:path'
import {fileURLToPath} from 'node:url'
import {JSDOM} from 'jsdom'

const here = dirname(fileURLToPath(import.meta.url))

export const oracle = JSON.parse(
  readFileSync(join(here, '..', '..', '..', 'packages', 'vikunja_logic', 'test', 'fixtures', 'sanitizer_oracle.json'), 'utf8'),
)

// The context the oracle was recorded in (fixture meta.context).
export const oracleLinks = {
  taskLinkBases: ['https://vikunja.example.com', 'https://vikunja.example.com/'],
  apiRoot: 'https://vikunja.example.com',
}

// jsdom has no layout: ranges have no rectangles and no point hits.
function withoutLayout(window) {
  window.Range.prototype.getClientRects = () => []
  window.Range.prototype.getBoundingClientRect = () => new window.DOMRect(0, 0, 0, 0)
  window.document.elementFromPoint = () => null
}

// The fixture marks ids the web generated as {{generated}}; ours are random
// too.
export function normaliseGeneratedIds(input, html) {
  const known = new Set([...input.matchAll(/data-task-id="([^"]*)"/g)].map(match => match[1]).filter(Boolean))
  return html.replace(/data-task-id="([^"]*)"/g, (all, id) => (known.has(id) ? all : 'data-task-id="{{generated}}"'))
}

export const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms))

// The built page in jsdom with a fake app channel.
export function loadPage(html) {
  const posted = []
  const dom = new JSDOM(html, {
    runScripts: 'dangerously',
    pretendToBeVisual: true,
    url: 'file:///android_asset/flutter_assets/assets/editor/editor.html',
    beforeParse(window) {
      window.VikunjaEditor = {postMessage: text => posted.push(JSON.parse(text))}
      withoutLayout(window)
    },
  })
  return {window: dom.window, posted, receive: message => dom.window.vikunja.receive(message)}
}

// The bridge from the sources against a jsdom document, for tests that
// need to reach into the editor. Call once per test file, before anything
// imports TipTap.
export async function sourceBridge() {
  const dom = new JSDOM('<!doctype html><html><body><div id="editor"></div></body></html>', {
    pretendToBeVisual: true,
    url: 'file:///android_asset/flutter_assets/assets/editor/editor.html',
  })
  const {window} = dom
  withoutLayout(window)
  for (const key of Object.getOwnPropertyNames(window)) {
    if (key in globalThis) continue
    try {
      Object.defineProperty(globalThis, key, {configurable: true, writable: true, value: window[key]})
    } catch {
      // Some window properties cannot be copied; TipTap does not need them.
    }
  }
  globalThis.window = window
  globalThis.document = window.document
  const {createBridge} = await import('../src/bridge.js')
  const posted = []
  const bridge = createBridge({
    mount: window.document.getElementById('editor'),
    root: window.document.documentElement,
    post: text => posted.push(JSON.parse(text)),
  })
  return {window, bridge, posted}
}

export async function waitFor(posted, predicate, timeout = 1000) {
  const started = Date.now()
  for (;;) {
    const found = posted.find(predicate)
    if (found) return found
    if (Date.now() - started > timeout) throw new Error('timed out waiting for a message')
    await tick(5)
  }
}
