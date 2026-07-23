// The app version, baked in at build time from app.zon (see vite.config.js).
// The `typeof` guard keeps this safe if the define ever doesn't run.
declare const __APP_VERSION__: string;

export const APP_VERSION: string =
  typeof __APP_VERSION__ !== "undefined" ? __APP_VERSION__ : "0.0.0";
