import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Razorpay from 'razorpay';

import { FirebaseService } from '../firebase/firebase.service.js';

@Injectable()
export class RazorpayRefundService {
  private readonly logger = new Logger(RazorpayRefundService.name);

  private readonly razorpay: Razorpay;

  constructor(
    private readonly configService: ConfigService,
    private readonly firebaseService: FirebaseService,
  ) {
    const keyId =
      this.configService.get<string>('RAZORPAY_KEY_ID');

    const keySecret =
      this.configService.get<string>('RAZORPAY_KEY_SECRET');

    if (!keyId || !keySecret) {
      throw new Error('Razorpay configuration is missing');
    }

    this.razorpay = new Razorpay({
      key_id: keyId,
      key_secret: keySecret,
    });
  }

  async refundPayment(
  paymentId: string,
  reason: string,
) {
  const db = this.firebaseService.getFirestore();

  const paymentRef = db
    .collection('payments')
    .doc(paymentId);

  // --------------------------------------------------
  // ATOMICALLY CLAIM REFUND
  // --------------------------------------------------

  const claimResult = await db.runTransaction(
    async (transaction) => {
      const snapshot =
        await transaction.get(paymentRef);

      if (!snapshot.exists) {
        throw new NotFoundException(
          'Payment not found',
        );
      }

      const payment = snapshot.data();

      if (!payment) {
        throw new NotFoundException(
          'Payment not found',
        );
      }

      // ----------------------------------------------
      // ALREADY REFUNDED
      // ----------------------------------------------

      if (payment.status === 'REFUNDED') {
        return {
          action: 'ALREADY_REFUNDED' as const,

          providerRefundId:
            payment.providerRefundId ?? null,
        };
      }

      // ----------------------------------------------
      // REFUND ALREADY SUBMITTED
      // ----------------------------------------------

      if (
        payment.status ===
        'REFUND_PENDING'
      ) {
        return {
          action: 'REFUND_PENDING' as const,

          providerRefundId:
            payment.providerRefundId ?? null,
        };
      }

      // ----------------------------------------------
      // ANOTHER REQUEST CURRENTLY OWNS REFUND
      // ----------------------------------------------

      if (
        payment.status ===
        'REFUND_PROCESSING'
      ) {
        return {
          action: 'REFUND_PROCESSING' as const,

          providerRefundId:
            payment.providerRefundId ?? null,
        };
      }

      // ----------------------------------------------
      // FAILED/AMBIGUOUS REFUND
      //
      // Do not automatically retry here because the
      // previous Razorpay request may have succeeded
      // even if our API call timed out.
      // ----------------------------------------------

      if (
        payment.status ===
        'REFUND_FAILED'
      ) {
        return {
          action: 'REFUND_FAILED' as const,

          providerRefundId:
            payment.providerRefundId ?? null,
        };
      }

      if (payment.status !== 'PAID') {
        throw new BadRequestException(
          `Payment cannot be refunded from status ${payment.status}`,
        );
      }

      if (
        typeof payment.providerPaymentId !==
          'string' ||
        payment.providerPaymentId.length === 0
      ) {
        throw new BadRequestException(
          'Razorpay payment ID is missing',
        );
      }

      if (
        typeof payment.amountInPaise !==
          'number' ||
        !Number.isInteger(
          payment.amountInPaise,
        ) ||
        payment.amountInPaise <= 0
      ) {
        throw new BadRequestException(
          'Invalid payment amount',
        );
      }

      const refundRequestedAt =
        new Date().toISOString();

      /*
       * Only one concurrent request can change
       * PAID -> REFUND_PROCESSING.
       *
       * Firestore retries this transaction if
       * another request modifies the payment.
       */
      transaction.update(
        paymentRef,
        {
          status: 'REFUND_PROCESSING',

          refundReason: reason,

          refundRequestedAt,

          updatedAt:
            refundRequestedAt,
        },
      );

      return {
        action: 'CREATE_REFUND' as const,

        providerPaymentId:
          payment.providerPaymentId as string,

        amountInPaise:
          payment.amountInPaise as number,
      };
    },
  );

  // --------------------------------------------------
  // IDEMPOTENT RETURNS
  // --------------------------------------------------

  if (
    claimResult.action ===
    'ALREADY_REFUNDED'
  ) {
    return {
      success: true,

      status: 'REFUNDED',

      providerRefundId:
        claimResult.providerRefundId,
    };
  }

  if (
    claimResult.action ===
    'REFUND_PENDING'
  ) {
    return {
      success: true,

      status: 'REFUND_PENDING',

      providerRefundId:
        claimResult.providerRefundId,
    };
  }

  if (
    claimResult.action ===
    'REFUND_PROCESSING'
  ) {
    return {
      success: true,

      status: 'REFUND_PROCESSING',

      providerRefundId:
        claimResult.providerRefundId,
    };
  }

  if (
    claimResult.action ===
    'REFUND_FAILED'
  ) {
    return {
      success: false,

      status: 'REFUND_FAILED',

      providerRefundId:
        claimResult.providerRefundId,
    };
  }

  // --------------------------------------------------
  // ONLY THE REQUEST THAT CLAIMED THE PAYMENT
  // REACHES RAZORPAY
  // --------------------------------------------------

  try {
    this.logger.warn(
      `Initiating Razorpay refund paymentId=${paymentId} providerPaymentId=${claimResult.providerPaymentId} reason=${reason}`,
    );

    const refund =
      await this.razorpay.payments.refund(
        claimResult.providerPaymentId,
        {
          amount:
            claimResult.amountInPaise,

          notes: {
            reason,
            paymentId,
          },

          receipt:
            `refund_${paymentId}`,
        },
      );

    const updatedAt =
      new Date().toISOString();

    await paymentRef.update({
      status: 'REFUND_PENDING',

      providerRefundId:
        refund.id,

      refundAmountInPaise:
        claimResult.amountInPaise,

      refundStatus:
        refund.status ?? null,

      refundCreatedAt:
        updatedAt,

      updatedAt,
    });

    this.logger.warn(
      `Razorpay refund initiated paymentId=${paymentId} refundId=${refund.id}`,
    );

    return {
      success: true,

      status: 'REFUND_PENDING',

      providerRefundId:
        refund.id,
    };
  } catch (error) {
    const failedAt =
      new Date().toISOString();

    /*
     * Important:
     *
     * An API/network failure can be ambiguous.
     * Razorpay may have received the refund even
     * when our request timed out.
     *
     * We therefore do not automatically retry.
     * The webhook can still change this payment
     * to REFUNDED if Razorpay later confirms it.
     */
    await paymentRef.update({
      status: 'REFUND_FAILED',

      refundFailedAt:
        failedAt,

      updatedAt:
        failedAt,
    });

    this.logger.error(
      `Razorpay refund request failed paymentId=${paymentId}`,
      error instanceof Error
        ? error.stack
        : String(error),
    );

    throw error;
  }
}
}