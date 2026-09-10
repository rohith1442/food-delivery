"use client";

import axios from "axios";
import { useCallback, useEffect, useMemo, useState } from "react";

import { api } from "@/lib/api";

interface Store {
  id: string;
  merchantId?: string;
  name?: string;
  moduleId?: string;
  zoneId?: string;
  address?: string;
  minimumOrder?: number;
  isActive?: boolean;
  isOpen?: boolean;
  createdAt?: string;
}

export default function StoresPage() {
  const [stores, setStores] = useState<Store[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionStoreId, setActionStoreId] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [filter, setFilter] = useState<"ALL" | "ACTIVE" | "INACTIVE">("ALL");

  const loadStores = useCallback(async () => {
    try {
      setLoading(true);
      setError("");

      const response = await api.get<Store[]>(
        "/admin/stores",
      );

      setStores(response.data);
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to load stores.",
        );
      } else {
        setError("Unable to load stores.");
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadStores();
  }, [loadStores]);

  const filteredStores = useMemo(() => {
    if (filter === "ACTIVE") {
      return stores.filter(
        (store) => store.isActive === true,
      );
    }

    if (filter === "INACTIVE") {
      return stores.filter(
        (store) => store.isActive !== true,
      );
    }

    return stores;
  }, [stores, filter]);

  const activeStores = stores.filter(
    (store) => store.isActive === true,
  ).length;

  const inactiveStores = stores.length - activeStores;

  const openStores = stores.filter(
    (store) =>
      store.isActive === true &&
      store.isOpen === true,
  ).length;

  const updateStoreStatus = async (
    store: Store,
  ) => {
    const nextStatus = store.isActive !== true;

    const confirmed = window.confirm(
      nextStatus
        ? `Activate ${store.name ?? "this store"}?`
        : `Deactivate ${store.name ?? "this store"}?`,
    );

    if (!confirmed) {
      return;
    }

    try {
      setActionStoreId(store.id);
      setError("");
      setMessage("");

      await api.patch(
        `/admin/stores/${store.id}/status`,
        {
          isActive: nextStatus,
        },
      );

      setMessage(
        nextStatus
          ? "Store activated successfully."
          : "Store deactivated successfully.",
      );

      await loadStores();
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to update store.",
        );
      } else {
        setError("Unable to update store.");
      }
    } finally {
      setActionStoreId(null);
    }
  };

  return (
    <main className="p-8">
      <div className="mx-auto max-w-7xl">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">
            Stores
          </h1>

          <p className="mt-2 text-gray-500">
            Manage merchant stores and platform availability
          </p>
        </div>

        <div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <StatCard
            title="Total Stores"
            value={stores.length}
          />

          <StatCard
            title="Active Stores"
            value={activeStores}
          />

          <StatCard
            title="Inactive Stores"
            value={inactiveStores}
          />

          <StatCard
            title="Currently Open"
            value={openStores}
          />
        </div>

        <div className="mt-8 flex gap-2">
          {[
            {
              label: "All",
              value: "ALL" as const,
            },
            {
              label: "Active",
              value: "ACTIVE" as const,
            },
            {
              label: "Inactive",
              value: "INACTIVE" as const,
            },
          ].map((item) => (
            <button
              key={item.value}
              onClick={() => setFilter(item.value)}
              className={`rounded-lg px-4 py-2 text-sm font-medium ${
                filter === item.value
                  ? "bg-gray-900 text-white"
                  : "bg-white text-gray-600 shadow-sm"
              }`}
            >
              {item.label}
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
              Loading stores...
            </div>
          ) : filteredStores.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              No stores found.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left">
                <thead className="bg-gray-50 text-sm text-gray-500">
                  <tr>
                    <th className="px-6 py-4">
                      Store
                    </th>

                    <th className="px-6 py-4">
                      Module
                    </th>

                    <th className="px-6 py-4">
                      Zone
                    </th>

                    <th className="px-6 py-4">
                      Merchant
                    </th>

                    <th className="px-6 py-4">
                      Min Order
                    </th>

                    <th className="px-6 py-4">
                      Store Status
                    </th>

                    <th className="px-6 py-4">
                      Merchant Status
                    </th>

                    <th className="px-6 py-4 text-right">
                      Action
                    </th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-gray-100">
                  {filteredStores.map((store) => {
                    const actionLoading =
                      actionStoreId === store.id;

                    return (
                      <tr key={store.id}>
                        <td className="px-6 py-4">
                          <p className="font-medium text-gray-900">
                            {store.name ?? "—"}
                          </p>

                          <p className="mt-1 max-w-[220px] truncate text-xs text-gray-500">
                            {store.address ?? store.id}
                          </p>
                        </td>

                        <td className="px-6 py-4 text-gray-600">
                          {store.moduleId ?? "—"}
                        </td>

                        <td className="px-6 py-4 text-gray-600">
                          {store.zoneId ?? "—"}
                        </td>

                        <td className="px-6 py-4">
                          <p className="max-w-[160px] truncate text-gray-600">
                            {store.merchantId ?? "—"}
                          </p>
                        </td>

                        <td className="px-6 py-4 text-gray-600">
                          ₹
                          {(
                            store.minimumOrder ?? 0
                          ).toFixed(2)}
                        </td>

                        <td className="px-6 py-4">
                          <StatusBadge
                            label={
                              store.isActive
                                ? "ACTIVE"
                                : "INACTIVE"
                            }
                            type={
                              store.isActive
                                ? "success"
                                : "danger"
                            }
                          />
                        </td>

                        <td className="px-6 py-4">
                          <StatusBadge
                            label={
                              store.isOpen
                                ? "OPEN"
                                : "CLOSED"
                            }
                            type={
                              store.isOpen
                                ? "success"
                                : "neutral"
                            }
                          />
                        </td>

                        <td className="px-6 py-4 text-right">
                          <button
                            disabled={actionLoading}
                            onClick={() =>
                              void updateStoreStatus(
                                store,
                              )
                            }
                            className={`rounded-lg px-4 py-2 text-sm font-medium text-white disabled:opacity-50 ${
                              store.isActive
                                ? "bg-red-600 hover:bg-red-700"
                                : "bg-green-600 hover:bg-green-700"
                            }`}
                          >
                            {actionLoading
                              ? "Processing..."
                              : store.isActive
                                ? "Deactivate"
                                : "Activate"}
                          </button>
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

function StatusBadge({
  label,
  type,
}: {
  label: string;
  type: "success" | "danger" | "neutral";
}) {
  const style =
    type === "success"
      ? "bg-green-50 text-green-700"
      : type === "danger"
        ? "bg-red-50 text-red-700"
        : "bg-gray-100 text-gray-600";

  return (
    <span
      className={`inline-flex rounded-full px-3 py-1 text-xs font-medium ${style}`}
    >
      {label}
    </span>
  );
}