"use client";

import axios from "axios";
import {
  FormEvent,
  useCallback,
  useEffect,
  useState,
} from "react";

import { api } from "@/lib/api";

interface Settings {
  deliveryFee: number;
  minimumOrder: number;
  maintenanceMode: boolean;

  customerMinVersion: string;
  customerForceUpdate: boolean;

  merchantMinVersion: string;
  merchantForceUpdate: boolean;

  deliveryMinVersion: string;
  deliveryForceUpdate: boolean;

  updatedAt?: string;
}

const defaultSettings: Settings = {
  deliveryFee: 40,
  minimumOrder: 0,
  maintenanceMode: false,

  customerMinVersion: "1.0.0",
  customerForceUpdate: false,

  merchantMinVersion: "1.0.0",
  merchantForceUpdate: false,

  deliveryMinVersion: "1.0.0",
  deliveryForceUpdate: false,
};

export default function SettingsPage() {
  const [settings, setSettings] =
    useState<Settings>(defaultSettings);

  const [loading, setLoading] =
    useState(true);

  const [saving, setSaving] =
    useState(false);

  const [error, setError] =
    useState("");

  const [message, setMessage] =
    useState("");

  const loadSettings = useCallback(async () => {
    try {
      setLoading(true);
      setError("");

      const response =
        await api.get<Settings>(
          "/admin/settings",
        );

      setSettings({
        ...defaultSettings,
        ...response.data,
      });
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to load settings.",
        );
      } else {
        setError(
          "Unable to load settings.",
        );
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadSettings();
  }, [loadSettings]);

  const updateField = <K extends keyof Settings>(
    field: K,
    value: Settings[K],
  ) => {
    setSettings((current) => ({
      ...current,
      [field]: value,
    }));
  };

  const handleSubmit = async (
    event: FormEvent,
  ) => {
    event.preventDefault();

    try {
      setSaving(true);
      setError("");
      setMessage("");

      const payload = {
        deliveryFee:
          Number(settings.deliveryFee),

        minimumOrder:
          Number(settings.minimumOrder),

        maintenanceMode:
          settings.maintenanceMode,

        customerMinVersion:
          settings.customerMinVersion.trim(),

        customerForceUpdate:
          settings.customerForceUpdate,

        merchantMinVersion:
          settings.merchantMinVersion.trim(),

        merchantForceUpdate:
          settings.merchantForceUpdate,

        deliveryMinVersion:
          settings.deliveryMinVersion.trim(),

        deliveryForceUpdate:
          settings.deliveryForceUpdate,
      };

      await api.patch(
        "/admin/settings",
        payload,
      );

      setMessage(
        "Settings updated successfully.",
      );

      await loadSettings();
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to update settings.",
        );
      } else {
        setError(
          "Unable to update settings.",
        );
      }
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <main className="p-8">
        <p className="text-gray-500">
          Loading settings...
        </p>
      </main>
    );
  }

  return (
    <main className="p-8">
      <div className="mx-auto max-w-5xl">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">
            Settings
          </h1>

          <p className="mt-2 text-gray-500">
            Manage global platform configuration
          </p>
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

        <form
          onSubmit={handleSubmit}
          className="mt-8 space-y-6"
        >
          <section className="rounded-xl bg-white p-6 shadow-sm">
            <h2 className="text-lg font-semibold text-gray-900">
              Order Configuration
            </h2>

            <p className="mt-1 text-sm text-gray-500">
              Backend-controlled pricing and
              platform order defaults.
            </p>

            <div className="mt-6 grid gap-5 md:grid-cols-2">
              <NumberField
                label="Delivery Fee"
                prefix="₹"
                value={settings.deliveryFee}
                onChange={(value) =>
                  updateField(
                    "deliveryFee",
                    value,
                  )
                }
              />

              <NumberField
                label="Default Minimum Order"
                prefix="₹"
                value={settings.minimumOrder}
                onChange={(value) =>
                  updateField(
                    "minimumOrder",
                    value,
                  )
                }
              />
            </div>

            <p className="mt-4 text-xs text-gray-500">
              Store-specific minimum order values
              currently take precedence during
              checkout.
            </p>
          </section>

          <section className="rounded-xl bg-white p-6 shadow-sm">
            <h2 className="text-lg font-semibold text-gray-900">
              Platform
            </h2>

            <div className="mt-5">
              <ToggleField
                label="Maintenance Mode"
                description="Temporarily mark the platform as under maintenance."
                checked={
                  settings.maintenanceMode
                }
                onChange={(value) =>
                  updateField(
                    "maintenanceMode",
                    value,
                  )
                }
              />
            </div>
          </section>

          <AppSettingsCard
            title="Customer App"
            version={
              settings.customerMinVersion
            }
            forceUpdate={
              settings.customerForceUpdate
            }
            onVersionChange={(value) =>
              updateField(
                "customerMinVersion",
                value,
              )
            }
            onForceUpdateChange={(value) =>
              updateField(
                "customerForceUpdate",
                value,
              )
            }
          />

          <AppSettingsCard
            title="Merchant App"
            version={
              settings.merchantMinVersion
            }
            forceUpdate={
              settings.merchantForceUpdate
            }
            onVersionChange={(value) =>
              updateField(
                "merchantMinVersion",
                value,
              )
            }
            onForceUpdateChange={(value) =>
              updateField(
                "merchantForceUpdate",
                value,
              )
            }
          />

          <AppSettingsCard
            title="Delivery App"
            version={
              settings.deliveryMinVersion
            }
            forceUpdate={
              settings.deliveryForceUpdate
            }
            onVersionChange={(value) =>
              updateField(
                "deliveryMinVersion",
                value,
              )
            }
            onForceUpdateChange={(value) =>
              updateField(
                "deliveryForceUpdate",
                value,
              )
            }
          />

          {settings.updatedAt && (
            <p className="text-sm text-gray-500">
              Last updated:{" "}
              {formatDate(
                settings.updatedAt,
              )}
            </p>
          )}

          <div className="flex justify-end">
            <button
              type="submit"
              disabled={saving}
              className="rounded-lg bg-gray-900 px-6 py-3 text-sm font-medium text-white hover:bg-gray-800 disabled:opacity-50"
            >
              {saving
                ? "Saving..."
                : "Save Settings"}
            </button>
          </div>
        </form>
      </div>
    </main>
  );
}

