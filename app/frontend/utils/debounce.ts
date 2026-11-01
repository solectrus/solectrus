// A function that runs `callback` once the calls pause for `delay` ms, with the
// arguments of the last call. `cancel` drops a run that is still pending.
export type Debounced<Args extends unknown[]> = ((...args: Args) => void) & {
  cancel: () => void;
};

export function debounce<Args extends unknown[]>(
  delay: number,
  callback: (...args: Args) => void,
): Debounced<Args> {
  let timeout: ReturnType<typeof setTimeout> | undefined;

  const debounced = (...args: Args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => callback(...args), delay);
  };

  return Object.assign(debounced, { cancel: () => clearTimeout(timeout) });
}
