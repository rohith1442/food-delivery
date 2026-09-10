"use client";

import { onAuthStateChanged } from "firebase/auth";
import { useRouter } from "next/navigation";
import {
  ReactNode,
  useEffect,
  useState,
} from "react";

import { api } from "@/lib/api";
import { auth } from "@/lib/firebase";

interface AdminGuardProps {
  children: ReactNode;
}

export default function AdminGuard({
  children,
}: AdminGuardProps) {
  const router = useRouter();
  const [checking, setChecking] = useState(true);
  const [allowed, setAllowed] = useState(false);

  useEffect(() => {
    let active = true;

    const unsubscribe = onAuthStateChanged(
      auth,
      async (firebaseUser) => {
        console.log(
          "Firebase user:",
          firebaseUser?.email,
        );

        if (!firebaseUser) {
          if (active) {
            setAllowed(false);
            setChecking(false);
            router.replace("/");
          }

          return;
        }

        try {
          const response =
            await api.get("/auth/me");

          console.log(
            "/auth/me response:",
            response.data,
          );

          const user = response.data?.user;

          const role = user?.role
            ?.toString()
            .trim()
            .toUpperCase();

          const status = user?.status
            ?.toString()
            .trim()
            .toUpperCase();

          console.log({
            role,
            status,
            isActive: user?.isActive,
          });

          if (
            role !== "ADMIN" ||
            status !== "ACTIVE" ||
            user?.isActive !== true
          ) {
            if (active) {
              setAllowed(false);
              setChecking(false);
              router.replace("/");
            }

            return;
          }

          if (active) {
            console.log(
              "Admin validation successful",
            );

            setAllowed(true);
            setChecking(false);
          }
        } catch (error) {
          console.error(
            "Admin validation failed:",
            error,
          );

          if (active) {
            setAllowed(false);
            setChecking(false);
            router.replace("/");
          }
        }
      },
    );

    return () => {
      active = false;
      unsubscribe();
    };
  }, [router]);

  if (checking) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p>Checking admin session...</p>
      </main>
    );
  }

  if (!allowed) {
    return null;
  }

  return children;
}