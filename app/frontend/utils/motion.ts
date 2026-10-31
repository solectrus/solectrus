// The curve of a glide, fast at first and then slow to rest, like a sheet on
// iOS. CSS has it as the token --ease-glide (application.css). The Web
// Animations API takes no CSS variable, so a controller takes the curve from
// here.
export const EASE_GLIDE = 'cubic-bezier(0.32, 0.72, 0, 1)';

// A quicker curve for a short move, fast at first and soft at the end
export const EASE_QUICK = 'cubic-bezier(0.2, 0.8, 0.2, 1)';
