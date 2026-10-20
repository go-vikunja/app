// The Vikunja web editor's schema (TipTap 3.31.3): the same extensions in
// the same order with the options that decide the stored HTML, because the
// order of the schema decides how ProseMirror repairs markup. The UI around
// it (suggestion lists, link prompts, toolbar) is native in the app.
import {Extension, Node, mergeAttributes} from '@tiptap/core'
import {Plugin, PluginKey, TextSelection} from '@tiptap/pm/state'
import StarterKit from '@tiptap/starter-kit'
import {Blockquote} from '@tiptap/extension-blockquote'
import {CodeBlock} from '@tiptap/extension-code-block'
import {HardBreak} from '@tiptap/extension-hard-break'
import {Placeholder} from '@tiptap/extensions'
import {Typography} from '@tiptap/extension-typography'
import {Subscript} from '@tiptap/extension-subscript'
import {Superscript} from '@tiptap/extension-superscript'
import {Underline} from '@tiptap/extension-underline'
import {Link} from '@tiptap/extension-link'
import {Table, TableCell, TableHeader, TableRow} from '@tiptap/extension-table'
import {Image} from '@tiptap/extension-image'
import {ListKeymap, TaskItem, TaskList} from '@tiptap/extension-list'
import {Mention} from '@tiptap/extension-mention'
import {parseAttachmentUrl, parseTaskIdFromUrl} from './links.js'

export const linkProtocols = ['ftp', 'git', 'obsidian', 'notion', 'message']
const linkAttributes = {target: '_blank', rel: 'noopener noreferrer nofollow'}
const plainAnchorAttributes = new Set(['href', 'target', 'rel'])

const idAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'

export function newTaskItemId() {
  const bytes = crypto.getRandomValues(new Uint8Array(8))
  let id = ''
  for (const byte of bytes) id += idAlphabet[byte & 63]
  return id
}

// context: {taskLinkBases, apiRoot, placeholder, imageLabel,
// mention: {onStart(props), onUpdate(props), onExit()}}; read when used, so
// that it may change while the editor lives.
export function createExtensions(context) {
  return [
    StarterKit.configure({
      codeBlock: false,
      hardBreak: false,
      blockquote: false,
      listKeymap: false,
      link: false,
      underline: false,
    }),
    ListKeymap,
    EnterReplacesSelection,
    BlockquoteWithCommentId,
    CodeBlock,
    HardBreakOnShiftEnter,
    Placeholder.configure({placeholder: () => context.placeholder ?? ''}),
    Typography,
    Subscript,
    Superscript,
    Underline,
    Link.extend({
      inclusive() {
        return false
      },
    }).configure({
      openOnClick: false,
      protocols: linkProtocols,
      HTMLAttributes: linkAttributes,
    }),
    createTaskLink(context),
    Table.configure({resizable: false}),
    TableRow,
    TableHeader,
    TableCellWithBackground,
    createImage(context),
    TaskList,
    TaskItemWithId.configure({nested: true, onReadOnlyChecked: () => false, a11y: {checkboxLabel}}),
    createMention(context),
    createEditorEvents(),
  ]
}

// splitBlock cannot handle a selection that starts at the start of a block.
const EnterReplacesSelection = Extension.create({
  name: 'enterReplacesSelection',
  priority: 1000,
  addKeyboardShortcuts() {
    return {
      Enter: ({editor}) => {
        const {selection} = editor.state
        if (selection.empty || !(selection instanceof TextSelection)) return false
        if (selection.$from.parentOffset !== 0) return false
        editor.commands.deleteSelection()
        return false
      },
    }
  },
})

const BlockquoteWithCommentId = Blockquote.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      commentId: {
        default: null,
        parseHTML: element => {
          const raw = element.getAttribute('data-comment-id')
          if (raw === null) return null
          const id = Number(raw)
          return Number.isInteger(id) && id > 0 ? id : null
        },
        renderHTML: attributes =>
          attributes.commentId == null ? {} : {'data-comment-id': String(attributes.commentId)},
      },
    }
  },
})

const HardBreakOnShiftEnter = HardBreak.extend({
  addKeyboardShortcuts() {
    return {
      'Shift-Enter': () => this.editor.commands.setHardBreak(),
      'Mod-Enter': () => true,
    }
  },
})

function isInCode(state) {
  const {$from} = state.selection
  if ($from.parent.type.spec.code) return true
  return (state.storedMarks ?? $from.marks()).some(mark => mark.type.name === 'code')
}

function createTaskLink(context) {
  return Node.create({
    name: 'taskLink',
    priority: 200,
    group: 'inline',
    inline: true,
    atom: true,
    selectable: true,
    draggable: false,
    addAttributes() {
      return {
        target: {default: null, parseHTML: element => element.getAttribute('target')},
        rel: {default: null, parseHTML: element => element.getAttribute('rel')},
        href: {default: null, parseHTML: element => element.getAttribute('href')},
      }
    },
    parseHTML() {
      return [
        {
          tag: 'a[href]',
          priority: 100,
          getAttrs: element => {
            const href = element.getAttribute('href') ?? ''
            if (parseTaskIdFromUrl(href, context.taskLinkBases) === null) return false
            if (element.textContent?.trim() !== href) return false
            if (element.children.length > 0) return false
            for (const attribute of element.attributes) {
              if (!plainAnchorAttributes.has(attribute.name)) return false
            }
            return {}
          },
        },
      ]
    },
    renderHTML({node, HTMLAttributes}) {
      return ['a', HTMLAttributes, node.attrs.href]
    },
    renderText({node}) {
      return node.attrs.href
    },
    addNodeView() {
      return ({node}) => {
        const dom = document.createElement('span')
        dom.className = 'task-link'
        dom.textContent = node.attrs.href
        return {dom}
      }
    },
    addProseMirrorPlugins() {
      const type = this.type
      return [
        new Plugin({
          key: new PluginKey('taskLinkPaste'),
          props: {
            handlePaste: (view, event) => {
              const {state} = view
              if (!state.selection.empty || isInCode(state)) return false
              const text = event.clipboardData?.getData('text/plain')?.trim() ?? ''
              if (text === '' || /\s/.test(text)) return false
              if (parseTaskIdFromUrl(text, context.taskLinkBases) === null) return false
              view.dispatch(
                state.tr.replaceSelectionWith(type.create({...linkAttributes, href: text}), false),
              )
              return true
            },
          },
        }),
      ]
    },
  })
}

