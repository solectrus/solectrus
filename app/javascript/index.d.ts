declare module 'el-transition' {
  function enter(el: HTMLElement, transitionName?: string): Promise<void>;
  function leave(el: HTMLElement, transitionName?: string): Promise<void>;
  function toggle(el: HTMLElement, transitionName?: string): Promise<void>;
}
