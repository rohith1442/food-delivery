import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  createHmac,
  randomInt,
  timingSafeEqual,
} from 'node:crypto';

import { FirebaseService } from '../firebase/firebase.service.js';
import { RazorpayRefundService } from '../payments/razorpay-refund.service.js';
import { NotificationsService } from '../notifications/notifications.service.js';

export interface PrepareCheckoutRequest {
  storeId: string;
  items: CreateOrderItem[];
  addressId: string;
}

export interface PreparedCheckout {
  storeId: string;
  customerId: string;
  subtotal: number;
  deliveryFee: number;
  total: number;
}

export interface CreateOrderItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
}

export interface CreateOrderRequest {
  storeId: string;

  items: CreateOrderItem[];

  addressId: string;

  paymentMethod: string;

  // These are still accepted for compatibility with
  // the current Flutter app, but the backend does NOT
  // trust or use them for order pricing.
  subtotal?: number;
  deliveryFee?: number;
  total?: number;
}

export interface OrderDeliveryAddress {
  addressId: string;
  label: string;
  address: string;
  latitude: number;
  longitude: number;
  zoneId: string;
}

export interface OrderDocument {
  id: string;

  customerId: string;

  storeId: string;
  storeName: string;
  storeAddress: string;
  storeLocation: OrderStoreLocation;

  merchantId: string;

  riderId?: string | null;

  items: CreateOrderItem[];

  deliveryAddress: OrderDeliveryAddress;

  paymentMethod: string;

  paymentStatus: 'PENDING' | 'PAID' | 'FAILED';

  paymentId?: string | null;

  providerPaymentId?: string | null;

  subtotal: number;
  deliveryFee: number;
  total: number;

  status: string;

  createdAt: string;
  updatedAt: string;

  /**
   * Kept only for compatibility with legacy orders.
   * New OTPs must never be stored in plaintext.
   */
  deliveryOtp?: string | null;
  deliveryOtpHash?: string | null;
  deliveryOtpCreatedAt?: string | null;
  deliveryOtpExpiresAt?: string | null;
  deliveryOtpAttempts?: number | null;
  deliveryOtpLockedUntil?: string | null;
}

interface StoreDocument {
  id: string;
  merchantId: string;
  name: string;
  moduleId: string;
  zoneId: string;
  address: string;
  latitude: number | null;
  longitude: number | null;
  minimumOrder: number;
  isActive: boolean;
  isOpen: boolean;
}

interface ProductDocument {
  id: string;
  storeId: string;
  merchantId: string;
  moduleId: string;
  categoryId: string;
  name: string;
  description?: string;
  price: number;
  stock: number;
  imageUrl?: string | null;
  isAvailable: boolean;
}

interface AddressDocument {
  id: string;
  userId: string;
  label: string;
  address: string;
  latitude: number;
  longitude: number;
  zoneId: string;
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface OrderStoreLocation {
  latitude: number;
  longitude: number;
}

@Injectable()
export class OrdersService {
  private readonly logger = new Logger(OrdersService.name);

  private static readonly DELIVERY_OTP_LENGTH = 4;

  private static readonly DELIVERY_OTP_EXPIRY_MS =
    10 * 60 * 1000;

  private static readonly DELIVERY_OTP_MAX_ATTEMPTS = 5;

  private static readonly DELIVERY_OTP_LOCK_MS =
    10 * 60 * 1000;

  constructor(
    private readonly firebaseService: FirebaseService,
    private readonly razorpayRefundService: RazorpayRefundService,
    private readonly notificationsService: NotificationsService,
    private readonly configService: ConfigService,
  ) {}

  // --------------------------------------------------
  // CUSTOMER
  // --------------------------------------------------

