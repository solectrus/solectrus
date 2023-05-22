const preventClick = (event: Event) => event.preventDefault();
document.addEventListener('contextmenu', preventClick);
