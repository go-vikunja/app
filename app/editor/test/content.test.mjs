import assert from 'node:assert/strict'
import {describe, test} from 'node:test'
import {sourceBridge, waitFor} from './helpers.mjs'

const {bridge, posted} = await sourceBridge()
const token = 't'

async function open(html, links) {
  posted.length = 0
  bridge.receive({type: 'init', token, html, links})
  await waitFor(posted, message => message.type === 'state')
  return bridge.editor
}

function paste(editor, text, {html, files = []} = {}) {
  const data = {'text/plain': text, ...(html === undefined ? {} : {'text/html': html})}
  const event = {
    clipboardData: {getData: type => data[type] ?? '', files, types: Object.keys(data)},
    preventDefault() {},
  }
  if (html === undefined) editor.view.pasteText(text, event)
  else editor.view.pasteHTML(html, event)
}

function nodeTypes(editor) {
  const types = []
  editor.state.doc.descendants(node => {
    types.push(node.type.name)
  })
  return types
}

const server = {taskLinkBases: ['https://vikunja.example.com', 'https://web.example.com/vikunja/'], apiRoot: 'https://vikunja.example.com'}
const pill = href => `<a target="_blank" rel="noopener noreferrer nofollow" href="${href}">${href}</a>`

describe('task links with the bases from init', () => {
  test("a pasted task URL of the server becomes a task link, as the web stores it", async () => {
    const editor = await open('<p>see </p>', server)
    editor.commands.setTextSelection(5)
    paste(editor, 'https://vikunja.example.com/tasks/42')
    assert.ok(nodeTypes(editor).includes('taskLink'))
    assert.equal(editor.getHTML(), `<p>see ${pill('https://vikunja.example.com/tasks/42')}</p>`)
    assert.equal(editor.view.dom.querySelector('.task-link').textContent, 'https://vikunja.example.com/tasks/42')
  })

  test('the frontend base with its sub-path counts, surrounding whitespace is trimmed', async () => {
    const editor = await open('<p></p>', server)
    paste(editor, '  https://web.example.com/vikunja/tasks/7\n')
    assert.equal(editor.getHTML(), `<p>${pill('https://web.example.com/vikunja/tasks/7')}</p>`)
  })

  for (const [name, text] of [
    ['another host', 'https://other.example.com/tasks/42'],
    ['the frontend host without its sub-path', 'https://web.example.com/tasks/42'],
    ['a task sub-page', 'https://vikunja.example.com/tasks/42/edit'],
    ['task 0', 'https://vikunja.example.com/tasks/0'],
    ['text around the URL', 'look https://vikunja.example.com/tasks/42'],
  ]) {
    test(`not for ${name}`, async () => {
      const editor = await open('<p></p>', server)
      paste(editor, text)
      assert.equal(nodeTypes(editor).includes('taskLink'), false)
    })
  }

  test('not without bases, inside code or over a selection', async () => {
    let editor = await open('<p></p>', {taskLinkBases: [], apiRoot: ''})
    paste(editor, 'https://vikunja.example.com/tasks/42')
    assert.equal(nodeTypes(editor).includes('taskLink'), false)

    editor = await open('<pre><code>x</code></pre>', server)
    editor.commands.setTextSelection(2)
    paste(editor, 'https://vikunja.example.com/tasks/42')
    assert.equal(nodeTypes(editor).includes('taskLink'), false)

    editor = await open('<p>word</p>', server)
    editor.commands.setTextSelection({from: 1, to: 5})
    paste(editor, 'https://vikunja.example.com/tasks/42')
    assert.equal(nodeTypes(editor).includes('taskLink'), false)
    assert.equal(
      editor.getHTML(),
      '<p><a target="_blank" rel="noopener noreferrer nofollow" href="https://vikunja.example.com/tasks/42">word</a></p>',
    )
  })

  test('a loaded anchor whose text is its task URL is a task link, relative ones against the first base', async () => {
    const editor = await open(
      '<p><a href="/tasks/5">/tasks/5</a> <a href="https://web.example.com/vikunja/tasks/6">https://web.example.com/vikunja/tasks/6</a></p>',
      server,
    )
    assert.deepEqual(
      nodeTypes(editor).filter(type => type === 'taskLink'),
      ['taskLink', 'taskLink'],
    )
    assert.equal(
      editor.getHTML(),
      '<p><a href="/tasks/5">/tasks/5</a> <a href="https://web.example.com/vikunja/tasks/6">https://web.example.com/vikunja/tasks/6</a></p>',
    )
  })

  test('the same anchor without matching bases is an ordinary link', async () => {
    const editor = await open('<p><a href="/tasks/5">/tasks/5</a></p>', {taskLinkBases: ['https://elsewhere.example.com/app/']})
    assert.equal(editor.getHTML(), '<p><a target="_blank" rel="noopener noreferrer nofollow" href="/tasks/5">/tasks/5</a></p>')
  })

  test('a typed URL becomes a link mark, as on the web', async () => {
    const editor = await open('<p></p>', server)
    paste(editor, 'docs at https://example.com/a and more')
    assert.equal(
      editor.getHTML(),
      '<p>docs at <a target="_blank" rel="noopener noreferrer nofollow" href="https://example.com/a">https://example.com/a</a> and more</p>',
    )
  })
})

