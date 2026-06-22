(function () {
  const STORAGE_KEY = "aixcam.members";
  const forms = document.querySelectorAll("[data-auth-form]");

  function readMembers() {
    try {
      const members = JSON.parse(window.localStorage.getItem(STORAGE_KEY) || "[]");
      return Array.isArray(members) ? members : [];
    } catch (_error) {
      return [];
    }
  }

  function writeMembers(members) {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(members));
  }

  function normalizeEmail(value) {
    return value.trim().toLowerCase();
  }

  function showStatus(form, type, message) {
    const status = form.querySelector("[data-form-status]");
    if (!status) {
      return;
    }

    status.textContent = message;
    status.className = `form-status is-visible ${type}`;
  }

  function getFormValues(form) {
    const data = new FormData(form);
    return {
      accountType: String(data.get("accountType") || ""),
      email: normalizeEmail(String(data.get("email") || "")),
      name: String(data.get("name") || "").trim(),
      password: String(data.get("password") || "")
    };
  }

  function validateForm(form, values) {
    if (!form.checkValidity()) {
      form.reportValidity();
      return false;
    }

    if (values.password.length < 8) {
      showStatus(form, "error", "Please use a password with at least 8 characters.");
      return false;
    }

    return true;
  }

  function handleSignup(form) {
    const values = getFormValues(form);
    if (!validateForm(form, values)) {
      return;
    }

    const members = readMembers();
    const existingMember = members.find((member) => member.email === values.email);

    if (existingMember) {
      showStatus(
        form,
        "error",
        "That email is already signed up. Please log in with your member account."
      );
      return;
    }

    members.push({
      accountType: values.accountType,
      createdAt: new Date().toISOString(),
      email: values.email,
      name: values.name
    });
    writeMembers(members);
    form.reset();

    showStatus(
      form,
      "success",
      "Your Aixcam account has been created. You can now use the member login page."
    );
  }

  function handleLogin(form) {
    const values = getFormValues(form);
    if (!validateForm(form, values)) {
      return;
    }

    const member = readMembers().find((item) => item.email === values.email);
    if (!member) {
      showStatus(
        form,
        "error",
        "We could not find that member email. Create a new account to join Aixcam."
      );
      return;
    }

    showStatus(form, "success", `Welcome back, ${member.name}. Your member account is ready.`);
  }

  forms.forEach((form) => {
    form.addEventListener("submit", (event) => {
      event.preventDefault();
      const mode = form.getAttribute("data-auth-form");

      if (mode === "signup") {
        handleSignup(form);
        return;
      }

      if (mode === "login") {
        handleLogin(form);
      }
    });
  });
})();
