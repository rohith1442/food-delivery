import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { FirebaseService } from '../firebase/firebase.service.js';

export interface ReviewDocument {
  id: string;
  orderId: string;
  customerId: string;
  storeId: string;
  storeName: string;
  rating: number;
  comment: string;
  createdAt: string;
  updatedAt: string;
}

export interface OrderDocument {
  id: string;
  customerId: string;
  storeId: string;
  storeName: string;
  status: string;
}

@Injectable()
export class ReviewsService {
  constructor(
    private readonly firebaseService: FirebaseService,
  ) {}

  async createReview(
    customerId: string,
    data: {
      orderId: string;
      rating: number;
      comment?: string;
    },
  ) {
    const orderId = data.orderId?.trim();

    if (!orderId) {
      throw new BadRequestException('Order ID is required');
    }

    if (
      !Number.isInteger(data.rating) ||
      data.rating < 1 ||
      data.rating > 5
    ) {
      throw new BadRequestException('Rating must be between 1 and 5');
    }

    const comment = data.comment?.trim() ?? '';

    if (comment.length > 500) {
      throw new BadRequestException(
        'Review comment cannot exceed 500 characters',
      );
    }

    const db = this.firebaseService.getFirestore();
    const orderRef = db.collection('orders').doc(orderId);
    const reviewRef = db.collection('reviews').doc(orderId);

    const result = await db.runTransaction(async (transaction) => {
      const [orderSnapshot, existingReviewSnapshot] = await Promise.all([
        transaction.get(orderRef),
        transaction.get(reviewRef),
      ]);

      if (!orderSnapshot.exists) {
        throw new NotFoundException('Order not found');
      }

      const order = {
        ...(orderSnapshot.data() as OrderDocument),
        id: orderSnapshot.id,
      };

      if (order.customerId !== customerId) {
        throw new ForbiddenException('You cannot review this order');
      }

      if (order.status !== 'DELIVERED') {
        throw new BadRequestException(
          'Only delivered orders can be reviewed',
        );
      }

      if (existingReviewSnapshot.exists) {
        throw new BadRequestException('This order has already been reviewed');
      }

      const storeRef = db.collection('stores').doc(order.storeId);
      const storeSnapshot = await transaction.get(storeRef);

      if (!storeSnapshot.exists) {
        throw new NotFoundException('Store not found');
      }

      const storeData = storeSnapshot.data() ?? {};
      const currentRatingCount =
        typeof storeData.ratingCount === 'number'
            ? storeData.ratingCount
            : 0;
      const currentRatingAverage =
        typeof storeData.ratingAverage === 'number'
            ? storeData.ratingAverage
            : 0;
      const currentTotal = currentRatingAverage * currentRatingCount;
      const newRatingCount = currentRatingCount + 1;
      const newRatingAverage = Number(
        ((currentTotal + data.rating) / newRatingCount).toFixed(2),
      );
      const now = new Date().toISOString();

      const review: ReviewDocument = {
        id: reviewRef.id,
        orderId,
        customerId,
        storeId: order.storeId,
        storeName: order.storeName ?? 'Store',
        rating: data.rating,
        comment,
        createdAt: now,
        updatedAt: now,
      };

      transaction.set(reviewRef, review);
      transaction.update(storeRef, {
        ratingAverage: newRatingAverage,
        ratingCount: newRatingCount,
        updatedAt: now,
      });

      return {
        review,
        ratingAverage: newRatingAverage,
        ratingCount: newRatingCount,
      };
    });

    return {
      success: true,
      ...result,
    };
  }

  async getOrderReview(customerId: string, orderId: string) {
    const normalizedOrderId = orderId?.trim();

    if (!normalizedOrderId) {
      throw new BadRequestException('Order ID is required');
    }

    const db = this.firebaseService.getFirestore();
    const orderSnapshot = await db
      .collection('orders')
      .doc(normalizedOrderId)
      .get();

    if (!orderSnapshot.exists) {
      throw new NotFoundException('Order not found');
    }

    const order = orderSnapshot.data() as OrderDocument;

    if (order.customerId !== customerId) {
      throw new ForbiddenException('You cannot access this order review');
    }

    const reviewSnapshot = await db
      .collection('reviews')
      .doc(normalizedOrderId)
      .get();

    return {
      success: true,
      review: reviewSnapshot.exists
          ? { id: reviewSnapshot.id, ...reviewSnapshot.data() }
          : null,
    };
  }

  async getStoreReviews(storeId: string) {
    const normalizedStoreId = storeId?.trim();

    if (!normalizedStoreId) {
      throw new BadRequestException('Store ID is required');
    }

    const db = this.firebaseService.getFirestore();
    const storeSnapshot = await db
      .collection('stores')
      .doc(normalizedStoreId)
      .get();

    if (!storeSnapshot.exists) {
      throw new NotFoundException('Store not found');
    }

    const snapshot = await db
      .collection('reviews')
      .where('storeId', '==', normalizedStoreId)
      .get();

    const reviews = snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .sort((a: any, b: any) =>
        (b.createdAt ?? '').toString().localeCompare(
          (a.createdAt ?? '').toString(),
        ),
      );
    const store = storeSnapshot.data() ?? {};

    return {
      success: true,
      ratingAverage: store.ratingAverage ?? 0,
      ratingCount: store.ratingCount ?? 0,
      reviews,
    };
  }
}
