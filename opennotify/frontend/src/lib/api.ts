const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:4000/api/v1";

const ACCESS_KEY = "opennotify.access";
const REFRESH_KEY = "opennotify.refresh";

export const tokens = {
  get access() {
    if (typeof window === "undefined") return null;
    return localStorage.getItem(ACCESS_KEY);
  },
  get refresh() {
    if (typeof window === "undefined") return null;
    return localStorage.getItem(REFRESH_KEY);
  },
  set(pair: { accessToken: string; refreshToken: string }) {
    localStorage.setItem(ACCESS_KEY, pair.accessToken);
    localStorage.setItem(REFRESH_KEY, pair.refreshToken);
  },
  clear() {
    localStorage.removeItem(ACCESS_KEY);
    localStorage.removeItem(REFRESH_KEY);
  },
};

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

async function refreshTokens(): Promise<boolean> {
  const refreshToken = tokens.refresh;
  if (!refreshToken) return false;
  const res = await fetch(`${API_URL}/auth/refresh`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refreshToken }),
  });
  if (!res.ok) {
    tokens.clear();
    return false;
  }
  tokens.set(await res.json());
  return true;
}

export async function api<T>(
  path: string,
  options: { method?: string; body?: unknown; retry?: boolean } = {},
): Promise<T> {
  const { method = "GET", body, retry = true } = options;
  const res = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(tokens.access ? { Authorization: `Bearer ${tokens.access}` } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  if (res.status === 401 && retry && (await refreshTokens())) {
    return api<T>(path, { method, body, retry: false });
  }

  if (!res.ok) {
    let message = res.statusText;
    try {
      const data = await res.json();
      message = Array.isArray(data.message) ? data.message.join(", ") : data.message;
    } catch {
      // keep statusText
    }
    throw new ApiError(res.status, message);
  }

  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}