describe('images', () => {
  const attachment =
    '<img data-src="https://vikunja.example.com/api/v1/tasks/3/attachments/9" src="#" alt="plan" title="v2" id="tiptap-image-3-9">'
  const external = '<img src="https://images.example.com/cat.png" alt="cat" title="Cat">'

  test('attachment and external images stay byte for byte through an edit', async () => {
    const editor = await open(`<p>before</p>${attachment}${external}<p>after</p>`, server)
    editor.commands.setTextSelection(3)
    editor.commands.insertContent('X')
    assert.equal(editor.getHTML(), `<p>beXfore</p>${attachment}${external}<p>after</p>`)
  })

  test('an attachment URL in src is written the web way', async () => {
    const editor = await open('<img src="https://vikunja.example.com/api/v2/tasks/3/attachments/9">', server)
    assert.equal(
      editor.getHTML(),
      '<img data-src="https://vikunja.example.com/api/v2/tasks/3/attachments/9" src="#" id="tiptap-image-3-9"><p></p>',
    )
  })

  test('the API root may come with a trailing slash or /api/v1', async () => {
    for (const apiRoot of ['https://vikunja.example.com/', 'https://vikunja.example.com/api/v1']) {
      const editor = await open('<img src="https://vikunja.example.com/tasks/3/attachments/9">', {...server, apiRoot})
      assert.match(editor.getHTML(), /id="tiptap-image-3-9"/)
    }
  })

  test('nothing is loaded: the live page shows placeholders, never an img', async () => {
    const editor = await open(`${attachment}${external}`, server)
    assert.equal(editor.view.dom.querySelectorAll('img').length, 0)
    const placeholders = [...editor.view.dom.querySelectorAll('.image-placeholder')]
    assert.deepEqual(
      placeholders.map(element => element.getAttribute('aria-label')),
      ['plan', 'cat'],
    )
  })

  test('a placeholder says it is an image shown after saving, with its alt text if any', async () => {
    posted.length = 0
    bridge.receive({
      type: 'init',
      token,
      html: `${attachment}<img src="https://images.example.com/dog.png">`,
      links: server,
      l10n: {image: 'Image (shown after saving)'},
    })
    await waitFor(posted, message => message.type === 'state')
    const placeholders = [...bridge.editor.view.dom.querySelectorAll('.image-placeholder')]
    assert.deepEqual(
      placeholders.map(element => [element.textContent, element.getAttribute('aria-label')]),
      [
        ['plan', 'plan, Image (shown after saving)'],
        ['Image (shown after saving)', 'Image (shown after saving)'],
      ],
    )
  })

  test('pasted files are swallowed, pasted text is not', async () => {
    const editor = await open('<p>a</p>', server)
    editor.commands.setTextSelection(2)
    const image = {name: 'x.png', type: 'image/png'}
    const event = {clipboardData: {getData: () => '', files: [image], types: ['Files']}, preventDefault() {}}
    editor.view.pasteText('', event)
    assert.equal(editor.getHTML(), '<p>a</p>')
    paste(editor, 'b', {files: [image]})
    assert.equal(editor.getHTML(), '<p>ab</p>')
  })

  test('dropped files are ignored', async () => {
    const editor = await open('<p>a</p>', server)
    const plugin = editor.state.plugins.find(candidate => candidate.key.startsWith('editorEvents'))
    assert.equal(plugin.props.handleDrop(editor.view, {dataTransfer: {files: [{name: 'x.png'}]}}), true)
    assert.equal(plugin.props.handleDrop(editor.view, {dataTransfer: {files: []}}), false)
  })
})