const TableCellWithBackground = TableCell.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      backgroundColor: {
        default: null,
        parseHTML: element => element.getAttribute('data-background-color'),
        renderHTML: attributes => ({
          'data-background-color': attributes.backgroundColor,
          style: `background-color: ${attributes.backgroundColor}`,
        }),
      },
    }
  },
})

// Images are never loaded here (the page has no session and no network);
// the node keeps its attributes and shows a placeholder that says so.
function createImage(context) {
  return Image.extend({
    addAttributes() {
      return {
        src: {default: null},
        alt: {default: null},
        title: {default: null},
        id: {default: null, parseHTML: () => null},
        'data-src': {default: null},
      }
    },
    renderHTML({HTMLAttributes}) {
      const url = HTMLAttributes['data-src'] ?? HTMLAttributes.src
      const attachment = parseAttachmentUrl(url, context.apiRoot)
      if (attachment === null) {
        return ['img', mergeAttributes(this.options.HTMLAttributes, HTMLAttributes)]
      }
      return [
        'img',
        mergeAttributes(this.options.HTMLAttributes, {
          'data-src': url,
          src: '#',
          alt: HTMLAttributes.alt,
          title: HTMLAttributes.title,
          id: `tiptap-image-${attachment.taskId}-${attachment.attachmentId}`,
        }),
      ]
    },
    addNodeView() {
      return ({node}) => {
        const dom = document.createElement('div')
        dom.className = 'image-placeholder'
        dom.setAttribute('role', 'img')
        const alt = node.attrs.alt == null ? '' : String(node.attrs.alt).trim()
        const label = context.imageLabel ?? ''
        const name = [alt, label].filter(part => part !== '').join(', ')
        if (name !== '') dom.setAttribute('aria-label', name)
        dom.textContent = alt || label
        return {dom}
      }
    },
  })
}

// TipTap's own label is an English sentence. The item's text reads in any
// language, and the screen reader names the role in its own; a blank label
// (an empty item) names nothing rather than falling back to the English.
export function checkboxLabel(node) {
  return node.firstChild?.textContent.trim() || ' '
}

const TaskItemWithId = TaskItem.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      taskId: {
        default: null,
        parseHTML: element => element.getAttribute('data-task-id') || newTaskItemId(),
        renderHTML: attributes => ({'data-task-id': attributes.taskId || newTaskItemId()}),
      },
    }
  },
  addProseMirrorPlugins() {
    const name = this.name
    return [
      ...(this.parent?.() ?? []),
      new Plugin({
        key: new PluginKey('taskItemIds'),
        appendTransaction: (transactions, _, state) => {
          if (!transactions.some(transaction => transaction.docChanged)) return null
          const seen = new Set()
          const reissue = []
          state.doc.descendants((node, pos) => {
            if (node.type.name !== name) return
            const id = node.attrs.taskId
            if (!id || seen.has(id)) reissue.push({node, pos})
            else seen.add(id)
          })
          if (reissue.length === 0) return null
          const tr = state.tr
          for (const {node, pos} of reissue) {
            tr.setNodeMarkup(pos, undefined, {...node.attrs, taskId: newTaskItemId()})
          }
          return tr
        },
      }),
    ]
  },
})

function createMention(context) {
  return Mention.extend({
    parseHTML() {
      return [{tag: 'mention-user'}]
    },
    renderHTML({HTMLAttributes}) {
      return ['mention-user', HTMLAttributes]
    },
    addNodeView() {
      return ({node}) => {
        const dom = document.createElement('span')
        dom.className = 'mention'
        dom.textContent = `@${node.attrs.label || node.attrs.id || ''}`
        return {dom}
      }
    },
  }).configure({
    suggestion: {
      char: '@',
      items: () => [],
      render: () => ({
        onStart: props => context.mention?.onStart(props),
        onUpdate: props => context.mention?.onUpdate(props),
        onExit: () => context.mention?.onExit(),
      }),
    },
  })
}

// Links never navigate while editing: a tap places the cursor, and the
// toolbar edits the link there. Pasted or dropped files are not inserted
// (uploads are not part of this editor).
function createEditorEvents() {
  return Extension.create({
    name: 'editorEvents',
    addProseMirrorPlugins() {
      return [
        new Plugin({
          key: new PluginKey('editorEvents'),
          props: {
            handleClick: (view, _, event) => {
              const anchor = event.target?.closest?.('a[href]')
              if (!anchor || !view.dom.contains(anchor)) return false
              event.preventDefault()
              return false
            },
            handlePaste: (_, event) => {
              const data = event.clipboardData
              if (!data || data.files.length === 0) return false
              return !data.types.some(type => type === 'text/plain' || type === 'text/html')
            },
            handleDrop: (_, event) => (event.dataTransfer?.files.length ?? 0) > 0,
          },
        }),
      ]
    },
  })
}
