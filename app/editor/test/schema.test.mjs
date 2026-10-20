import assert from 'node:assert/strict'
import {test} from 'node:test'
import {oracle, sourceBridge} from './helpers.mjs'

await sourceBridge()
const {Editor} = await import('@tiptap/core')
const {createExtensions} = await import('../src/extensions.js')

function describeSchema(schema) {
  const defaults = type =>
    Object.fromEntries(Object.entries(type.spec.attrs ?? {}).map(([name, attr]) => [name, attr.default ?? null]))
  const nodes = {}
  schema.spec.nodes.forEach((name, spec) => {
    const type = schema.nodes[name]
    nodes[name] = {
      group: spec.group ?? null,
      content: spec.content ?? null,
      inline: type.isInline,
      atom: !!spec.atom,
      attrs: defaults(type),
    }
  })
  const marks = {}
  schema.spec.marks.forEach((name, spec) => {
    marks[name] = {attrs: defaults(schema.marks[name]), inclusive: spec.inclusive ?? null}
  })
  return {nodes, marks}
}

test("the schema is the web editor's, in the same order", () => {
  const editor = new Editor({extensions: createExtensions({taskLinkBases: [], apiRoot: ''})})
  const schema = describeSchema(editor.schema)
  editor.destroy()

  assert.deepEqual(Object.keys(schema.nodes), Object.keys(oracle.schema.nodes))
  assert.deepEqual(Object.keys(schema.marks), Object.keys(oracle.schema.marks))
  assert.deepEqual(schema, oracle.schema)
})
