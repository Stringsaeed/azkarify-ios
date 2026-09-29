const $ = (selector) => document.querySelector(selector);
let docs = new Map();
let originals = new Map();
let language = 'en';
let selected = null;
let saving = false;
const dirty = new Set();

function status(message, error = false) {
  $('#status').textContent = message;
  $('#status').classList.toggle('error', error);
}
function changed(path) {
  if (JSON.stringify(docs.get(path).data) === originals.get(path)) dirty.delete(path);
  else dirty.add(path);
  $('#save').disabled = saving || dirty.size === 0;
  status(dirty.size ? `${dirty.size} file${dirty.size === 1 ? '' : 's'} with unsaved changes` : 'All changes saved');
}
function indexPath() { return `${language}/husn_${language}.json`; }
function categories() { return docs.get(indexPath()).data.items; }
function detail(category) { return docs.get(category.detailUrl.replace(/^\//, '')); }
function element(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
}
function renderList() {
  const query = $('#search').value.trim().toLocaleLowerCase();
  const items = categories().filter(category => `${category.id} ${category.title} ${JSON.stringify(detail(category).data.items.map(item => item.text))}`.toLocaleLowerCase().includes(query));
  const total = categories().reduce((count, category) => count + detail(category).data.items.length, 0);
  $('#summary').textContent = `${items.length} of ${categories().length} categories · ${total} entries`;
  $('#categories').replaceChildren();
  for (const category of items) {
    const button = element('button', category.title);
    button.dir = language === 'ar' ? 'rtl' : 'ltr';
    button.classList.toggle('active', selected === category.id);
    button.setAttribute('aria-current', selected === category.id ? 'page' : 'false');
    button.append(element('small', `#${category.id} · ${detail(category).data.items.length} entries`));
    button.onclick = () => { selected = category.id; renderList(); renderEditor(); window.scrollTo(0, 0); };
    $('#categories').append(button);
  }
  if (!items.length) $('#categories').append(element('p', 'No matching categories.', 'empty'));
}
function textField(label, value, direction, onInput) {
  const wrapper = element('div', undefined, 'field');
  const fieldLabel = element('div', undefined, 'field-label');
  fieldLabel.append(element('span', label));
  const info = element('span');
  fieldLabel.append(info);
  const input = element('textarea');
  input.value = value;
  input.dir = direction;
  input.spellcheck = false;
  input.setAttribute('aria-label', label);
  const stats = () => { info.textContent = `${Array.from(input.value).length} characters · ${input.value.split('\n').length} lines`; };
  stats();
  input.oninput = () => { onInput(input.value); stats(); };
  // A nested label gives each multiline field a native accessible name.
  const accessibleLabel = element('label');
  accessibleLabel.append(fieldLabel, input);
  wrapper.append(accessibleLabel);
  return wrapper;
}
function renderEditor() {
  const category = categories().find(item => item.id === selected);
  const editor = $('#editor');
  editor.replaceChildren();
  if (!category) { editor.append(element('p', 'Choose a category.', 'empty')); return; }
  const doc = detail(category);
  const heading = element('h2', category.title);
  heading.dir = language === 'ar' ? 'rtl' : 'ltr';
  editor.append(heading, element('p', `content/${doc.path}`, 'metadata'), element('p', 'Press Enter to add a line break. Save changes writes directly to the JSON files. Arabic and English collections are edited separately.', 'hint'));
  const title = textField('Category title', category.title, language === 'ar' ? 'rtl' : 'ltr', value => {
    category.title = value; heading.textContent = value; changed(indexPath()); renderList();
  });
  title.classList.add('title-field');
  editor.append(title);
  for (const entry of doc.data.items) {
    const card = $('#entry-template').content.firstElementChild.cloneNode(true);
    card.querySelector('h3').textContent = `Entry #${entry.id}`;
    const repeat = card.querySelector('input');
    repeat.value = entry.repeat;
    repeat.setAttribute('aria-label', `Repeat count for entry ${entry.id}`);
    repeat.oninput = () => { entry.repeat = Number.isInteger(repeat.valueAsNumber) ? repeat.valueAsNumber : null; changed(doc.path); };
    const names = { arabic: 'Arabic text', arabicTranslated: 'Transliteration / reading guide', translated: language === 'en' ? 'English translation' : 'Translation / notes' };
    for (const [key, value] of Object.entries(entry.text)) {
      card.querySelector('.text-fields').append(textField(names[key] || key, value, key === 'arabic' ? 'rtl' : 'auto', text => {
        entry.text[key] = text; changed(doc.path);
      }));
    }
    const audio = card.querySelector('a');
    if (/^https?:\/\//.test(entry.audioUrl)) audio.href = entry.audioUrl;
    else card.querySelector('details').remove();
    editor.append(card);
  }
}
$('#language').onchange = () => { language = $('#language').value; selected = categories()[0]?.id; renderList(); renderEditor(); };
$('#search').oninput = renderList;
window.addEventListener('beforeunload', event => { if (dirty.size) { event.preventDefault(); event.returnValue = ''; } });
$('#save').onclick = async () => {
  const invalid = [...dirty].some(path => docs.get(path).data.items.some(item =>
    'repeat' in item ? !Number.isInteger(item.repeat) || item.repeat < 1 || item.repeat > 2147483647 : !item.title.trim()));
  if (invalid) { status('Use positive whole repeat counts and nonempty category titles.', true); return; }
  saving = true;
  document.body.classList.add('saving');
  $('#save').disabled = true;
  $('#language').disabled = true;
  $('#search').disabled = true;
  // Prevent edits while requests are in flight, including via keyboard focus.
  $('#editor').inert = true;
  $('#categories').inert = true;
  status('Saving…');
  let saved = 0;
  try {
    for (const path of [...dirty]) {
      const doc = docs.get(path);
      const response = await fetch('/api/save', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(doc) });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Save failed.');
      doc.revision = result.revision;
      originals.set(path, JSON.stringify(doc.data));
      dirty.delete(path);
      saved++;
    }
    status(`Saved ${saved} file${saved === 1 ? '' : 's'} to JSON`);
  } catch (error) {
    status(`${saved ? `${saved} files saved. ` : ''}${error.message} ${dirty.size} files remain unsaved.`, true);
  } finally {
    saving = false;
    document.body.classList.remove('saving');
    $('#editor').inert = false;
    $('#categories').inert = false;
    $('#language').disabled = false;
    $('#search').disabled = false;
    $('#save').disabled = dirty.size === 0;
  }
};
async function load() {
  try {
    const response = await fetch('/api/documents');
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || 'Could not load content.');
    docs = new Map(result.documents.map(doc => [doc.path, doc]));
    originals = new Map(result.documents.map(doc => [doc.path, JSON.stringify(doc.data)]));
    selected = categories()[0]?.id;
    renderList(); renderEditor(); status('All changes saved');
  } catch (error) { status(error.message, true); $('#editor').replaceChildren(element('p', 'Could not load the local files. Check the server output, then reload.', 'empty')); }
}
load();