  async createOrder(
    uid: string,
    data: CreateOrderRequest,
    options?: {
      allowOnline?: boolean;
      orderId?: string;
      paymentId?: string;
      providerPaymentId?: string;
      expectedAmountInPaise?: number;
    },
  ) {
    this.logger.log(
      `Create order request received userId=${uid} storeId=${data.storeId}`,
    );

    try {
      if (!data.storeId?.trim()) {
        this.logger.warn(`Create order failed: storeId missing userId=${uid}`);
        throw new BadRequestException('Store ID is required');
      }

      if (!data.items?.length) {
        this.logger.warn(`Create order failed: no items userId=${uid}`);
        throw new BadRequestException('Order must contain items');
      }

      if (!data.addressId?.trim()) {
        this.logger.warn(
          `Create order failed: addressId missing userId=${uid}`,
        );

        throw new BadRequestException('Delivery address is required');
      }

      if (!data.paymentMethod?.trim()) {
        this.logger.warn(
          `Create order failed: payment method missing userId=${uid}`,
        );

        throw new BadRequestException('Payment method is required');
      }

      const paymentMethod = data.paymentMethod.trim().toUpperCase();

      if (!['COD', 'ONLINE'].includes(paymentMethod)) {
        throw new BadRequestException('Payment method must be COD or ONLINE');
      }

      if (paymentMethod === 'ONLINE' && options?.allowOnline !== true) {
        throw new BadRequestException(
          'Online orders must be created through payment verification',
        );
      }

      const requestedProductIds = new Set<string>();

      for (const item of data.items) {
        if (!item.id?.trim()) {
          throw new BadRequestException('Product ID is required');
        }

        if (!Number.isInteger(item.quantity) || item.quantity <= 0) {
          throw new BadRequestException(
            `Invalid quantity for product ${item.id}`,
          );
        }

        if (requestedProductIds.has(item.id)) {
          throw new BadRequestException(`Duplicate product ${item.id}`);
        }

        requestedProductIds.add(item.id);
      }

      const db = this.firebaseService.getFirestore();

      const storeRef = db.collection('stores').doc(data.storeId);

      const addressRef = db.collection('addresses').doc(data.addressId);

      const orderRef = options?.orderId
        ? db.collection('orders').doc(options.orderId)
        : db.collection('orders').doc();

      const now = new Date().toISOString();

      const result = await db.runTransaction(async (transaction) => {
        // --------------------------------------------
        // IDEMPOTENCY
        // --------------------------------------------

        const existingOrderSnapshot = await transaction.get(orderRef);

        if (existingOrderSnapshot.exists) {
          const existingOrder = {
            id: existingOrderSnapshot.id,
            ...existingOrderSnapshot.data(),
          } as OrderDocument;

          if (existingOrder.customerId !== uid) {
            throw new ForbiddenException('Order already exists');
          }

          return {
            order: existingOrder,
            created: false,
          };
        }

        // --------------------------------------------
        // STORE + ADDRESS
        // --------------------------------------------

        const storeSnapshot = await transaction.get(storeRef);

        const addressSnapshot = await transaction.get(addressRef);

        if (!storeSnapshot.exists) {
          throw new NotFoundException('Store not found');
        }

        if (!addressSnapshot.exists) {
          throw new NotFoundException('Delivery address not found');
        }

        const store = {
          id: storeSnapshot.id,
          ...storeSnapshot.data(),
        } as StoreDocument;

        const deliveryAddress = {
          id: addressSnapshot.id,
          ...addressSnapshot.data(),
        } as AddressDocument;

        if (deliveryAddress.userId !== uid) {
          throw new NotFoundException('Delivery address not found');
        }

        if (!store.isActive) {
          throw new BadRequestException('Store is currently unavailable');
        }

        if (!store.isOpen) {
          throw new BadRequestException('Store is currently closed');
        }

        if (
          !deliveryAddress.zoneId ||
          deliveryAddress.zoneId !== store.zoneId
        ) {
          throw new BadRequestException(
            'Store does not deliver to the selected address',
          );
        }

        // --------------------------------------------
        // PRODUCTS
        // --------------------------------------------

        const productRefs = data.items.map((item) =>
          db
            .collection('stores')
            .doc(store.id)
            .collection('products')
            .doc(item.id),
        );

        const productSnapshots = await Promise.all(
          productRefs.map((productRef) => transaction.get(productRef)),
        );

        const authoritativeItems: CreateOrderItem[] = [];

        for (let index = 0; index < productSnapshots.length; index++) {
          const productSnapshot = productSnapshots[index];

          const requestedItem = data.items[index];

          if (!productSnapshot.exists) {
            throw new NotFoundException(
              `Product ${requestedItem.id} not found`,
            );
          }

          const product = {
            id: productSnapshot.id,
            ...productSnapshot.data(),
          } as ProductDocument;

          if (!product.isAvailable) {
            throw new BadRequestException(
              `${product.name} is currently unavailable`,
            );
          }

          if (
            typeof product.price !== 'number' ||
            !Number.isFinite(product.price) ||
            product.price < 0
          ) {
            throw new BadRequestException(
              `Invalid price configured for ${product.name}`,
            );
          }

          if (
            typeof product.stock !== 'number' ||
            product.stock < requestedItem.quantity
          ) {
            throw new BadRequestException(
              `Insufficient stock for ${product.name}`,
            );
          }

          authoritativeItems.push({
            id: product.id,
            name: product.name,
            price: product.price,
            quantity: requestedItem.quantity,
          });
        }

        // --------------------------------------------
        // PRICING
        // --------------------------------------------

        const subtotal = authoritativeItems.reduce(
          (sum, item) => sum + item.price * item.quantity,
          0,
        );

        if (store.minimumOrder > 0 && subtotal < store.minimumOrder) {
          throw new BadRequestException(
            `Minimum order amount is ₹${store.minimumOrder}`,
          );
        }

        const deliveryFee = await this.getDeliveryFee();

        const total = subtotal + deliveryFee;

        if (!Number.isFinite(total) || total <= 0) {
          throw new BadRequestException('Invalid order total');
        }

        if (
          paymentMethod === 'ONLINE' &&
          options?.expectedAmountInPaise !== undefined
        ) {
          const calculatedAmountInPaise = Math.round(total * 100);

          if (calculatedAmountInPaise !== options.expectedAmountInPaise) {
            throw new BadRequestException(
              'Order amount changed after payment was initiated',
            );
          }
        }

        // --------------------------------------------
        // DELIVERY ADDRESS SNAPSHOT
        // --------------------------------------------

        const authoritativeDeliveryAddress: OrderDeliveryAddress = {
          addressId: deliveryAddress.id,
          label: deliveryAddress.label,
          address: deliveryAddress.address,
          latitude: deliveryAddress.latitude,
          longitude: deliveryAddress.longitude,
          zoneId: deliveryAddress.zoneId,
        };

        // --------------------------------------------
        // STORE LOCATION
        // --------------------------------------------

        if (
          typeof store.latitude !== 'number' ||
          !Number.isFinite(store.latitude) ||
          store.latitude < -90 ||
          store.latitude > 90 ||
          typeof store.longitude !== 'number' ||
          !Number.isFinite(store.longitude) ||
          store.longitude < -180 ||
          store.longitude > 180
        ) {
          throw new BadRequestException('Store location is not configured');
        }

        // --------------------------------------------
        // CREATE ORDER
        // --------------------------------------------

        const newOrder: OrderDocument = {
          id: orderRef.id,

          customerId: uid,

          storeId: store.id,
          storeName: store.name,
          storeAddress: store.address,

          storeLocation: {
            latitude: store.latitude,
            longitude: store.longitude,
          },

          merchantId: store.merchantId,

          riderId: null,

          items: authoritativeItems,

          deliveryAddress: authoritativeDeliveryAddress,

          paymentMethod,

          paymentStatus: paymentMethod === 'ONLINE' ? 'PAID' : 'PENDING',

          paymentId: options?.paymentId ?? null,

          providerPaymentId: options?.providerPaymentId ?? null,

          subtotal,
          deliveryFee,
          total,

          status: 'VENDOR_PENDING',

          createdAt: now,
          updatedAt: now,

          deliveryOtp: null,
          deliveryOtpHash: null,
          deliveryOtpCreatedAt: null,
          deliveryOtpExpiresAt: null,
          deliveryOtpAttempts: 0,
          deliveryOtpLockedUntil: null,
        };

        // --------------------------------------------
        // DECREMENT STOCK
        // --------------------------------------------

        for (let index = 0; index < productSnapshots.length; index++) {
          const product = productSnapshots[index].data() as ProductDocument;

          const requestedItem = data.items[index];

          const newStock = product.stock - requestedItem.quantity;

          transaction.update(productRefs[index], {
            stock: newStock,

            ...(newStock === 0
              ? {
                  isAvailable: false,
                }
              : {}),

            updatedAt: now,
          });
        }

        transaction.set(orderRef, newOrder);

        return {
          order: newOrder,
          created: true,
        };
      });

      const { order, created } = result;

      if (created) {
        await this.notificationsService.sendToUser(order.merchantId, {
          title: 'New Order',
          body: `You received a new order from ${order.storeName}`,
          data: {
            type: 'NEW_ORDER',
            orderId: order.id,
            storeId: order.storeId,
          },
        });
      }

      this.logger.log(
        `Order created successfully orderId=${order.id} userId=${uid} total=${order.total}`,
      );

      return {
        success: true,
        orderId: order.id,
        order,
      };
    } catch (error) {
      if (
        error instanceof BadRequestException ||
        error instanceof NotFoundException ||
        error instanceof ForbiddenException
      ) {
        this.logger.warn(
          `Create order failed userId=${uid} storeId=${data.storeId}: ${error.message}`,
        );

        throw error;
      }

      this.logger.error(
        `Unexpected create order failure userId=${uid} storeId=${data.storeId}`,
        error instanceof Error ? error.stack : String(error),
      );

      throw error;
    }
  }

