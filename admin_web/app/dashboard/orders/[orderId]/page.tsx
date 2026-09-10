"use client";

import axios from "axios";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";

import { api } from "@/lib/api";

interface OrderItem {
  productId?: string;
  name?: string;
  quantity?: number;
  price?: number;
  total?: number;
}

interface Order {
  id: string;
  customerId?: string;
  storeId?: string;
  deliveryPartnerId?: string;
  riderId?: string;

  status?: string;

  subtotal?: number;
  deliveryFee?: number;
  total?: number;
  totalAmount?: number;

  paymentMethod?: string;
  paymentStatus?: string;

  createdAt?: string;
  updatedAt?: string;

  items?: OrderItem[];

  deliveryAddress?: {
    name?: string;
    phoneNumber?: string;
    address?: string;
    city?: string;
    state?: string;
    pincode?: string;
    latitude?: number;
    longitude?: number;
  };

  address?: {
    name?: string;
    phoneNumber?: string;
    address?: string;
    city?: string;
    state?: string;
    pincode?: string;
  };

  [key: string]: unknown;
}

export default function OrderDetailsPage() {
  const params = useParams();

  const orderId = params.orderId as string;

  const [order, setOrder] =
    useState<Order | null>(null);

  const [loading, setLoading] =
    useState(true);

  const [error, setError] =
    useState("");

  useEffect(() => {
    const loadOrder = async () => {
      try {
        setLoading(true);
        setError("");

        const response =
          await api.get<Order>(
            `/admin/orders/${orderId}`,
          );

        setOrder(response.data);
      } catch (error) {
        if (axios.isAxiosError(error)) {
          setError(
            error.response?.data?.message ??
              "Unable to load order.",
          );
        } else {
          setError(
            "Unable to load order.",
          );
        }
      } finally {
        setLoading(false);
      }
    };

    if (orderId) {
      void loadOrder();
    }
  }, [orderId]);

  if (loading) {
    return (
      <main className="p-8">
        <p className="text-gray-500">
          Loading order...
        </p>
      </main>
    );
  }

  if (error || !order) {
    return (
      <main className="p-8">
        <Link
          href="/dashboard/orders"
          className="text-sm font-medium text-gray-600"
        >
          ← Back to Orders
        </Link>

        <div className="mt-6 rounded-lg bg-red-50 p-4 text-red-700">
          {error || "Order not found."}
        </div>
      </main>
    );
  }

  const address =
    order.deliveryAddress ??
    order.address;

  const total =
    order.total ??
    order.totalAmount ??
    0;

  const riderId =
    order.deliveryPartnerId ??
    order.riderId;

  return (
    <main className="p-8">
      <div className="mx-auto max-w-7xl">
        <Link
          href="/dashboard/orders"
          className="text-sm font-medium text-gray-600 hover:text-gray-900"
        >
          ← Back to Orders
        </Link>

        <div className="mt-5 flex flex-wrap items-start justify-between gap-4">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">
              Order Details
            </h1>

            <p className="mt-2 text-sm text-gray-500">
              {order.id}
            </p>
          </div>

          <StatusBadge
            status={
              order.status ??
              "UNKNOWN"
            }
          />
        </div>

        <div className="mt-8 grid gap-6 lg:grid-cols-3">
          <InfoCard
            title="Customer"
            rows={[
              [
                "Customer ID",
                order.customerId ?? "—",
              ],
            ]}
          />

          <InfoCard
            title="Store"
            rows={[
              [
                "Store ID",
                order.storeId ?? "—",
              ],
            ]}
          />

          <InfoCard
            title="Delivery"
            rows={[
              [
                "Rider ID",
                riderId ?? "Not assigned",
              ],
            ]}
          />
        </div>

        <div className="mt-6 grid gap-6 lg:grid-cols-2">
          <InfoCard
            title="Payment"
            rows={[
              [
                "Payment Method",
                order.paymentMethod ?? "—",
              ],
              [
                "Payment Status",
                order.paymentStatus ?? "—",
              ],
              [
                "Subtotal",
                formatCurrency(
                  order.subtotal ?? 0,
                ),
              ],
              [
                "Delivery Fee",
                formatCurrency(
                  order.deliveryFee ?? 0,
                ),
              ],
              [
                "Total",
                formatCurrency(total),
              ],
            ]}
          />

          <InfoCard
            title="Order Information"
            rows={[
              [
                "Status",
                order.status ?? "—",
              ],
              [
                "Created",
                formatDate(
                  order.createdAt,
                ),
              ],
              [
                "Updated",
                formatDate(
                  order.updatedAt,
                ),
              ],
            ]}
          />
        </div>

        <section className="mt-6 rounded-xl bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-gray-900">
            Delivery Address
          </h2>

          {!address ? (
            <p className="mt-4 text-gray-500">
              No delivery address available.
            </p>
          ) : (
            <div className="mt-4 space-y-2 text-sm">
              {address.name && (
                <p className="font-medium text-gray-900">
                  {address.name}
                </p>
              )}

              {address.phoneNumber && (
                <p className="text-gray-600">
                  {address.phoneNumber}
                </p>
              )}

              <p className="text-gray-600">
                {[
                  address.address,
                  address.city,
                  address.state,
                  address.pincode,
                ]
                  .filter(Boolean)
                  .join(", ")}
              </p>
            </div>
          )}
        </section>

        <section className="mt-6 overflow-hidden rounded-xl bg-white shadow-sm">
          <div className="border-b border-gray-100 px-6 py-5">
            <h2 className="text-lg font-semibold text-gray-900">
              Items
            </h2>
          </div>

          {!order.items ||
          order.items.length === 0 ? (
            <div className="p-6 text-gray-500">
              No item details available.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left">
                <thead className="bg-gray-50 text-sm text-gray-500">
                  <tr>
                    <th className="px-6 py-4">
                      Product
                    </th>

                    <th className="px-6 py-4">
                      Price
                    </th>

                    <th className="px-6 py-4">
                      Quantity
                    </th>

                    <th className="px-6 py-4">
                      Total
                    </th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-gray-100">
                  {order.items.map(
                    (item, index) => {
                      const quantity =
                        item.quantity ?? 0;

                      const price =
                        item.price ?? 0;

                      const itemTotal =
                        item.total ??
                        price * quantity;

                      return (
                        <tr
                          key={
                            item.productId ??
                            index
                          }
                        >
                          <td className="px-6 py-4">
                            <p className="font-medium text-gray-900">
                              {item.name ??
                                "Product"}
                            </p>

                            {item.productId && (
                              <p className="mt-1 text-xs text-gray-500">
                                {
                                  item.productId
                                }
                              </p>
                            )}
                          </td>

                          <td className="px-6 py-4 text-gray-600">
                            {formatCurrency(
                              price,
                            )}
                          </td>

                          <td className="px-6 py-4 text-gray-600">
                            {quantity}
                          </td>

                          <td className="px-6 py-4 font-medium text-gray-900">
                            {formatCurrency(
                              itemTotal,
                            )}
                          </td>
                        </tr>
                      );
                    },
                  )}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </main>
  );
}

function InfoCard({
  title,
  rows,
}: {
  title: string;
  rows: [string, string][];
}) {
  return (
    <div className="rounded-xl bg-white p-6 shadow-sm">
      <h2 className="text-lg font-semibold text-gray-900">
        {title}
      </h2>

      <div className="mt-5 space-y-4">
        {rows.map(([label, value]) => (
          <div
            key={label}
            className="flex justify-between gap-4"
          >
            <span className="text-sm text-gray-500">
              {label}
            </span>

            <span className="max-w-[65%] break-all text-right text-sm font-medium text-gray-900">
              {value}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

function StatusBadge({
  status,
}: {
  status: string;
}) {
  const normalized =
    status.toUpperCase();

  const style =
    normalized === "DELIVERED"
      ? "bg-green-50 text-green-700"
      : normalized === "REJECTED" ||
          normalized === "CANCELLED" ||
          normalized === "PAYMENT_FAILED"
        ? "bg-red-50 text-red-700"
        : normalized === "ON_THE_WAY" ||
            normalized === "PICKED_UP"
          ? "bg-blue-50 text-blue-700"
          : "bg-yellow-50 text-yellow-700";

  return (
    <span
      className={`rounded-full px-4 py-2 text-sm font-medium ${style}`}
    >
      {status.replaceAll("_", " ")}
    </span>
  );
}

function formatCurrency(
  value: number,
) {
  return `₹${value.toFixed(2)}`;
}

function formatDate(
  value?: string,
) {
  if (!value) {
    return "—";
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString();
}