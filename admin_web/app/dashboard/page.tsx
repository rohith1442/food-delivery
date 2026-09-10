"use client";

import axios from "axios";
import Link from "next/link";
import { useCallback, useEffect, useState } from "react";

import { api } from "@/lib/api";

interface DashboardData {
  pendingApprovals: number;
  totalOrders: number;
  activeStores: number;
  customers: number;
  activeMerchants: number;
  activeDeliveryPartners: number;
  activeZones: number;
  deliveredOrders: number;
  revenue: number;
}

export default function DashboardPage() {
  const [data, setData] =
    useState<DashboardData | null>(null);

  const [loading, setLoading] =
    useState(true);

  const [error, setError] =
    useState("");

  const loadDashboard = useCallback(async () => {
    try {
      setLoading(true);
      setError("");

      const response =
        await api.get<DashboardData>(
          "/admin/dashboard",
        );

      setData(response.data);
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to load dashboard.",
        );
      } else {
        setError(
          "Unable to load dashboard.",
        );
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadDashboard();
  }, [loadDashboard]);

  if (loading) {
    return (
      <main className="p-8">
        <p className="text-gray-500">
          Loading dashboard...
        </p>
      </main>
    );
  }

  if (error || !data) {
    return (
      <main className="p-8">
        <div className="rounded-lg bg-red-50 p-4 text-red-700">
          {error || "Unable to load dashboard."}
        </div>
      </main>
    );
  }

  return (
    <main className="p-8">
      <div className="mx-auto max-w-7xl">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">
            Dashboard
          </h1>

          <p className="mt-2 text-gray-500">
            Platform overview and operational
            summary
          </p>
        </div>

        <div className="mt-8 grid gap-5 sm:grid-cols-2 xl:grid-cols-4">
          <DashboardCard
            title="Pending Approvals"
            value={data.pendingApprovals}
            href="/dashboard/approvals"
          />

          <DashboardCard
            title="Total Orders"
            value={data.totalOrders}
            href="/dashboard/orders"
          />

          <DashboardCard
            title="Active Stores"
            value={data.activeStores}
            href="/dashboard/stores"
          />

          <DashboardCard
            title="Customers"
            value={data.customers}
            href="/dashboard/users"
          />

          <DashboardCard
            title="Active Merchants"
            value={data.activeMerchants}
            href="/dashboard/users"
          />

          <DashboardCard
            title="Active Delivery Partners"
            value={data.activeDeliveryPartners}
            href="/dashboard/users"
          />

          <DashboardCard
            title="Active Zones"
            value={data.activeZones}
            href="/dashboard/zones"
          />

          <DashboardCard
            title="Delivered Orders"
            value={data.deliveredOrders}
            href="/dashboard/orders"
          />
        </div>

        <section className="mt-8 rounded-xl bg-white p-6 shadow-sm">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="text-sm font-medium text-gray-500">
                Delivered Order Revenue
              </p>

              <p className="mt-2 text-4xl font-bold text-gray-900">
                {formatCurrency(data.revenue)}
              </p>
            </div>

            <Link
              href="/dashboard/orders"
              className="rounded-lg bg-gray-900 px-5 py-2.5 text-sm font-medium text-white hover:bg-gray-800"
            >
              View Orders
            </Link>
          </div>

          <p className="mt-4 text-sm text-gray-500">
            Revenue shown here is calculated from
            orders currently marked as DELIVERED.
          </p>
        </section>

        <section className="mt-8">
          <h2 className="text-lg font-semibold text-gray-900">
            Quick Actions
          </h2>

          <div className="mt-4 flex flex-wrap gap-3">
            <QuickAction
              href="/dashboard/approvals"
              label="Review Approvals"
            />

            <QuickAction
              href="/dashboard/orders"
              label="View Orders"
            />

            <QuickAction
              href="/dashboard/stores"
              label="Manage Stores"
            />

            <QuickAction
              href="/dashboard/users"
              label="Manage Users"
            />

            <QuickAction
              href="/dashboard/zones"
              label="Manage Zones"
            />

            <QuickAction
              href="/dashboard/modules"
              label="Manage Modules"
            />
          </div>
        </section>
      </div>
    </main>
  );
}

function DashboardCard({
  title,
  value,
  href,
}: {
  title: string;
  value: number;
  href: string;
}) {
  return (
    <Link
      href={href}
      className="rounded-xl bg-white p-6 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
    >
      <p className="text-sm text-gray-500">
        {title}
      </p>

      <p className="mt-3 text-3xl font-bold text-gray-900">
        {value}
      </p>

      <p className="mt-4 text-sm font-medium text-blue-600">
        View details →
      </p>
    </Link>
  );
}

function QuickAction({
  href,
  label,
}: {
  href: string;
  label: string;
}) {
  return (
    <Link
      href={href}
      className="rounded-lg border border-gray-200 bg-white px-4 py-2.5 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50"
    >
      {label}
    </Link>
  );
}

function formatCurrency(value: number) {
  return new Intl.NumberFormat(
    "en-IN",
    {
      style: "currency",
      currency: "INR",
      maximumFractionDigits: 2,
    },
  ).format(value);
}