  async calculateCheckout(
    uid: string,
    data: CreateOrderRequest,
  ): Promise<{
    storeId: string;
    customerId: string;
    subtotal: number;
    deliveryFee: number;
    total: number;
  }> {
    if (!data.storeId?.trim()) {
      throw new BadRequestException('Store ID is required');
    }

    if (!data.items?.length) {
      throw new BadRequestException('Order must contain items');
    }

    if (!data.addressId?.trim()) {
      throw new BadRequestException('Delivery address is required');
    }

    const requestedProductIds = new Set<string>();

    for (const item of data.items) {
      if (!item.id?.trim()) {
        throw new BadRequestException('Product ID is required');
      }

      if (!Number.isInteger(item.quantity) || item.quantity <= 0) {
        throw new BadRequestException(
          `Invalid quantity for product ${item.id}`,
        );
      }

      if (requestedProductIds.has(item.id)) {
        throw new BadRequestException(`Duplicate product ${item.id}`);
      }

      requestedProductIds.add(item.id);
    }

    const db = this.firebaseService.getFirestore();

    const storeSnapshot = await db.collection('stores').doc(data.storeId).get();

    if (!storeSnapshot.exists) {
      throw new NotFoundException('Store not found');
    }

    const store = {
      id: storeSnapshot.id,
      ...storeSnapshot.data(),
    } as StoreDocument;

    if (!store.isActive) {
      throw new BadRequestException('Store is currently unavailable');
    }

    if (!store.isOpen) {
      throw new BadRequestException('Store is currently closed');
    }

    const addressSnapshot = await db
      .collection('addresses')
      .doc(data.addressId)
      .get();

    if (!addressSnapshot.exists) {
      throw new NotFoundException('Delivery address not found');
    }

    const deliveryAddress = {
      id: addressSnapshot.id,
      ...addressSnapshot.data(),
    } as AddressDocument;

    if (deliveryAddress.userId !== uid) {
      throw new NotFoundException('Delivery address not found');
    }

    if (!deliveryAddress.zoneId || deliveryAddress.zoneId !== store.zoneId) {
      throw new BadRequestException(
        'Store does not deliver to the selected address',
      );
    }

    let subtotal = 0;

    for (const item of data.items) {
      const productSnapshot = await db
        .collection('stores')
        .doc(store.id)
        .collection('products')
        .doc(item.id)
        .get();

      if (!productSnapshot.exists) {
        throw new NotFoundException(`Product ${item.id} not found`);
      }

      const product = {
        id: productSnapshot.id,
        ...productSnapshot.data(),
      } as ProductDocument;

      if (!product.isAvailable) {
        throw new BadRequestException(
          `${product.name} is currently unavailable`,
        );
      }

      if (
        typeof product.price !== 'number' ||
        !Number.isFinite(product.price) ||
        product.price < 0
      ) {
        throw new BadRequestException(
          `Invalid price configured for ${product.name}`,
        );
      }

      if (typeof product.stock !== 'number' || product.stock < item.quantity) {
        throw new BadRequestException(`Insufficient stock for ${product.name}`);
      }

      subtotal += product.price * item.quantity;
    }

    if (store.minimumOrder > 0 && subtotal < store.minimumOrder) {
      throw new BadRequestException(
        `Minimum order amount is ₹${store.minimumOrder}`,
      );
    }

    const deliveryFee = await this.getDeliveryFee();

    const total = subtotal + deliveryFee;

    if (!Number.isFinite(total) || total <= 0) {
      throw new BadRequestException('Invalid order total');
    }

    return {
      storeId: store.id,
      customerId: uid,
      subtotal,
      deliveryFee,
      total,
    };
  }

  async getCustomerOrders(uid: string) {
    const db = this.firebaseService.getFirestore();

    const snapshot = await db
      .collection('orders')
      .where('customerId', '==', uid)
      .get();

    const orders: OrderDocument[] = snapshot.docs.map((doc) => {
      const data = doc.data() as Omit<OrderDocument, 'id'>;

      return {
        id: doc.id,
        ...data,
      };
    });

    orders.sort((a, b) => b.createdAt.localeCompare(a.createdAt));

    return {
      success: true,
      orders,
    };
  }

  async getCustomerOrder(uid: string, orderId: string) {
    const db = this.firebaseService.getFirestore();

    const orderRef = db.collection('orders').doc(orderId);

    const snapshot = await orderRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException('Order not found');
    }

    const data = snapshot.data() as Omit<OrderDocument, 'id'>;

    const order: OrderDocument = {
      id: snapshot.id,
      ...data,
    };

    if (order.customerId !== uid) {
      throw new NotFoundException('Order not found');
    }

    return {
      success: true,
      order,
    };
  }

  // --------------------------------------------------
  // MERCHANT
  // --------------------------------------------------

  async getMerchantOrders(merchantId: string) {
    const db = this.firebaseService.getFirestore();

    /*
     * Keep the Firestore query simple.
     *
     * We query by merchantId and filter
     * the small MVP result set in memory.
     *
     * This also avoids immediately requiring
     * a merchantId + status composite index.
     */
    const snapshot = await db
      .collection('orders')
      .where('merchantId', '==', merchantId)
      .get();

    const merchantStatuses = [
      'VENDOR_PENDING',
      'ACCEPTED',
      'PREPARING',
      'READY',
    ];

    const orders: OrderDocument[] = snapshot.docs
      .map((doc) => {
        const data = doc.data() as Omit<OrderDocument, 'id'>;

        return {
          id: doc.id,
          ...data,
        };
      })
      .filter((order) => merchantStatuses.includes(order.status));

    orders.sort((a, b) => b.createdAt.localeCompare(a.createdAt));

    return {
      success: true,
      orders,
    };
  }

