"use client";

import axios from "axios";
import {
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";

import { api } from "@/lib/api";

interface User {
  id: string;
  uid?: string;
  name?: string | null;
  email?: string | null;
  phoneNumber?: string | null;
  businessName?: string | null;
  role?: string;
  status?: string;
  isActive?: boolean;
  createdAt?: string;
}

type RoleFilter =
  | "ALL"
  | "CUSTOMER"
  | "MERCHANT"
  | "DELIVERY";

const roleFilters: {
  label: string;
  value: RoleFilter;
}[] = [
  { label: "All", value: "ALL" },
  { label: "Customers", value: "CUSTOMER" },
  { label: "Merchants", value: "MERCHANT" },
  { label: "Delivery", value: "DELIVERY" },
];

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [roleFilter, setRoleFilter] =
    useState<RoleFilter>("ALL");

  const [loading, setLoading] = useState(true);
  const [actionUid, setActionUid] =
    useState<string | null>(null);

  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  const loadUsers = useCallback(async () => {
    try {
      setLoading(true);
      setError("");

      const response = await api.get<User[]>(
        "/admin/users/all",
      );

      setUsers(response.data);
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to load users.",
        );
      } else {
        setError("Unable to load users.");
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadUsers();
  }, [loadUsers]);

  const filteredUsers = useMemo(() => {
    return users.filter((user) => {
      const role =
        user.role?.toUpperCase();

      if (role === "ADMIN") {
        return false;
      }

      if (roleFilter === "ALL") {
        return true;
      }

      return role === roleFilter;
    });
  }, [users, roleFilter]);

  const counts = useMemo(() => {
    return {
      customers: users.filter(
        (user) =>
          user.role?.toUpperCase() ===
          "CUSTOMER",
      ).length,

      merchants: users.filter(
        (user) =>
          user.role?.toUpperCase() ===
          "MERCHANT",
      ).length,

      delivery: users.filter(
        (user) =>
          user.role?.toUpperCase() ===
          "DELIVERY",
      ).length,

      suspended: users.filter(
        (user) =>
          user.status?.toUpperCase() ===
          "SUSPENDED",
      ).length,
    };
  }, [users]);

  const handleStatusChange = async (
    user: User,
  ) => {
    const uid = user.uid ?? user.id;

    const currentlyActive =
      user.status?.toUpperCase() ===
        "ACTIVE" &&
      user.isActive === true;

    const nextActive = !currentlyActive;

    const action = nextActive
      ? "reactivate"
      : "suspend";

    const confirmed = window.confirm(
      `${action === "suspend" ? "Suspend" : "Reactivate"} ${
        user.name ?? user.email ?? "this user"
      }?`,
    );

    if (!confirmed) {
      return;
    }

    try {
      setActionUid(uid);
      setError("");
      setMessage("");

      await api.patch(
        `/admin/users/${uid}/status`,
        {
          isActive: nextActive,
        },
      );

      setMessage(
        nextActive
          ? "User reactivated successfully."
          : "User suspended successfully.",
      );

      await loadUsers();
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to update user.",
        );
      } else {
        setError(
          "Unable to update user.",
        );
      }
    } finally {
      setActionUid(null);
    }
  };

  return (
    <main className="p-8">
      <div className="mx-auto max-w-7xl">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">
            Users
          </h1>

          <p className="mt-2 text-gray-500">
            Manage customers, merchants and
            delivery partners
          </p>
        </div>

        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <StatCard
            title="Customers"
            value={counts.customers}
          />

          <StatCard
            title="Merchants"
            value={counts.merchants}
          />

          <StatCard
            title="Delivery Partners"
            value={counts.delivery}
          />

          <StatCard
            title="Suspended"
            value={counts.suspended}
          />
        </div>

        <div className="mt-8 flex flex-wrap gap-2">
          {roleFilters.map((filter) => (
            <button
              key={filter.value}
              onClick={() =>
                setRoleFilter(filter.value)
              }
              className={`rounded-lg px-4 py-2 text-sm font-medium ${
                roleFilter === filter.value
                  ? "bg-gray-900 text-white"
                  : "bg-white text-gray-600 shadow-sm hover:bg-gray-100"
              }`}
            >
              {filter.label}
            </button>
          ))}
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

        <section className="mt-6 overflow-hidden rounded-xl bg-white shadow-sm">
          {loading ? (
            <div className="p-8 text-gray-500">
              Loading users...
            </div>
          ) : filteredUsers.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              No users found.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left">
                <thead className="bg-gray-50 text-sm text-gray-500">
                  <tr>
                    <th className="px-6 py-4">
                      User
                    </th>

                    <th className="px-6 py-4">
                      Role
                    </th>

                    <th className="px-6 py-4">
                      Business
                    </th>

                    <th className="px-6 py-4">
                      Phone
                    </th>

                    <th className="px-6 py-4">
                      Status
                    </th>

                    <th className="px-6 py-4">
                      Joined
                    </th>

                    <th className="px-6 py-4 text-right">
                      Action
                    </th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-gray-100">
                  {filteredUsers.map((user) => {
                    const uid =
                      user.uid ?? user.id;

                    const status =
                      user.status
                        ?.toUpperCase() ??
                      "UNKNOWN";

                    const active =
                      status === "ACTIVE" &&
                      user.isActive === true;

                    const canChange =
                      status === "ACTIVE" ||
                      status === "SUSPENDED";

                    return (
                      <tr key={uid}>
                        <td className="px-6 py-4">
                          <p className="font-medium text-gray-900">
                            {user.name ?? "—"}
                          </p>

                          <p className="mt-1 text-sm text-gray-500">
                            {user.email ?? "—"}
                          </p>
                        </td>

                        <td className="px-6 py-4">
                          <RoleBadge
                            role={
                              user.role ??
                              "UNKNOWN"
                            }
                          />
                        </td>

                        <td className="px-6 py-4 text-gray-600">
                          {user.businessName ??
                            "—"}
                        </td>

                        <td className="px-6 py-4 text-gray-600">
                          {user.phoneNumber ??
                            "—"}
                        </td>

                        <td className="px-6 py-4">
                          <StatusBadge
                            status={status}
                          />
                        </td>

                        <td className="px-6 py-4 text-sm text-gray-500">
                          {formatDate(
                            user.createdAt,
                          )}
                        </td>

                        <td className="px-6 py-4 text-right">
                          {canChange ? (
                            <button
                              disabled={
                                actionUid === uid
                              }
                              onClick={() =>
                                void handleStatusChange(
                                  user,
                                )
                              }
                              className={`rounded-lg px-4 py-2 text-sm font-medium text-white disabled:opacity-50 ${
                                active
                                  ? "bg-red-600 hover:bg-red-700"
                                  : "bg-green-600 hover:bg-green-700"
                              }`}
                            >
                              {actionUid === uid
                                ? "Processing..."
                                : active
                                  ? "Suspend"
                                  : "Reactivate"}
                            </button>
                          ) : (
                            <span className="text-sm text-gray-400">
                              Use Approvals
                            </span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </section>
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

function RoleBadge({
  role,
}: {
  role: string;
}) {
  return (
    <span className="inline-flex rounded-full bg-blue-50 px-3 py-1 text-xs font-medium text-blue-700">
      {role}
    </span>
  );
}

function StatusBadge({
  status,
}: {
  status: string;
}) {
  const style =
    status === "ACTIVE"
      ? "bg-green-50 text-green-700"
      : status === "SUSPENDED"
        ? "bg-red-50 text-red-700"
        : status === "PENDING"
          ? "bg-yellow-50 text-yellow-700"
          : "bg-gray-100 text-gray-600";

  return (
    <span
      className={`inline-flex rounded-full px-3 py-1 text-xs font-medium ${style}`}
    >
      {status}
    </span>
  );
}

function formatDate(value?: string) {
  if (!value) {
    return "—";
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString();
}