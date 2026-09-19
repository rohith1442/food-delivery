import axios from "axios";

import { auth } from "./firebase";

export const api = axios.create({
  baseURL:
    process.env.NEXT_PUBLIC_API_URL ??
    "http://localhost:3000",
});

api.interceptors.request.use(async (config) => {
  if (
    typeof FormData !== "undefined" &&
    config.data instanceof FormData
  ) {
    if (config.headers) {
      if (typeof config.headers.delete === "function") {
        config.headers.delete("Content-Type");
      } else {
        delete config.headers["Content-Type"];
        delete config.headers["content-type"];
      }
    }
  }

  const user = auth.currentUser;

  if (user) {
    const token = await user.getIdToken();

    config.headers.Authorization =
      `Bearer ${token}`;
  }

  return config;
});
