"use client";

import axios from "axios";
import { signOut } from "firebase/auth";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";

import { api } from "@/lib/api";
import { auth } from "@/lib/firebase";

interface PendingUser {
  id: string;
  uid: string;
  email?: string;
  phoneNumber?: string;
  name?: string;
  businessName?: string;
  role: "MERCHANT" | "DELIVERY";
  status: string;
  isActive: boolean;
  createdAt?: string;
}

export default function DashboardPage() {
  const router = useRouter();

  const [users, setUsers] = useState<PendingUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionUid, setActionUid] = useState<string | null>(
    null,
  );
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  const loadPendingUsers = useCallback(async () => {
    try {
      setError("");

      const response = await api.get<PendingUser[]>(
        "/admin/users?status=PENDING",
      );

      setUsers(response.data);
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to load pending users.",
        );
      } else {
        setError("Unable to load pending users.");
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadPendingUsers();
  }, [loadPendingUsers]);

  const handleAction = async (
    uid: string,
    action: "approve" | "reject",
  ) => {
    const confirmed = window.confirm(
      action === "approve"
        ? "Approve this user?"
        : "Reject this user?",
    );

    if (!confirmed) {
      return;
    }

    try {
      setActionUid(uid);
      setError("");
      setMessage("");

      await api.patch(
        `/admin/users/${uid}/${action}`,
      );

      setMessage(
        action === "approve"
          ? "User approved successfully."
          : "User rejected successfully.",
      );

      await loadPendingUsers();
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            `Unable to ${action} user.`,
        );
      } else {
        setError(`Unable to ${action} user.`);
      }
    } finally {
      setActionUid(null);
    }
  };

  const handleLogout = async () => {
    await signOut(auth);
    router.replace("/");
  };

  const merchants = users.filter(
    (user) => user.role === "MERCHANT",
  );

  const deliveryPartners = users.filter(
    (user) => user.role === "DELIVERY",
  );

  return (
    <main className="min-h-screen bg-gray-50 p-8">
      <div className="mx-auto max-w-7xl">
        <header className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">
              Admin Dashboard
            </h1>

            <p className="mt-1 text-gray-500">
              Food Delivery Administration
            </p>
          </div>

          <button
            onClick={handleLogout}
            className="rounded-lg bg-gray-900 px-5 py-2.5 text-sm font-medium text-white"
          >
            Logout
          </button>
        </header>

        <div className="mt-8 grid gap-4 sm:grid-cols-3">
          <StatCard
            title="Pending Approvals"
            value={users.length}
          />

          <StatCard
            title="Pending Merchants"
            value={merchants.length}
          />

          <StatCard
            title="Pending Riders"
            value={deliveryPartners.length}
          />
        </div>

        {error && (
          <div className="mt-6 rounded-lg bg-red-50 p-4 text-sm text-red-700">
            {error}
          </div>
        )}

        {message && (
          <div className="mt-6 rounded-lg bg-green-50 p-4 text-sm text-green-700">
            {message}
          </div>
        )}

        {loading ? (
          <div className="mt-8 rounded-xl bg-white p-8 shadow-sm">
            Loading pending approvals...
          </div>
        ) : (
          <>
            <ApprovalSection
              title="Pending Merchants"
              users={merchants}
              actionUid={actionUid}
              showBusiness
              onAction={handleAction}
            />

            <ApprovalSection
              title="Pending Delivery Partners"
              users={deliveryPartners}
              actionUid={actionUid}
              onAction={handleAction}
            />
          </>
        )}
      </div>
    </main>
  );
}

function StatCard({
  title,
  value,
}: {
  title: string;
  value: number;
}) {
  return (
    <div className="rounded-xl bg-white p-6 shadow-sm">
      <p className="text-sm text-gray-500">
        {title}
      </p>

      <p className="mt-2 text-3xl font-bold text-gray-900">
        {value}
      </p>
    </div>
  );
}

function ApprovalSection({
  title,
  users,
  actionUid,
  showBusiness = false,
  onAction,
}: {
  title: string;
  users: PendingUser[];
  actionUid: string | null;
  showBusiness?: boolean;
  onAction: (
    uid: string,
    action: "approve" | "reject",
  ) => Promise<void>;
}) {
  return (
    <section className="mt-8 overflow-hidden rounded-xl bg-white shadow-sm">
      <div className="border-b border-gray-100 px-6 py-5">
        <h2 className="text-xl font-semibold text-gray-900">
          {title}
        </h2>
      </div>

      {users.length === 0 ? (
        <div className="p-8 text-center text-gray-500">
          No pending approvals.
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead className="bg-gray-50 text-sm text-gray-500">
              <tr>
                <th className="px-6 py-4">
                  Name
                </th>

                {showBusiness && (
                  <th className="px-6 py-4">
                    Business
                  </th>
                )}

                <th className="px-6 py-4">
                  Email
                </th>

                <th className="px-6 py-4">
                  Status
                </th>

                <th className="px-6 py-4 text-right">
                  Actions
                </th>
              </tr>
            </thead>

            <tbody className="divide-y divide-gray-100">
              {users.map((user) => {
                const actionLoading =
                  actionUid === user.uid;

                return (
                  <tr key={user.uid}>
                    <td className="px-6 py-4 font-medium text-gray-900">
                      {user.name || "—"}
                    </td>

                    {showBusiness && (
                      <td className="px-6 py-4 text-gray-600">
                        {user.businessName || "—"}
                      </td>
                    )}

                    <td className="px-6 py-4 text-gray-600">
                      {user.email || "—"}
                    </td>

                    <td className="px-6 py-4">
                      <span className="rounded-full bg-yellow-50 px-3 py-1 text-xs font-medium text-yellow-700">
                        {user.status}
                      </span>
                    </td>

                    <td className="px-6 py-4">
                      <div className="flex justify-end gap-2">
                        <button
                          disabled={actionLoading}
                          onClick={() =>
                            void onAction(
                              user.uid,
                              "approve",
                            )
                          }
                          className="rounded-lg bg-green-600 px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
                        >
                          {actionLoading
                            ? "Processing..."
                            : "Approve"}
                        </button>

                        <button
                          disabled={actionLoading}
                          onClick={() =>
                            void onAction(
                              user.uid,
                              "reject",
                            )
                          }
                          className="rounded-lg bg-red-600 px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
                        >
                          Reject
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}