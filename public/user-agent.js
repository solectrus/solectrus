document.addEventListener("DOMContentLoaded", () => {
  document.getElementById("user-agent").textContent = navigator.userAgent;

  setTimeout(() => {
    const el = document.getElementById("skip");
    el.innerHTML =
      '<a href="/skip-browser-check"><button>Hold my beer, let me in!</button></a>';
  }, 2000);
});
