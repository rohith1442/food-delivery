"use client";

import axios from "axios";
import { useCallback, useEffect, useMemo, useState } from "react";

import { api } from "@/lib/api";
import Link from "next/link";

interface Order {
  id: string;
  customerId?: string;
  storeId?: string;
  status?: string;
  subtotal?: number;
  deliveryFee?: number;
  total?: number;
  totalAmount?: number;
  createdAt?: string;
  updatedAt?: string;
  paymentMethod?: string;
  paymentStatus?: string;
}

const statusFilters = [
  { label: "All", value: "" },
  { label: "Pending", value: "VENDOR_PENDING" },
  { label: "Accepted", value: "ACCEPTED" },
  { label: "Preparing", value: "PREPARING" },
  { label: "Ready", value: "READY" },
  { label: "Rider Assigned", value: "RIDER_ASSIGNED" },
  { label: "Picked Up", value: "PICKED_UP" },
  { label: "On The Way", value: "ON_THE_WAY" },
  { label: "Delivered", value: "DELIVERED" },
  { label: "Rejected", value: "REJECTED" },
  { label: "Cancelled", value: "CANCELLED" },
];

export default function OrdersPage() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const loadOrders = useCallback(async () => {
    try {
      setLoading(true);
      setError("");

      const response = await api.get<Order[]>("/admin/orders", {
        params: status
          ? {
              status,
            }
          : undefined,
      });

      setOrders(response.data);
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(error.response?.data?.message ?? "Unable to load orders.");
      } else {
        setError("Unable to load orders.");
      }
    } finally {
      setLoading(false);
    }
  }, [status]);

  useEffect(() => {
    void loadOrders();
  }, [loadOrders]);

  const totalRevenue = useMemo(() => {
    return orders
      .filter((order) => order.status?.toUpperCase() === "DELIVERED")
      .reduce((sum, order) => {
        return sum + (order.total ?? order.totalAmount ?? 0);
      }, 0);
  }, [orders]);

  return (
    <main className="p-8">
      <div className="mx-auto max-w-7xl">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Orders</h1>

          <p className="mt-2 text-gray-500">
            Monitor orders across the platform
          </p>
        </div>

        <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <StatCard title="Orders" value={orders.length.toString()} />

          <StatCard
            title="Delivered"
            value={orders
              .filter((order) => order.status?.toUpperCase() === "DELIVERED")
              .length.toString()}
          />

          <StatCard
            title="Delivered Revenue"
            value={`₹${totalRevenue.toFixed(2)}`}
          />
        </div>

        <div className="mt-8 overflow-x-auto">
          <div className="flex min-w-max gap-2">
            {statusFilters.map((filter) => {
              const active = status === filter.value;

              return (
                <button
                  key={filter.label}
                  onClick={() => setStatus(filter.value)}
                  className={`rounded-lg px-4 py-2 text-sm font-medium ${
                    active
                      ? "bg-gray-900 text-white"
                      : "bg-white text-gray-600 shadow-sm hover:bg-gray-100"
                  }`}
                >
                  {filter.label}
                </button>
              );
            })}
          </div>
        </div>

        {error && (
          <div className="mt-6 rounded-lg bg-red-50 p-4 text-sm text-red-700">
            {error}
          </div>
        )}

        <section className="mt-6 overflow-hidden rounded-xl bg-white shadow-sm">
          {loading ? (
            <div className="p-8 text-gray-500">Loading orders...</div>
          ) : orders.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              No orders found.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left">
                <thead className="bg-gray-50 text-sm text-gray-500">
                  <tr>
                    <th className="px-6 py-4">Order</th>

                    <th className="px-6 py-4">Customer</th>

                    <th className="px-6 py-4">Store</th>

                    <th className="px-6 py-4">Amount</th>

                    <th className="px-6 py-4">Payment</th>

                    <th className="px-6 py-4">Status</th>

                    <th className="px-6 py-4">Created</th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-gray-100">
                  {orders.map((order) => (
                    <tr key={order.id}>
                      <td className="px-6 py-4">
                        <Link
                          href={`/dashboard/orders/${order.id}`}
                          className="block max-w-[160px] truncate font-medium text-blue-600 hover:underline"
                        >
                          {order.id}
                        </Link>
                      </td>

                      <td className="px-6 py-4 text-gray-600">
                        <Link
                          href={`/dashboard/customers/${order.customerId}`}
                          className="block max-w-[160px] truncate text-blue-600 hover:underline"
                        >
                          {order.customerId ?? "—"}
                        </Link>
                      </td>

                      <td className="px-6 py-4 text-gray-600">
                        <p className="max-w-[160px] truncate">
                          {order.storeId ?? "—"}
                        </p>
                      </td>

                      <td className="px-6 py-4 font-medium text-gray-900">
                        ₹{(order.total ?? order.totalAmount ?? 0).toFixed(2)}
                      </td>

                      <td className="px-6 py-4 text-gray-600">
                        {order.paymentMethod ?? "—"}
                      </td>

                      <td className="px-6 py-4">
                        <StatusBadge status={order.status ?? "UNKNOWN"} />
                      </td>

                      <td className="px-6 py-4 text-sm text-gray-500">
                        {formatDate(order.createdAt)}
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

function StatCard({ title, value }: { title: string; value: string }) {
  return (
    <div className="rounded-xl bg-white p-6 shadow-sm">
      <p className="text-sm text-gray-500">{title}</p>

      <p className="mt-2 text-3xl font-bold text-gray-900">{value}</p>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const normalized = status.toUpperCase();

  const className =
    normalized === "DELIVERED"
      ? "bg-green-50 text-green-700"
      : normalized === "CANCELLED" ||
          normalized === "REJECTED" ||
          normalized === "PAYMENT_FAILED"
        ? "bg-red-50 text-red-700"
        : normalized === "ON_THE_WAY" || normalized === "PICKED_UP"
          ? "bg-blue-50 text-blue-700"
          : "bg-yellow-50 text-yellow-700";

  return (
    <span
      className={`inline-flex rounded-full px-3 py-1 text-xs font-medium ${className}`}
    >
      {status.replaceAll("_", " ")}
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
