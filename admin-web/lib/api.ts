/**
 * lib/api.ts
 * ===========
 * Wrapper cho fetch() với auto-attach JWT token + error handling.
 *
 * Hỗ trợ 2 loại tài khoản:
 *   - adminApp    : AdminUser (web admin / dev team) — quản lý bug reports.
 *   - schoolAdmin : users.role='admin' (admin trường) — quản lý GV/HS/PH/Lịch.
 *
 * Mỗi loại có token + user info lưu ở localStorage key riêng để tránh đụng nhau.
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

// ═══════════════════════════════════════════════════════════════════════════
//  KEY NAMESPACES
// ═══════════════════════════════════════════════════════════════════════════

const NS = {
  schoolAdmin: {
    token: "school_admin_token",
    refresh: "school_admin_refresh",
    sessionId: "school_admin_session_id",
    info: "school_admin_info",
  },
  adminApp: {
    token: "admin_token",
    info: "admin_info",
  },
};

export type AccountKind = "schoolAdmin" | "adminApp";

function currentKind(): AccountKind {
  if (typeof window === "undefined") return "adminApp";
  // Ưu tiên schoolAdmin nếu có token (admin trường đăng nhập gần nhất)
  if (window.localStorage.getItem(NS.schoolAdmin.token)) return "schoolAdmin";
  return "adminApp";
}

function keysFor(kind: AccountKind) {
  return kind === "schoolAdmin" ? NS.schoolAdmin : NS.adminApp;
}

// ═══════════════════════════════════════════════════════════════════════════
//  TOKEN & INFO GETTERS / SETTERS
// ═══════════════════════════════════════════════════════════════════════════

export function getToken(kind?: AccountKind): string | null {
  if (typeof window === "undefined") return null;
  const k = kind ?? currentKind();
  return window.localStorage.getItem(keysFor(k).token);
}

export function setToken(token: string, kind: AccountKind) {
  window.localStorage.setItem(keysFor(kind).token, token);
}

export function getRefreshToken(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(NS.schoolAdmin.refresh);
}

export function setRefreshToken(token: string) {
  window.localStorage.setItem(NS.schoolAdmin.refresh, token);
}

export function getSessionId(): string | null {
  if (typeof window === "undefined") return null;
  const stored = window.localStorage.getItem(NS.schoolAdmin.sessionId);
  if (stored) return stored;
  // Fallback: giải mã từ JWT access token nếu session_id chưa lưu riêng
  const token = getToken("schoolAdmin");
  if (token) {
    try {
      const parts = token.split(".");
      if (parts.length >= 2) {
        const payload = JSON.parse(atob(parts[1]));
        return payload.session_id || null;
      }
    } catch {
      return null;
    }
  }
  return null;
}

export function setSessionId(sid: string) {
  if (typeof window !== "undefined") {
    window.localStorage.setItem(NS.schoolAdmin.sessionId, sid);
  }
}

export function clearAllTokens() {
  window.localStorage.removeItem(NS.schoolAdmin.token);
  window.localStorage.removeItem(NS.schoolAdmin.refresh);
  window.localStorage.removeItem(NS.schoolAdmin.sessionId);
  window.localStorage.removeItem(NS.schoolAdmin.info);
  window.localStorage.removeItem(NS.adminApp.token);
  window.localStorage.removeItem(NS.adminApp.info);
}

export function clearToken(kind?: AccountKind) {
  const k = kind ?? currentKind();
  const ks = keysFor(k);
  window.localStorage.removeItem(ks.token);
  window.localStorage.removeItem(ks.info);
  if (k === "schoolAdmin") {
    window.localStorage.removeItem(NS.schoolAdmin.refresh);
    window.localStorage.removeItem(NS.schoolAdmin.sessionId);
  }
}

// ── User info objects ────────────────────────────────────────────────────

export interface SchoolAdminInfo {
  user_id: string;
  username: string;
  full_name: string;
  role: "admin";
  school_id?: string | null;
  school_name?: string | null;
}

export interface AdminAppInfo {
  admin_user_id: string;
  email: string;
  full_name: string;
  is_super_admin: boolean;
}

export function getStoredSchoolAdmin(): SchoolAdminInfo | null {
  if (typeof window === "undefined") return null;
  const raw = window.localStorage.getItem(NS.schoolAdmin.info);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function setStoredSchoolAdmin(info: SchoolAdminInfo) {
  window.localStorage.setItem(NS.schoolAdmin.info, JSON.stringify(info));
}

export function getStoredAdmin(): AdminAppInfo | null {
  if (typeof window === "undefined") return null;
  const raw = window.localStorage.getItem(NS.adminApp.info);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function setStoredAdmin(admin: AdminAppInfo) {
  window.localStorage.setItem(NS.adminApp.info, JSON.stringify(admin));
}

// ═══════════════════════════════════════════════════════════════════════════
//  FETCH WRAPPER
// ═══════════════════════════════════════════════════════════════════════════

interface RequestOpts {
  method?: "GET" | "POST" | "PATCH" | "DELETE" | "PUT";
  body?: any;
  query?: Record<string, string | number | undefined | null | boolean>;
  auth?: boolean;
  isFormData?: boolean;
  account?: AccountKind;
}

let isRefreshingPromise: Promise<string | null> | null = null;

async function performTokenRefresh(): Promise<string | null> {
  const sid = getSessionId();
  const rf = getRefreshToken();
  if (!sid || !rf) return null;

  try {
    const res = await fetch(`${API_BASE}/api/auth/refresh`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Bypass-Tunnel-Reminder": "true",
      },
      body: JSON.stringify({
        session_id: sid,
        refresh_token: rf,
      }),
    });

    if (!res.ok) {
      return null;
    }

    const data = await res.json();
    if (data.access_token) {
      setToken(data.access_token, "schoolAdmin");
      if (data.refresh_token) {
        setRefreshToken(data.refresh_token);
      }
      if (data.session_id) {
        setSessionId(data.session_id);
      }
      return data.access_token;
    }
    return null;
  } catch {
    return null;
  }
}

export async function apiFetch<T = any>(
  path: string,
  opts: RequestOpts = {},
  isRetry = false,
): Promise<T> {
  const {
    method = "GET",
    body,
    query,
    auth = true,
    isFormData = false,
    account,
  } = opts;

  // URL
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
  const headers: Record<string, string> = {
    "Bypass-Tunnel-Reminder": "true",
  };
  if (!isFormData && body) {
    headers["Content-Type"] = "application/json";
  }
  if (auth) {
    const token = getToken(account);
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
    // Tự động làm mới token nếu 401 khi gọi API có auth
    if (
      res.status === 401 &&
      auth &&
      !isRetry &&
      !path.includes("/login") &&
      !path.includes("/refresh")
    ) {
      if (!isRefreshingPromise) {
        isRefreshingPromise = performTokenRefresh().finally(() => {
          isRefreshingPromise = null;
        });
      }
      const newToken = await isRefreshingPromise;
      if (newToken) {
        // Thử lại request gốc với token mới vừa được cấp
        return apiFetch<T>(path, opts, true);
      }
    }

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
    if (res.status === 401) {
      // KHÔNG xóa token ở đây — component tự quyết định (giữ cho login flow hiển thị lỗi)
    }
    throw new ApiError(res.status, detail);
  }

  if (res.status === 204) return null as T;
  return res.json();
}

// ═══════════════════════════════════════════════════════════════════════════
//  AUTH-SPECIFIC HELPERS
// ═══════════════════════════════════════════════════════════════════════════

export async function schoolAdminLoginRequest(payload: {
  username: string;
  password: string;
}) {
  return apiFetch<{
    access_token: string;
    refresh_token: string;
    session_id: string;
    token_type: string;
    role: string;
    user_id: string;
    username: string;
    full_name: string;
    school_id?: string | null;
    school_name?: string | null;
  }>("/api/school-admin/login", {
    method: "POST",
    body: payload,
    auth: false,
  });
}

export async function adminAppLoginRequest(payload: {
  email: string;
  password: string;
}) {
  return apiFetch<{
    access_token: string;
    admin: AdminAppInfo;
  }>("/api/admin-auth/login", {
    method: "POST",
    body: payload,
    auth: false,
  });
}