import { BadRequestException, Injectable } from '@nestjs/common';
import { FirebaseService } from '../firebase/firebase.service.js';
import { RazorpayPayoutService } from './razorpay-payout.service.js';
import { RazorpayRouteService } from './razorpay-route.service.js';
import { SettlementTransaction } from './settlement.types.js';

@Injectable()
export class SettlementsService {
  constructor(private readonly firebase: FirebaseService, private readonly route: RazorpayRouteService, private readonly payout: RazorpayPayoutService) {}

  async finalizeOrderSettlement(orderId: string) {
    const db = this.firebase.getFirestore();
    const snapshot = await db.collection('orders').doc(orderId).get();
    if (!snapshot.exists) throw new BadRequestException('Order not found');
    const order = snapshot.data() as any;
    if (order.status !== 'DELIVERED') throw new BadRequestException('Only delivered orders can be settled');
    const financials = order.financials;
    if (!financials) throw new BadRequestException('Order financial snapshot missing');
    const now = new Date().toISOString();
    const merchantRef = db.collection('settlements').doc(`${orderId}_MERCHANT`);
    const riderRef = db.collection('settlements').doc(`${orderId}_RIDER`);
    const platformRef = db.collection('settlements').doc(`${orderId}_PLATFORM`);

    await db.runTransaction(async (transaction) => {
      const [merchant, rider, platform] = await Promise.all([transaction.get(merchantRef), transaction.get(riderRef), transaction.get(platformRef)]);
      if (!merchant.exists) transaction.set(merchantRef, { id: merchantRef.id, orderId, partyType: 'MERCHANT', partyId: order.merchantId, storeId: order.storeId, grossAmount: financials.itemAmount, commissionAmount: financials.merchantCommission, deliveryEarning: 0, deductions: 0, taxAmount: 0, netAmount: financials.merchantPayable, provider: order.paymentMethod === 'ONLINE' ? 'RAZORPAY_ROUTE' : 'INTERNAL', status: 'PENDING', createdAt: now, updatedAt: now });
      if (order.riderId && !rider.exists) transaction.set(riderRef, { id: riderRef.id, orderId, partyType: 'DELIVERY_PARTNER', partyId: order.riderId, storeId: order.storeId, grossAmount: financials.riderEarning, commissionAmount: 0, deliveryEarning: financials.riderEarning, deductions: 0, taxAmount: 0, netAmount: financials.riderEarning, provider: 'RAZORPAY_X', status: 'PENDING', createdAt: now, updatedAt: now });
      if (!platform.exists) transaction.set(platformRef, { id: platformRef.id, orderId, partyType: 'PLATFORM', partyId: 'PLATFORM', storeId: order.storeId, grossAmount: order.total ?? 0, commissionAmount: financials.merchantCommission, deliveryEarning: financials.riderEarning, deductions: 0, taxAmount: 0, netAmount: financials.platformRevenue, provider: 'INTERNAL', status: 'PAID', createdAt: now, updatedAt: now, paidAt: now });
    });

    const merchant = (await merchantRef.get()).data() as any;
    if (merchant?.status === 'PAID' || merchant?.status === 'PROCESSING') return merchant;
    if (order.paymentMethod !== 'ONLINE' || !order.providerPaymentId) return (await merchantRef.get()).data();
    const settings = (await db.collection('settings').doc('global').get()).data() ?? {};
    if (settings.payments?.settlement?.merchantEnabled !== true) {
      await merchantRef.set({ status: 'ON_HOLD', failureReason: 'Merchant settlements are disabled globally', updatedAt: new Date().toISOString() }, { merge: true });
      return (await merchantRef.get()).data();
    }
    const store = (await db.collection('stores').doc(order.storeId).get()).data() as any;
    const settlement = store?.settlement;
    if (settlement?.settlementEnabled !== true || settlement.linkedAccountStatus !== 'ACTIVE' || !settlement.razorpayLinkedAccountId) {
      await merchantRef.set({ status: 'ON_HOLD', failureReason: 'Merchant settlement account is not active', updatedAt: new Date().toISOString() }, { merge: true });
      return (await merchantRef.get()).data();
    }
    try {
      await merchantRef.set({ status: 'PROCESSING', transferAttemptedAt: new Date().toISOString(), updatedAt: new Date().toISOString() }, { merge: true });
      const transfer = await this.route.transferPayment({ razorpayPaymentId: order.providerPaymentId, linkedAccountId: settlement.razorpayLinkedAccountId, amountInPaise: Math.round(Number(financials.merchantPayable) * 100), orderId });
      const transferId = transfer?.items?.[0]?.id ?? transfer?.transfers?.[0]?.id ?? transfer?.id ?? null;
      await merchantRef.set({ providerTransferId: transferId, status: 'PROCESSING', failureReason: null, updatedAt: new Date().toISOString() }, { merge: true });
    } catch (error) {
      await merchantRef.set({ status: 'ON_HOLD', reconciliationRequired: true, failureReason: error instanceof Error ? error.message : String(error), updatedAt: new Date().toISOString() }, { merge: true });
    }
    return (await merchantRef.get()).data();
  }

