/**
 * lib/api.ts
 * ===========
 * Wrapper cho fetch() với auto-attach JWT token + error handling.
 */

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";

export class ApiError extends Error {
  status: number;
  detail: string;
  constructor(status: number, detail: string) {
    super(detail);
    this.status = status;
    this.detail = detail;
  }
}

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem("admin_token");
}

export function setToken(token: string) {
  window.localStorage.setItem("admin_token", token);
}

export function clearToken() {
  window.localStorage.removeItem("admin_token");
  window.localStorage.removeItem("admin_info");
}

export function getStoredAdmin(): {
  admin_user_id: string;
  email: string;
  full_name: string;
  is_super_admin: boolean;
} | null {
  if (typeof window === "undefined") return null;
  const raw = window.localStorage.getItem("admin_info");
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function setStoredAdmin(admin: object) {
  window.localStorage.setItem("admin_info", JSON.stringify(admin));
}

interface RequestOpts {
  method?: "GET" | "POST" | "PATCH" | "DELETE" | "PUT";
  body?: any;
  query?: Record<string, string | number | undefined | null>;
  auth?: boolean; // mặc định true: gửi kèm JWT
  isFormData?: boolean;
}

export async function apiFetch<T = any>(
  path: string,
  opts: RequestOpts = {},
): Promise<T> {
  const { method = "GET", body, query, auth = true, isFormData = false } = opts;

  // Build URL
  let url = `${API_BASE}${path}`;
  if (query && Object.keys(query).length > 0) {
    const params = new URLSearchParams();
    Object.entries(query).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== "") {
        params.append(k, String(v));
      }
    });
    const qs = params.toString();
    if (qs) url += `?${qs}`;
  }

  // Headers
  const headers: Record<string, string> = {};
  if (!isFormData && body) {
    headers["Content-Type"] = "application/json";
  }
  if (auth) {
    const token = getToken();
    if (token) {
      headers["Authorization"] = `Bearer ${token}`;
    }
  }

  // Body
  let payload: BodyInit | undefined;
  if (body) {
    payload = isFormData ? (body as FormData) : JSON.stringify(body);
  }

  const res = await fetch(url, {
    method,
    headers,
    body: payload,
  });

  if (!res.ok) {
    let detail = `HTTP ${res.status}`;
    try {
      const errJson = await res.json();
      detail = errJson.detail || detail;
    } catch {
      try {
        detail = await res.text();
      } catch {
        /* ignore */
      }
    }
    throw new ApiError(res.status, detail);
  }

  // 204 No Content
  if (res.status === 204) return null as T;

  return res.json();
}
