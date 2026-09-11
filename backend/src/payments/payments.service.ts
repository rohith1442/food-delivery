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
import {
  CreateOrderRequest,
  OrdersService,
} from '../orders/orders.service.js';

interface CreateRazorpayOrderRequest {
  storeId: string;
  addressId: string;
  items: Array<{
    id: string;
    quantity: number;
  }>;
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
  ) {
    const keyId =
      this.configService.get<string>('RAZORPAY_KEY_ID');

    const keySecret =
      this.configService.get<string>('RAZORPAY_KEY_SECRET');

    if (!keyId || !keySecret) {
      throw new Error(
        'Razorpay configuration is missing',
      );
    }

    this.razorpayKeyId = keyId;

    this.razorpay = new Razorpay({
      key_id: keyId,
      key_secret: keySecret,
    });
  }

  async createRazorpayOrder(
    uid: string,
    body: CreateRazorpayOrderRequest,
  ) {
    if (!body?.storeId?.trim()) {
      throw new BadRequestException(
        'Store ID is required',
      );
    }

    if (!body?.addressId?.trim()) {
      throw new BadRequestException(
        'Delivery address is required',
      );
    }

    if (!body?.items?.length) {
      throw new BadRequestException(
        'Order must contain items',
      );
    }

    /*
     * Build the same shape expected by OrdersService.
     *
     * Prices and names coming from the client are deliberately
     * not used. calculateCheckout() reads authoritative product
     * data from Firestore.
     */
    const checkoutRequest: CreateOrderRequest = {
      storeId: body.storeId,
      addressId: body.addressId,

      items: body.items.map((item) => ({
        id: item.id,
        quantity: item.quantity,

        // Not trusted/used by calculateCheckout().
        name: '',
        price: 0,
      })),

      paymentMethod: 'ONLINE',
    };

    const checkout =
      await this.ordersService.calculateCheckout(
        uid,
        checkoutRequest,
      );

    /*
     * Razorpay expects amount in the smallest currency unit.
     *
     * ₹100.50 => 10050 paise
     */
    const amountInPaise = Math.round(
      checkout.total * 100,
    );

    if (
      !Number.isInteger(amountInPaise) ||
      amountInPaise <= 0
    ) {
      throw new BadRequestException(
        'Invalid payment amount',
      );
    }

    const db = this.firebaseService.getFirestore();

    const paymentRef =
      db.collection('payments').doc();

    const now = new Date().toISOString();

    this.logger.log(
      `Creating Razorpay order paymentId=${paymentRef.id} userId=${uid} amount=${amountInPaise}`,
    );

    const razorpayOrder =
      await this.razorpay.orders.create({
        amount: amountInPaise,
        currency: 'INR',

        /*
         * Our Firestore payment ID gives us a unique
         * reference which can later be correlated with
         * Razorpay.
         */
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
  if (!body?.paymentId?.trim()) {
    throw new BadRequestException(
      'Payment ID is required',
    );
  }

  if (!body?.razorpayOrderId?.trim()) {
    throw new BadRequestException(
      'Razorpay order ID is required',
    );
  }

  if (!body?.razorpayPaymentId?.trim()) {
    throw new BadRequestException(
      'Razorpay payment ID is required',
    );
  }

  if (!body?.razorpaySignature?.trim()) {
    throw new BadRequestException(
      'Razorpay signature is required',
    );
  }

  const db =
    this.firebaseService.getFirestore();

  const paymentRef = db
    .collection('payments')
    .doc(body.paymentId);

  const paymentSnapshot =
    await paymentRef.get();

  if (!paymentSnapshot.exists) {
    throw new NotFoundException(
      'Payment not found',
    );
  }

  const payment =
    paymentSnapshot.data();

  if (!payment) {
    throw new NotFoundException(
      'Payment not found',
    );
  }

  // Do not expose whether somebody else's
  // payment ID exists.
  if (payment.customerId !== uid) {
    throw new NotFoundException(
      'Payment not found',
    );
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

  if (payment.provider !== 'RAZORPAY') {
    throw new BadRequestException(
      'Invalid payment provider',
    );
  }

  if (
    typeof payment.providerOrderId !== 'string' ||
    payment.providerOrderId.length === 0
  ) {
    throw new BadRequestException(
      'Razorpay order information is missing',
    );
  }

  /*
   * Compare the client order ID with the order ID
   * that WE originally stored.
   *
   * Do not trust the client's order ID as the source
   * for signature generation.
   */
  if (
    payment.providerOrderId !==
    body.razorpayOrderId
  ) {
    throw new BadRequestException(
      'Razorpay order ID does not match',
    );
  }

  // --------------------------------------------
  // SIGNATURE VERIFICATION
  // --------------------------------------------

  const keySecret =
    this.configService.get<string>(
      'RAZORPAY_KEY_SECRET',
    );

  if (!keySecret) {
    throw new Error(
      'Razorpay secret configuration is missing',
    );
  }

  const signaturePayload =
    `${payment.providerOrderId}|${body.razorpayPaymentId}`;

  const expectedSignature =
    createHmac('sha256', keySecret)
      .update(signaturePayload)
      .digest('hex');

  const receivedSignature =
    body.razorpaySignature.trim();

  if (
    !/^[a-fA-F0-9]+$/.test(
      receivedSignature,
    )
  ) {
    throw new BadRequestException(
      'Invalid payment signature',
    );
  }

  const expectedBuffer =
    Buffer.from(
      expectedSignature,
      'hex',
    );

  const receivedBuffer =
    Buffer.from(
      receivedSignature,
      'hex',
    );

  if (
    expectedBuffer.length !==
      receivedBuffer.length ||
    !timingSafeEqual(
      expectedBuffer,
      receivedBuffer,
    )
  ) {
    throw new BadRequestException(
      'Invalid payment signature',
    );
  }

  // --------------------------------------------
  // VERIFY PAYMENT DIRECTLY WITH RAZORPAY
  // --------------------------------------------

  const razorpayPayment =
    await this.razorpay.payments.fetch(
      body.razorpayPaymentId,
    );

  if (
    razorpayPayment.order_id !==
    payment.providerOrderId
  ) {
    throw new BadRequestException(
      'Payment does not belong to this Razorpay order',
    );
  }

  const razorpayAmount =
    Number(razorpayPayment.amount);

  if (
    !Number.isFinite(razorpayAmount) ||
    razorpayAmount !==
      payment.amountInPaise
  ) {
    throw new BadRequestException(
      'Payment amount does not match',
    );
  }

  if (
    razorpayPayment.currency !== 'INR'
  ) {
    throw new BadRequestException(
      'Invalid payment currency',
    );
  }

  /*
   * For now require a captured payment before
   * creating the food order.
   *
   * Razorpay payment statuses include:
   * created, authorized, captured, refunded, failed.
   */
  if (
    razorpayPayment.status !== 'captured'
  ) {
    throw new BadRequestException(
      `Payment is not captured. Current status: ${razorpayPayment.status}`,
    );
  }

  // --------------------------------------------
  // RESTORE ORIGINAL CHECKOUT REQUEST
  // --------------------------------------------

  const checkoutRequest =
    payment.checkoutRequest;

  if (
    !checkoutRequest ||
    typeof checkoutRequest.storeId !==
      'string' ||
    typeof checkoutRequest.addressId !==
      'string' ||
    !Array.isArray(
      checkoutRequest.items,
    )
  ) {
    throw new BadRequestException(
      'Stored checkout details are invalid',
    );
  }

  const orderRequest: CreateOrderRequest =
    {
      storeId:
        checkoutRequest.storeId,

      addressId:
        checkoutRequest.addressId,

      items:
        checkoutRequest.items.map(
          (item: {
            id: string;
            quantity: number;
          }) => ({
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
  // CREATE ACTUAL ORDER
  // --------------------------------------------

  const result =
    await this.ordersService.createOrder(
      uid,
      orderRequest,
      {
        allowOnline: true,

        /*
         * Deterministic order ID.
         * Repeated verification cannot create
         * multiple orders.
         */
        orderId: paymentRef.id,

        paymentId:
          paymentRef.id,

        providerPaymentId:
          body.razorpayPaymentId,

        /*
         * Protect against price / fee changes
         * between payment initiation and verification.
         */
        expectedAmountInPaise:
          payment.amountInPaise,
      },
    );

  // --------------------------------------------
  // LINK PAYMENT -> ORDER
  // --------------------------------------------

  const updatedAt =
    new Date().toISOString();

  await paymentRef.update({
    status: 'PAID',

    providerPaymentId:
      body.razorpayPaymentId,

    orderId:
      result.orderId,

    updatedAt,
  });

  this.logger.log(
    `Razorpay payment verified paymentId=${paymentRef.id} orderId=${result.orderId}`,
  );

  return {
    success: true,

    paymentId:
      paymentRef.id,

    razorpayPaymentId:
      body.razorpayPaymentId,

    orderId:
      result.orderId,

    status: 'PAID',

    order: result.order,
  };
}
}