  async updateOrderStatus(merchantId: string, orderId: string, status: string) {
    const allowedStatuses = ['ACCEPTED', 'REJECTED', 'PREPARING', 'READY'];

    if (!allowedStatuses.includes(status)) {
      throw new BadRequestException('Invalid order status');
    }

    const db = this.firebaseService.getFirestore();

    const orderRef = db.collection('orders').doc(orderId);

    this.logger.log(
      `Merchant status update received merchantId=${merchantId} orderId=${orderId} status=${status}`,
    );

    try {
      // --------------------------------------------------
      // REJECTED
      // --------------------------------------------------

      if (status === 'REJECTED') {
        const updatedAt = new Date().toISOString();

        /*
         * We need these after the transaction finishes.
         *
         * Do NOT call Razorpay from inside a Firestore
         * transaction because Firestore may retry the
         * transaction callback.
         */
        let rejectedOrder: OrderDocument | undefined;

        await db.runTransaction(async (transaction) => {
          const orderSnapshot = await transaction.get(orderRef);

          if (!orderSnapshot.exists) {
            throw new NotFoundException('Order not found');
          }

          const order = {
            id: orderSnapshot.id,
            ...orderSnapshot.data(),
          } as OrderDocument;

          if (order.merchantId !== merchantId) {
            throw new ForbiddenException(
              'You do not have access to this order',
            );
          }

          if (order.status !== 'VENDOR_PENDING') {
            throw new BadRequestException(
              `Cannot change order from ${order.status} to REJECTED`,
            );
          }

          // ---------------------------------------------
          // READ PRODUCTS
          // ---------------------------------------------

          const productRefs = order.items.map((item) =>
            db
              .collection('stores')
              .doc(order.storeId)
              .collection('products')
              .doc(item.id),
          );

          const productSnapshots = await Promise.all(
            productRefs.map((productRef) => transaction.get(productRef)),
          );

          // ---------------------------------------------
          // RESTORE STOCK
          // ---------------------------------------------

          for (let index = 0; index < productSnapshots.length; index++) {
            const productSnapshot = productSnapshots[index];

            const orderItem = order.items[index];

            if (!productSnapshot.exists) {
              throw new NotFoundException(
                `Product ${orderItem.id} not found while restoring stock`,
              );
            }

            const product = productSnapshot.data() as ProductDocument;

            const restoredStock = product.stock + orderItem.quantity;

            transaction.update(productRefs[index], {
              stock: restoredStock,

              isAvailable: true,

              updatedAt,
            });

            this.logger.debug(
              `Restoring stock product=${orderItem.name} quantity=${orderItem.quantity} newStock=${restoredStock}`,
            );
          }

          // ---------------------------------------------
          // REJECT ORDER
          // ---------------------------------------------

          transaction.update(orderRef, {
            status: 'REJECTED',
            updatedAt,
          });

          rejectedOrder = order;
        });

        if (!rejectedOrder) {
          throw new Error('Rejected order details are missing');
        }

        this.logger.log(`Order rejected and stock restored orderId=${orderId}`);

        await this.notifyCustomerOrderStatus(rejectedOrder, 'REJECTED');

        // ------------------------------------------------
        // REFUND ONLINE PAID ORDER
        // ------------------------------------------------

        let refundStatus: string | null = null;

        if (
          rejectedOrder.paymentMethod === 'ONLINE' &&
          rejectedOrder.paymentStatus === 'PAID'
        ) {
          if (!rejectedOrder.paymentId) {
            this.logger.error(
              `Paid online order is missing paymentId orderId=${orderId}`,
            );

            throw new BadRequestException(
              'Order was rejected but payment information is missing',
            );
          }

          try {
            const refund = await this.razorpayRefundService.refundPayment(
              rejectedOrder.paymentId,
              'MERCHANT_REJECTED_ORDER',
            );

            refundStatus = refund.status;

            this.logger.log(
              `Refund requested for rejected order orderId=${orderId} paymentId=${rejectedOrder.paymentId} status=${refund.status}`,
            );
          } catch (refundError) {
            /*
             * Do NOT reverse the order rejection.
             *
             * Stock restoration and REJECTED status have
             * already completed successfully.
             */

            this.logger.error(
              `Order rejected but refund failed orderId=${orderId} paymentId=${rejectedOrder.paymentId}`,
              refundError instanceof Error
                ? refundError.stack
                : String(refundError),
            );

            return {
              success: true,

              orderId,

              status: 'REJECTED',

              refundStatus: 'REFUND_FAILED',

              message:
                'Order rejected successfully, but refund requires review.',

              updatedAt,
            };
          }
        }

        return {
          success: true,

          orderId,

          status: 'REJECTED',

          refundStatus,

          updatedAt,
        };
      }

      // --------------------------------------------------
      // NORMAL MERCHANT FLOW
      // --------------------------------------------------

      const snapshot = await orderRef.get();

      if (!snapshot.exists) {
        throw new NotFoundException('Order not found');
      }

      const order = {
        id: snapshot.id,
        ...snapshot.data(),
      } as OrderDocument;

      if (order.merchantId !== merchantId) {
        throw new ForbiddenException('You do not have access to this order');
      }

      const validTransitions: Record<string, string[]> = {
        VENDOR_PENDING: ['ACCEPTED'],

        ACCEPTED: ['PREPARING'],

        PREPARING: ['READY'],

        READY: [],
      };

      const allowedNextStatuses = validTransitions[order.status] ?? [];

      if (!allowedNextStatuses.includes(status)) {
        throw new BadRequestException(
          `Cannot change order from ${order.status} to ${status}`,
        );
      }

      const updatedAt = new Date().toISOString();

      await orderRef.update({
        status,
        updatedAt,
      });

      this.logger.log(
        `Order status updated orderId=${orderId} ${order.status} -> ${status}`,
      );

      await this.notifyCustomerOrderStatus(order, status);

      if (status === 'READY') {
        await this.notifyAvailableDeliveryPartners({
          ...order,
          status,
          updatedAt,
        });
      }

      return {
        success: true,

        orderId,

        status,

        updatedAt,
      };
    } catch (error) {
      if (
        error instanceof BadRequestException ||
        error instanceof NotFoundException ||
        error instanceof ForbiddenException
      ) {
        this.logger.warn(
          `Merchant status update failed merchantId=${merchantId} orderId=${orderId} status=${status}: ${error.message}`,
        );

        throw error;
      }

      this.logger.error(
        `Unexpected merchant status update failure merchantId=${merchantId} orderId=${orderId}`,
        error instanceof Error ? error.stack : String(error),
      );

      throw error;
    }
  }

  private async notifyCustomerOrderStatus(
    order: OrderDocument,
    status: string,
  ): Promise<void> {
    const notifications: Record<
      string,
      { title: string; body: string }
    > = {
      ACCEPTED: {
        title: 'Order Accepted',
        body: `${order.storeName} accepted your order.`,
      },
      PREPARING: {
        title: 'Preparing Your Order',
        body: `${order.storeName} is preparing your order.`,
      },
      READY: {
        title: 'Order Ready',
        body: 'Your order is ready for pickup by a delivery partner.',
      },
      REJECTED: {
        title: 'Order Rejected',
        body: `${order.storeName} could not accept your order.`,
      },
    };

    const notification = notifications[status];

    if (!notification) {
      return;
    }

    await this.notificationsService.sendToUser(order.customerId, {
      title: notification.title,
      body: notification.body,
      data: {
        type: 'ORDER_STATUS_CHANGED',
        orderId: order.id,
        status,
      },
    });
  }

