"use client";

import { signOut } from "firebase/auth";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";

import { auth } from "@/lib/firebase";

const menuItems = [
  {
    label: "Dashboard",
    href: "/dashboard",
  },
  {
    label: "Approvals",
    href: "/dashboard/approvals",
  },
  {
    label: "Orders",
    href: "/dashboard/orders",
  },
  {
    label: "Stores",
    href: "/dashboard/stores",
  },
  {
    label: "Users",
    href: "/dashboard/users",
  },
  {
    label: "Coupons",
    href: "/dashboard/coupons",
  },
    {
    label: "Zones",
    href: "/dashboard/zones",
  },
  {
    label: "Modules",
    href: "/dashboard/modules",
  },
  {
    label: "Settings",
    href: "/dashboard/settings",
  }
];

export default function AdminSidebar() {
  const pathname = usePathname();
  const router = useRouter();

  const handleLogout = async () => {
    await signOut(auth);
    router.replace("/");
  };

  return (
    <aside className="flex min-h-screen w-64 flex-col bg-gray-950 text-white">
      <div className="border-b border-gray-800 px-6 py-6">
        <h1 className="text-xl font-bold">
          Food Delivery
        </h1>

        <p className="mt-1 text-xs text-gray-400">
          Admin Panel
        </p>
      </div>

      <nav className="flex-1 space-y-1 p-4">
        {menuItems.map((item) => {
          const active =
            pathname === item.href;

          return (
            <Link
              key={item.href}
              href={item.href}
              className={`block rounded-lg px-4 py-3 text-sm font-medium ${
                active
                  ? "bg-white text-gray-950"
                  : "text-gray-300 hover:bg-gray-800 hover:text-white"
              }`}
            >
              {item.label}
            </Link>
          );
        })}
      </nav>

      <div className="border-t border-gray-800 p-4">
        <button
          onClick={handleLogout}
          className="w-full rounded-lg bg-red-600 px-4 py-3 text-sm font-medium text-white hover:bg-red-700"
        >
          Logout
        </button>
      </div>
    </aside>
  );
}