"use client";

import axios from "axios";
import {
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";

import { api } from "@/lib/api";

interface Module {
  id: string;
  name?: string;
  description?: string;
  imageUrl?: string;
  isActive?: boolean;
  sortOrder?: number;
  createdAt?: string;
  updatedAt?: string;
}

export default function ModulesPage() {
  const [modules, setModules] = useState<Module[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionId, setActionId] =
    useState<string | null>(null);

  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  const loadModules = useCallback(async () => {
    try {
      setLoading(true);
      setError("");

      const response =
        await api.get<Module[]>(
          "/admin/modules",
        );

      setModules(response.data);
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to load modules.",
        );
      } else {
        setError("Unable to load modules.");
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadModules();
  }, [loadModules]);

  const counts = useMemo(() => {
    return {
      total: modules.length,
      active: modules.filter(
        (module) =>
          module.isActive === true,
      ).length,
      inactive: modules.filter(
        (module) =>
          module.isActive !== true,
      ).length,
    };
  }, [modules]);

  const handleStatusChange = async (
    module: Module,
  ) => {
    const nextStatus =
      module.isActive !== true;

    const confirmed = window.confirm(
      `${
        nextStatus
          ? "Enable"
          : "Disable"
      } ${module.name ?? module.id}?`,
    );

    if (!confirmed) {
      return;
    }

    try {
      setActionId(module.id);
      setError("");
      setMessage("");

      await api.patch(
        `/admin/modules/${module.id}/status`,
        {
          isActive: nextStatus,
        },
      );

      setMessage(
        nextStatus
          ? "Module enabled successfully."
          : "Module disabled successfully.",
      );

      await loadModules();
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to update module.",
        );
      } else {
        setError(
          "Unable to update module.",
        );
      }
    } finally {
      setActionId(null);
    }
  };

  const updateModuleOrder = async (module: Module) => {
    try {
      setActionId(module.id);
      setError("");

      await api.patch(
        `/admin/modules/${module.id}/order`,
        {
          sortOrder: module.sortOrder ?? 999,
        },
      );

      await loadModules();
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to update module order.",
        );
      }
    } finally {
      setActionId(null);
    }
  };

  return (
    <main className="p-8">
      <div className="mx-auto max-w-7xl">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">
            Modules
          </h1>

          <p className="mt-2 text-gray-500">
            Control which shopping modules are
            available to customers
          </p>
        </div>

        <div className="mt-8 grid gap-4 sm:grid-cols-3">
          <StatCard
            title="Total Modules"
            value={counts.total}
          />

          <StatCard
            title="Active"
            value={counts.active}
          />

          <StatCard
            title="Inactive"
            value={counts.inactive}
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

        <section className="mt-8 overflow-hidden rounded-xl bg-white shadow-sm">
          {loading ? (
            <div className="p-8 text-gray-500">
              Loading modules...
            </div>
          ) : modules.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              No modules found.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left">
                <thead className="bg-gray-50 text-sm text-gray-500">
                  <tr>
                    <th className="px-6 py-4">
                      Module
                    </th>

                    <th className="px-6 py-4">
                      Description
                    </th>

                    <th className="px-6 py-4">
                      Status
                    </th>

                    <th className="px-6 py-4">
                      Order
                    </th>

                    <th className="px-6 py-4 text-right">
                      Action
                    </th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-gray-100">
                  {modules.map((module) => (
                    <tr key={module.id}>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-4">
                          {module.imageUrl && (
                            <img
                              src={
                                module.imageUrl
                              }
                              alt={
                                module.name ??
                                module.id
                              }
                              className="h-12 w-12 rounded-lg object-cover"
                            />
                          )}

                          <div>
                            <p className="font-medium text-gray-900">
                              {module.name ??
                                formatModuleName(
                                  module.id,
                                )}
                            </p>

                            <p className="mt-1 text-xs text-gray-400">
                              {module.id}
                            </p>
                          </div>
                        </div>
                      </td>

                      <td className="px-6 py-4 text-sm text-gray-600">
                        {module.description ??
                          "—"}
                      </td>

                      <td className="px-6 py-4">
                        <StatusBadge
                          active={
                            module.isActive ===
                            true
                          }
                        />
                      </td>

                      <td className="px-6 py-4">
                        <input
                          type="number"
                          min={1}
                          value={module.sortOrder ?? 999}
                          onChange={(event) => {
                            const value = Number(event.target.value);

                            setModules((current) =>
                              current.map((item) =>
                                item.id === module.id
                                  ? {
                                      ...item,
                                      sortOrder: value,
                                    }
                                  : item,
                              ),
                            );
                          }}
                          onBlur={() =>
                            void updateModuleOrder(module)
                          }
                          className="w-20 rounded-lg border border-gray-300 px-3 py-2 text-sm"
                        />
                      </td>

                      <td className="px-6 py-4 text-right">
                        <button
                          disabled={
                            actionId ===
                            module.id
                          }
                          onClick={() =>
                            void handleStatusChange(
                              module,
                            )
                          }
                          className={`rounded-lg px-4 py-2 text-sm font-medium text-white disabled:opacity-50 ${
                            module.isActive
                              ? "bg-red-600 hover:bg-red-700"
                              : "bg-green-600 hover:bg-green-700"
                          }`}
                        >
                          {actionId ===
                          module.id
                            ? "Processing..."
                            : module.isActive
                              ? "Disable"
                              : "Enable"}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>

        <div className="mt-6 rounded-xl bg-blue-50 p-5 text-sm text-blue-800">
          Disabling a module hides it from
          customers and prevents its stores from
          being returned through the customer
          Stores API. Existing stores and orders
          are preserved.
        </div>
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
  active,
}: {
  active: boolean;
}) {
  return (
    <span
      className={`inline-flex rounded-full px-3 py-1 text-xs font-medium ${
        active
          ? "bg-green-50 text-green-700"
          : "bg-red-50 text-red-700"
      }`}
    >
      {active ? "ACTIVE" : "INACTIVE"}
    </span>
  );
}

function formatModuleName(
  moduleId: string,
) {
  return moduleId
    .replaceAll("_", " ")
    .replace(/\b\w/g, (character) =>
      character.toUpperCase(),
    );
}