  private async notifyCustomerDeliveryStatus(
    order: OrderDocument,
    status: string,
  ): Promise<void> {
    const notifications: Record<
      string,
      { title: string; body: string }
    > = {
      RIDER_ASSIGNED: {
        title: 'Delivery Partner Assigned',
        body: 'A delivery partner has been assigned to your order.',
      },
      PICKED_UP: {
        title: 'Order Picked Up',
        body: `Your order from ${order.storeName} has been picked up.`,
      },
      ON_THE_WAY: {
        title: 'Order On The Way',
        body: 'Your order is on the way.',
      },
      DELIVERED: {
        title: 'Order Delivered',
        body: 'Your order has been delivered successfully.',
      },
    };

    const notification = notifications[status];

    if (!notification) {
      return;
    }

    await this.notificationsService.sendToUser(order.customerId, {
      title: notification.title,
      body: notification.body,
      data: {
        type: 'DELIVERY_STATUS_CHANGED',
        orderId: order.id,
        status,
      },
    });
  }

  private async notifyAvailableDeliveryPartners(
    order: OrderDocument,
  ): Promise<void> {
    try {
      const db = this.firebaseService.getFirestore();

      const zoneId = order.deliveryAddress?.zoneId;

      if (!zoneId) {
        this.logger.warn(
          `Cannot notify riders - order has no zoneId orderId=${order.id}`,
        );
        return;
      }

      const partnersSnapshot = await db
        .collection('delivery_partners')
        .where('zoneId', '==', zoneId)
        .get();

      if (partnersSnapshot.empty) {
        this.logger.log(
          `No delivery partners found zoneId=${zoneId}`,
        );
        return;
      }

      const eligiblePartnerIds: string[] = [];

      for (const partnerDoc of partnersSnapshot.docs) {
        const partner = partnerDoc.data();

        if (
          partner.isOnline !== true ||
          partner.isAvailable !== true
        ) {
          continue;
        }

        const userSnapshot = await db
          .collection('users')
          .doc(partnerDoc.id)
          .get();

        if (!userSnapshot.exists) {
          continue;
        }

        const user = userSnapshot.data();

        if (
          user?.role !== 'DELIVERY' ||
          user?.status !== 'ACTIVE' ||
          user?.isActive !== true
        ) {
          continue;
        }

        eligiblePartnerIds.push(partnerDoc.id);
      }

      if (eligiblePartnerIds.length === 0) {
        this.logger.log(
          `No eligible delivery partners zoneId=${zoneId}`,
        );
        return;
      }

      await Promise.all(
        eligiblePartnerIds.map((riderId) =>
          this.notificationsService.sendToUser(riderId, {
            title: 'New Delivery Available',
            body: `A new delivery is ready from ${order.storeName}.`,
            data: {
              type: 'NEW_DELIVERY',
              orderId: order.id,
              storeId: order.storeId,
              zoneId,
            },
          }),
        ),
      );

      this.logger.log(
        `Delivery notification sent orderId=${order.id} riders=${eligiblePartnerIds.length}`,
      );
    } catch (error) {
      // Never fail merchant status update because FCM failed.
      this.logger.error(
        `Failed to notify delivery partners orderId=${order.id}`,
        error instanceof Error
          ? error.stack
          : String(error),
      );
    }
  }

  // --------------------------------------------------
  // DELIVERY
  // --------------------------------------------------

  async getDeliveryPartnerProfile(uid: string) {
    const db = this.firebaseService.getFirestore();

    const userSnapshot = await db
      .collection('users')
      .doc(uid)
      .get();

    if (!userSnapshot.exists) {
      throw new NotFoundException('User not found');
    }

    const user = userSnapshot.data();

    if (
      user?.role !== 'DELIVERY' ||
      user?.status !== 'ACTIVE' ||
      user?.isActive !== true
    ) {
      throw new ForbiddenException(
        'Delivery partner account is not active',
      );
    }

    const partnerRef = db
      .collection('delivery_partners')
      .doc(uid);

    const partnerSnapshot = await partnerRef.get();

    if (!partnerSnapshot.exists) {
      return {
        success: true,
        profile: {
          userId: uid,
          zoneId: null,
          isOnline: false,
          isAvailable: false,
        },
      };
    }

    return {
      success: true,
      profile: {
        userId: uid,
        ...partnerSnapshot.data(),
      },
    };
  }

  async updateDeliveryPartnerAvailability(
    uid: string,
    data: {
      zoneId?: string;
      isOnline?: boolean;
    },
  ) {
    const db = this.firebaseService.getFirestore();

    const userSnapshot = await db
      .collection('users')
      .doc(uid)
      .get();

    if (!userSnapshot.exists) {
      throw new NotFoundException('User not found');
    }

    const user = userSnapshot.data();

    if (
      user?.role !== 'DELIVERY' ||
      user?.status !== 'ACTIVE' ||
      user?.isActive !== true
    ) {
      throw new ForbiddenException(
        'Delivery partner account is not active',
      );
    }

    const partnerRef = db
      .collection('delivery_partners')
      .doc(uid);

    const existingSnapshot = await partnerRef.get();
    const existing = existingSnapshot.data();

    const zoneId =
      data.zoneId?.trim() ||
      existing?.zoneId ||
      null;

    if (!zoneId) {
      throw new BadRequestException(
        'Delivery zone is required',
      );
    }

    const zoneSnapshot = await db
      .collection('zones')
      .doc(zoneId)
      .get();

    if (!zoneSnapshot.exists) {
      throw new BadRequestException('Invalid delivery zone');
    }

    const zone = zoneSnapshot.data();

    if (zone?.isActive !== true) {
      throw new BadRequestException(
        'Delivery zone is not active',
      );
    }

    const isOnline =
      data.isOnline ?? existing?.isOnline ?? false;

    const now = new Date().toISOString();

    const profile = {
      userId: uid,
      zoneId,
      isOnline,
      isAvailable: isOnline,
      updatedAt: now,
      ...(!existingSnapshot.exists
        ? { createdAt: now }
        : {}),
    };

    await partnerRef.set(profile, { merge: true });

    return {
      success: true,
      profile,
    };
  }

  private buildDeliveryOrderResponse(
    order: OrderDocument,
    riderId: string,
  ) {
    const {
      customerId: _customerId,
      paymentId: _paymentId,
      providerPaymentId: _providerPaymentId,
      deliveryOtp: _deliveryOtp,
      deliveryOtpHash: _deliveryOtpHash,
      deliveryOtpCreatedAt: _deliveryOtpCreatedAt,
      deliveryOtpExpiresAt: _deliveryOtpExpiresAt,
      deliveryOtpAttempts: _deliveryOtpAttempts,
      deliveryOtpLockedUntil: _deliveryOtpLockedUntil,
      ...safeOrder
    } = order;

    const isAssignedToRider = order.riderId === riderId;

    return {
      ...safeOrder,
      deliveryAddress: isAssignedToRider
        ? {
            label: order.deliveryAddress.label,
            address: order.deliveryAddress.address,
            latitude: order.deliveryAddress.latitude,
            longitude: order.deliveryAddress.longitude,
            zoneId: order.deliveryAddress.zoneId,
          }
        : {
            label: 'Delivery area',
            address:
              'Exact delivery address will be visible after accepting the order',
            latitude: null,
            longitude: null,
            zoneId: order.deliveryAddress.zoneId,
          },
    };
  }