function NumberField({
  label,
  prefix,
  value,
  onChange,
}: {
  label: string;
  prefix?: string;
  value: number;
  onChange: (value: number) => void;
}) {
  return (
    <label>
      <span className="text-sm font-medium text-gray-700">
        {label}
      </span>

      <div className="mt-2 flex rounded-lg border border-gray-300">
        {prefix && (
          <span className="flex items-center border-r border-gray-300 px-4 text-gray-500">
            {prefix}
          </span>
        )}

        <input
          type="number"
          min="0"
          step="0.01"
          value={value}
          onChange={(event) =>
            onChange(
              Number(event.target.value),
            )
          }
          className="w-full rounded-r-lg px-4 py-3 outline-none"
        />
      </div>
    </label>
  );
}

function ToggleField({
  label,
  description,
  checked,
  onChange,
}: {
  label: string;
  description: string;
  checked: boolean;
  onChange: (value: boolean) => void;
}) {
  return (
    <div className="flex items-center justify-between gap-6">
      <div>
        <p className="font-medium text-gray-900">
          {label}
        </p>

        <p className="mt-1 text-sm text-gray-500">
          {description}
        </p>
      </div>

      <button
        type="button"
        role="switch"
        aria-checked={checked}
        onClick={() =>
          onChange(!checked)
        }
        className={`relative h-7 w-12 rounded-full transition ${
          checked
            ? "bg-green-600"
            : "bg-gray-300"
        }`}
      >
        <span
          className={`absolute top-1 h-5 w-5 rounded-full bg-white transition ${
            checked
              ? "left-6"
              : "left-1"
          }`}
        />
      </button>
    </div>
  );
}

function AppSettingsCard({
  title,
  version,
  forceUpdate,
  onVersionChange,
  onForceUpdateChange,
}: {
  title: string;
  version: string;
  forceUpdate: boolean;
  onVersionChange: (
    value: string,
  ) => void;
  onForceUpdateChange: (
    value: boolean,
  ) => void;
}) {
  return (
    <section className="rounded-xl bg-white p-6 shadow-sm">
      <h2 className="text-lg font-semibold text-gray-900">
        {title}
      </h2>

      <div className="mt-6 grid gap-6 md:grid-cols-2">
        <label>
          <span className="text-sm font-medium text-gray-700">
            Minimum Version
          </span>

          <input
            value={version}
            onChange={(event) =>
              onVersionChange(
                event.target.value,
              )
            }
            placeholder="1.0.0"
            className="mt-2 w-full rounded-lg border border-gray-300 px-4 py-3 outline-none focus:border-gray-500"
          />
        </label>

        <ToggleField
          label="Force Update"
          description="Require users below the minimum version to update."
          checked={forceUpdate}
          onChange={
            onForceUpdateChange
          }
        />
      </div>
    </section>
  );
}

function formatDate(value: string) {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString();
}