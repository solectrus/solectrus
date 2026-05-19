// Lightweight CSS transition helper, ported from the (abandoned) `el-transition`
// package. Toggles Tailwind transition classes declared via `data-transition-*`
// attributes and resolves once the CSS transition has finished.

type Direction = 'enter' | 'leave';

export async function enter(
  element: HTMLElement,
  transitionName: string | null = null,
): Promise<void> {
  element.classList.remove('hidden');
  await transition('enter', element, transitionName);
}

export async function leave(
  element: HTMLElement,
  transitionName: string | null = null,
): Promise<void> {
  await transition('leave', element, transitionName);
  element.classList.add('hidden');
}

export async function toggle(
  element: HTMLElement,
  transitionName: string | null = null,
): Promise<void> {
  if (element.classList.contains('hidden')) {
    await enter(element, transitionName);
  } else {
    await leave(element, transitionName);
  }
}

async function transition(
  direction: Direction,
  element: HTMLElement,
  animation: string | null,
): Promise<void> {
  const { dataset } = element;
  const animationClass = animation ? `${animation}-${direction}` : direction;
  const key = `transition${direction.charAt(0).toUpperCase()}${direction.slice(1)}`;

  const genesis = dataset[key]?.split(' ') ?? [animationClass];
  const start = dataset[`${key}Start`]?.split(' ') ?? [
    `${animationClass}-start`,
  ];
  const end = dataset[`${key}End`]?.split(' ') ?? [`${animationClass}-end`];

  element.classList.add(...genesis, ...start);
  await nextFrame();
  element.classList.remove(...start);
  element.classList.add(...end);
  await afterTransition(element);
  element.classList.remove(...end, ...genesis);
}

function nextFrame(): Promise<void> {
  return new Promise((resolve) => {
    requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
  });
}

function afterTransition(element: HTMLElement): Promise<void> {
  return new Promise((resolve) => {
    // Safari returns a comma-separated list of durations
    const computedDuration =
      getComputedStyle(element).transitionDuration.split(',')[0];
    const duration = Number(computedDuration.replace('s', '')) * 1000;
    setTimeout(resolve, duration);
  });
}