  async getDeliveryOrders(riderId: string) {
    const db = this.firebaseService.getFirestore();

    const userSnapshot = await db
      .collection('users')
      .doc(riderId)
      .get();

    if (!userSnapshot.exists) {
      throw new NotFoundException('User not found');
    }

    const user = userSnapshot.data();

    if (
      user?.role !== 'DELIVERY' ||
      user?.status !== 'ACTIVE' ||
      user?.isActive !== true
    ) {
      throw new ForbiddenException(
        'Delivery partner account is not active',
      );
    }

    const partnerSnapshot = await db
      .collection('delivery_partners')
      .doc(riderId)
      .get();

    const partner = partnerSnapshot.data();

    const snapshot = await db
      .collection('orders')
      .where('status', 'in', [
        'READY',
        'RIDER_ASSIGNED',
        'PICKED_UP',
        'ON_THE_WAY',
      ])
      .get();

    const orders: OrderDocument[] = snapshot.docs
      .map((doc) => {
        const data = doc.data() as Omit<OrderDocument, 'id'>;

        return {
          id: doc.id,
          ...data,
        };
      })
      .filter((order) => {
        // Rider's current assigned order must remain visible.
        if (order.riderId === riderId) {
          return true;
        }

        // New orders are shown only to online, available riders in the same zone.
        if (
          order.status === 'READY' &&
          order.riderId == null &&
          partner?.isOnline === true &&
          partner?.isAvailable === true &&
          typeof partner?.zoneId === 'string' &&
          partner.zoneId === order.deliveryAddress.zoneId
        ) {
          return true;
        }

        return false;
      });

    orders.sort((a, b) => b.createdAt.localeCompare(a.createdAt));

    return {
      success: true,
      orders: orders.map((order) =>
        this.buildDeliveryOrderResponse(order, riderId),
      ),
    };
  }