describe('task item ids', () => {
  test('stored ids stay; missing and repeated ones get eight-character ids', async () => {
    const editor = await open(
      '<ul data-type="taskList">' +
        '<li data-checked="true" data-type="taskItem" data-task-id="keep1234"><p>a</p></li>' +
        '<li data-checked="false" data-type="taskItem" data-task-id="keep1234"><p>b</p></li>' +
        '<li data-checked="false" data-type="taskItem"><p>c</p></li>' +
        '</ul>',
      server,
    )
    const ids = [...editor.getHTML().matchAll(/data-task-id="([^"]*)"/g)].map(match => match[1])
    assert.equal(ids[0], 'keep1234')
    assert.equal(new Set(ids).size, 3)
    for (const id of ids) assert.match(id, /^[A-Za-z0-9_-]{8}$/)
  })

  test('a new item from Enter gets its own id', async () => {
    const editor = await open(
      '<ul data-type="taskList"><li data-checked="false" data-type="taskItem" data-task-id="first123"><p>a</p></li></ul>',
      server,
    )
    editor.commands.setTextSelection(4)
    editor.commands.splitListItem('taskItem')
    const ids = [...editor.getHTML().matchAll(/data-task-id="([^"]*)"/g)].map(match => match[1])
    assert.equal(ids.length, 2)
    assert.equal(ids[0], 'first123')
    assert.notEqual(ids[1], 'first123')
  })

  test('a checkbox click while editing toggles the item', async () => {
    const editor = await open(
      '<ul data-type="taskList"><li data-checked="false" data-type="taskItem" data-task-id="click123"><p>a</p></li></ul>',
      server,
    )
    const checkbox = editor.view.dom.querySelector('input[type="checkbox"]')
    checkbox.checked = true
    checkbox.dispatchEvent(new window.Event('change'))
    assert.match(editor.getHTML(), /data-checked="true" data-task-id="click123"/)
  })

  test("checkboxes are named by their item's own text, not in English", async () => {
    const editor = await open(
      '<ul data-type="taskList"><li data-checked="false" data-type="taskItem"><p> Milch </p>' +
        '<ul data-type="taskList"><li data-checked="true" data-type="taskItem"><p></p></li></ul></li></ul>',
      server,
    )
    const labels = [...editor.view.dom.querySelectorAll('input[type="checkbox"]')].map(box =>
      box.getAttribute('aria-label'),
    )
    assert.deepEqual(labels, ['Milch', ' '])
    assert.doesNotMatch(editor.getHTML(), /aria-label|Milch<\/span>/)
  })
})

describe('keys', () => {
  function press(editor, key, modifiers = {}) {
    const event = new window.KeyboardEvent('keydown', {key, bubbles: true, cancelable: true, ...modifiers})
    return editor.view.someProp('handleKeyDown', handler => handler(editor.view, event))
  }

  test('Enter over a selection that starts a block replaces it with a new line', async () => {
    const editor = await open('<p>first</p><p>second</p>', server)
    editor.commands.setTextSelection({from: 1, to: 11})
    assert.equal(press(editor, 'Enter'), true)
    assert.equal(editor.getHTML(), '<p></p><p>ond</p>')
  })

  test('Shift-Enter is a line break, Mod-Enter does nothing', async () => {
    const editor = await open('<p>ab</p>', server)
    editor.commands.setTextSelection(2)
    press(editor, 'Enter', {shiftKey: true})
    assert.equal(editor.getHTML(), '<p>a<br>b</p>')
    press(editor, 'Enter', {ctrlKey: true})
    press(editor, 'Enter', {metaKey: true})
    assert.equal(editor.getHTML(), '<p>a<br>b</p>')
  })
})
