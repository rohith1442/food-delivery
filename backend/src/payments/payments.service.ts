import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Razorpay from 'razorpay';
import { createHmac, timingSafeEqual } from 'node:crypto';

import { FirebaseService } from '../firebase/firebase.service.js';
import { CreateOrderRequest, OrdersService } from '../orders/orders.service.js';
import { RazorpayRefundService } from './razorpay-refund.service.js';

interface CreateRazorpayOrderRequest {
  storeId: string;
  addressId: string;
  items: Array<{
    id: string;
    quantity: number;
  }>;
}
interface RazorpayRefundEntity {
  id: string;
  payment_id: string;
  amount: number;
  currency: string;
  status: string;
}

interface RazorpayRefundWebhookPayload {
  event: string;

  payload?: {
    refund?: {
      entity?: RazorpayRefundEntity;
    };
  };
}

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  private readonly razorpay: Razorpay;

  private readonly razorpayKeyId: string;

  constructor(
    private readonly configService: ConfigService,
    private readonly firebaseService: FirebaseService,
    private readonly ordersService: OrdersService,
    private readonly razorpayRefundService: RazorpayRefundService,
  ) {
    const keyId = this.configService.get<string>('RAZORPAY_KEY_ID');

    const keySecret = this.configService.get<string>('RAZORPAY_KEY_SECRET');

    if (!keyId || !keySecret) {
      throw new Error('Razorpay configuration is missing');
    }

    this.razorpayKeyId = keyId;

    console.log('Razorpay test key loaded:', keyId.startsWith('rzp_test_'));

    console.log('Razorpay secret loaded:', keySecret.length > 0);

    this.razorpay = new Razorpay({
      key_id: keyId,
      key_secret: keySecret,
    });
  }

  async createRazorpayOrder(uid: string, body: CreateRazorpayOrderRequest) {
    try {
      if (!body?.storeId?.trim()) {
        throw new BadRequestException('Store ID is required');
      }

      if (!body?.addressId?.trim()) {
        throw new BadRequestException('Delivery address is required');
      }

      if (!body?.items?.length) {
        throw new BadRequestException('Order must contain items');
      }

      const checkoutRequest: CreateOrderRequest = {
        storeId: body.storeId,
        addressId: body.addressId,

        items: body.items.map((item) => ({
          id: item.id,
          quantity: item.quantity,
          name: '',
          price: 0,
        })),

        paymentMethod: 'ONLINE',
      };

      const checkout = await this.ordersService.calculateCheckout(
        uid,
        checkoutRequest,
      );

      const amountInPaise = Math.round(checkout.total * 100);

      if (!Number.isInteger(amountInPaise) || amountInPaise <= 0) {
        throw new BadRequestException('Invalid payment amount');
      }

      const db = this.firebaseService.getFirestore();

      const paymentRef = db.collection('payments').doc();

      const now = new Date().toISOString();

      this.logger.log(
        `Creating Razorpay order paymentId=${paymentRef.id} userId=${uid} amount=${amountInPaise}`,
      );

      const razorpayOrder = await this.razorpay.orders.create({
        amount: amountInPaise,
        currency: 'INR',
        receipt: `payment_${paymentRef.id}`,
      });

      const paymentDocument = {
        id: paymentRef.id,

        customerId: uid,

        provider: 'RAZORPAY',

        providerOrderId: razorpayOrder.id,

        amount: checkout.total,
        amountInPaise,

        currency: 'INR',

        status: 'CREATED',

        storeId: checkout.storeId,

        checkoutRequest: {
          storeId: body.storeId,
          addressId: body.addressId,

          items: body.items.map((item) => ({
            id: item.id,
            quantity: item.quantity,
          })),
        },

        orderId: null,

        providerPaymentId: null,

        providerRefundId: null,

        refundAmountInPaise: null,

        orderCreationFailedAt: null,

        refundCreatedAt: null,

        refundFailedAt: null,

        createdAt: now,
        updatedAt: now,
      };

      await paymentRef.set(paymentDocument);

      this.logger.log(
        `Razorpay order created paymentId=${paymentRef.id} razorpayOrderId=${razorpayOrder.id}`,
      );

      return {
        success: true,

        paymentId: paymentRef.id,

        razorpayOrderId: razorpayOrder.id,

        keyId: this.razorpayKeyId,

        amount: amountInPaise,

        currency: 'INR',

        total: checkout.total,
      };
    } catch (error) {
      this.logger.error(
        `Error creating Razorpay order: ${
          error instanceof Error ? error.message : String(error)
        }`,
        error instanceof Error ? error.stack : undefined,
      );

      if (error instanceof BadRequestException) {
        throw error;
      }

      throw new BadRequestException('Failed to create Razorpay order');
    }
  }

  async verifyRazorpayPayment(
    uid: string,
    body: {
      paymentId: string;
      razorpayOrderId: string;
      razorpayPaymentId: string;
      razorpaySignature: string;
    },
  ) {
    this.logger.debug(
      `Starting Razorpay payment verification paymentId=${body?.paymentId ?? 'missing'} userId=${uid} razorpayOrderId=${body?.razorpayOrderId ?? 'missing'} razorpayPaymentId=${body?.razorpayPaymentId ?? 'missing'}`,
    );

    if (!body?.paymentId?.trim()) {
      throw new BadRequestException('Payment ID is required');
    }

    if (!body?.razorpayOrderId?.trim()) {
      throw new BadRequestException('Razorpay order ID is required');
    }

    if (!body?.razorpayPaymentId?.trim()) {
      throw new BadRequestException('Razorpay payment ID is required');
    }

    if (!body?.razorpaySignature?.trim()) {
      throw new BadRequestException('Razorpay signature is required');
    }

    const db = this.firebaseService.getFirestore();

    const paymentRef = db.collection('payments').doc(body.paymentId);

    const paymentSnapshot = await paymentRef.get();

    if (!paymentSnapshot.exists) {
      throw new NotFoundException('Payment not found');
    }

    const payment = paymentSnapshot.data();

    if (!payment) {
      throw new NotFoundException('Payment not found');
    }

    if (payment.customerId !== uid) {
      throw new NotFoundException('Payment not found');
    }

    // --------------------------------------------
    // IDEMPOTENCY
    // --------------------------------------------

    if (
      payment.status === 'PAID' &&
      typeof payment.orderId === 'string' &&
      payment.orderId.length > 0
    ) {
      return {
        success: true,
        paymentId: paymentRef.id,
        orderId: payment.orderId,
        status: 'PAID',
      };
    }

    if (payment.status === 'REFUND_PENDING' || payment.status === 'REFUNDED') {
      throw new BadRequestException(
        'This payment has already been submitted for refund',
      );
    }

    if (payment.status === 'REFUND_FAILED') {
      throw new BadRequestException(
        'This payment requires manual refund review',
      );
    }

    if (payment.provider !== 'RAZORPAY') {
      throw new BadRequestException('Invalid payment provider');
    }

    if (
      typeof payment.providerOrderId !== 'string' ||
      payment.providerOrderId.length === 0
    ) {
      throw new BadRequestException('Razorpay order information is missing');
    }

    if (payment.providerOrderId !== body.razorpayOrderId) {
      throw new BadRequestException('Razorpay order ID does not match');
    }

    // --------------------------------------------
    // SIGNATURE VERIFICATION
    // --------------------------------------------

    const keySecret = this.configService.get<string>('RAZORPAY_KEY_SECRET');

    if (!keySecret) {
      throw new Error('Razorpay secret configuration is missing');
    }

    const signaturePayload = `${payment.providerOrderId}|${body.razorpayPaymentId}`;

    const expectedSignature = createHmac('sha256', keySecret)
      .update(signaturePayload)
      .digest('hex');

    const receivedSignature = body.razorpaySignature.trim();

    if (!/^[a-fA-F0-9]+$/.test(receivedSignature)) {
      throw new BadRequestException('Invalid payment signature');
    }

    const expectedBuffer = Buffer.from(expectedSignature, 'hex');

    const receivedBuffer = Buffer.from(receivedSignature, 'hex');

    if (
      expectedBuffer.length !== receivedBuffer.length ||
      !timingSafeEqual(expectedBuffer, receivedBuffer)
    ) {
      throw new BadRequestException('Invalid payment signature');
    }

    this.logger.debug(
      `Razorpay signature verified paymentId=${paymentRef.id} razorpayPaymentId=${body.razorpayPaymentId}`,
    );

    // --------------------------------------------
    // VERIFY WITH RAZORPAY
    // --------------------------------------------

    const razorpayPayment = await this.razorpay.payments.fetch(
      body.razorpayPaymentId,
    );

    this.logger.debug(
      `Fetched Razorpay payment razorpayPaymentId=${body.razorpayPaymentId} orderId=${razorpayPayment.order_id} status=${razorpayPayment.status} amount=${razorpayPayment.amount} currency=${razorpayPayment.currency}`,
    );

    if (razorpayPayment.order_id !== payment.providerOrderId) {
      throw new BadRequestException(
        'Payment does not belong to this Razorpay order',
      );
    }

    const razorpayAmount = Number(razorpayPayment.amount);

    if (
      !Number.isFinite(razorpayAmount) ||
      razorpayAmount !== payment.amountInPaise
    ) {
      throw new BadRequestException('Payment amount does not match');
    }

    if (razorpayPayment.currency !== 'INR') {
      throw new BadRequestException('Invalid payment currency');
    }

    if (razorpayPayment.status !== 'captured') {
      throw new BadRequestException(
        `Payment is not captured. Current status: ${razorpayPayment.status}`,
      );
    }

    // --------------------------------------------
    // RESTORE CHECKOUT
    // --------------------------------------------

    const checkoutRequest = payment.checkoutRequest;

    if (
      !checkoutRequest ||
      typeof checkoutRequest.storeId !== 'string' ||
      typeof checkoutRequest.addressId !== 'string' ||
      !Array.isArray(checkoutRequest.items)
    ) {
      throw new BadRequestException('Stored checkout details are invalid');
    }

    const orderRequest: CreateOrderRequest = {
      storeId: checkoutRequest.storeId,

      addressId: checkoutRequest.addressId,

      items: checkoutRequest.items.map(
        (item: { id: string; quantity: number }) => ({
          id: item.id,
          quantity: item.quantity,
          name: '',
          price: 0,
        }),
      ),

      paymentMethod: 'ONLINE',
    };

    this.logger.log(
      `Creating verified online order paymentId=${paymentRef.id} razorpayPaymentId=${body.razorpayPaymentId}`,
    );

    // --------------------------------------------
    // CREATE ORDER
    // --------------------------------------------

    try {
      const result = await this.ordersService.createOrder(uid, orderRequest, {
        allowOnline: true,

        orderId: paymentRef.id,

        paymentId: paymentRef.id,

        providerPaymentId: body.razorpayPaymentId,

        expectedAmountInPaise: payment.amountInPaise,
      });

      const updatedAt = new Date().toISOString();

      await paymentRef.update({
        status: 'PAID',

        providerPaymentId: body.razorpayPaymentId,

        orderId: result.orderId,

        updatedAt,
      });

      this.logger.log(
        `Razorpay payment verified paymentId=${paymentRef.id} orderId=${result.orderId}`,
      );

      return {
        success: true,

        paymentId: paymentRef.id,

        razorpayPaymentId: body.razorpayPaymentId,

        orderId: result.orderId,

        status: 'PAID',

        order: result.order,
      };
    } catch (orderError) {
      const orderCreationFailedAt = new Date().toISOString();

      this.logger.error(
        `Order creation failed after captured payment paymentId=${paymentRef.id} razorpayPaymentId=${body.razorpayPaymentId}`,
        orderError instanceof Error ? orderError.stack : undefined,
      );

      /*
       * Mark as PAID first because Razorpay already
       * confirmed that the payment was captured.
       *
       * RazorpayRefundService only accepts PAID payments
       * for a new refund claim.
       */
      await paymentRef.update({
        status: 'PAID',

        providerPaymentId: body.razorpayPaymentId,

        orderCreationFailedAt,

        orderCreationStatus: 'FAILED',

        updatedAt: orderCreationFailedAt,
      });

      try {
        const refund = await this.razorpayRefundService.refundPayment(
          paymentRef.id,
          'ORDER_CREATION_FAILED',
        );

        this.logger.warn(
          `Refund requested after order creation failure paymentId=${paymentRef.id} status=${refund.status}`,
        );

        throw new BadRequestException(
          'Payment succeeded but order creation failed. Refund has been initiated.',
        );
      } catch (refundError) {
        if (refundError instanceof BadRequestException) {
          throw refundError;
        }

        this.logger.error(
          `Refund failed after order creation failure paymentId=${paymentRef.id}`,
          refundError instanceof Error
            ? refundError.stack
            : String(refundError),
        );

        throw new BadRequestException(
          'Payment succeeded but order creation failed. Refund requires manual review.',
        );
      }
    }
  }
  async handleRazorpayWebhook(
    rawBody: Buffer,
    receivedSignature: string,
    eventId: string,
  ) {
    const webhookSecret = this.configService.get<string>(
      'RAZORPAY_WEBHOOK_SECRET',
    );

    if (!webhookSecret) {
      throw new Error('Razorpay webhook configuration is missing');
    }

    // --------------------------------------------
    // VERIFY WEBHOOK SIGNATURE
    // --------------------------------------------

    const expectedSignature = createHmac('sha256', webhookSecret)
      .update(rawBody)
      .digest('hex');

    const signature = receivedSignature.trim();

    if (!/^[a-fA-F0-9]+$/.test(signature)) {
      throw new BadRequestException('Invalid webhook signature');
    }

    const expectedBuffer = Buffer.from(expectedSignature, 'hex');

    const receivedBuffer = Buffer.from(signature, 'hex');

    if (
      expectedBuffer.length !== receivedBuffer.length ||
      !timingSafeEqual(expectedBuffer, receivedBuffer)
    ) {
      this.logger.warn(`Invalid Razorpay webhook signature eventId=${eventId}`);

      throw new BadRequestException('Invalid webhook signature');
    }

    let webhook: RazorpayRefundWebhookPayload;

    try {
      webhook = JSON.parse(
        rawBody.toString('utf8'),
      ) as RazorpayRefundWebhookPayload;
    } catch {
      throw new BadRequestException('Invalid webhook payload');
    }

    this.logger.log(
      `Razorpay webhook received eventId=${eventId} event=${webhook.event}`,
    );

    const db = this.firebaseService.getFirestore();

    const webhookRef = db.collection('payment_webhook_events').doc(eventId);

    // --------------------------------------------
    // IDEMPOTENCY
    // --------------------------------------------

    const previousWebhook = await webhookRef.get();

    if (previousWebhook.exists) {
      this.logger.debug(
        `Duplicate Razorpay webhook ignored eventId=${eventId}`,
      );

      return {
        success: true,
        duplicate: true,
      };
    }

    // --------------------------------------------
    // ONLY HANDLE REFUND EVENTS FOR NOW
    // --------------------------------------------

    if (
      webhook.event !== 'refund.processed' &&
      webhook.event !== 'refund.failed'
    ) {
      await webhookRef.set({
        eventId,
        event: webhook.event,
        status: 'IGNORED',
        createdAt: new Date().toISOString(),
      });

      return {
        success: true,
        ignored: true,
      };
    }

    const refund = webhook.payload?.refund?.entity;

    if (!refund?.id || !refund.payment_id) {
      throw new BadRequestException('Refund information is missing');
    }

    // --------------------------------------------
    // FIND PAYMENT
    // --------------------------------------------

    let paymentQuery = await db
      .collection('payments')
      .where('providerRefundId', '==', refund.id)
      .limit(1)
      .get();

    /*
     * Webhook may arrive very quickly, before our
     * refund API response has finished updating
     * providerRefundId.
     *
     * Fall back to providerPaymentId.
     */
    if (paymentQuery.empty) {
      paymentQuery = await db
        .collection('payments')
        .where('providerPaymentId', '==', refund.payment_id)
        .limit(1)
        .get();
    }

    if (paymentQuery.empty) {
      this.logger.error(
        `Payment not found for Razorpay refund eventId=${eventId} refundId=${refund.id} razorpayPaymentId=${refund.payment_id}`,
      );

      /*
       * Throwing lets Razorpay retry the webhook
       * instead of permanently acknowledging it.
       */
      throw new BadRequestException('Payment not found for refund');
    }

    const paymentDoc = paymentQuery.docs[0];

    const paymentRef = paymentDoc.ref;

    const payment = paymentDoc.data();

    // --------------------------------------------
    // VALIDATE REFUND
    // --------------------------------------------

    if (payment.providerPaymentId !== refund.payment_id) {
      throw new BadRequestException('Refund payment ID does not match');
    }

    if (
      typeof payment.amountInPaise === 'number' &&
      refund.amount !== payment.amountInPaise
    ) {
      this.logger.error(
        `Refund amount mismatch paymentId=${paymentRef.id} expected=${payment.amountInPaise} received=${refund.amount}`,
      );

      throw new BadRequestException('Refund amount does not match');
    }

    const now = new Date().toISOString();

    // --------------------------------------------
    // ATOMIC WEBHOOK PROCESSING
    // --------------------------------------------

    await db.runTransaction(async (transaction) => {
      const webhookSnapshot = await transaction.get(webhookRef);

      if (webhookSnapshot.exists) {
        return;
      }

      const latestPaymentSnapshot = await transaction.get(paymentRef);

      if (!latestPaymentSnapshot.exists) {
        throw new BadRequestException('Payment not found');
      }

      const latestPayment = latestPaymentSnapshot.data();

      if (!latestPayment) {
        throw new BadRequestException('Payment not found');
      }

      if (webhook.event === 'refund.processed') {
        transaction.update(paymentRef, {
          status: 'REFUNDED',

          providerRefundId: refund.id,

          refundAmountInPaise: refund.amount,

          refundStatus: refund.status,

          refundedAt: now,

          updatedAt: now,
        });
      }

      if (webhook.event === 'refund.failed') {
        transaction.update(paymentRef, {
          status: 'REFUND_FAILED',

          providerRefundId: refund.id,

          refundAmountInPaise: refund.amount,

          refundStatus: refund.status,

          refundFailedAt: now,

          updatedAt: now,
        });
      }

      transaction.set(webhookRef, {
        eventId,

        event: webhook.event,

        paymentId: paymentRef.id,

        providerPaymentId: refund.payment_id,

        providerRefundId: refund.id,

        processedAt: now,

        status: 'PROCESSED',
      });
    });

    this.logger.log(
      `Razorpay webhook processed event=${webhook.event} paymentId=${paymentRef.id} refundId=${refund.id}`,
    );

    return {
      success: true,
    };
  }
}
