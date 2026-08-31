let accessToken = "";
const out = document.getElementById("output");

async function api(path, options = {}) {
  const response = await fetch(`/backend${path}`, options);
  const text = await response.text();
  let body;
  try { body = JSON.parse(text); } catch { body = text; }
  out.textContent = JSON.stringify({ status: response.status, body }, null, 2);
  return { response, body };
}

document.getElementById("login").onclick = async () => {
  const result = await api("/api/auth/login", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      email: document.getElementById("email").value,
      password: document.getElementById("password").value
    })
  });
  if (result.response.ok) accessToken = result.body.accessToken;
};

document.getElementById("own").onclick = () => api("/api/tenant/tasks", {
  headers: { authorization: `Bearer ${accessToken}`, "x-organization-id": "00000000-0000-0000-0000-00000000000a" }
});

document.getElementById("other").onclick = () => api("/api/tenant/tasks", {
  headers: { authorization: `Bearer ${accessToken}`, "x-organization-id": "00000000-0000-0000-0000-00000000000b" }
});

document.getElementById("health").onclick = () => api("/health/live");

if ("serviceWorker" in navigator) navigator.serviceWorker.register("/sw.js").catch(() => undefined);
