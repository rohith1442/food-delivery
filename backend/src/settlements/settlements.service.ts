import { BadRequestException, Injectable } from '@nestjs/common';
import { FirebaseService } from '../firebase/firebase.service.js';
import { RazorpayRouteService } from './razorpay-route.service.js';
import { RazorpayPayoutService } from './razorpay-payout.service.js';
import { SettlementTransaction } from './settlement.types.js';

@Injectable()
export class SettlementsService {
  constructor(private readonly firebase: FirebaseService, private readonly route: RazorpayRouteService, private readonly payout: RazorpayPayoutService) {}
  async finalizeOrderSettlement(orderId: string) {
    const db = this.firebase.getFirestore(); const orderSnapshot = await db.collection('orders').doc(orderId).get();
    if (!orderSnapshot.exists) throw new BadRequestException('Order not found');
    const order = orderSnapshot.data() as any; if (order.status !== 'DELIVERED') throw new BadRequestException('Only delivered orders can be settled');
    const now = new Date().toISOString(); const financials = order.financials ?? { itemAmount: order.subtotal ?? 0, customerDeliveryFee: order.deliveryFee ?? 0, grossAmount: order.total ?? 0, merchantCommission: 0, merchantPayable: order.subtotal ?? 0, riderEarning: 0, platformRevenue: order.deliveryFee ?? 0 };
    const ref = db.collection('settlements').doc(`${orderId}_MERCHANT`); const existing = await ref.get(); const existingData = existing.data() as Partial<SettlementTransaction> | undefined;
    const record: SettlementTransaction = { id: ref.id, orderId, partyType: 'MERCHANT', partyId: order.merchantId, storeId: order.storeId, grossAmount: financials.itemAmount, commissionAmount: financials.merchantCommission, deliveryEarning: financials.riderEarning, deductions: 0, taxAmount: 0, netAmount: financials.merchantPayable, provider: order.paymentMethod === 'ONLINE' ? 'RAZORPAY_ROUTE' : 'INTERNAL', status: existingData?.status ?? 'PENDING', createdAt: existingData?.createdAt ?? now, updatedAt: now };
    await ref.set(record, { merge: true });
    const storeSnapshot = await db.collection('stores').doc(order.storeId).get();
    const store = storeSnapshot.data() as any;
    if (!['PAID', 'PROCESSING'].includes(record.status) && order.paymentMethod === 'ONLINE' && order.providerPaymentId && store?.settlement?.linkedAccountStatus === 'ACTIVE' && store.settlement.razorpayLinkedAccountId) {
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
    const platformRef = db.collection('settlements').doc(`${orderId}_PLATFORM`);
    await platformRef.set({ id: platformRef.id, orderId, partyType: 'PLATFORM', partyId: 'PLATFORM', grossAmount: order.total ?? 0, commissionAmount: 0, deliveryEarning: 0, deductions: 0, taxAmount: 0, netAmount: financials.platformRevenue, provider: 'INTERNAL', status: 'PAID', createdAt: now, updatedAt: now, paidAt: now }, { merge: true });
    return record;
  }
  async getTransactions(partyType: 'MERCHANT' | 'DELIVERY_PARTNER', partyId: string) {
    const snapshot = await this.firebase.getFirestore().collection('settlements').where('partyType', '==', partyType).where('partyId', '==', partyId).get();
    const transactions = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })).sort((a: any, b: any) => String(b.createdAt).localeCompare(String(a.createdAt)));
    const lifetimeNet = transactions.reduce((sum: number, item: any) => sum + Number(item.netAmount ?? 0), 0);
    const pendingSettlement = transactions.filter((item: any) => item.status === 'PENDING').reduce((sum: number, item: any) => sum + Number(item.netAmount ?? 0), 0);
    return { success: true, transactions, summary: { lifetimeNet, pendingSettlement } };
  }
  async getSettlement(orderId: string) {
    const snapshot = await this.firebase.getFirestore().collection('settlements').where('orderId', '==', orderId).get();
    return { success: true, settlements: snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })) };
  }
  async payoutRider(riderId: string) {
    const db = this.firebase.getFirestore();
    const user = await db.collection('users').doc(riderId).get();
    const profile = (user.data()?.deliveryOnboarding ?? {}) as any;
    if (profile.payoutStatus !== 'ACTIVE' || !profile.razorpayFundAccountId) throw new BadRequestException('Rider payout account is not active');
    const snapshot = await db.collection('settlements').where('partyType', '==', 'DELIVERY_PARTNER').where('partyId', '==', riderId).where('status', '==', 'PENDING').get();
    const amount = snapshot.docs.reduce((sum, doc) => sum + Number(doc.data().netAmount ?? 0), 0);
    if (amount <= 0) throw new BadRequestException('No pending rider earnings');
    const batchId = `rider_${riderId}_${Date.now()}`;
    const batchRef = db.collection('payout_batches').doc(batchId);
    await batchRef.set({ id: batchId, riderId, settlementIds: snapshot.docs.map((doc) => doc.id), amount, status: 'CREATED', createdAt: new Date().toISOString() });
    try {
      const payout = await this.payout.createPayout({ fundAccountId: profile.razorpayFundAccountId, amountInPaise: Math.round(amount * 100), payoutBatchId: batchId });
      await batchRef.update({ status: 'PROCESSING', razorpayPayoutId: payout.id ?? null });
      await Promise.all(snapshot.docs.map((doc) => doc.ref.update({ status: 'PROCESSING', providerPayoutId: payout.id ?? null, updatedAt: new Date().toISOString() })));
      return { success: true, batchId, payoutId: payout.id ?? null, amount };
    } catch (error) {
      await batchRef.update({ status: 'FAILED', failureReason: String(error) });
      throw error;
    }
  }
  async reconcileProviderEvent(event: string, payload: any) {
    const entity = payload?.transfer?.entity ?? payload?.payout?.entity;
    const providerId = entity?.id;
    if (!providerId) return false;
    const isTransfer = event.startsWith('transfer.');
    const field = isTransfer ? 'providerTransferId' : 'providerPayoutId';
    const status = event.endsWith('.processed') ? 'PAID' : event.endsWith('.failed') || event.endsWith('.reversed') || event.endsWith('.reversed/returned') ? (event.endsWith('.reversed') ? 'REVERSED' : 'FAILED') : null;
    if (!status) return false;
    const snapshot = await this.firebase.getFirestore().collection('settlements').where(field, '==', providerId).get();
    await Promise.all(snapshot.docs.map((doc) => doc.ref.update({ status, failureReason: status === 'FAILED' ? entity.error_description ?? 'Provider payout failed' : null, paidAt: status === 'PAID' ? new Date().toISOString() : null, updatedAt: new Date().toISOString() })));
    return snapshot.size > 0;
  }
}
