// The IntervalTimer class encapsulates setting up an interval
//
// Usage:
//
// const timer = new IntervalTimer(() => console.log('Interval'), 1000);
// timer.start();
// timer.stop();

export class IntervalTimer {
  // Stores the ID of the currently running INTERVAL, used to clear the interval when needed.
  private intervalId?: NodeJS.Timeout;
  // The callback function that will be executed at each interval.
  private callback: () => void;
  // The interval delay in milliseconds.
  private delay: number;

  // Constructor initializes the timer with a callback function and a delay.
  constructor(callback: () => void, delay: number) {
    this.callback = callback;
    this.delay = delay;
  }

  // Starts the timer (when not already running)
  start(): void {
    // Ensure no interval is already running
    this.clearInterVal();

    this.intervalId = setInterval(() => {
      this.run();
    }, this.delay);
  }

  // Clears the currently running interval, if any.
  stop(): void {
    this.clearInterVal();
  }

  // Checks if the timer is currently active.
  isActive(): boolean {
    return this.intervalId !== undefined;
  }

  // Executes the callback function and resets the start time.
  private run(): void {
    this.callback();
  }

  private clearInterVal(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = undefined;
    }
  }
}
