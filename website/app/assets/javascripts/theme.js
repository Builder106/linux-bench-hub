(() => {
  const scheme = document.querySelector('meta[name="color-scheme"]');
  const button = document.querySelector(".theme-toggle");
  if (!scheme || !button) return;

  const preference = matchMedia("(prefers-color-scheme: dark)");
  const systemScheme = () => preference.matches ? "dark" : "light";
  const currentScheme = () =>
    scheme.content === "light" || scheme.content === "dark" ? scheme.content : systemScheme();

  function updateThemeColor() {
    const themeColor = document.querySelector('meta[name="theme-color"]');
    if (themeColor) themeColor.content = currentScheme() === "light" ? "#f4f6f8" : "#0a0507";
  }

  function usePreference(value) {
    scheme.content = value === "light" || value === "dark" ? value : "light dark";
    updateThemeColor();
  }

  button.addEventListener("click", () => {
    const next = currentScheme() === "light" ? "dark" : "light";
    const system = systemScheme();
    usePreference(next === system ? "light dark" : next);

    try {
      if (next === system) localStorage.removeItem("color-scheme");
      else localStorage.setItem("color-scheme", next);
    } catch {}
  });

  preference.addEventListener("change", updateThemeColor);
  addEventListener("storage", (event) => {
    if (event.key !== "color-scheme" && event.key !== null) return;
    usePreference(event.newValue);
  });

  updateThemeColor();
})();
