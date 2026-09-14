"use client";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
type RecordItem = { uid: string; [key: string]: any };
export default function MerchantKycPage() {
  const [items, setItems] = useState<RecordItem[]>([]);
  const load = async () => { const response = await api.get<{ users: RecordItem[] }>("/admin/merchant-onboarding"); setItems(response.data.users ?? []); };
  useEffect(() => { void load(); }, []);
  const action = async (uid: string, path: string, body?: object) => { await api.post(`/admin/merchant-onboarding/${uid}/${path}`, body); await load(); };
  const reject = async (uid: string) => { const reason = window.prompt("Enter rejection reason"); if (reason?.trim()) await action(uid, "reject", { reason: reason.trim() }); };
  return <main className="p-8"><h1 className="text-3xl font-bold">Merchant KYC</h1><div className="mt-8 overflow-x-auto rounded-xl bg-white shadow"><table className="w-full text-left text-sm"><thead><tr className="border-b"><th className="p-4">Merchant</th><th className="p-4">KYC</th><th className="p-4">Settlement</th><th className="p-4">Actions</th></tr></thead><tbody>{items.map((item) => <tr key={item.uid} className="border-b"><td className="p-4">{item.legalBusinessName ?? item.uid}</td><td className="p-4">{item.kycStatus ?? "NOT_STARTED"}</td><td className="p-4">{item.settlementStatus ?? "NOT_CONFIGURED"}</td><td className="flex flex-wrap gap-2 p-4"><button disabled={item.kycStatus === "VERIFIED"} className="rounded bg-green-600 px-3 py-2 text-white disabled:opacity-50" onClick={() => action(item.uid, "verify")}>Verify</button><button disabled={item.kycStatus !== "VERIFIED" || Boolean(item.razorpayLinkedAccountId)} className="rounded bg-blue-600 px-3 py-2 text-white disabled:opacity-50" onClick={() => action(item.uid, "create-linked-account")}>Create Route</button><button disabled={item.linkedAccountStatus !== "CREATED" || item.settlementStatus === "ACTIVE"} className="rounded bg-purple-600 px-3 py-2 text-white disabled:opacity-50" onClick={() => action(item.uid, "activate-settlement")}>Activate</button><button disabled={item.kycStatus === "VERIFIED"} className="rounded bg-red-600 px-3 py-2 text-white disabled:opacity-50" onClick={() => reject(item.uid)}>Reject</button></td></tr>)}</tbody></table></div></main>;
}
