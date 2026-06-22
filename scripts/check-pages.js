const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const requiredFiles = [
  "index.html",
  "signup.html",
  "login.html",
  "css/styles.css",
  "scripts/auth.js",
  "assets/app-icon.svg"
];

const failures = [];

function read(relativePath) {
  const filePath = path.join(root, relativePath);
  if (!fs.existsSync(filePath)) {
    failures.push(`Missing required file: ${relativePath}`);
    return "";
  }
  return fs.readFileSync(filePath, "utf8");
}

for (const relativePath of requiredFiles) {
  read(relativePath);
}

const pages = {
  "index.html": read("index.html"),
  "signup.html": read("signup.html"),
  "login.html": read("login.html")
};

for (const [page, html] of Object.entries(pages)) {
  if (!html.includes('href="css/styles.css"')) {
    failures.push(`${page} does not include the shared stylesheet.`);
  }

  if (!html.includes('assets/app-icon.svg')) {
    failures.push(`${page} does not render the app icon asset.`);
  }
}

if (!pages["signup.html"].includes('data-auth-form="signup"')) {
  failures.push("signup.html is missing the sign-up form hook.");
}

if (!pages["login.html"].includes('data-auth-form="login"')) {
  failures.push("login.html is missing the login form hook.");
}

const css = read("css/styles.css");
if (!/\.app-icon\s*\{[\s\S]*aspect-ratio:\s*1/.test(css)) {
  failures.push("The app icon wrapper must enforce a square aspect ratio.");
}

if (!/\.app-icon img\s*\{[\s\S]*object-fit:\s*contain/.test(css)) {
  failures.push("The app icon image must use object-fit: contain.");
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log("Page checks passed.");
