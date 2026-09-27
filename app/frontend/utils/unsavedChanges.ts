// Whether a form inside `root` holds changes that are not saved yet: a field
// whose value differs from the one the page rendered. A field changed and
// then changed back counts as unchanged.
export function hasUnsavedChanges(root: ParentNode): boolean {
  for (const form of root.querySelectorAll('form')) {
    for (const element of form.elements) {
      if (isChanged(element)) return true;
    }
  }
  return false;
}

function isChanged(element: Element): boolean {
  if (element instanceof HTMLInputElement) {
    if (element.type === 'checkbox' || element.type === 'radio')
      return element.checked !== element.defaultChecked;

    return element.value !== element.defaultValue;
  }

  if (element instanceof HTMLTextAreaElement)
    return element.value !== element.defaultValue;

  if (element instanceof HTMLSelectElement) return isSelectChanged(element);

  return false;
}

function isSelectChanged(select: HTMLSelectElement): boolean {
  const options = Array.from(select.options);
  if (options.length === 0) return false;
  if (select.multiple)
    return options.some((option) => option.selected !== option.defaultSelected);

  // Without a preselected option, a single select starts at the first one.
  // With several, the last one wins.
  let initial = 0;
  options.forEach((option, index) => {
    if (option.defaultSelected) initial = index;
  });
  return select.selectedIndex !== initial;
}
