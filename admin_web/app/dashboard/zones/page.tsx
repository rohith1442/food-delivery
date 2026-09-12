"use client";

import axios from "axios";
import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

import { api } from "@/lib/api";

interface Zone {
  id: string;
  name?: string;
  city?: string;
  state?: string;
  centerLatitude?: number;
  centerLongitude?: number;
  radiusKm?: number;
  isActive?: boolean;
  createdAt?: string;
  updatedAt?: string;
}

type Filter = "ALL" | "ACTIVE" | "INACTIVE";

export default function ZonesPage() {
  const [zones, setZones] = useState<Zone[]>([]);
  const [filter, setFilter] = useState<Filter>("ALL");

  const [name, setName] = useState("");
  const [city, setCity] = useState("");
  const [state, setState] = useState("");
  const [centerLatitude, setCenterLatitude] =
    useState("");
  const [centerLongitude, setCenterLongitude] =
    useState("");
  const [radiusKm, setRadiusKm] =
    useState("");

  const [editingZone, setEditingZone] = useState<Zone | null>(null);

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [actionZoneId, setActionZoneId] = useState<string | null>(null);

  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  const loadZones = useCallback(async () => {
    try {
      setLoading(true);
      setError("");

      const response = await api.get<Zone[]>("/admin/zones");

      setZones(response.data);
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to load zones.",
        );
      } else {
        setError("Unable to load zones.");
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadZones();
  }, [loadZones]);

  const filteredZones = useMemo(() => {
    if (filter === "ACTIVE") {
      return zones.filter((zone) => zone.isActive === true);
    }

    if (filter === "INACTIVE") {
      return zones.filter((zone) => zone.isActive !== true);
    }

    return zones;
  }, [zones, filter]);

  const counts = useMemo(() => {
    return {
      total: zones.length,
      active: zones.filter((zone) => zone.isActive === true).length,
      inactive: zones.filter((zone) => zone.isActive !== true).length,
    };
  }, [zones]);

  const resetForm = () => {
    setName("");
    setCity("");
    setState("");
    setCenterLatitude("");
    setCenterLongitude("");
    setRadiusKm("");
    setEditingZone(null);
  };

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();

    if (!name.trim()) {
      setError("Zone name is required.");
      return;
    }

    try {
      setSaving(true);
      setError("");
      setMessage("");

      const latitude = Number(centerLatitude);
      const longitude = Number(centerLongitude);
      const radius = Number(radiusKm);

      if (
        !Number.isFinite(latitude) ||
        latitude < -90 ||
        latitude > 90
      ) {
        setError(
          "Latitude must be between -90 and 90.",
        );
        return;
      }

      if (
        !Number.isFinite(longitude) ||
        longitude < -180 ||
        longitude > 180
      ) {
        setError(
          "Longitude must be between -180 and 180.",
        );
        return;
      }

      if (
        !Number.isFinite(radius) ||
        radius <= 0
      ) {
        setError(
          "Radius must be greater than 0.",
        );
        return;
      }

      const body = {
        name: name.trim(),
        city: city.trim(),
        state: state.trim(),
        centerLatitude: latitude,
        centerLongitude: longitude,
        radiusKm: radius,
      };

      if (editingZone) {
        await api.patch(
          `/admin/zones/${editingZone.id}`,
          body,
        );

        setMessage("Zone updated successfully.");
      } else {
        await api.post("/admin/zones", body);

        setMessage("Zone created successfully.");
      }

      resetForm();
      await loadZones();
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to save zone.",
        );
      } else {
        setError("Unable to save zone.");
      }
    } finally {
      setSaving(false);
    }
  };

  const handleEdit = (zone: Zone) => {
    setEditingZone(zone);
    setName(zone.name ?? "");
    setCity(zone.city ?? "");
    setState(zone.state ?? "");
    setCenterLatitude(
      zone.centerLatitude?.toString() ?? "",
    );
    setCenterLongitude(
      zone.centerLongitude?.toString() ?? "",
    );
    setRadiusKm(
      zone.radiusKm?.toString() ?? "",
    );
    setError("");
    setMessage("");

    window.scrollTo({
      top: 0,
      behavior: "smooth",
    });
  };

  const handleStatusChange = async (zone: Zone) => {
    const nextStatus = zone.isActive !== true;

    const confirmed = window.confirm(
      `${nextStatus ? "Activate" : "Deactivate"} ${zone.name ?? "this zone"}?`,
    );

    if (!confirmed) {
      return;
    }

    try {
      setActionZoneId(zone.id);
      setError("");
      setMessage("");

      await api.patch(
        `/admin/zones/${zone.id}/status`,
        {
          isActive: nextStatus,
        },
      );

      setMessage(
        nextStatus
          ? "Zone activated successfully."
          : "Zone deactivated successfully.",
      );

      await loadZones();
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to update zone status.",
        );
      } else {
        setError("Unable to update zone status.");
      }
    } finally {
      setActionZoneId(null);
    }
  };

  return (
    <main className="p-8">
      <div className="mx-auto max-w-7xl">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">
            Zones
          </h1>

          <p className="mt-2 text-gray-500">
            Manage serviceable delivery zones
          </p>
        </div>

        <div className="mt-8 grid gap-4 sm:grid-cols-3">
          <StatCard title="Total Zones" value={counts.total} />
          <StatCard title="Active" value={counts.active} />
          <StatCard title="Inactive" value={counts.inactive} />
        </div>

        <section className="mt-8 rounded-xl bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-gray-900">
            {editingZone ? "Edit Zone" : "Add Zone"}
          </h2>

          <form
            onSubmit={handleSubmit}
            className="mt-5 grid gap-4 md:grid-cols-3"
          >
            <input
              value={name}
              onChange={(event) => setName(event.target.value)}
              placeholder="Zone name"
              className="rounded-lg border border-gray-300 px-4 py-3 outline-none focus:border-gray-500"
            />

            <input
              value={city}
              onChange={(event) => setCity(event.target.value)}
              placeholder="City"
              className="rounded-lg border border-gray-300 px-4 py-3 outline-none focus:border-gray-500"
            />

            <input
              value={state}
              onChange={(event) => setState(event.target.value)}
              placeholder="State"
              className="rounded-lg border border-gray-300 px-4 py-3 outline-none focus:border-gray-500"
            />

            <input
              type="number"
              step="any"
              value={centerLatitude}
              onChange={(event) =>
                setCenterLatitude(event.target.value)
              }
              placeholder="Center latitude"
              className="rounded-lg border border-gray-300 px-4 py-3 outline-none focus:border-gray-500"
            />

            <input
              type="number"
              step="any"
              value={centerLongitude}
              onChange={(event) =>
                setCenterLongitude(event.target.value)
              }
              placeholder="Center longitude"
              className="rounded-lg border border-gray-300 px-4 py-3 outline-none focus:border-gray-500"
            />

            <input
              type="number"
              step="any"
              min="0.1"
              value={radiusKm}
              onChange={(event) =>
                setRadiusKm(event.target.value)
              }
              placeholder="Radius (km)"
              className="rounded-lg border border-gray-300 px-4 py-3 outline-none focus:border-gray-500"
            />

            <div className="flex gap-3 md:col-span-3">
              <button
                type="submit"
                disabled={saving}
                className="rounded-lg bg-gray-900 px-5 py-2.5 text-sm font-medium text-white hover:bg-gray-800 disabled:opacity-50"
              >
                {saving
                  ? "Saving..."
                  : editingZone
                    ? "Update Zone"
                    : "Create Zone"}
              </button>

              {editingZone && (
                <button
                  type="button"
                  onClick={resetForm}
                  className="rounded-lg border border-gray-300 px-5 py-2.5 text-sm font-medium text-gray-700"
                >
                  Cancel
                </button>
              )}
            </div>
          </form>
        </section>

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

        <div className="mt-8 flex gap-2">
          {(["ALL", "ACTIVE", "INACTIVE"] as Filter[]).map(
            (value) => (
              <button
                key={value}
                onClick={() => setFilter(value)}
                className={`rounded-lg px-4 py-2 text-sm font-medium ${
                  filter === value
                    ? "bg-gray-900 text-white"
                    : "bg-white text-gray-600 shadow-sm"
                }`}
              >
                {value === "ALL"
                  ? "All"
                  : value === "ACTIVE"
                    ? "Active"
                    : "Inactive"}
              </button>
            ),
          )}
        </div>

        <section className="mt-5 overflow-hidden rounded-xl bg-white shadow-sm">
          {loading ? (
            <div className="p-8 text-gray-500">
              Loading zones...
            </div>
          ) : filteredZones.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              No zones found.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left">
                <thead className="bg-gray-50 text-sm text-gray-500">
                  <tr>
                    <th className="px-6 py-4">Zone</th>
                    <th className="px-6 py-4">City</th>
                    <th className="px-6 py-4">State</th>
                    <th className="px-6 py-4">Status</th>
                    <th className="px-6 py-4 text-right">
                      Actions
                    </th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-gray-100">
                  {filteredZones.map((zone) => (
                    <tr key={zone.id}>
                      <td className="px-6 py-4">
                        <p className="font-medium text-gray-900">
                          {zone.name ?? "—"}
                        </p>

                        <p className="mt-1 text-xs text-gray-400">
                          {zone.id}
                        </p>
                      </td>

                      <td className="px-6 py-4 text-gray-600">
                        {zone.city || "—"}
                      </td>

                      <td className="px-6 py-4 text-gray-600">
                        {zone.state || "—"}
                      </td>

                      <td className="px-6 py-4">
                        <StatusBadge active={zone.isActive === true} />
                      </td>

                      <td className="px-6 py-4">
                        <div className="flex justify-end gap-2">
                          <button
                            onClick={() => handleEdit(zone)}
                            className="rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700"
                          >
                            Edit
                          </button>

                          <button
                            disabled={actionZoneId === zone.id}
                            onClick={() =>
                              void handleStatusChange(zone)
                            }
                            className={`rounded-lg px-3 py-2 text-sm font-medium text-white disabled:opacity-50 ${
                              zone.isActive
                                ? "bg-red-600 hover:bg-red-700"
                                : "bg-green-600 hover:bg-green-700"
                            }`}
                          >
                            {actionZoneId === zone.id
                              ? "Processing..."
                              : zone.isActive
                                ? "Deactivate"
                                : "Activate"}
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
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
      <p className="text-sm text-gray-500">{title}</p>
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
