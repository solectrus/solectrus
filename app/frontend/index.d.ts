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

  interface StreamActionContext {
    hasAttribute(attributeName: string): boolean;
    templateContent: DocumentFragment;
    templateElement: HTMLTemplateElement;
    targetElements: Element[];
  }

  export function visit(url: string, options?): void;

  export const config: {
    drive: {
      progressBarDelay: number;
    };
  };

  export const StreamActions: {
    [key: string]: (this: Element) => void;
  };
}
