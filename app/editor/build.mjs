// Builds app/assets/editor/editor.html (one self-contained page, its script
// allowed by hash) and NOTICES.md (the licences of every bundled package).
// `--check` builds in memory and fails when the committed files differ.
import {createHash} from 'node:crypto'
import {existsSync} from 'node:fs'
import {mkdir, readdir, readFile, writeFile} from 'node:fs/promises'
import {dirname, join, resolve, sep} from 'node:path'
import {fileURLToPath} from 'node:url'
import {build, transform} from 'esbuild'

const here = dirname(fileURLToPath(import.meta.url))
const outputDir = resolve(here, '..', 'assets', 'editor')

export async function buildEditor() {
  const bundle = await build({
    entryPoints: [join(here, 'src', 'main.js')],
    absWorkingDir: here,
    bundle: true,
    write: false,
    minify: true,
    format: 'iife',
    platform: 'browser',
    target: ['chrome87', 'safari15'],
    legalComments: 'none',
    metafile: true,
    logLevel: 'silent',
  })
  const script = bundle.outputFiles[0].text.trim()
  // Inline script text ends at the first `</script`, and `<!--` can change
  // how the HTML parser reads it.
  if (/<\/script|<!--/i.test(script)) throw new Error('The bundle cannot be inlined into a script element')

  const style = (
    await transform(await readFile(join(here, 'src', 'editor.css'), 'utf8'), {
      loader: 'css',
      minify: true,
      target: ['chrome87', 'safari15'],
    })
  ).code.trim()
  if (/<\/style/i.test(style)) throw new Error('The stylesheet cannot be inlined into a style element')

  const scriptHash = createHash('sha256').update(script, 'utf8').digest('base64')
  const csp = [
    "default-src 'none'",
    `script-src 'sha256-${scriptHash}'`,
    "style-src 'unsafe-inline'",
    'img-src data:',
    "base-uri 'none'",
    "form-action 'none'",
  ].join('; ')

  const template = await readFile(join(here, 'src', 'template.html'), 'utf8')
  const html = template
    .replace('__CSP__', () => csp)
    .replace('__STYLE__', () => style)
    .replace('__SCRIPT__', () => script)

  return {html, script, csp, notices: await notices(bundle.metafile)}
}

async function notices(metafile) {
  const packages = new Map()
  for (const input of Object.keys(metafile.inputs)) {
    const dir = packageDir(input)
    if (dir === null || packages.has(dir)) continue
    const manifest = JSON.parse(await readFile(join(here, dir, 'package.json'), 'utf8'))
    packages.set(dir, {
      name: manifest.name,
      version: manifest.version,
      license: manifest.license,
      text: await licenseText(join(here, dir), manifest.name),
    })
  }
  const byText = new Map()
  for (const entry of [...packages.values()].sort((a, b) => (a.name < b.name ? -1 : 1))) {
    const group = byText.get(entry.text) ?? []
    group.push(entry)
    byText.set(entry.text, group)
  }
  const sections = [...byText.entries()].map(([text, group]) => {
    const names = group.map(({name, version, license}) => `- ${name} ${version} (${license})`).join('\n')
    return `${names}\n\n\`\`\`text\n${text}\n\`\`\``
  })
  return [
    '# Third-party notices',
    '',
    'The editor page (`editor.html`) contains the following packages, built from',
    '`app/editor` by `tool/build_editor.sh`. Generated file, do not edit.',
    '',
    sections.join('\n\n'),
    '',
  ].join('\n')
}

// The package an esbuild input belongs to: the last node_modules segment,
// with its scope.
function packageDir(input) {
  const parts = input.split('/')
  const index = parts.lastIndexOf('node_modules')
  if (index < 0) return null
  const length = parts[index + 1]?.startsWith('@') ? 2 : 1
  return parts.slice(0, index + 1 + length).join('/')
}

export async function licenseText(dir, name) {
  const file = (await readdir(dir)).sort().find(entry => /^licen[cs]e(\.(md|txt))?$/i.test(entry))
  if (file === undefined) throw new Error(`${name} has no licence file`)
  const text = (await readFile(join(dir, file), 'utf8')).replace(/\r\n/g, '\n').trim()
  // The app's licence page ends a licence text at a line starting with ```.
  if (/^```/m.test(text)) throw new Error(`${name}'s licence file has a line starting with \`\`\``)
  return text
}

const outputs = result => ({
  'editor.html': result.html,
  'NOTICES.md': result.notices,
})

async function main() {
  const check = process.argv.includes('--check')
  const files = outputs(await buildEditor())
  if (!check) {
    await mkdir(outputDir, {recursive: true})
    for (const [name, content] of Object.entries(files)) await writeFile(join(outputDir, name), content)
    return
  }
  const stale = []
  for (const [name, content] of Object.entries(files)) {
    const path = join(outputDir, name)
    if (!existsSync(path) || (await readFile(path, 'utf8')) !== content) stale.push(name)
  }
  if (stale.length > 0) {
    console.error(`Stale in app${sep}assets${sep}editor: ${stale.join(', ')}. Run tool/build_editor.sh`)
    process.exit(1)
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main()
