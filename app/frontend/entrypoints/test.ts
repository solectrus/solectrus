// Entrypoint for system tests
// This entrypoint will be deleted from production build (see Dockerfile)

import sinon from 'sinon';

// Setup Sinon fake timers immediately
declare global {
  interface Window {
    clock: sinon.SinonFakeTimers;
  }
}

// Get server time from meta tag
const serverTimeElement = document.querySelector('meta[name="server-time"]');
const serverTime = serverTimeElement
  ? parseInt(serverTimeElement.getAttribute('content') || '0') * 1000
  : Date.now();

// Install fake timers immediately, before any other scripts load
window.clock = sinon.useFakeTimers({
  now: serverTime,
  shouldAdvanceTime: true,
});

console.log('Sinon installed', new Date());