  async getTransactions(partyType: 'MERCHANT' | 'DELIVERY_PARTNER', partyId: string) {
    const snapshot = await this.firebase.getFirestore().collection('settlements').where('partyType', '==', partyType).where('partyId', '==', partyId).get();
    const transactions = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })).sort((a: any, b: any) => String(b.createdAt ?? '').localeCompare(String(a.createdAt ?? '')));
    const today = new Date();
    const todayPrefix = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
    const sum = (list: any[], field: string) => list.reduce((total, item) => total + Number(item[field] ?? 0), 0);
    const todayItems = transactions.filter((item: any) => String(item.createdAt ?? '').startsWith(todayPrefix));
    const pending = transactions.filter((item: any) => ['PENDING', 'ON_HOLD', 'PROCESSING'].includes(item.status));
    const summary = { todayGross: sum(todayItems, 'grossAmount'), todayCommission: sum(todayItems, 'commissionAmount'), todayNet: sum(todayItems, 'netAmount'), pendingSettlement: sum(pending, 'netAmount'), processing: sum(transactions.filter((item: any) => item.status === 'PROCESSING'), 'netAmount'), paid: sum(transactions.filter((item: any) => item.status === 'PAID'), 'netAmount'), failed: sum(transactions.filter((item: any) => item.status === 'FAILED'), 'netAmount'), lifetimeGross: sum(transactions, 'grossAmount'), lifetimeCommission: sum(transactions, 'commissionAmount'), lifetimeNet: sum(transactions, 'netAmount') };
    return { success: true, transactions, summary };
  }

  async getOrderSettlements(orderId: string) { const snapshot = await this.firebase.getFirestore().collection('settlements').where('orderId', '==', orderId).get(); return { success: true, settlements: snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })) }; }
  async getSettlement(orderId: string) { return this.getOrderSettlements(orderId); }
  async getAllSettlements() { const snapshot = await this.firebase.getFirestore().collection('settlements').limit(500).get(); const settlements = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })).sort((a: any, b: any) => String(b.createdAt ?? '').localeCompare(String(a.createdAt ?? ''))); return { success: true, settlements }; }
  async retryMerchantSettlement(orderId: string) {
    const ref = this.firebase.getFirestore().collection('settlements').doc(`${orderId}_MERCHANT`);
    const snapshot = await ref.get();
    if (!snapshot.exists) throw new BadRequestException('Merchant settlement not found');
    const settlement = snapshot.data() as any;
    if (settlement?.providerTransferId) throw new BadRequestException('Settlement already has a provider transfer ID');
    if (!['FAILED', 'ON_HOLD'].includes(settlement?.status)) throw new BadRequestException('Settlement cannot be retried in its current state');
    return this.finalizeOrderSettlement(orderId);
  }
  async reconcileMerchantSettlement(orderId: string) {
    const db = this.firebase.getFirestore();
    const order = (await db.collection('orders').doc(orderId).get()).data() as any;
    const ref = db.collection('settlements').doc(`${orderId}_MERCHANT`);
    if (!order?.providerPaymentId) throw new BadRequestException('Provider payment is missing');
    const transfers = await this.route.listPaymentTransfers(order.providerPaymentId);
    const transfer = (transfers?.items ?? transfers?.transfers ?? []).find((item: any) => item.notes?.orderId === orderId);
    if (!transfer?.id) { await ref.set({ status: 'ON_HOLD', reconciliationRequired: true, failureReason: 'No matching provider transfer found', updatedAt: new Date().toISOString() }, { merge: true }); return { success: true, matched: false }; }
    await ref.set({ providerTransferId: transfer.id, status: transfer.status === 'processed' ? 'PAID' : 'PROCESSING', reconciliationRequired: false, failureReason: null, ...(transfer.status === 'processed' ? { paidAt: new Date().toISOString() } : {}), updatedAt: new Date().toISOString() }, { merge: true });
    return { success: true, matched: true, providerTransferId: transfer.id };
  }

  async payoutRider(riderId: string) {
    const db = this.firebase.getFirestore();
    const settings = (await db.collection('settings').doc('global').get()).data() ?? {};
    if (settings.payments?.settlement?.riderPayoutEnabled !== true) throw new BadRequestException('Rider payouts are disabled');
    const user = await db.collection('users').doc(riderId).get();
    if (!user.exists) throw new BadRequestException('Rider not found');
    const onboarding = (user.data()?.deliveryOnboarding ?? {}) as any;
    if (onboarding.payoutStatus !== 'ACTIVE' || !onboarding.razorpayFundAccountId) throw new BadRequestException('Rider payout account is not active');
    const snapshot = await db.collection('settlements').where('partyType', '==', 'DELIVERY_PARTNER').where('partyId', '==', riderId).where('status', '==', 'PENDING').get();
    if (snapshot.empty) return { success: true, message: 'No pending payouts' };
    const amount = snapshot.docs.reduce((sum, doc) => sum + Number(doc.data().netAmount ?? 0), 0);
    if (amount <= 0) throw new BadRequestException('Invalid payout amount');
    const batchRef = db.collection('payout_batches').doc();
    const now = new Date().toISOString();
    await db.runTransaction(async (transaction) => {
      const freshSnapshots = await Promise.all(snapshot.docs.map((doc) => transaction.get(doc.ref)));
      if (freshSnapshots.some((fresh) => fresh.data()?.status !== 'PENDING')) throw new BadRequestException('Some settlements are already being paid');
      for (const doc of snapshot.docs) {
        transaction.update(doc.ref, { status: 'PAYOUT_RESERVED', payoutBatchId: batchRef.id, updatedAt: now });
      }
      transaction.set(batchRef, { id: batchRef.id, riderId, settlementIds: snapshot.docs.map((doc) => doc.id), amount, status: 'CREATED', createdAt: now, updatedAt: now });
    });
    try {
      const payout = await this.payout.createPayout({ fundAccountId: onboarding.razorpayFundAccountId, amountInPaise: Math.round(amount * 100), payoutBatchId: batchRef.id });
      const batch = db.batch();
      for (const doc of snapshot.docs) batch.update(doc.ref, { status: 'PROCESSING', providerPayoutId: payout.id, updatedAt: new Date().toISOString() });
      await batch.commit();
      await batchRef.set({ razorpayPayoutId: payout.id, status: 'PROCESSING', updatedAt: new Date().toISOString() }, { merge: true });
      return { success: true, payoutBatchId: batchRef.id, providerPayoutId: payout.id, amount };
    } catch (error) {
      const failureReason = error instanceof Error ? error.message : String(error);
      await batchRef.set({ status: 'FAILED', failureReason, updatedAt: new Date().toISOString() }, { merge: true });
      const hold = db.batch();
      for (const doc of snapshot.docs) hold.update(doc.ref, { status: 'ON_HOLD', reconciliationRequired: true, failureReason: 'Payout result uncertain; reconciliation required', updatedAt: new Date().toISOString() });
      await hold.commit();
      throw error;
    }
  }

  async reconcileProviderEvent(event: string, payload: any) {
    const entity = payload?.transfer?.entity ?? payload?.payout?.entity;
    const providerId = entity?.id;
    if (!providerId) return false;
    const field = event.startsWith('transfer.') ? 'providerTransferId' : 'providerPayoutId';
    const status = event.endsWith('.processed') ? 'PAID' : event.endsWith('.failed') ? 'FAILED' : event.endsWith('.reversed') ? 'REVERSED' : null;
    if (!status) return false;
    const snapshot = await this.firebase.getFirestore().collection('settlements').where(field, '==', providerId).get();
    await Promise.all(snapshot.docs.map((doc) => doc.ref.update({ status, ...(status === 'PAID' ? { paidAt: new Date().toISOString() } : {}), failureReason: status === 'FAILED' ? entity.error_description ?? 'Provider operation failed' : null, updatedAt: new Date().toISOString() })));
    if (field === 'providerPayoutId') {
      const batches = await this.firebase.getFirestore().collection('payout_batches').where('razorpayPayoutId', '==', providerId).get();
      await Promise.all(batches.docs.map((doc) => doc.ref.update({ status, ...(status === 'PAID' ? { paidAt: new Date().toISOString() } : {}), failureReason: status === 'FAILED' ? entity.error_description ?? 'Provider payout failed' : null, updatedAt: new Date().toISOString() })));
    }
    return snapshot.size > 0;
  }
}
