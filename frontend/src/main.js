import { createApp } from "vue";
import App from "./App.vue";
import "./style.css";
import { initTheme } from "./lib/theme.js";

// Apply the saved/system theme before the first paint to avoid a flash.
initTheme();
createApp(App).mount("#app");
