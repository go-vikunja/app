import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import {dirname, join} from 'node:path'
import {before, describe, test} from 'node:test'
import {fileURLToPath} from 'node:url'
import {buildEditor} from '../build.mjs'
import {loadPage, oracleLinks, waitFor} from './helpers.mjs'

// What the app's comment composer sends (commentHtmlFromText in
// vikunja_logic) must be what this editor, the web's schema, writes itself.
const vectors = JSON.parse(
  readFileSync(
    join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', 'packages', 'vikunja_logic', 'test', 'fixtures', 'comment_html_vectors.json'),
    'utf8',
  ),
).vectors

let page
let requestId = 0

async function htmlFor(input) {
  const token = 'comments'
  page.posted.length = 0
  page.receive({type: 'init', token, html: input, readOnly: false, links: oracleLinks})
  const id = ++requestId
  page.receive({type: 'getHtml', token, requestId: id})
  const reply = await waitFor(page.posted, message => message.type === 'html' && message.requestId === id)
  return reply.html
}

before(async () => {
  page = loadPage((await buildEditor()).html)
  await waitFor(page.posted, message => message.type === 'ready')
})

describe("the composer's comment HTML is the editor's own", () => {
  for (const vector of vectors.filter(vector => vector.editorFixedPoint !== false)) {
    test(vector.id, async () => {
      assert.equal(await htmlFor(vector.html), vector.html)
    })
  }
})