  async getDeliveryHistory(riderId: string) {
    const snapshot = await this.firebaseService.getFirestore()
      .collection('orders').where('riderId', '==', riderId).get();
    const orders = snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() } as OrderDocument))
      .filter((order) => order.status === 'DELIVERED')
      .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
    return { success: true, orders: orders.map((order) => this.buildDeliveryOrderResponse(order, riderId)) };
  }

  async acceptDeliveryOrder(
    orderId: string,
    riderId: string,
  ) {
    const db = this.firebaseService.getFirestore();

    const orderRef =
      db.collection('orders').doc(orderId);

    const partnerRef = db
      .collection('delivery_partners')
      .doc(riderId);

    const userRef =
      db.collection('users').doc(riderId);

    const updatedAt = new Date().toISOString();

    await db.runTransaction(async (transaction) => {
      const [
        orderSnapshot,
        partnerSnapshot,
        userSnapshot,
      ] = await Promise.all([
        transaction.get(orderRef),
        transaction.get(partnerRef),
        transaction.get(userRef),
      ]);

      if (!userSnapshot.exists) {
        throw new NotFoundException(
          'Delivery partner not found',
        );
      }

      const user = userSnapshot.data();

      if (
        user?.role !== 'DELIVERY' ||
        user?.status !== 'ACTIVE' ||
        user?.isActive !== true
      ) {
        throw new ForbiddenException(
          'Delivery partner account is not active',
        );
      }

      if (!partnerSnapshot.exists) {
        throw new BadRequestException(
          'Delivery partner profile is not configured',
        );
      }

      const partner = partnerSnapshot.data();

      if (
        partner?.isOnline !== true ||
        partner?.isAvailable !== true
      ) {
        throw new BadRequestException(
          'Delivery partner is not available',
        );
      }

      if (!orderSnapshot.exists) {
        throw new NotFoundException(
          'Order not found',
        );
      }

      const order = {
        id: orderSnapshot.id,
        ...orderSnapshot.data(),
      } as OrderDocument;

      if (order.status !== 'READY') {
        throw new BadRequestException(
          `Order cannot be accepted from status ${order.status}`,
        );
      }

      if (order.riderId) {
        throw new BadRequestException(
          'Order has already been assigned to a rider',
        );
      }

      if (
        !partner?.zoneId ||
        partner.zoneId !== order.deliveryAddress.zoneId
      ) {
        throw new ForbiddenException(
          'Order is outside your delivery zone',
        );
      }

      transaction.update(orderRef, {
        riderId,
        status: 'RIDER_ASSIGNED',
        updatedAt,
      });

      transaction.update(partnerRef, {
        isAvailable: false,
        updatedAt,
      });
    });

    const updatedOrderSnapshot = await orderRef.get();

    if (updatedOrderSnapshot.exists) {
      const updatedOrder = {
        id: updatedOrderSnapshot.id,
        ...updatedOrderSnapshot.data(),
      } as OrderDocument;

      await this.notifyCustomerDeliveryStatus(
        updatedOrder,
        'RIDER_ASSIGNED',
      );
    }

    return {
      success: true,
      orderId,
      riderId,
      status: 'RIDER_ASSIGNED',
      updatedAt,
    };
  }

  async updateDeliveryStatus(orderId: string, riderId: string, status: string) {
    const allowedStatuses = ['PICKED_UP', 'ON_THE_WAY'];

    if (!allowedStatuses.includes(status)) {
      throw new BadRequestException('Invalid delivery status');
    }

    const db = this.firebaseService.getFirestore();

    const orderRef = db.collection('orders').doc(orderId);

    const snapshot = await orderRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException('Order not found');
    }

    const order = snapshot.data() as OrderDocument;

    if (order.riderId !== riderId) {
      throw new ForbiddenException('This order is not assigned to you');
    }

    const validTransitions: Record<string, string[]> = {
      RIDER_ASSIGNED: ['PICKED_UP'],
      PICKED_UP: ['ON_THE_WAY'],
      ON_THE_WAY: [],
    };

    const allowedNextStatuses = validTransitions[order.status] ?? [];

    if (!allowedNextStatuses.includes(status)) {
      throw new BadRequestException(
        `Cannot change delivery status from ${order.status} to ${status}`,
      );
    }

    const updatedAt = new Date().toISOString();

    await orderRef.update({
      status,
      updatedAt,
    });

    const updatedOrder: OrderDocument = {
      ...order,
      id: snapshot.id,
      status,
      updatedAt,
    };

    await this.notifyCustomerDeliveryStatus(
      updatedOrder,
      status,
    );

    return {
      success: true,
      orderId,
      riderId,
      status,
      updatedAt,
    };
  }

  private getDeliveryOtpSecret(): string {
    const secret = this.configService.get<string>('DELIVERY_OTP_SECRET');

    if (!secret?.trim()) {
      throw new Error('DELIVERY_OTP_SECRET configuration is missing');
    }

    return secret;
  }

  private hashDeliveryOtp(orderId: string, otp: string): string {
    return createHmac('sha256', this.getDeliveryOtpSecret())
      .update(`${orderId}:${otp}`)
      .digest('hex');
  }

  private isDeliveryOtpMatch(
    orderId: string,
    otp: string,
    storedHash: string,
  ): boolean {
    const suppliedBuffer = Buffer.from(
      this.hashDeliveryOtp(orderId, otp),
      'hex',
    );
    const storedBuffer = Buffer.from(storedHash, 'hex');

    if (suppliedBuffer.length !== storedBuffer.length) {
      return false;
    }

    return timingSafeEqual(suppliedBuffer, storedBuffer);
  }

  async generateDeliveryOtp(orderId: string, riderId: string) {
    const db = this.firebaseService.getFirestore();
    const orderRef = db.collection('orders').doc(orderId);

    const otp = randomInt(
      10 ** (OrdersService.DELIVERY_OTP_LENGTH - 1),
      10 ** OrdersService.DELIVERY_OTP_LENGTH,
    ).toString();
    const otpHash = this.hashDeliveryOtp(orderId, otp);
    const now = new Date();
    const deliveryOtpCreatedAt = now.toISOString();
    const deliveryOtpExpiresAt = new Date(
      now.getTime() + OrdersService.DELIVERY_OTP_EXPIRY_MS,
    ).toISOString();

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(orderRef);

      if (!snapshot.exists) {
        throw new NotFoundException('Order not found');
      }

      const order = {
        id: snapshot.id,
        ...snapshot.data(),
      } as OrderDocument;

      if (order.riderId !== riderId) {
        throw new ForbiddenException('This order is not assigned to you');
      }

      if (order.status !== 'ON_THE_WAY') {
        throw new BadRequestException(
          'Delivery OTP can only be generated when order is on the way',
        );
      }

      const lockedUntilMs = order.deliveryOtpLockedUntil
        ? Date.parse(order.deliveryOtpLockedUntil)
        : 0;

      if (Number.isFinite(lockedUntilMs) && lockedUntilMs > now.getTime()) {
        throw new BadRequestException(
          'Delivery OTP verification is temporarily locked. Please try again later.',
        );
      }

      const existingExpiryMs = order.deliveryOtpExpiresAt
        ? Date.parse(order.deliveryOtpExpiresAt)
        : 0;

      if (
        order.deliveryOtpHash &&
        Number.isFinite(existingExpiryMs) &&
        existingExpiryMs > now.getTime()
      ) {
        throw new BadRequestException(
          'A delivery OTP is already active for this order',
        );
      }

      transaction.update(orderRef, {
        deliveryOtp: null,
        deliveryOtpHash: otpHash,
        deliveryOtpCreatedAt,
        deliveryOtpExpiresAt,
        deliveryOtpAttempts: 0,
        deliveryOtpLockedUntil: null,
        updatedAt: deliveryOtpCreatedAt,
      });
    });

    const orderSnapshot = await orderRef.get();
    if (orderSnapshot.exists) {
      const order = { id: orderSnapshot.id, ...orderSnapshot.data() } as OrderDocument;
      await this.notificationsService.sendToUser(order.customerId, {
        title: 'Delivery OTP',
        body: `Your delivery OTP is ${otp}. Share it only after receiving your order.`,
        data: { type: 'DELIVERY_OTP', orderId, expiresAt: deliveryOtpExpiresAt },
      });
    }

    const response: {
      success: true;
      orderId: string;
      expiresAt: string;
      maxAttempts: number;
      otp?: string;
    } = {
      success: true,
      orderId,
      expiresAt: deliveryOtpExpiresAt,
      maxAttempts: OrdersService.DELIVERY_OTP_MAX_ATTEMPTS,
    };

    if (this.configService.get<string>('NODE_ENV') !== 'production') {
      response.otp = otp;
    }

    return response;
  }

  async verifyDeliveryOtp(orderId: string, riderId: string, otp: string) {
    const normalizedOtp = otp?.trim();

    if (!normalizedOtp || !/^\d{4}$/.test(normalizedOtp)) {
      throw new BadRequestException(
        'A valid 4-digit delivery OTP is required',
      );
    }

    const db = this.firebaseService.getFirestore();
    const orderRef = db.collection('orders').doc(orderId);
    const partnerRef = db.collection('delivery_partners').doc(riderId);
    const now = new Date();
    const updatedAt = now.toISOString();

    type VerificationResult =
      | { type: 'SUCCESS'; order: OrderDocument }
      | { type: 'INVALID'; remainingAttempts: number }
      | { type: 'LOCKED'; lockedUntil: string }
      | { type: 'EXPIRED' };

    const result = await db.runTransaction<VerificationResult>(
      async (transaction) => {
        const orderSnapshot = await transaction.get(orderRef);
        const partnerSnapshot = await transaction.get(partnerRef);

        if (!orderSnapshot.exists) {
          throw new NotFoundException('Order not found');
        }

        const order = {
          id: orderSnapshot.id,
          ...orderSnapshot.data(),
        } as OrderDocument;

        if (order.riderId !== riderId) {
          throw new ForbiddenException('This order is not assigned to you');
        }

        if (order.status !== 'ON_THE_WAY') {
          throw new BadRequestException(
            'Order is not ready for delivery verification',
          );
        }

        if (!order.deliveryOtpHash) {
          throw new BadRequestException(
            'Delivery OTP has not been generated',
          );
        }

        const lockedUntilMs = order.deliveryOtpLockedUntil
          ? Date.parse(order.deliveryOtpLockedUntil)
          : 0;

        if (Number.isFinite(lockedUntilMs) && lockedUntilMs > now.getTime()) {
          return {
            type: 'LOCKED',
            lockedUntil: order.deliveryOtpLockedUntil!,
          };
        }

        const expiryMs = order.deliveryOtpExpiresAt
          ? Date.parse(order.deliveryOtpExpiresAt)
          : 0;

        if (!Number.isFinite(expiryMs) || expiryMs <= now.getTime()) {
          return { type: 'EXPIRED' };
        }

        const isValid = this.isDeliveryOtpMatch(
          orderId,
          normalizedOtp,
          order.deliveryOtpHash,
        );

        if (!isValid) {
          const currentAttempts =
            typeof order.deliveryOtpAttempts === 'number'
              ? order.deliveryOtpAttempts
              : 0;
          const nextAttempts = currentAttempts + 1;

          if (nextAttempts >= OrdersService.DELIVERY_OTP_MAX_ATTEMPTS) {
            const lockedUntil = new Date(
              now.getTime() + OrdersService.DELIVERY_OTP_LOCK_MS,
            ).toISOString();

            transaction.update(orderRef, {
              deliveryOtpAttempts: nextAttempts,
              deliveryOtpLockedUntil: lockedUntil,
              updatedAt,
            });

            return { type: 'LOCKED', lockedUntil };
          }

          transaction.update(orderRef, {
            deliveryOtpAttempts: nextAttempts,
            updatedAt,
          });

          return {
            type: 'INVALID',
            remainingAttempts:
              OrdersService.DELIVERY_OTP_MAX_ATTEMPTS - nextAttempts,
          };
        }

        transaction.update(orderRef, {
          status: 'DELIVERED',
          deliveryOtp: null,
          deliveryOtpHash: null,
          deliveryOtpCreatedAt: null,
          deliveryOtpExpiresAt: null,
          deliveryOtpAttempts: 0,
          deliveryOtpLockedUntil: null,
          updatedAt,
        });

        if (partnerSnapshot.exists) {
          const partner = partnerSnapshot.data();

          transaction.update(partnerRef, {
            isAvailable: partner?.isOnline === true,
            updatedAt,
          });
        }

        return {
          type: 'SUCCESS',
          order: {
            ...order,
            status: 'DELIVERED',
            deliveryOtp: null,
            deliveryOtpHash: null,
            deliveryOtpCreatedAt: null,
            deliveryOtpExpiresAt: null,
            deliveryOtpAttempts: 0,
            deliveryOtpLockedUntil: null,
            updatedAt,
          },
        };
      },
    );

    if (result.type === 'EXPIRED') {
      throw new BadRequestException(
        'Delivery OTP has expired. Generate a new OTP.',
      );
    }

    if (result.type === 'INVALID') {
      throw new BadRequestException(
        `Invalid delivery OTP. ${result.remainingAttempts} attempts remaining.`,
      );
    }

    if (result.type === 'LOCKED') {
      throw new BadRequestException(
        `Too many invalid OTP attempts. Try again after ${result.lockedUntil}.`,
      );
    }

    await this.notifyCustomerDeliveryStatus(result.order, 'DELIVERED');

    return {
      success: true,
      orderId,
      status: 'DELIVERED',
      updatedAt,
    };
  }

  private async getDeliveryFee(): Promise<number> {
    const db = this.firebaseService.getFirestore();

    const snapshot = await db.collection('settings').doc('global').get();

    if (!snapshot.exists) {
      return 40;
    }

    const data = snapshot.data();

    const deliveryFee = data?.deliveryFee;

    if (
      typeof deliveryFee !== 'number' ||
      !Number.isFinite(deliveryFee) ||
      deliveryFee < 0
    ) {
      return 40;
    }

    return deliveryFee;
  }

  async cancelOrder(customerId: string, orderId: string) {
    const db = this.firebaseService.getFirestore();

    const orderRef = db.collection('orders').doc(orderId);

    const updatedAt = new Date().toISOString();

    let cancelledOrder: OrderDocument | undefined;

    await db.runTransaction(async (transaction) => {
      const orderSnapshot = await transaction.get(orderRef);

      if (!orderSnapshot.exists) {
        throw new NotFoundException('Order not found');
      }

      const order = {
        id: orderSnapshot.id,
        ...orderSnapshot.data(),
      } as OrderDocument;

      if (order.customerId !== customerId) {
        throw new ForbiddenException('You do not have access to this order');
      }

      /*
       * MVP rule:
       * customer may cancel only before
       * merchant accepts the order.
       */
      if (order.status !== 'VENDOR_PENDING') {
        throw new BadRequestException(
          `Cannot cancel order from ${order.status}`,
        );
      }

      const productRefs = order.items.map((item) =>
        db
          .collection('stores')
          .doc(order.storeId)
          .collection('products')
          .doc(item.id),
      );

      const productSnapshots = await Promise.all(
        productRefs.map((productRef) => transaction.get(productRef)),
      );

      for (let index = 0; index < productSnapshots.length; index++) {
        const productSnapshot = productSnapshots[index];

        const orderItem = order.items[index];

        if (!productSnapshot.exists) {
          throw new NotFoundException(
            `Product ${orderItem.id} not found while restoring stock`,
          );
        }

        const product = productSnapshot.data() as ProductDocument;

        const restoredStock = product.stock + orderItem.quantity;

        transaction.update(productRefs[index], {
          stock: restoredStock,

          isAvailable: true,

          updatedAt,
        });
      }

      transaction.update(orderRef, {
        status: 'CANCELLED',
        updatedAt,
      });

      cancelledOrder = order;
    });

    if (!cancelledOrder) {
      throw new Error('Cancelled order details are missing');
    }

    this.logger.log(
      `Customer cancelled order orderId=${orderId} customerId=${customerId}`,
    );

    let refundStatus: string | null = null;

    /*
     * COD:
     * no refund required.
     *
     * ONLINE + PAID:
     * trigger Razorpay refund.
     */
    if (
      cancelledOrder.paymentMethod === 'ONLINE' &&
      cancelledOrder.paymentStatus === 'PAID'
    ) {
      if (!cancelledOrder.paymentId) {
        this.logger.error(
          `Cancelled paid online order is missing paymentId orderId=${orderId}`,
        );

        return {
          success: true,

          orderId,

          status: 'CANCELLED',

          refundStatus: 'REFUND_FAILED',

          message: 'Order cancelled but payment information is missing.',

          updatedAt,
        };
      }

      try {
        const refund = await this.razorpayRefundService.refundPayment(
          cancelledOrder.paymentId,
          'CUSTOMER_CANCELLED_ORDER',
        );

        refundStatus = refund.status;

        this.logger.log(
          `Refund requested for cancelled order orderId=${orderId} paymentId=${cancelledOrder.paymentId} status=${refund.status}`,
        );
      } catch (refundError) {
        this.logger.error(
          `Order cancelled but refund failed orderId=${orderId} paymentId=${cancelledOrder.paymentId}`,
          refundError instanceof Error
            ? refundError.stack
            : String(refundError),
        );

        return {
          success: true,

          orderId,

          status: 'CANCELLED',

          refundStatus: 'REFUND_FAILED',

          message: 'Order cancelled successfully, but refund requires review.',

          updatedAt,
        };
      }
    }

    return {
      success: true,

      orderId,

      status: 'CANCELLED',

      refundStatus,

      updatedAt,
    };
  }
}
