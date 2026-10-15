// Dummy declaration for Chart.js Crosshair Plugin
declare module 'chartjs-plugin-crosshair';

// Dummy declaration for Turbo 8
declare module '@hotwired/turbo' {
  export class FrameElement extends HTMLElement {
    src: string | undefined;
    reload(): Promise<void>;
  }

  export type TurboFrameMissingEvent = CustomEvent<{
    response: Response;
  }>;

  export type TurboBeforeFetchResponseEvent = CustomEvent<{
    fetchResponse: { succeeded: boolean; contentType: string | null };
  }>;

  export function visit(url: string, options?): void;

  export const config: {
    forms: {
      confirm?: (
        message: string,
        form: HTMLFormElement,
        submitter?: HTMLElement | null,
      ) => Promise<boolean>;
    };
  };

  export const cache: {
    clear(): void;
  };

  export const session: {
    adapter: unknown;
  };

  export const StreamActions: {
    [key: string]: (this: Element) => void;
  };
}
