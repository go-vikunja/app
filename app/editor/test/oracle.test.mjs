import assert from 'node:assert/strict'
import {before, describe, test} from 'node:test'
import {buildEditor} from '../build.mjs'
import {loadPage, normaliseGeneratedIds, oracle, oracleLinks, waitFor} from './helpers.mjs'

let page
let requestId = 0

async function htmlFor(input, links) {
  const token = 'oracle'
  page.posted.length = 0
  page.receive({type: 'init', token, html: input, readOnly: false, links})
  const id = ++requestId
  page.receive({type: 'getHtml', token, requestId: id})
  const reply = await waitFor(page.posted, message => message.type === 'html' && message.requestId === id)
  return reply.html
}

before(async () => {
  page = loadPage((await buildEditor()).html)
  await waitFor(page.posted, message => message.type === 'ready')
})

describe("the web's recorded output for every oracle vector", () => {
  test('there are 123 vectors', () => {
    assert.equal(oracle.vectors.length, 123)
  })

  for (const vector of oracle.vectors) {
    test(vector.id, async () => {
      const html = await htmlFor(vector.input, oracleLinks)
      assert.equal(normaliseGeneratedIds(vector.input, html), vector.html)
    })
  }
})

describe('task link upgrade vectors (frontend on http://localhost:3000)', () => {
  for (const vector of oracle.taskLinkUpgrade) {
    test(vector.id, async () => {
      const html = await htmlFor(vector.input, {taskLinkBases: ['http://localhost:3000'], apiRoot: 'http://localhost:3000'})
      assert.equal(html, vector.html)
    })
  }
})
