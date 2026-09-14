import { BadRequestException, Injectable } from '@nestjs/common';
import { FirebaseService } from '../firebase/firebase.service.js';
import { RazorpayRouteService } from './razorpay-route.service.js';
import { SettlementTransaction } from './settlement.types.js';

@Injectable()
export class SettlementsService {
  constructor(private readonly firebase: FirebaseService, private readonly route: RazorpayRouteService) {}
  async finalizeOrderSettlement(orderId: string) {
    const db = this.firebase.getFirestore(); const orderSnapshot = await db.collection('orders').doc(orderId).get();
    if (!orderSnapshot.exists) throw new BadRequestException('Order not found');
    const order = orderSnapshot.data() as any; if (order.status !== 'DELIVERED') throw new BadRequestException('Only delivered orders can be settled');
    const now = new Date().toISOString(); const financials = order.financials ?? { itemAmount: order.subtotal ?? 0, customerDeliveryFee: order.deliveryFee ?? 0, grossAmount: order.total ?? 0, merchantCommission: 0, merchantPayable: order.subtotal ?? 0, riderEarning: 0, platformRevenue: order.deliveryFee ?? 0 };
    const ref = db.collection('settlements').doc(`${orderId}_MERCHANT`); const existing = await ref.get(); if (existing.exists && ['PAID', 'PROCESSING'].includes(existing.data()?.status)) return existing.data();
    const record: SettlementTransaction = { id: ref.id, orderId, partyType: 'MERCHANT', partyId: order.merchantId, storeId: order.storeId, grossAmount: financials.itemAmount, commissionAmount: financials.merchantCommission, deliveryEarning: financials.riderEarning, deductions: 0, taxAmount: 0, netAmount: financials.merchantPayable, provider: order.paymentMethod === 'ONLINE' ? 'RAZORPAY_ROUTE' : 'INTERNAL', status: 'PENDING', createdAt: existing.data()?.createdAt ?? now, updatedAt: now };
    await ref.set(record, { merge: true });
    const storeSnapshot = await db.collection('stores').doc(order.storeId).get();
    const store = storeSnapshot.data() as any;
    if (order.paymentMethod === 'ONLINE' && order.providerPaymentId && store?.settlement?.linkedAccountStatus === 'ACTIVE' && store.settlement.razorpayLinkedAccountId) {
      try {
        const transfer = await this.route.transferPayment({ razorpayPaymentId: order.providerPaymentId, linkedAccountId: store.settlement.razorpayLinkedAccountId, amountInPaise: Math.round(financials.merchantPayable * 100), orderId });
        const transferId = transfer?.items?.[0]?.id ?? transfer?.transfers?.[0]?.id ?? transfer?.id ?? null;
        await ref.set({ status: 'PROCESSING', providerTransferId: transferId, updatedAt: new Date().toISOString() }, { merge: true });
        record.status = 'PROCESSING'; record.providerTransferId = transferId;
      } catch (error) {
        await ref.set({ status: 'FAILED', failureReason: String(error), updatedAt: new Date().toISOString() }, { merge: true });
        record.status = 'FAILED'; record.failureReason = String(error);
      }
    }
    if (order.riderId) {
      const riderRef = db.collection('settlements').doc(`${orderId}_RIDER`);
      const riderRecord: SettlementTransaction = { id: riderRef.id, orderId, partyType: 'DELIVERY_PARTNER', partyId: order.riderId, storeId: order.storeId, grossAmount: financials.riderEarning, commissionAmount: 0, deliveryEarning: financials.riderEarning, deductions: 0, taxAmount: 0, netAmount: financials.riderEarning, provider: 'RAZORPAY_X', status: 'PENDING', createdAt: now, updatedAt: now };
      await riderRef.set(riderRecord, { merge: true });
    }
    return record;
  }
  async getTransactions(partyType: 'MERCHANT' | 'DELIVERY_PARTNER', partyId: string) {
    const snapshot = await this.firebase.getFirestore().collection('settlements').where('partyType', '==', partyType).where('partyId', '==', partyId).get();
    const transactions = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })).sort((a: any, b: any) => String(b.createdAt).localeCompare(String(a.createdAt)));
    const lifetimeNet = transactions.reduce((sum: number, item: any) => sum + Number(item.netAmount ?? 0), 0);
    const pendingSettlement = transactions.filter((item: any) => item.status === 'PENDING').reduce((sum: number, item: any) => sum + Number(item.netAmount ?? 0), 0);
    return { success: true, transactions, summary: { lifetimeNet, pendingSettlement } };
  }
}
