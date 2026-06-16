const THEMES = [
  { name: "paper", color: "#E5D8C0" },
  { name: "stone", color: "#D3D7DB" },
  { name: "sage", color: "#CCD4BE" },
  { name: "clay", color: "#D9C0A8" },
  { name: "ink", color: "#151515" },
];

async function render() {
  const { currentTheme } = await browser.storage.local.get("currentTheme");
  const container = document.getElementById("themes");
  container.replaceChildren();
  for (const t of THEMES) {
    const btn = document.createElement("button");
    btn.className = "theme" + (t.name === currentTheme ? " active" : "");
    btn.type = "button";

    const swatch = document.createElement("span");
    swatch.className = "swatch";
    swatch.style.background = t.color;

    const name = document.createElement("span");
    name.className = "name";
    name.textContent = t.name;

    btn.append(swatch, name);
    btn.addEventListener("click", async () => {
      await browser.runtime.sendMessage({ type: "setTheme", theme: t.name });
      window.close();
    });
    container.appendChild(btn);
  }
}

render();
browser.storage.onChanged.addListener(render);
